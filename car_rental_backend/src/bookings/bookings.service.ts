import {
  Injectable,
  NotFoundException,
  ConflictException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import {
  BookingStatus,
  Role,
  TripType,
  PaymentStatus,
  VerificationStatus,
  InspectionType,
  HandoverOtpType,
  Prisma,
} from '@prisma/client';
import { PaginationDto } from '../common/pagination.dto';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CancellationPolicyService } from './cancellation-policy.service';
import { redactVendor } from '../common/vendor-redactor.util';
import { AuditLogService } from '../admin/audit-log.service';
import { HandoverOtpService } from './handover-otp.service';
import { CouponsService } from '../coupons/coupons.service';
import { DepositRulesService } from '../deposits/deposit-rules.service';
import { InvoicesService } from '../invoices/invoices.service';
import { ReferralsService } from '../referrals/referrals.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import { Optional } from '@nestjs/common';
import { SecurityDepositStatus } from '@prisma/client';

@Injectable()
export class BookingsService {
  private readonly logger = new Logger(BookingsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly bookingLockService: BookingLockService,
    private readonly commissionResolver: CommissionResolverService,
    private readonly fareCalculator: FareCalculatorService,
    private readonly paymentsService: PaymentsService,
    private readonly notificationsService: NotificationsService,
    private readonly cancellationPolicyService: CancellationPolicyService,
    private readonly auditLogService: AuditLogService,
    private readonly handoverOtpService: HandoverOtpService,
    private readonly couponsService: CouponsService,
    @Optional() private readonly depositRulesService?: DepositRulesService,
    @Optional() private readonly invoicesService?: InvoicesService,
    @Optional() private readonly referralsService?: ReferralsService,
    @Optional() private readonly loyaltyService?: LoyaltyService,
  ) {}

  async createBooking(customerId: string, dto: CreateBookingDto) {
    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);

    if (start >= end) {
      throw new BadRequestException('Start date must be before end date.');
    }

    if (start < new Date()) {
      throw new BadRequestException('Start date cannot be in the past.');
    }

    // Validate if platform enabledTripTypes allows this tripType
    let settings = await this.prisma.platformSettings.findUnique({
      where: { id: 'singleton' },
    });
    if (!settings) {
      settings = await this.prisma.platformSettings.create({
        data: {
          id: 'singleton',
          platformName: 'DriveGo',
          gstNumber: '27AAAAA1111A1Z1',
          supportEmail: 'support@drivego.in',
          supportPhone: '+919876543210',
          appVersion: '1.0.0',
          enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
        },
      });
    }

    if (!settings.enabledTripTypes.includes(dto.tripType)) {
      throw new BadRequestException(
        'This trip type is not currently available',
      );
    }

    // 1. Acquire Redis distributed car lock
    const lockToken = await this.bookingLockService.acquireLock(dto.carId);

    try {
      // Fetch car outside of the transaction to do validations and resolve fares
      const car = await this.prisma.car.findUnique({
        where: { id: dto.carId },
        include: { vendor: true },
      });

      if (!car) {
        throw new NotFoundException('Car not found.');
      }

      if (car.vendor?.verificationStatus !== VerificationStatus.VERIFIED) {
        throw new BadRequestException(
          'Cannot book a vehicle from an unverified vendor.',
        );
      }

      if (!car.isAvailable) {
        throw new ConflictException('This car is marked as unavailable.');
      }

      // Check if tripType is supported by the car
      if (!car.availableTripTypes.includes(dto.tripType)) {
        throw new BadRequestException(
          `This car does not support ${dto.tripType} trip type.`,
        );
      }

      // Check blockedDates range overlap
      const hasBlockedDate = car.blockedDates.some((blockedDate) => {
        const bTime = blockedDate.getTime();
        return bTime >= start.getTime() && bTime <= end.getTime();
      });

      if (hasBlockedDate) {
        throw new ConflictException(
          'The requested date range conflicts with blocked dates for this car.',
        );
      }

      // 3. Resolve commission percentage outside the transaction
      const commissionPercent =
        await this.commissionResolver.resolveCommissionPercent(
          car.vendor.city,
          car.type,
          dto.tripType,
        );

      // 4. Calculate fare details outside the transaction
      const durationMs = end.getTime() - start.getTime();
      const durationDays = Math.max(
        1,
        Math.ceil(durationMs / (1000 * 60 * 60 * 24)),
      );
      let basePackagePrice = new Prisma.Decimal(0);

      if (
        dto.tripType === TripType.LOCAL ||
        dto.tripType === TripType.AIRPORT_TRANSFER
      ) {
        const durationHours = Math.ceil(durationMs / (1000 * 60 * 60));
        basePackagePrice = car.pricePerHour.mul(durationHours);
      } else {
        basePackagePrice = car.pricePerDay.mul(durationDays);
      }

      const distance = dto.distanceKm
        ? new Prisma.Decimal(dto.distanceKm)
        : new Prisma.Decimal(0);

      const fareDetails = this.fareCalculator.calculateFare(
        distance,
        basePackagePrice,
        car.pricePerKm,
        commissionPercent,
        durationDays,
        car.weeklyDiscountPercent || 0,
        car.monthlyDiscountPercent || 0,
      );

      const deliveryFee = dto.deliveryFee ? new Prisma.Decimal(dto.deliveryFee) : new Prisma.Decimal(0);
      const pickupFee = dto.pickupFee ? new Prisma.Decimal(dto.pickupFee) : new Prisma.Decimal(0);
      const totalDeliveryAddons = deliveryFee.add(pickupFee);

      const baseTotalDecimal =
        fareDetails.total instanceof Prisma.Decimal
          ? fareDetails.total
          : new Prisma.Decimal(Number(fareDetails.total || 0));

      const baseNetToVendorDecimal =
        fareDetails.netToVendor instanceof Prisma.Decimal
          ? fareDetails.netToVendor
          : new Prisma.Decimal(Number(fareDetails.netToVendor || 0));

      // Validate coupon if code provided
      let validatedCoupon: any = null;
      let finalTotalFare = baseTotalDecimal.add(totalDeliveryAddons);
      let discountAmountDecimal: Prisma.Decimal | null = null;

      if (dto.couponCode) {
        validatedCoupon = await this.couponsService.validateCoupon(customerId, {
          code: dto.couponCode,
          carId: dto.carId,
          subtotal: Number(fareDetails.total),
          city: car.vendor.city,
          tripType: dto.tripType,
          carCategory: car.type,
        });

        discountAmountDecimal = new Prisma.Decimal(validatedCoupon.discountAmount);
        const netPayable = Math.max(0, Number(fareDetails.total) - validatedCoupon.discountAmount) + totalDeliveryAddons.toNumber();
        finalTotalFare = new Prisma.Decimal(netPayable);
      } else if (this.referralsService) {
        // Check Referee First-Booking Referral Benefit
        const eligibility = await this.referralsService.getRefereeEligibility(customerId);
        if (eligibility.eligible && Number(fareDetails.total) >= eligibility.minBookingAmount) {
          discountAmountDecimal = new Prisma.Decimal(eligibility.discountAmount);
          const netPayable = Math.max(0, Number(fareDetails.total) - eligibility.discountAmount) + totalDeliveryAddons.toNumber();
          finalTotalFare = new Prisma.Decimal(netPayable);
        }
      }

      // Resolve Protection Package if selected
      let protectionPackage: any = null;
      let protectionFeeDecimal = new Prisma.Decimal(0);
      let protectionDeductibleDecimal: Prisma.Decimal | null = null;
      let protectionCode: string | null = null;

      if (dto.protectionPackageId) {
        protectionPackage = await this.prisma.protectionPackage.findUnique({
          where: { id: dto.protectionPackageId },
        });
        if (protectionPackage && protectionPackage.isActive) {
          if (!protectionPackage.city || protectionPackage.city === car.vendor.city) {
            protectionFeeDecimal = protectionPackage.dailyRate.mul(durationDays);
            protectionDeductibleDecimal = protectionPackage.deductibleAmount;
            protectionCode = protectionPackage.code;
            finalTotalFare = finalTotalFare.add(protectionFeeDecimal);
          }
        }
      }

      // Calculate authoritative dynamic security deposit requirement
      let depositAmount = 5000;
      if (this.depositRulesService) {
        depositAmount = await this.depositRulesService.getDepositAmount(
          car.type,
          car.vendor?.city,
        );
      }

      // 2. Perform transactional double-booking check and creation (with 15s timeout to support slow pg_bouncer pools)
      const booking = await this.prisma.$transaction(
        async (tx) => {
          // Tier 2: Acquire pessimistic database row-level lock on the Car record to serialize concurrent transactions
          await tx.$queryRaw`SELECT id FROM "Car" WHERE id = ${dto.carId} FOR UPDATE`;

          // Check overlapping bookings
          const overlappingBooking = await tx.booking.findFirst({
            where: {
              carId: dto.carId,
              status: {
                in: [
                  BookingStatus.PENDING,
                  BookingStatus.CONFIRMED,
                  BookingStatus.ONGOING,
                ],
              },
              AND: [{ startDate: { lt: end } }, { endDate: { gt: start } }],
            },
          });

          if (overlappingBooking) {
            throw new ConflictException(
              'This car is already booked during the selected date range.',
            );
          }

          // 5. Create booking row with dynamic security deposit and delivery options
          const newBooking = await tx.booking.create({
            data: {
              customerId,
              vendorId: car.vendorId,
              carId: dto.carId,
              tripType: dto.tripType,
              pickupLocation: dto.pickupLocation,
              dropLocation: dto.dropLocation,
              startDate: start,
              endDate: end,
              distanceKm: dto.distanceKm ? distance : null,
              baseFare: fareDetails.baseFare,
              platformFee: fareDetails.platformFee,
              gstAmount: fareDetails.gst,
              totalFare: finalTotalFare,
              netToVendor: baseNetToVendorDecimal.add(totalDeliveryAddons),
              driverIncluded: dto.driverIncluded ?? true,
              childSeat: dto.childSeat ?? false,
              extraLuggage: dto.extraLuggage ?? false,
              deliveryType: dto.deliveryType ?? 'NONE',
              deliveryAddress: dto.deliveryAddress,
              deliveryLatitude: dto.deliveryLatitude,
              deliveryLongitude: dto.deliveryLongitude,
              deliveryFee,
              pickupAddress: dto.pickupAddress,
              pickupLatitude: dto.pickupLatitude,
              pickupLongitude: dto.pickupLongitude,
              pickupFee,
              protectionPackageId: protectionPackage ? protectionPackage.id : null,
              protectionCode,
              protectionFee: protectionFeeDecimal,
              protectionDeductible: protectionDeductibleDecimal,
              couponId: validatedCoupon ? validatedCoupon.couponId : null,
              couponCode: validatedCoupon ? validatedCoupon.code : null,
              discountAmount: discountAmountDecimal,
              status: BookingStatus.PENDING,
              securityDeposit: {
                create: {
                  amount: new Prisma.Decimal(depositAmount),
                  status: SecurityDepositStatus.REQUIRED,
                },
              },
            },
            include: {
              car: true,
              customer: {
                select: {
                  id: true,
                  name: true,
                  phone: true,
                  email: true,
                },
              },
              securityDeposit: true,
            },
          });

          return newBooking;
        },
        {
          timeout: 15000,
        },
      );

      // After transaction completes, notify vendor
      const vendorUser = await this.prisma.vendor.findUnique({
        where: { id: booking.vendorId },
        select: { userId: true },
      });
      if (vendorUser && vendorUser.userId) {
        this.notificationsService
          .notifyUser(
            vendorUser.userId,
            'New Booking Request',
            `You have received a new booking request for ${booking.car.make} ${booking.car.model} (${booking.car.registrationNumber}).`,
          )
          .catch((err) =>
            this.logger.error('Failed to notify vendor of new booking', err),
          );
      }

      return booking;
    } finally {
      // 6. Release car-level lock
      await this.bookingLockService.releaseLock(dto.carId, lockToken);
    }
  }

  async getBookingById(
    id: string,
    requestingUser: { userId: string; role: Role },
  ) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        car: true,
        customer: true,
        vendor: {
          include: {
            user: {
              select: {
                id: true,
                name: true,
                email: true,
                profilePhotoUrl: true,
              },
            },
          },
        },
        payment: true,
      },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    const isCustomer = booking.customerId === requestingUser.userId;
    const isVendor = booking.vendor.userId === requestingUser.userId;
    const isStaff =
      requestingUser.role === Role.ADMIN ||
      requestingUser.role === Role.SUPPORT_AGENT;

    if (!isCustomer && !isVendor && !isStaff) {
      throw new ForbiddenException(
        'Access denied: You are not authorized to view this booking.',
      );
    }

    return this.redactVendorInBooking(booking, requestingUser);
  }

  async getBookingsForCustomer(
    customerId: string,
    statusFilter?: BookingStatus,
    pagination?: PaginationDto,
  ) {
    const page = pagination?.page ?? 1;
    const limit = pagination?.limit ?? 10;
    const skip = (page - 1) * limit;
    const take = limit;

    const where: Prisma.BookingWhereInput = {
      customerId,
      ...(statusFilter ? { status: statusFilter } : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.booking.findMany({
        where,
        include: {
          car: true,
          vendor: {
            include: {
              user: {
                select: {
                  id: true,
                  name: true,
                  email: true,
                  profilePhotoUrl: true,
                },
              },
            },
          },
          payment: true,
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.booking.count({ where }),
    ]);

    const redactedData = this.redactVendorInBooking(data, {
      userId: customerId,
      role: Role.CUSTOMER,
    });

    return {
      data: redactedData,
      total,
      page,
      totalPages: Math.ceil(total / take),
    };
  }

  async getBookingsForVendor(
    vendorUserId: string,
    statusFilter?: BookingStatus,
    pagination?: PaginationDto,
  ) {
    const page = pagination?.page ?? 1;
    const limit = pagination?.limit ?? 10;
    const skip = (page - 1) * limit;
    const take = limit;

    const vendor = await this.prisma.vendor.findUnique({
      where: { userId: vendorUserId },
    });

    if (!vendor) {
      throw new NotFoundException('Vendor profile not found.');
    }

    const where: Prisma.BookingWhereInput = {
      vendorId: vendor.id,
      ...(statusFilter ? { status: statusFilter } : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.booking.findMany({
        where,
        include: {
          car: true,
          customer: {
            select: {
              id: true,
              name: true,
              phone: true,
              email: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.booking.count({ where }),
    ]);

    return {
      data,
      total,
      page,
      totalPages: Math.ceil(total / take),
    };
  }

  async getBookingsForAdmin(
    filters: {
      city?: string;
      startDate?: string;
      endDate?: string;
      tripType?: TripType;
      status?: BookingStatus;
      vendorId?: string;
      carType?: string;
    },
    pagination?: PaginationDto,
  ) {
    const page = pagination?.page ?? 1;
    const limit = pagination?.limit ?? 10;
    const skip = (page - 1) * limit;
    const take = limit;

    const where: Prisma.BookingWhereInput = {
      ...(filters.status ? { status: filters.status } : {}),
      ...(filters.tripType ? { tripType: filters.tripType } : {}),
      ...(filters.vendorId ? { vendorId: filters.vendorId } : {}),
      ...(filters.carType ? { car: { type: filters.carType as any } } : {}),
      ...(filters.city
        ? {
            car: {
              vendor: { city: { equals: filters.city, mode: 'insensitive' } },
            },
          }
        : {}),
      ...(filters.startDate && filters.endDate
        ? {
            startDate: { gte: new Date(filters.startDate) },
            endDate: { lte: new Date(filters.endDate) },
          }
        : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.booking.findMany({
        where,
        include: {
          car: true,
          customer: true,
          vendor: true,
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.booking.count({ where }),
    ]);

    return {
      data,
      total,
      page,
      totalPages: Math.ceil(total / take),
    };
  }

  async updateStatus(
    bookingId: string,
    newStatus: BookingStatus,
    requestingUser: { userId: string; role: Role },
    reason?: string,
    handoverOtp?: string,
  ) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { vendor: true },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    const isAdmin = requestingUser.role === Role.ADMIN;
    const isCustomer = booking.customerId === requestingUser.userId;
    const isVendor = booking.vendor.userId === requestingUser.userId;

    if (!isAdmin && !isCustomer && !isVendor) {
      throw new ForbiddenException(
        'Access denied: You are not authorized to update this booking.',
      );
    }

    // If not admin, check state machine transitions
    if (!isAdmin) {
      const allowed = this.getAllowedNextStates(
        booking.status,
        requestingUser.role,
      );
      if (!allowed.includes(newStatus)) {
        throw new BadRequestException(
          `Invalid transition from ${booking.status} to ${newStatus}. Allowed transitions for ${requestingUser.role}: ${allowed.join(', ') || 'None'}`,
        );
      }

      if (isCustomer && booking.customerId !== requestingUser.userId) {
        throw new ForbiddenException('You can only cancel your own bookings.');
      }
      if (isVendor && booking.vendor.userId !== requestingUser.userId) {
        throw new ForbiddenException(
          'You can only transition bookings for your own fleet.',
        );
      }
    }

    // Additional validations
    if (newStatus === BookingStatus.CONFIRMED) {
      const payment = await this.prisma.payment.findUnique({
        where: { bookingId },
      });
      const isPaid = payment && payment.status === PaymentStatus.PAID;

      if (!isAdmin && !isPaid) {
        throw new BadRequestException(
          `Cannot confirm booking: Payment has not been captured (Payment status: ${payment?.status || 'NONE'}). Bookings must be paid before confirmation.`,
        );
      }

      if (isAdmin && !isPaid) {
        if (!reason || reason.trim().length < 10) {
          throw new BadRequestException(
            'Admin confirmation of an unpaid booking requires an explicit justification (minimum 10 characters) in the reason field.',
          );
        }
        await this.auditLogService.log(
          requestingUser.userId,
          'BOOKING_ADMIN_FORCE_CONFIRMED',
          'Booking',
          bookingId,
          {
            previousStatus: booking.status,
            paymentStatus: payment?.status || 'NONE',
            justification: reason,
          },
        );
      }
    }

    if (newStatus === BookingStatus.ONGOING) {
      // 1. Enforce finalized PRE_TRIP inspection
      const preTrip = await this.prisma.inspection.findUnique({
        where: {
          bookingId_type: {
            bookingId,
            type: InspectionType.PRE_TRIP,
          },
        },
      });

      if (!preTrip || !preTrip.finalized) {
        throw new BadRequestException(
          'Cannot start trip: Pre-trip vehicle inspection must be recorded and finalized before vehicle handover.',
        );
      }

      // 2. Enforce Handover OTP
      if (!isAdmin) {
        if (!handoverOtp) {
          throw new BadRequestException(
            'Customer handover OTP is required to verify vehicle pickup and start trip.',
          );
        }
        await this.handoverOtpService.verifyOtp(
          bookingId,
          HandoverOtpType.PICKUP,
          handoverOtp,
        );
      } else if (isAdmin && !handoverOtp) {
        if (!reason || reason.trim().length < 10) {
          throw new BadRequestException(
            'Admin trip start override without handover OTP requires explicit justification (minimum 10 characters) in the reason field.',
          );
        }
        await this.auditLogService.log(
          requestingUser.userId,
          'TRIP_ADMIN_FORCE_START',
          'Booking',
          bookingId,
          { justification: reason },
        );
      }
    }

    if (newStatus === BookingStatus.COMPLETED) {
      // 1. Enforce finalized POST_TRIP inspection
      const postTrip = await this.prisma.inspection.findUnique({
        where: {
          bookingId_type: {
            bookingId,
            type: InspectionType.POST_TRIP,
          },
        },
      });

      if (!postTrip || !postTrip.finalized) {
        throw new BadRequestException(
          'Cannot complete trip: Post-trip vehicle inspection must be recorded and finalized before completing trip.',
        );
      }

      // 2. Enforce Return OTP
      if (!isAdmin) {
        if (!handoverOtp) {
          throw new BadRequestException(
            'Customer return verification OTP is required to complete trip.',
          );
        }
        await this.handoverOtpService.verifyOtp(
          bookingId,
          HandoverOtpType.RETURN,
          handoverOtp,
        );
      } else if (isAdmin && !handoverOtp) {
        if (!reason || reason.trim().length < 10) {
          throw new BadRequestException(
            'Admin trip complete override without return OTP requires explicit justification (minimum 10 characters) in the reason field.',
          );
        }
        await this.auditLogService.log(
          requestingUser.userId,
          'TRIP_ADMIN_FORCE_COMPLETE',
          'Booking',
          bookingId,
          { justification: reason },
        );
      }
    }

    if (newStatus === BookingStatus.CANCELLED && isVendor && !reason) {
      throw new BadRequestException(
        'Vendors must specify a reason when rejecting/cancelling a booking.',
      );
    }

    let cancellationCalc: any = null;
    let cancelLockToken: string | null = null;
    if (newStatus === BookingStatus.CANCELLED) {
      cancelLockToken =
        await this.bookingLockService.acquireCancellationLock(bookingId);
      try {
        const payment = await this.prisma.payment.findUnique({
          where: { bookingId },
        });
        const amountPaid = payment?.amount || booking.totalFare;
        cancellationCalc = this.cancellationPolicyService.calculateCancellation(
          {
            startDate: booking.startDate,
            cancellationTime: new Date(),
            amountPaid,
            actorRole: requestingUser.role,
            isAdminOverride: isAdmin && reason?.includes('admin_full_refund'),
          },
        );

        await this.paymentsService.refund(
          bookingId,
          cancellationCalc.refundAmountInPaise,
          reason,
          cancellationCalc.tier,
        );
      } finally {
        if (cancelLockToken) {
          await this.bookingLockService.releaseCancellationLock(
            bookingId,
            cancelLockToken,
          );
        }
      }
    }

    const updatedBooking = await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: newStatus,
        ...(reason ? { cancellationReason: reason } : {}),
        ...(cancellationCalc
          ? {
              cancellationFee: cancellationCalc.cancellationFee,
              refundAmount: cancellationCalc.refundAmount,
              cancelledAt: new Date(),
              cancelledBy: requestingUser.userId,
            }
          : {}),
      },
      include: { car: true, customer: true },
    });

    let title = '';
    let body = '';
    if (newStatus === BookingStatus.CONFIRMED) {
      title = 'Booking Confirmed';
      body = `Your booking for ${updatedBooking.car.make} ${updatedBooking.car.model} (${updatedBooking.car.registrationNumber}) has been accepted.`;
    } else if (newStatus === BookingStatus.CANCELLED) {
      title = 'Booking Cancelled';
      body = `Your booking for ${updatedBooking.car.make} ${updatedBooking.car.model} (${updatedBooking.car.registrationNumber}) was rejected/cancelled.`;
    } else {
      title = 'Booking Update';
      body = `Your booking status has been updated to ${newStatus}.`;
    }

    this.notificationsService
      .notifyUser(updatedBooking.customerId, title, body)
      .catch((err) =>
        this.logger.error('Failed to notify customer of status update', err),
      );

    // Trigger Referral Qualification Trigger on Booking Completion
    if (newStatus === BookingStatus.COMPLETED && this.referralsService) {
      this.referralsService
        .handleBookingCompleted(bookingId)
        .catch((err) =>
          this.logger.error(`Referral qualification failed for booking ${bookingId}:`, err),
        );
    }

    // Trigger Loyalty Point Earning on Booking Completion
    if (newStatus === BookingStatus.COMPLETED && this.loyaltyService) {
      this.loyaltyService
        .handleBookingCompleted(bookingId)
        .catch((err) =>
          this.logger.error(`Loyalty point crediting failed for booking ${bookingId}:`, err),
        );
    }

    return updatedBooking;
  }

  async getCancellationPreview(
    bookingId: string,
    requestingUser: { userId: string; role: Role },
  ) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { payment: true, vendor: true },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    const isAdmin =
      requestingUser.role === Role.ADMIN ||
      requestingUser.role === Role.SUPPORT_AGENT;
    const isCustomer = booking.customerId === requestingUser.userId;
    const isVendor = booking.vendor?.userId === requestingUser.userId;

    if (!isAdmin && !isCustomer && !isVendor) {
      throw new ForbiddenException(
        'Access denied: You are not authorized to view cancellation preview for this booking.',
      );
    }

    if (booking.status === BookingStatus.CANCELLED) {
      throw new BadRequestException('Booking is already cancelled.');
    }

    if (booking.status === BookingStatus.COMPLETED) {
      throw new BadRequestException('Completed bookings cannot be cancelled.');
    }

    const amountPaid = booking.payment?.amount || booking.totalFare;
    const calculation = this.cancellationPolicyService.calculateCancellation({
      startDate: booking.startDate,
      cancellationTime: new Date(),
      amountPaid,
      actorRole: requestingUser.role,
    });

    return {
      bookingId: booking.id,
      tier: calculation.tier,
      tierDescription: calculation.tierDescription,
      startDate: calculation.startDate,
      cancellationTime: calculation.cancellationTime,
      hoursRemaining: calculation.hoursRemaining,
      amountPaid: calculation.amountPaid,
      cancellationFeePercent: calculation.cancellationFeePercent,
      cancellationFee: calculation.cancellationFee,
      refundAmountPercent: calculation.refundAmountPercent,
      refundAmount: calculation.refundAmount,
      currency: 'INR',
      isEligibleForRefund: calculation.isEligibleForRefund,
    };
  }

  async cancelBooking(bookingId: string, customerId: string, reason: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { payment: true, vendor: true },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    if (booking.customerId !== customerId) {
      throw new ForbiddenException(
        'Access denied: You can only cancel your own bookings.',
      );
    }

    const allowed = this.getAllowedNextStates(booking.status, Role.CUSTOMER);
    if (!allowed.includes(BookingStatus.CANCELLED)) {
      throw new BadRequestException(
        `Cannot cancel booking in ${booking.status} status.`,
      );
    }

    const lockToken =
      await this.bookingLockService.acquireCancellationLock(bookingId);

    try {
      const amountPaid = booking.payment?.amount || booking.totalFare;
      const calculation = this.cancellationPolicyService.calculateCancellation({
        startDate: booking.startDate,
        cancellationTime: new Date(),
        amountPaid,
        actorRole: Role.CUSTOMER,
      });

      await this.paymentsService.refund(
        bookingId,
        calculation.refundAmountInPaise,
        reason,
        calculation.tier,
      );

      const updatedBooking = await this.prisma.booking.update({
        where: { id: bookingId },
        data: {
          status: BookingStatus.CANCELLED,
          cancellationReason: reason,
          cancellationFee: calculation.cancellationFee,
          refundAmount: calculation.refundAmount,
          cancelledAt: new Date(),
          cancelledBy: customerId,
        },
        include: { car: true, vendor: true },
      });

      if (updatedBooking.vendor?.userId) {
        this.notificationsService
          .notifyUser(
            updatedBooking.vendor.userId,
            'Booking Cancelled',
            `Booking for ${updatedBooking.car.make} ${updatedBooking.car.model} (${updatedBooking.car.registrationNumber}) has been cancelled by the customer.`,
          )
          .catch((err) =>
            this.logger.error('Failed to notify vendor of cancellation', err),
          );
      }

      return this.redactVendorInBooking(updatedBooking, {
        userId: customerId,
        role: Role.CUSTOMER,
      });
    } finally {
      await this.bookingLockService.releaseCancellationLock(
        bookingId,
        lockToken,
      );
    }
  }

  async flagDispute(bookingId: string, note: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    return this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        disputeFlag: true,
        disputeNote: note,
      },
    });
  }

  async resolveDispute(bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    return this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        disputeFlag: false,
        disputeNote: null,
      },
    });
  }

  validateStatusTransition(
    currentStatus: BookingStatus,
    targetStatus: BookingStatus,
  ): void {
    if (currentStatus === targetStatus) {
      return;
    }

    const allowedTransitions: Record<BookingStatus, BookingStatus[]> = {
      [BookingStatus.PENDING]: [
        BookingStatus.CONFIRMED,
        BookingStatus.CANCELLED,
        BookingStatus.EXPIRED,
      ],
      [BookingStatus.CONFIRMED]: [
        BookingStatus.HANDOVER_READY,
        BookingStatus.ONGOING,
        BookingStatus.CANCELLED,
        BookingStatus.REFUND_PENDING,
      ],
      [BookingStatus.HANDOVER_READY]: [
        BookingStatus.ONGOING,
        BookingStatus.CANCELLED,
      ],
      [BookingStatus.ONGOING]: [
        BookingStatus.RETURN_PENDING,
        BookingStatus.COMPLETED,
      ],
      [BookingStatus.RETURN_PENDING]: [
        BookingStatus.COMPLETED,
        BookingStatus.DISPUTED,
      ],
      [BookingStatus.REFUND_PENDING]: [
        BookingStatus.REFUNDED,
        BookingStatus.DISPUTED,
      ],
      [BookingStatus.DISPUTED]: [
        BookingStatus.COMPLETED,
        BookingStatus.REFUND_PENDING,
        BookingStatus.REFUNDED,
      ],
      [BookingStatus.COMPLETED]: [],
      [BookingStatus.REFUNDED]: [],
      [BookingStatus.CANCELLED]: [],
      [BookingStatus.EXPIRED]: [],
    };

    const validTargets = allowedTransitions[currentStatus] || [];
    if (!validTargets.includes(targetStatus)) {
      throw new BadRequestException(
        `Invalid booking status transition from ${currentStatus} to ${targetStatus}.`,
      );
    }
  }

  private getAllowedNextStates(
    current: BookingStatus,
    role: Role,
  ): BookingStatus[] {
    if (role === Role.CUSTOMER) {
      if (
        current === BookingStatus.PENDING ||
        current === BookingStatus.CONFIRMED
      ) {
        return [BookingStatus.CANCELLED];
      }
      return [];
    }

    if (role === Role.VENDOR) {
      switch (current) {
        case BookingStatus.PENDING:
          return [BookingStatus.CONFIRMED, BookingStatus.CANCELLED];
        case BookingStatus.CONFIRMED:
          return [BookingStatus.HANDOVER_READY, BookingStatus.ONGOING, BookingStatus.CANCELLED];
        case BookingStatus.HANDOVER_READY:
          return [BookingStatus.ONGOING, BookingStatus.CANCELLED];
        case BookingStatus.ONGOING:
          return [BookingStatus.RETURN_PENDING, BookingStatus.COMPLETED];
        case BookingStatus.RETURN_PENDING:
          return [BookingStatus.COMPLETED];
        default:
          return [];
      }
    }

    return [];
  }

  private redactVendorInBooking(
    booking: any,
    requestingUser: { userId: string; role: Role },
  ) {
    if (!booking) return booking;

    if (Array.isArray(booking)) {
      return booking.map((b) => this.redactVendorInBooking(b, requestingUser));
    }

    if (!booking.vendor) return booking;

    const isAdmin = requestingUser.role === Role.ADMIN;
    const isVendor = booking.vendor.userId === requestingUser.userId;
    const isPaid =
      booking.payment?.status === PaymentStatus.PAID ||
      booking.payment?.status === 'PAID';

    const copy = { ...booking };
    copy.vendor = redactVendor(booking.vendor, {
      isAdmin,
      isOwner: isVendor,
      isPaid,
    });

    return copy;
  }
}

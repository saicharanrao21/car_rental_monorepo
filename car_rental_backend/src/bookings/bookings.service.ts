import { 
  Injectable, 
  NotFoundException, 
  ConflictException, 
  ForbiddenException, 
  BadRequestException,
  Logger
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { BookingStatus, Role, TripType, Prisma } from '@prisma/client';
import { PaginationDto } from '../common/pagination.dto';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';

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
  ) {}


  async createBooking(customerId: string, dto: CreateBookingDto) {
    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);

    if (start >= end) {
      throw new BadRequestException('Start date must be before end date.');
    }

    // 1. Acquire Redis distributed lock
    const lockToken = await this.bookingLockService.acquireLock(dto.carId, start, end);

    try {
      // Fetch car outside of the transaction to do validations and resolve fares
      const car = await this.prisma.car.findUnique({
        where: { id: dto.carId },
        include: { vendor: true },
      });

      if (!car) {
        throw new NotFoundException('Car not found.');
      }

      if (!car.isAvailable) {
        throw new ConflictException('This car is marked as unavailable.');
      }

      // Check if tripType is supported by the car
      if (!car.availableTripTypes.includes(dto.tripType)) {
        throw new BadRequestException(`This car does not support ${dto.tripType} trip type.`);
      }

      // Check blockedDates range overlap
      const hasBlockedDate = car.blockedDates.some((blockedDate) => {
        const bTime = blockedDate.getTime();
        return bTime >= start.getTime() && bTime <= end.getTime();
      });

      if (hasBlockedDate) {
        throw new ConflictException('The requested date range conflicts with blocked dates for this car.');
      }

      // 3. Resolve commission percentage outside the transaction
      const commissionPercent = await this.commissionResolver.resolveCommissionPercent(
        car.vendor.city,
        car.type,
        dto.tripType,
      );

      // 4. Calculate fare details outside the transaction
      const durationMs = end.getTime() - start.getTime();
      let basePackagePrice = new Prisma.Decimal(0);

      if (dto.tripType === TripType.LOCAL || dto.tripType === TripType.AIRPORT_TRANSFER) {
        const durationHours = Math.ceil(durationMs / (1000 * 60 * 60));
        basePackagePrice = car.pricePerHour.mul(durationHours);
      } else {
        const durationDays = Math.ceil(durationMs / (1000 * 60 * 60 * 24));
        basePackagePrice = car.pricePerDay.mul(durationDays > 0 ? durationDays : 1);
      }

      const distance = dto.distanceKm ? new Prisma.Decimal(dto.distanceKm) : new Prisma.Decimal(0);
      
      const fareDetails = this.fareCalculator.calculateFare(
        distance,
        basePackagePrice,
        car.pricePerKm,
        commissionPercent,
      );

      // 2. Perform transactional double-booking check and creation (with 15s timeout to support slow pg_bouncer pools)
      const booking = await this.prisma.$transaction(async (tx) => {
        // Check overlapping bookings
        const overlappingBooking = await tx.booking.findFirst({
          where: {
            carId: dto.carId,
            status: {
              in: [BookingStatus.PENDING, BookingStatus.CONFIRMED, BookingStatus.ONGOING],
            },
            AND: [
              { startDate: { lt: end } },
              { endDate: { gt: start } },
            ],
          },
        });

        if (overlappingBooking) {
          throw new ConflictException('This car is already booked during the selected date range.');
        }

        // 5. Create booking row
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
            totalFare: fareDetails.total,
            netToVendor: fareDetails.netToVendor,
            status: BookingStatus.PENDING,
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
          },
        });

        return newBooking;
      }, {
        timeout: 15000
      });

      // After transaction completes, notify vendor
      const vendorUser = await this.prisma.vendor.findUnique({
        where: { id: booking.vendorId },
        select: { userId: true },
      });
      if (vendorUser) {
        this.notificationsService
          .notifyUser(
            vendorUser.userId,
            'New Booking Request',
            `You have received a new booking request for ${booking.car.make} ${booking.car.model} (${booking.car.registrationNumber}).`,
          )
          .catch((err) => this.logger.error('Failed to notify vendor of new booking', err));
      }

      return booking;
    } finally {
      // 6. Release lock
      await this.bookingLockService.releaseLock(dto.carId, start, end, lockToken);
    }
  }

  async getBookingById(id: string, requestingUser: { userId: string; role: Role }) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        car: true,
        customer: true,
        vendor: true,
      },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    const isCustomer = booking.customerId === requestingUser.userId;
    const isVendor = booking.vendor.userId === requestingUser.userId;
    const isAdmin = requestingUser.role === Role.ADMIN;

    if (!isCustomer && !isVendor && !isAdmin) {
      throw new ForbiddenException('Access denied: You are not authorized to view this booking.');
    }

    return this.redactVendorInBooking(booking, requestingUser);
  }

  async getBookingsForCustomer(customerId: string, statusFilter?: BookingStatus, pagination?: PaginationDto) {
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
          vendor: true,
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.booking.count({ where }),
    ]);

    const redactedData = this.redactVendorInBooking(data, { userId: customerId, role: Role.CUSTOMER });

    return {
      data: redactedData,
      total,
      page,
      totalPages: Math.ceil(total / take),
    };
  }

  async getBookingsForVendor(vendorUserId: string, statusFilter?: BookingStatus, pagination?: PaginationDto) {
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

  async getBookingsForAdmin(filters: {
    city?: string;
    startDate?: string;
    endDate?: string;
    tripType?: TripType;
    status?: BookingStatus;
    vendorId?: string;
    carType?: string;
  }, pagination?: PaginationDto) {
    const page = pagination?.page ?? 1;
    const limit = pagination?.limit ?? 10;
    const skip = (page - 1) * limit;
    const take = limit;

    const where: Prisma.BookingWhereInput = {
      ...(filters.status ? { status: filters.status } : {}),
      ...(filters.tripType ? { tripType: filters.tripType } : {}),
      ...(filters.vendorId ? { vendorId: filters.vendorId } : {}),
      ...(filters.carType ? { car: { type: filters.carType as any } } : {}),
      ...(filters.city ? { car: { vendor: { city: { equals: filters.city, mode: 'insensitive' } } } } : {}),
      ...(filters.startDate && filters.endDate ? {
        startDate: { gte: new Date(filters.startDate) },
        endDate: { lte: new Date(filters.endDate) },
      } : {}),
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
    reason?: string
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
      throw new ForbiddenException('Access denied: You are not authorized to update this booking.');
    }

    // If not admin, check state machine transitions
    if (!isAdmin) {
      const allowed = this.getAllowedNextStates(booking.status, requestingUser.role);
      if (!allowed.includes(newStatus)) {
        throw new BadRequestException(
          `Invalid transition from ${booking.status} to ${newStatus}. Allowed transitions for ${requestingUser.role}: ${allowed.join(', ') || 'None'}`
        );
      }

      if (isCustomer && booking.customerId !== requestingUser.userId) {
        throw new ForbiddenException('You can only cancel your own bookings.');
      }
      if (isVendor && booking.vendor.userId !== requestingUser.userId) {
        throw new ForbiddenException('You can only transition bookings for your own fleet.');
      }
    }

    // Additional validations
    if (newStatus === BookingStatus.CANCELLED && isVendor && !reason) {
      throw new BadRequestException('Vendors must specify a reason when rejecting/cancelling a booking.');
    }

    if (newStatus === BookingStatus.CANCELLED) {
      await this.paymentsService.refund(bookingId, reason);
    }

    const updatedBooking = await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: newStatus,
        ...(reason ? { cancellationReason: reason } : {}),
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
      .catch((err) => this.logger.error('Failed to notify customer of status update', err));

    return updatedBooking;
  }

  async cancelBooking(bookingId: string, customerId: string, reason: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { vendor: true },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    if (booking.customerId !== customerId) {
      throw new ForbiddenException('Access denied: You can only cancel your own bookings.');
    }

    const allowed = this.getAllowedNextStates(booking.status, Role.CUSTOMER);
    if (!allowed.includes(BookingStatus.CANCELLED)) {
      throw new BadRequestException(`Cannot cancel booking in ${booking.status} status.`);
    }

    await this.paymentsService.refund(bookingId, reason);

    const updatedBooking = await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: BookingStatus.CANCELLED,
        cancellationReason: reason,
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
        .catch((err) => this.logger.error('Failed to notify vendor of cancellation', err));
    }

    return this.redactVendorInBooking(updatedBooking, { userId: customerId, role: Role.CUSTOMER });
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

  private getAllowedNextStates(current: BookingStatus, role: Role): BookingStatus[] {
    if (role === Role.CUSTOMER) {
      if (current === BookingStatus.PENDING || current === BookingStatus.CONFIRMED) {
        return [BookingStatus.CANCELLED];
      }
      return [];
    }

    if (role === Role.VENDOR) {
      switch (current) {
        case BookingStatus.PENDING:
          return [BookingStatus.CONFIRMED, BookingStatus.CANCELLED];
        case BookingStatus.CONFIRMED:
          return [BookingStatus.ONGOING];
        case BookingStatus.ONGOING:
          return [BookingStatus.COMPLETED];
        default:
          return [];
      }
    }

    return [];
  }

  private redactVendorInBooking(booking: any, requestingUser: { userId: string; role: Role }) {
    if (!booking) return booking;

    if (Array.isArray(booking)) {
      return booking.map((b) => this.redactVendorInBooking(b, requestingUser));
    }

    if (!booking.vendor) return booking;

    const isAdmin = requestingUser.role === Role.ADMIN;
    const isVendor = booking.vendor.userId === requestingUser.userId;

    if (!isAdmin && !isVendor) {
      const copy = { ...booking.vendor };
      delete copy.gstNumber;
      delete copy.panNumber;
      delete copy.bankDetails;
      booking.vendor = copy;
    }

    return booking;
  }
}

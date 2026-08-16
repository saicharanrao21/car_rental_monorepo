import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Logger,
  Inject,
  Optional,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { InvoicesService } from '../invoices/invoices.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import {
  BookingStatus,
  ExtensionStatus,
  Role,
  TripType,
  Prisma,
} from '@prisma/client';
import Razorpay from 'razorpay';
import * as crypto from 'crypto';

export interface ExtensionQuote {
  bookingId: string;
  currentEndDate: Date;
  requestedEndDate: Date;
  extraDays: number;
  extraHours: number;
  baseFare: number;
  platformFee: number;
  gstAmount: number;
  totalFare: number;
  netToVendor: number;
}

@Injectable()
export class TripExtensionsService {
  private readonly logger = new Logger(TripExtensionsService.name);
  private razorpay: Razorpay | null = null;
  private readonly useMock: boolean;

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
    private readonly commissionResolver: CommissionResolverService,
    private readonly fareCalculator: FareCalculatorService,
    private readonly invoicesService: InvoicesService,
    private readonly notificationsService: NotificationsService,
    private readonly auditLogService: AuditLogService,
  ) {
    this.useMock =
      this.configService.get<string>('RAZORPAY_USE_MOCK') === 'true';
    const keyId = this.configService.get<string>('RAZORPAY_KEY_ID');
    const keySecret = this.configService.get<string>('RAZORPAY_KEY_SECRET');

    if (keyId && keySecret) {
      this.razorpay = new Razorpay({
        key_id: keyId,
        key_secret: keySecret,
      });
    }
  }

  /**
   * Generates a real-time authoritative extension quote and validates vehicle availability.
   */
  async getQuote(
    bookingId: string,
    requestedEndDateStr: string,
    requestingUser: { userId: string; role: Role },
  ): Promise<ExtensionQuote> {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        car: {
          include: { vendor: true },
        },
      },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    if (
      requestingUser.role === Role.CUSTOMER &&
      booking.customerId !== requestingUser.userId
    ) {
      throw new ForbiddenException(
        'Access denied: You do not own this booking.',
      );
    }

    if (booking.status !== BookingStatus.ONGOING) {
      throw new BadRequestException(
        `Cannot extend booking in '${booking.status}' status. Extension is only permitted for ONGOING trips.`,
      );
    }

    const requestedEndDate = new Date(requestedEndDateStr);
    if (isNaN(requestedEndDate.getTime())) {
      throw new BadRequestException('Invalid requested end date format.');
    }

    if (requestedEndDate <= booking.endDate) {
      throw new BadRequestException(
        'Requested extension end date must be after the current booking end date.',
      );
    }

    // Check car availability for extended period (booking.endDate -> requestedEndDate)
    await this.validateExtensionAvailability(
      booking.carId,
      booking.id,
      booking.endDate,
      requestedEndDate,
      booking.car.blockedDates,
    );

    const extraDurationMs =
      requestedEndDate.getTime() - booking.endDate.getTime();
    const extraHours = Math.ceil(extraDurationMs / (1000 * 60 * 60));
    const extraDays = Math.max(1, Math.ceil(extraDurationMs / (1000 * 60 * 60 * 24)));

    let extraBasePrice = new Prisma.Decimal(0);
    if (
      booking.tripType === TripType.LOCAL ||
      booking.tripType === TripType.AIRPORT_TRANSFER
    ) {
      extraBasePrice = booking.car.pricePerHour.mul(extraHours);
    } else {
      extraBasePrice = booking.car.pricePerDay.mul(extraDays);
    }

    const commissionPercent =
      await this.commissionResolver.resolveCommissionPercent(
        booking.car.vendor.city,
        booking.car.type,
        booking.tripType,
      );

    const fareDetails = this.fareCalculator.calculateFare(
      new Prisma.Decimal(0),
      extraBasePrice,
      new Prisma.Decimal(0),
      commissionPercent,
      extraDays,
      0,
      0,
    );

    return {
      bookingId: booking.id,
      currentEndDate: booking.endDate,
      requestedEndDate,
      extraDays,
      extraHours,
      baseFare: fareDetails.baseFare.toNumber(),
      platformFee: fareDetails.platformFee.toNumber(),
      gstAmount: fareDetails.gst.toNumber(),
      totalFare: fareDetails.total.toNumber(),
      netToVendor: fareDetails.netToVendor.toNumber(),
    };
  }

  /**
   * Initializes a trip extension and creates a Razorpay payment order.
   */
  async createExtension(
    bookingId: string,
    requestedEndDateStr: string,
    customerId: string,
  ) {
    const quote = await this.getQuote(
      bookingId,
      requestedEndDateStr,
      { userId: customerId, role: Role.CUSTOMER },
    );

    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { car: true },
    });

    if (!booking) throw new NotFoundException('Booking not found.');

    const amountInPaise = Math.round(quote.totalFare * 100);
    let orderId = `ext_mock_${Date.now()}`;

    if (!this.useMock && this.razorpay) {
      try {
        const order = await this.razorpay.orders.create({
          amount: amountInPaise,
          currency: 'INR',
          receipt: `ext_${booking.id.substring(0, 10)}_${Date.now()}`,
          notes: {
            bookingId: booking.id,
            type: 'TRIP_EXTENSION',
            extraDays: String(quote.extraDays),
          },
        });
        orderId = order.id;
      } catch (err: any) {
        this.logger.error(`Razorpay order creation failed: ${err.message}`);
        throw new BadRequestException(
          'Failed to initialize extension payment gateway.',
        );
      }
    }

    const extension = await this.prisma.tripExtension.create({
      data: {
        bookingId: booking.id,
        currentEndDate: quote.currentEndDate,
        requestedEndDate: quote.requestedEndDate,
        extraDays: quote.extraDays,
        extraHours: quote.extraHours,
        baseFare: new Prisma.Decimal(quote.baseFare),
        platformFee: new Prisma.Decimal(quote.platformFee),
        gstAmount: new Prisma.Decimal(quote.gstAmount),
        totalFare: new Prisma.Decimal(quote.totalFare),
        netToVendor: new Prisma.Decimal(quote.netToVendor),
        razorpayOrderId: orderId,
        status: ExtensionStatus.PENDING_PAYMENT,
      },
    });

    return {
      extensionId: extension.id,
      bookingId: booking.id,
      orderId,
      amount: quote.totalFare,
      amountInPaise,
      currency: 'INR',
      keyId: this.configService.get<string>('RAZORPAY_KEY_ID') || 'mock_key_id',
    };
  }

  /**
   * Verifies Razorpay payment for trip extension and atomically extends the booking.
   */
  async verifyExtensionPayment(
    bookingId: string,
    extensionId: string,
    paymentDetails: {
      razorpayOrderId: string;
      razorpayPaymentId: string;
      razorpaySignature: string;
    },
    customerId: string,
  ) {
    const extension = await this.prisma.tripExtension.findUnique({
      where: { id: extensionId },
      include: {
        booking: {
          include: { car: true, vendor: true, customer: true },
        },
      },
    });

    if (!extension || extension.bookingId !== bookingId) {
      throw new NotFoundException('Trip extension record not found.');
    }

    if (extension.booking.customerId !== customerId) {
      throw new ForbiddenException('Access denied: Unauthorized customer.');
    }

    if (extension.status === ExtensionStatus.CONFIRMED) {
      return { success: true, message: 'Extension already confirmed.' };
    }

    // Verify HMAC signature in live mode
    if (!this.useMock) {
      const secret = this.configService.get<string>('RAZORPAY_KEY_SECRET') || '';
      const body = `${paymentDetails.razorpayOrderId}|${paymentDetails.razorpayPaymentId}`;
      const expectedSignature = crypto
        .createHmac('sha256', secret)
        .update(body)
        .digest('hex');

      if (expectedSignature !== paymentDetails.razorpaySignature) {
        throw new BadRequestException('Invalid payment signature verification.');
      }
    }

    // Transactional confirmation and end date update
    await this.prisma.$transaction(async (tx) => {
      // Pessimistic Car row lock
      await tx.$queryRaw`SELECT id FROM "Car" WHERE id = ${extension.booking.carId} FOR UPDATE`;

      // Check collision again inside transaction
      const collision = await tx.booking.findFirst({
        where: {
          carId: extension.booking.carId,
          id: { not: bookingId },
          status: {
            in: [
              BookingStatus.PENDING,
              BookingStatus.CONFIRMED,
              BookingStatus.ONGOING,
              BookingStatus.HANDOVER_READY,
            ],
          },
          AND: [
            { startDate: { lt: extension.requestedEndDate } },
            { endDate: { gt: extension.currentEndDate } },
          ],
        },
      });

      if (collision) {
        throw new ConflictException(
          'Cannot complete extension: A conflicting booking was confirmed concurrently.',
        );
      }

      await tx.tripExtension.update({
        where: { id: extension.id },
        data: {
          status: ExtensionStatus.CONFIRMED,
          razorpayPaymentId: paymentDetails.razorpayPaymentId,
        },
      });

      await tx.booking.update({
        where: { id: bookingId },
        data: {
          endDate: extension.requestedEndDate,
        },
      });
    });

    // Generate supplementary extension invoice
    try {
      await this.invoicesService.generateInvoiceForBooking(bookingId);
    } catch (err: any) {
      this.logger.warn(`Extension invoice creation note: ${err.message}`);
    }

    // Emit notifications
    if (extension.booking.customerId) {
      await this.notificationsService.notifyUser(
        extension.booking.customerId,
        'Trip Extension Confirmed',
        `Your rental has been successfully extended until ${extension.requestedEndDate.toLocaleDateString()}.`,
      );
    }

    if (extension.booking.vendor.userId) {
      await this.notificationsService.notifyUser(
        extension.booking.vendor.userId,
        'Trip Extended by Customer',
        `Booking #${bookingId.substring(0, 8)} for ${extension.booking.car.make} ${extension.booking.car.model} was extended until ${extension.requestedEndDate.toLocaleDateString()}.`,
      );
    }

    return {
      success: true,
      extensionId: extension.id,
      newEndDate: extension.requestedEndDate,
      message: 'Trip extension confirmed and scheduled successfully.',
    };
  }

  /**
   * Retrieves all extensions for a booking.
   */
  async getExtensionsForBooking(bookingId: string) {
    return this.prisma.tripExtension.findMany({
      where: { bookingId },
      orderBy: { createdAt: 'desc' },
    });
  }

  private async validateExtensionAvailability(
    carId: string,
    bookingId: string,
    currentEndDate: Date,
    requestedEndDate: Date,
    blockedDates: Date[],
  ) {
    const hasBlockedDate = blockedDates.some((bDate) => {
      const bTime = bDate.getTime();
      return (
        bTime > currentEndDate.getTime() && bTime <= requestedEndDate.getTime()
      );
    });

    if (hasBlockedDate) {
      throw new ConflictException(
        'The vehicle is blocked by the fleet partner during the requested extension dates.',
      );
    }

    const conflictingBooking = await this.prisma.booking.findFirst({
      where: {
        carId,
        id: { not: bookingId },
        status: {
          in: [
            BookingStatus.PENDING,
            BookingStatus.CONFIRMED,
            BookingStatus.ONGOING,
            BookingStatus.HANDOVER_READY,
          ],
        },
        AND: [
          { startDate: { lt: requestedEndDate } },
          { endDate: { gt: currentEndDate } },
        ],
      },
    });

    if (conflictingBooking) {
      throw new ConflictException(
        'The vehicle has an upcoming confirmed booking during the requested extension period.',
      );
    }
  }
}

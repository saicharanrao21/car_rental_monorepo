import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { KycStatus, Role, Prisma } from '@prisma/client';
import { AddDriverDto } from './dto/add-driver.dto';

export { AddDriverDto };

@Injectable()
export class AdditionalDriversService {
  private readonly logger = new Logger(AdditionalDriversService.name);
  static readonly ADDITIONAL_DRIVER_FEE = 350.0;

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
    private readonly auditLogService: AuditLogService,
  ) {}

  /**
   * Adds an additional authorized driver to a booking with licence verification.
   */
  async addDriver(
    bookingId: string,
    dto: AddDriverDto,
    requestingUser: { userId: string; role: Role },
  ) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { additionalDrivers: true },
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

    if (booking.additionalDrivers.length >= 2) {
      throw new BadRequestException(
        'Maximum 2 additional drivers allowed per rental.',
      );
    }

    const expiry = new Date(dto.expiryDate);
    if (isNaN(expiry.getTime()) || expiry <= new Date()) {
      throw new BadRequestException(
        'Driving licence has expired or invalid expiry date provided.',
      );
    }

    // Check if licence is already verified in customer KYC pool
    const existingKyc = await this.prisma.customerKyc.findFirst({
      where: {
        licenceNumber: dto.licenceNumber.trim().toUpperCase(),
        status: KycStatus.VERIFIED,
      },
    });

    const initialStatus = existingKyc ? KycStatus.VERIFIED : KycStatus.PENDING;

    const driver = await this.prisma.additionalDriver.create({
      data: {
        bookingId,
        fullName: dto.fullName.trim(),
        phone: dto.phone.trim(),
        email: dto.email?.trim(),
        licenceNumber: dto.licenceNumber.trim().toUpperCase(),
        licenceFrontUrl: dto.licenceFrontUrl,
        licenceBackUrl: dto.licenceBackUrl,
        expiryDate: expiry,
        kycStatus: initialStatus,
        verifiedAt: existingKyc ? new Date() : null,
        feeAmount: new Prisma.Decimal(AdditionalDriversService.ADDITIONAL_DRIVER_FEE),
      },
    });

    this.logger.log(
      `Added additional driver ${driver.fullName} (${driver.id}) to booking ${bookingId}`,
    );

    return driver;
  }

  /**
   * Retrieves all additional drivers for a booking.
   */
  async getDriversForBooking(bookingId: string) {
    return this.prisma.additionalDriver.findMany({
      where: { bookingId },
      orderBy: { createdAt: 'asc' },
    });
  }

  /**
   * Admin verification / adjudication of an additional driver licence.
   */
  async verifyDriver(
    driverId: string,
    isApproved: boolean,
    rejectionReason?: string,
    adminUserId?: string,
  ) {
    const driver = await this.prisma.additionalDriver.findUnique({
      where: { id: driverId },
      include: { booking: true },
    });

    if (!driver) {
      throw new NotFoundException('Additional driver record not found.');
    }

    const updated = await this.prisma.additionalDriver.update({
      where: { id: driverId },
      data: {
        kycStatus: isApproved ? KycStatus.VERIFIED : KycStatus.REJECTED,
        rejectionReason: isApproved ? null : rejectionReason || 'Licence documents unreadable or invalid',
        verifiedAt: isApproved ? new Date() : null,
      },
    });

    if (adminUserId) {
      await this.auditLogService.log(
        adminUserId,
        isApproved ? 'APPROVE_ADDITIONAL_DRIVER' : 'REJECT_ADDITIONAL_DRIVER',
        'AdditionalDriver',
        driverId,
        {
          bookingId: driver.bookingId,
          driverName: driver.fullName,
          rejectionReason,
        },
      );
    }

    // Notify customer
    if (driver.booking.customerId) {
      await this.notificationsService.notifyUser(
        driver.booking.customerId,
        isApproved
          ? 'Additional Driver Approved'
          : 'Additional Driver Licence Rejected',
        isApproved
          ? `${driver.fullName} has been verified and authorized to drive.`
          : `${driver.fullName}'s driving licence was rejected: ${rejectionReason || 'Please re-upload valid documents.'}`,
      );
    }

    return updated;
  }
}

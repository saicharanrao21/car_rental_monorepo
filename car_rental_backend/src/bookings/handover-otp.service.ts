import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { HandoverOtpType, BookingStatus, Role } from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';

@Injectable()
export class HandoverOtpService {
  private readonly logger = new Logger(HandoverOtpService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  /**
   * Generates and dispatches a cryptographically secure 6-digit OTP for vehicle pickup or return.
   */
  async generateAndSendOtp(
    bookingId: string,
    otpType: HandoverOtpType,
    requestingUser: { userId: string; role: Role },
  ): Promise<{ success: boolean; message: string; expiresInSec: number }> {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        vendor: true,
        customer: true,
        car: true,
      },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    const isAdmin = requestingUser.role === Role.ADMIN;
    const isVendor = booking.vendor.userId === requestingUser.userId;
    const isCustomer = booking.customerId === requestingUser.userId;

    if (!isAdmin && !isVendor && !isCustomer) {
      throw new ForbiddenException(
        'Access denied: You are not authorized to generate handover OTP for this booking.',
      );
    }

    // Booking state checks for OTP generation
    if (otpType === HandoverOtpType.PICKUP) {
      if (booking.status !== BookingStatus.CONFIRMED) {
        throw new BadRequestException(
          `Pickup handover OTP can only be generated for CONFIRMED bookings. Current status: ${booking.status}`,
        );
      }
    } else if (otpType === HandoverOtpType.RETURN) {
      if (booking.status !== BookingStatus.ONGOING) {
        throw new BadRequestException(
          `Return handover OTP can only be generated for ONGOING trips. Current status: ${booking.status}`,
        );
      }
    }

    // Target recipient: Customer receives OTP for both pickup and return verification
    const recipient = booking.customer;
    if (!recipient) {
      throw new NotFoundException('Customer record for booking not found.');
    }

    // Invalidate prior unverified OTPs for this booking and action type
    await this.prisma.handoverOtp.deleteMany({
      where: {
        bookingId,
        otpType,
        verified: false,
      },
    });

    // Generate 6-digit OTP
    const rawOtp = crypto.randomInt(100000, 999999).toString();
    const otpHash = bcrypt.hashSync(rawOtp, 10);
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes TTL

    await this.prisma.handoverOtp.create({
      data: {
        bookingId,
        otpType,
        recipientId: recipient.id,
        otpHash,
        expiresAt,
        verified: false,
        attemptCount: 0,
      },
    });

    const actionText = otpType === HandoverOtpType.PICKUP ? 'Pickup' : 'Return';
    const message = `Your DriveGo vehicle ${actionText} OTP for ${booking.car.make} ${booking.car.model} (${booking.car.registrationNumber}) is: ${rawOtp}. Valid for 15 minutes. Share this with the fleet owner to verify handover.`;

    this.logger.log(
      `[HANDOVER-OTP] Generated ${otpType} OTP for booking ${bookingId} (expires in 15m)`,
    );

    // Send push / in-app notification
    await this.notificationsService
      .notifyUser(recipient.id, `Vehicle ${actionText} OTP: ${rawOtp}`, message)
      .catch((err) =>
        this.logger.error(
          `Failed to dispatch in-app notification for handover OTP: ${err.message}`,
        ),
      );

    return {
      success: true,
      message: `Handover ${actionText} OTP dispatched to customer ending in ${recipient.phone.slice(-4)}`,
      expiresInSec: 900,
    };
  }

  /**
   * Verifies handover OTP against stored bcrypt hash, enforces attempt limits and expiration.
   * Uses atomic database operations to resist race conditions and replay attacks.
   */
  async verifyOtp(
    bookingId: string,
    otpType: HandoverOtpType,
    rawOtp: string,
  ): Promise<boolean> {
    if (!rawOtp || rawOtp.trim().length !== 6) {
      throw new BadRequestException(
        'Handover OTP must be a valid 6-digit code.',
      );
    }

    const latestOtp = await this.prisma.handoverOtp.findFirst({
      where: {
        bookingId,
        otpType,
        verified: false,
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!latestOtp) {
      throw new BadRequestException(
        `No active ${otpType} handover OTP found for this booking. Please request a new OTP.`,
      );
    }

    if (new Date() > latestOtp.expiresAt) {
      throw new BadRequestException(
        `Handover OTP has expired. Please request a new OTP.`,
      );
    }

    if (latestOtp.attemptCount >= 5) {
      throw new BadRequestException(
        `Too many invalid attempts (max 5). Handover OTP is locked. Please generate a new OTP.`,
      );
    }

    const isMatch = bcrypt.compareSync(rawOtp.trim(), latestOtp.otpHash);

    if (!isMatch) {
      const updated = await this.prisma.handoverOtp.update({
        where: { id: latestOtp.id },
        data: { attemptCount: { increment: 1 } },
        select: { attemptCount: true },
      });
      const remaining = Math.max(0, 5 - updated.attemptCount);
      throw new BadRequestException(
        `Invalid handover OTP. ${remaining} attempt(s) remaining.`,
      );
    }

    // Atomic conditional invalidation upon successful verification (prevents replay/race)
    const updateResult = await this.prisma.handoverOtp.updateMany({
      where: {
        id: latestOtp.id,
        verified: false,
      },
      data: {
        verified: true,
        verifiedAt: new Date(),
      },
    });

    if (updateResult.count === 0) {
      throw new BadRequestException(
        'Handover OTP has already been verified or invalidated.',
      );
    }

    return true;
  }
}

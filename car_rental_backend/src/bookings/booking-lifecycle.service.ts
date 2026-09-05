import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  ConflictException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BookingOutboxService } from './booking-outbox.service';
import { CancellationPolicyService } from './cancellation-policy.service';
import { HandoverOtpService } from './handover-otp.service';
import { PaymentsService } from '../payments/payments.service';
import { AuditLogService } from '../admin/audit-log.service';
import { ReferralsService } from '../referrals/referrals.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import { BookingLockService } from '../redis/booking-lock.service';
import {
  BookingStatus,
  Role,
  PaymentStatus,
  InspectionType,
  HandoverOtpType,
  SecurityDepositStatus,
} from '@prisma/client';
import {
  BookingTransitionContext,
  BookingTransitionResult,
  BookingLifecyclePayload,
} from './booking-lifecycle.types';

@Injectable()
export class BookingLifecycleService {
  private readonly logger = new Logger(BookingLifecycleService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly outboxService: BookingOutboxService,
    private readonly cancellationPolicyService: CancellationPolicyService,
    private readonly handoverOtpService: HandoverOtpService,
    private readonly paymentsService: PaymentsService,
    private readonly auditLogService: AuditLogService,
    private readonly bookingLockService: BookingLockService,
    @Optional() private readonly referralsService?: ReferralsService,
    @Optional() private readonly loyaltyService?: LoyaltyService,
  ) {}

  /**
   * 1. CONFIRM BOOKING (Vendor accepts paid booking)
   */
  async confirmBooking(
    bookingId: string,
    actorId: string,
    actorRole: Role | 'SYSTEM',
    reason?: string,
  ): Promise<BookingTransitionResult> {
    return this.executeTransition({
      bookingId,
      actorId,
      actorRole,
      targetStatus: BookingStatus.CONFIRMED,
      reason,
    });
  }

  /**
   * 2. REJECT BOOKING (Vendor rejects pending booking)
   */
  async rejectBooking(
    bookingId: string,
    actorId: string,
    actorRole: Role | 'SYSTEM',
    reason: string,
  ): Promise<BookingTransitionResult> {
    if (!reason || reason.trim().length === 0) {
      throw new BadRequestException('A rejection reason is mandatory.');
    }
    return this.executeTransition({
      bookingId,
      actorId,
      actorRole,
      targetStatus: BookingStatus.CANCELLED,
      reason: `Vendor Rejected: ${reason}`,
    });
  }

  /**
   * 3. CANCEL BOOKING (Customer, Vendor, or Admin cancels)
   */
  async cancelBooking(
    bookingId: string,
    actorId: string,
    actorRole: Role | 'SYSTEM',
    reason: string,
  ): Promise<BookingTransitionResult> {
    if (!reason || reason.trim().length === 0) {
      throw new BadRequestException('Cancellation reason is required.');
    }
    return this.executeTransition({
      bookingId,
      actorId,
      actorRole,
      targetStatus: BookingStatus.CANCELLED,
      reason,
    });
  }

  /**
   * 4. MARK READY FOR HANDOVER (Pre-trip inspection done, vehicle positioned)
   */
  async markReadyForHandover(
    bookingId: string,
    actorId: string,
    actorRole: Role | 'SYSTEM',
  ): Promise<BookingTransitionResult> {
    return this.executeTransition({
      bookingId,
      actorId,
      actorRole,
      targetStatus: BookingStatus.HANDOVER_READY,
    });
  }

  /**
   * 5. START RENTAL (Customer pickup OTP verified, vehicle handed over)
   */
  async startRental(
    bookingId: string,
    actorId: string,
    actorRole: Role | 'SYSTEM',
    handoverOtp?: string,
    adminReason?: string,
  ): Promise<BookingTransitionResult> {
    return this.executeTransition({
      bookingId,
      actorId,
      actorRole,
      targetStatus: BookingStatus.ONGOING,
      handoverOtp,
      reason: adminReason,
    });
  }

  /**
   * 6. INITIATE RETURN (Rental returning to hub or collection)
   */
  async initiateReturn(
    bookingId: string,
    actorId: string,
    actorRole: Role | 'SYSTEM',
  ): Promise<BookingTransitionResult> {
    return this.executeTransition({
      bookingId,
      actorId,
      actorRole,
      targetStatus: BookingStatus.RETURN_PENDING,
    });
  }

  /**
   * 7. COMPLETE BOOKING (Post-trip inspection finalized, return OTP verified, clean completion)
   */
  async completeBooking(
    bookingId: string,
    actorId: string,
    actorRole: Role | 'SYSTEM',
    handoverOtp?: string,
    adminReason?: string,
  ): Promise<BookingTransitionResult> {
    return this.executeTransition({
      bookingId,
      actorId,
      actorRole,
      targetStatus: BookingStatus.COMPLETED,
      handoverOtp,
      reason: adminReason,
    });
  }

  /**
   * 8. EXPIRE BOOKING (Unconfirmed pending booking timed out)
   */
  async expireBooking(
    bookingId: string,
    systemReason = 'Booking expired due to unconfirmed timeout',
  ): Promise<BookingTransitionResult> {
    return this.executeTransition({
      bookingId,
      actorId: 'SYSTEM',
      actorRole: 'SYSTEM',
      targetStatus: BookingStatus.EXPIRED,
      reason: systemReason,
    });
  }

  /**
   * Core atomic state transition engine enforcing lock, validation, transactional outbox & dispatch.
   */
  async executeTransition(context: BookingTransitionContext): Promise<BookingTransitionResult> {
    const { bookingId, actorId, actorRole, targetStatus, reason, handoverOtp } = context;

    // Acquire lock to serialize mutations for this specific booking
    const lockToken = await this.bookingLockService.acquireCancellationLock(bookingId);

    try {
      // 1. Fetch current authoritative booking with all relations
      const booking = await this.prisma.booking.findUnique({
        where: { id: bookingId },
        include: {
          vendor: { include: { user: true } },
          customer: true,
          car: true,
          payment: true,
          securityDeposit: true,
        },
      });

      if (!booking) {
        throw new NotFoundException(`Booking with ID ${bookingId} not found.`);
      }

      const previousStatus = booking.status;

      // Idempotency check: If already in target status, return success idempotently
      if (previousStatus === targetStatus) {
        this.logger.log(`Booking ${bookingId} already in status ${targetStatus} (idempotent skip).`);
        const existingOutbox = await this.prisma.bookingOutboxEvent.findFirst({
          where: { bookingId, newStatus: targetStatus },
          orderBy: { createdAt: 'desc' },
        });

        return {
          success: true,
          booking,
          outboxEventId: existingOutbox?.id || 'idempotent_existing',
          correlationId: existingOutbox?.correlationId || `idempotent_${bookingId}_${targetStatus}`,
          previousStatus,
          newStatus: targetStatus,
          message: `Booking is already in ${targetStatus} status.`,
        };
      }

      // 2. Authorize actor and validate allowed transitions
      this.validateAuthorization(booking, actorId, actorRole, targetStatus);
      this.validateStateTransition(previousStatus, targetStatus);

      // 3. Validate business preconditions based on target state
      await this.validateBusinessPreconditions(booking, targetStatus, actorId, actorRole, reason, handoverOtp);

      // 4. Compute cancellation fees and refunds if transitioning to CANCELLED
      let cancellationCalc: any = null;
      if (targetStatus === BookingStatus.CANCELLED) {
        const amountPaid = booking.payment?.amount || booking.totalFare;
        const depositAmount = booking.securityDeposit?.amount || 0;
        const isPendingConfirmation = previousStatus === BookingStatus.PENDING;

        cancellationCalc = this.cancellationPolicyService.calculateCancellation({
          startDate: booking.startDate,
          cancellationTime: new Date(),
          amountPaid,
          depositAmount,
          actorRole: actorRole === 'SYSTEM' ? Role.ADMIN : (actorRole as Role),
          isAdminOverride: actorRole === Role.ADMIN && reason?.includes('admin_full_refund'),
          isPendingConfirmation,
        });

        if (cancellationCalc.refundAmountInPaise > 0) {
          await this.paymentsService.refund(
            bookingId,
            cancellationCalc.refundAmountInPaise,
            reason,
            cancellationCalc.tier,
          );
        }
      }

      // 5. Execute DB updates and write Transactional Outbox Event inside an atomic transaction
      const correlationId = `evt_booking_${targetStatus.toLowerCase()}_${bookingId}_${Date.now()}`;
      const eventType = this.resolveEventType(targetStatus);

      const sanitizedPayload: BookingLifecyclePayload = {
        bookingId: booking.id,
        customerId: booking.customerId,
        customerName: booking.customer.name,
        customerPhone: booking.customer.phone,
        vendorId: booking.vendorId,
        vendorName: booking.vendor.businessName,
        vendorPhone: booking.vendor.user?.phone,
        carId: booking.carId,
        vehicleName: `${booking.car.make} ${booking.car.model}`,
        registrationNumber: booking.car.registrationNumber,
        startDate: new Date(booking.startDate).toISOString(),
        endDate: new Date(booking.endDate).toISOString(),
        totalFare: Number(booking.totalFare),
        currency: 'INR',
        pickupLocation: booking.pickupLocation,
        dropLocation: booking.dropLocation || undefined,
        cancellationReason: reason,
        cancellationFee: cancellationCalc ? Number(cancellationCalc.cancellationFee) : undefined,
        refundAmount: cancellationCalc ? Number(cancellationCalc.refundAmount) : undefined,
        actionUrl: `/bookings/${booking.id}`,
      };

      const [updatedBooking, outboxEvent] = await this.prisma.$transaction(
        async (tx) => {
          // Conditional update to protect against concurrent state changes
          const updated = await tx.booking.update({
            where: {
              id: bookingId,
              status: previousStatus, // Optimistic concurrency guard
            },
            data: {
              status: targetStatus,
              ...(reason ? { cancellationReason: reason } : {}),
              ...(cancellationCalc
                ? {
                    cancellationFee: cancellationCalc.cancellationFee,
                    refundAmount: cancellationCalc.refundAmount,
                    cancelledAt: new Date(),
                    cancelledBy: actorId,
                  }
                : {}),
            },
            include: {
              car: true,
              customer: true,
              vendor: { include: { user: true } },
            },
          });

          // Cancel active security deposit if booking cancelled
          if (targetStatus === BookingStatus.CANCELLED && booking.securityDeposit) {
            await tx.securityDeposit.updateMany({
              where: {
                bookingId,
                status: { in: [SecurityDepositStatus.REQUIRED, SecurityDepositStatus.HELD] },
              },
              data: {
                status: SecurityDepositStatus.CANCELLED,
                releasedAt: new Date(),
              },
            });
          }

          // Persist the transactional outbox event
          const event = await tx.bookingOutboxEvent.create({
            data: {
              bookingId,
              eventType,
              aggregateType: 'BOOKING',
              aggregateId: bookingId,
              tenantId: booking.vendorId,
              actorId,
              actorRole: String(actorRole),
              previousStatus,
              newStatus: targetStatus,
              correlationId,
              payload: sanitizedPayload as any,
              status: 'PENDING',
            },
          });

          return [updated, event];
        },
        { timeout: 15000 },
      );

      // 6. Record Audit Log if administrator executed an override
      if (actorRole === Role.ADMIN) {
        await this.auditLogService.log(
          actorId,
          `BOOKING_LIFECYCLE_${targetStatus}`,
          'Booking',
          bookingId,
          {
            previousStatus,
            newStatus: targetStatus,
            reason,
            correlationId,
          },
        );
      }

      // 7. Post-commit asynchronous dispatch to NotificationOrchestrator and SSE stream
      this.outboxService.dispatchEvent(outboxEvent.id).catch((err) => {
        this.logger.error(`Asynchronous outbox dispatch failed for event ${outboxEvent.id}: ${err.message}`);
      });

      // 8. Trigger Referral and Loyalty incentives upon clean completion
      if (targetStatus === BookingStatus.COMPLETED) {
        if (this.referralsService) {
          this.referralsService
            .handleBookingCompleted(bookingId)
            .catch((err) => this.logger.error(`Referral qualification failed for ${bookingId}:`, err));
        }
        if (this.loyaltyService) {
          this.loyaltyService
            .handleBookingCompleted(bookingId)
            .catch((err) => this.logger.error(`Loyalty crediting failed for ${bookingId}:`, err));
        }
      }

      return {
        success: true,
        booking: updatedBooking,
        outboxEventId: outboxEvent.id,
        correlationId,
        previousStatus,
        newStatus: targetStatus,
        message: `Booking successfully transitioned to ${targetStatus}.`,
      };
    } catch (err: any) {
      if (err.code === 'P2025') {
        throw new ConflictException(
          'Booking status was concurrently updated by another process. Please reload and try again.',
        );
      }
      throw err;
    } finally {
      if (lockToken) {
        await this.bookingLockService.releaseCancellationLock(bookingId, lockToken);
      }
    }
  }

  /**
   * Authorization validator
   */
  private validateAuthorization(
    booking: any,
    actorId: string,
    actorRole: Role | 'SYSTEM',
    targetStatus: BookingStatus,
  ) {
    if (actorRole === 'SYSTEM' || actorRole === Role.ADMIN) {
      return; // System and Admin are universally authorized
    }

    const isCustomer = booking.customerId === actorId;
    const isVendor = booking.vendor?.userId === actorId;

    if (!isCustomer && !isVendor) {
      throw new ForbiddenException('Access denied: You are not authorized to perform actions on this booking.');
    }

    if (actorRole === Role.CUSTOMER) {
      if (!isCustomer) {
        throw new ForbiddenException('You can only perform actions on your own bookings.');
      }
      // Customer may only cancel or initiate return
      if (targetStatus !== BookingStatus.CANCELLED && targetStatus !== BookingStatus.RETURN_PENDING) {
        throw new ForbiddenException(`Customers are not permitted to transition bookings to ${targetStatus}.`);
      }
    }

    if (actorRole === Role.VENDOR) {
      if (!isVendor) {
        throw new ForbiddenException('You can only transition bookings for your own fleet.');
      }
      // Vendor may not unilaterally complete without return OTP or cancel without reason
      if (targetStatus === BookingStatus.REFUNDED) {
        throw new ForbiddenException('Vendors cannot directly transition bookings to REFUNDED.');
      }
    }
  }

  /**
   * Canonical State Machine Transition Matrix
   */
  private validateStateTransition(current: BookingStatus, target: BookingStatus): void {
    const matrix: Record<BookingStatus, BookingStatus[]> = {
      [BookingStatus.PENDING]: [BookingStatus.CONFIRMED, BookingStatus.CANCELLED, BookingStatus.EXPIRED],
      [BookingStatus.CONFIRMED]: [
        BookingStatus.HANDOVER_READY,
        BookingStatus.ONGOING,
        BookingStatus.CANCELLED,
        BookingStatus.REFUND_PENDING,
      ],
      [BookingStatus.HANDOVER_READY]: [BookingStatus.ONGOING, BookingStatus.CANCELLED],
      [BookingStatus.ONGOING]: [BookingStatus.RETURN_PENDING, BookingStatus.COMPLETED],
      [BookingStatus.RETURN_PENDING]: [BookingStatus.COMPLETED, BookingStatus.DISPUTED],
      [BookingStatus.REFUND_PENDING]: [BookingStatus.REFUNDED, BookingStatus.DISPUTED],
      [BookingStatus.DISPUTED]: [BookingStatus.COMPLETED, BookingStatus.REFUND_PENDING, BookingStatus.REFUNDED],
      [BookingStatus.COMPLETED]: [],
      [BookingStatus.REFUNDED]: [],
      [BookingStatus.CANCELLED]: [],
      [BookingStatus.EXPIRED]: [],
    };

    const allowed = matrix[current] || [];
    if (!allowed.includes(target)) {
      throw new BadRequestException(
        `Invalid lifecycle transition: Cannot move booking from ${current} to ${target}. Allowed next states: ${allowed.join(', ') || 'None (Terminal State)'}.`,
      );
    }
  }

  /**
   * Precondition validator for specific target states
   */
  private async validateBusinessPreconditions(
    booking: any,
    targetStatus: BookingStatus,
    actorId: string,
    actorRole: Role | 'SYSTEM',
    reason?: string,
    handoverOtp?: string,
  ) {
    const isAdmin = actorRole === Role.ADMIN || actorRole === 'SYSTEM';

    // PRECONDITION FOR CONFIRMED: Payment must be captured unless Admin explicit justification
    if (targetStatus === BookingStatus.CONFIRMED) {
      const isPaid = booking.payment && booking.payment.status === PaymentStatus.PAID;
      if (!isPaid) {
        if (!isAdmin) {
          throw new BadRequestException(
            `Cannot confirm booking: Payment has not been captured (Payment status: ${booking.payment?.status || 'NONE'}).`,
          );
        }
        if (!reason || reason.trim().length < 10) {
          throw new BadRequestException(
            'Admin confirmation of an unpaid booking requires an explicit justification (minimum 10 characters).',
          );
        }
      }
    }

    // PRECONDITION FOR HANDOVER_READY: Pre-trip inspection must be recorded
    if (targetStatus === BookingStatus.HANDOVER_READY) {
      const preTrip = await this.prisma.inspection.findUnique({
        where: { bookingId_type: { bookingId: booking.id, type: InspectionType.PRE_TRIP } },
      });
      if (!preTrip || !preTrip.finalized) {
        throw new BadRequestException(
          'Cannot mark ready for handover: Pre-trip vehicle inspection must be recorded and finalized first.',
        );
      }
    }

    // PRECONDITION FOR ONGOING: Pre-trip inspection finalized + Pickup OTP verified
    if (targetStatus === BookingStatus.ONGOING) {
      const preTrip = await this.prisma.inspection.findUnique({
        where: { bookingId_type: { bookingId: booking.id, type: InspectionType.PRE_TRIP } },
      });
      if (!preTrip || !preTrip.finalized) {
        throw new BadRequestException(
          'Cannot start trip: Pre-trip vehicle inspection must be recorded and finalized before vehicle handover.',
        );
      }

      if (!isAdmin) {
        if (!handoverOtp) {
          throw new BadRequestException('Customer handover OTP is required to verify pickup and start the trip.');
        }
        await this.handoverOtpService.verifyOtp(booking.id, HandoverOtpType.PICKUP, handoverOtp);
      } else if (!handoverOtp && (!reason || reason.trim().length < 10)) {
        throw new BadRequestException('Admin trip start override requires explicit justification (minimum 10 characters).');
      }
    }

    // PRECONDITION FOR COMPLETED: Dispute check + Post-trip inspection finalized + Return OTP verified
    if (targetStatus === BookingStatus.COMPLETED) {
      if (booking.disputeFlag && !isAdmin) {
        throw new BadRequestException(
          'Cannot complete trip: Booking is flagged with an active dispute or damage claim. Resolve dispute before completion.',
        );
      }

      const postTrip = await this.prisma.inspection.findUnique({
        where: { bookingId_type: { bookingId: booking.id, type: InspectionType.POST_TRIP } },
      });
      if (!postTrip || !postTrip.finalized) {
        throw new BadRequestException(
          'Cannot complete trip: Post-trip vehicle inspection must be recorded and finalized before completing trip.',
        );
      }

      if (!isAdmin) {
        if (!handoverOtp) {
          throw new BadRequestException('Customer return verification OTP is required to complete the trip.');
        }
        await this.handoverOtpService.verifyOtp(booking.id, HandoverOtpType.RETURN, handoverOtp);
      } else if (!handoverOtp && (!reason || reason.trim().length < 10)) {
        throw new BadRequestException('Admin trip completion override requires explicit justification (minimum 10 characters).');
      }
    }
  }

  private resolveEventType(status: BookingStatus): string {
    switch (status) {
      case BookingStatus.CONFIRMED:
        return 'BOOKING_CONFIRMED';
      case BookingStatus.CANCELLED:
        return 'BOOKING_CANCELLED';
      case BookingStatus.HANDOVER_READY:
        return 'HANDOVER_READY';
      case BookingStatus.ONGOING:
        return 'TRIP_STARTED';
      case BookingStatus.RETURN_PENDING:
        return 'RETURN_PENDING';
      case BookingStatus.COMPLETED:
        return 'BOOKING_COMPLETED';
      case BookingStatus.EXPIRED:
        return 'BOOKING_EXPIRED';
      default:
        return `BOOKING_${status}`;
    }
  }
}

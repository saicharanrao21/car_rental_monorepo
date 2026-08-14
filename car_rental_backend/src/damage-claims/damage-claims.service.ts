import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { DepositsService } from '../deposits/deposits.service';
import { UploadsService } from '../uploads/uploads.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { CreateDamageClaimDto } from './dto/create-damage-claim.dto';
import { AdjudicateClaimDto, ClaimDecision } from './dto/adjudicate-claim.dto';
import { DisputeClaimDto } from './dto/dispute-claim.dto';
import { DamageClaimStatus, BookingStatus, Role, Prisma } from '@prisma/client';

@Injectable()
export class DamageClaimsService {
  private readonly logger = new Logger(DamageClaimsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly depositsService: DepositsService,
    private readonly uploadsService: UploadsService,
    private readonly notificationsService: NotificationsService,
    private readonly auditLogService: AuditLogService,
  ) {}

  /**
   * Submits a new post-trip damage claim with atomic concurrency protection against duplicate active claims (SEC-P3-01).
   */
  async createClaim(
    bookingId: string,
    dto: CreateDamageClaimDto,
    requestingUser: { userId: string; role: Role },
  ) {
    let claim: any;
    try {
      claim = await this.prisma.$transaction(async (tx) => {
        const booking = await tx.booking.findUnique({
          where: { id: bookingId },
          include: { vendor: true, customer: true },
        });

        if (!booking) {
          throw new NotFoundException('Booking not found.');
        }

        const isAdmin = requestingUser.role === Role.ADMIN;
        const isVendor = booking.vendor.userId === requestingUser.userId;

        if (!isAdmin && !isVendor) {
          throw new ForbiddenException(
            'Access denied: Only the fleet owner or admin can file a damage claim.',
          );
        }

        if (booking.status !== BookingStatus.COMPLETED) {
          throw new BadRequestException(
            `Damage claims can only be submitted for COMPLETED trips. Current status: ${booking.status}`,
          );
        }

        const existingClaim = await tx.damageClaim.findFirst({
          where: {
            bookingId,
            status: {
              notIn: [DamageClaimStatus.REJECTED, DamageClaimStatus.SETTLED],
            },
          },
        });

        if (existingClaim) {
          throw new ConflictException(
            'An active damage claim is already undergoing review for this booking.',
          );
        }

        return tx.damageClaim.create({
          data: {
            bookingId,
            vendorId: booking.vendorId,
            claimedAmount: new Prisma.Decimal(dto.claimedAmount),
            status: DamageClaimStatus.SUBMITTED,
            description: dto.description,
            damagePhotos: dto.damagePhotos || [],
            vendorNotes: dto.vendorNotes || null,
          },
          include: {
            booking: {
              select: { customerId: true },
            },
          },
        });
      });
    } catch (err: any) {
      if (err.code === 'P2002') {
        throw new ConflictException(
          'An active damage claim already exists for this booking (database constraint enforced).',
        );
      }
      throw err;
    }

    // Notify customer
    if (claim.booking?.customerId) {
      this.notificationsService
        .notifyUser(
          claim.booking.customerId,
          'Damage Claim Submitted',
          `A damage claim of INR ${dto.claimedAmount} was submitted for your completed trip. Our support team is reviewing the inspection records.`,
        )
        .catch((err) =>
          this.logger.error('Failed to notify customer of damage claim', err),
        );
    }

    return claim;
  }

  /**
   * Retrieves all damage claims for a booking with presigned photo download URLs.
   */
  async getClaimsForBooking(
    bookingId: string,
    requestingUser: { userId: string; role: Role },
  ) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { vendor: true },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    const isAdmin = requestingUser.role === Role.ADMIN;
    const isSupport = requestingUser.role === Role.SUPPORT_AGENT;
    const isCustomer = booking.customerId === requestingUser.userId;
    const isVendor = booking.vendor.userId === requestingUser.userId;

    if (!isAdmin && !isSupport && !isCustomer && !isVendor) {
      throw new ForbiddenException(
        'Access denied: You are not authorized to view claims for this booking.',
      );
    }

    const claims = await this.prisma.damageClaim.findMany({
      where: { bookingId },
      orderBy: { createdAt: 'desc' },
    });

    // Resolve presigned GET URLs for all damage photos
    return Promise.all(
      claims.map(async (claim) => {
        const signedPhotos = await Promise.all(
          claim.damagePhotos.map((photoKey) =>
            this.uploadsService.getPresignedDownloadUrl(photoKey, 900),
          ),
        );
        return {
          ...claim,
          damagePhotos: signedPhotos,
        };
      }),
    );
  }

  /**
   * Records customer dispute for an active damage claim.
   */
  async disputeClaim(
    claimId: string,
    dto: DisputeClaimDto,
    requestingUser: { userId: string; role: Role },
  ) {
    const claim = await this.prisma.damageClaim.findUnique({
      where: { id: claimId },
      include: { booking: true },
    });

    if (!claim) {
      throw new NotFoundException('Damage claim not found.');
    }

    if (claim.booking.customerId !== requestingUser.userId) {
      throw new ForbiddenException(
        'Access denied: You can only dispute claims against your own bookings.',
      );
    }

    if (
      claim.status !== DamageClaimStatus.SUBMITTED &&
      claim.status !== DamageClaimStatus.UNDER_REVIEW
    ) {
      throw new BadRequestException(
        `Cannot dispute claim in status: ${claim.status}`,
      );
    }

    return this.prisma.damageClaim.update({
      where: { id: claimId },
      data: {
        customerDispute: dto.customerDispute,
        status: DamageClaimStatus.UNDER_REVIEW,
      },
    });
  }

  /**
   * Admin adjudication of a damage claim and automated settlement against security deposit.
   */
  async adjudicateClaim(
    claimId: string,
    dto: AdjudicateClaimDto,
    adminUserId: string,
  ) {
    const claim = await this.prisma.damageClaim.findUnique({
      where: { id: claimId },
      include: { booking: true },
    });

    if (!claim) {
      throw new NotFoundException('Damage claim not found.');
    }

    if (
      claim.status === DamageClaimStatus.SETTLED ||
      claim.status === DamageClaimStatus.REJECTED
    ) {
      throw new ConflictException(
        `Claim is already finalized with status: ${claim.status}`,
      );
    }

    if (dto.decision === ClaimDecision.REJECTED) {
      const updated = await this.prisma.damageClaim.update({
        where: { id: claimId },
        data: {
          status: DamageClaimStatus.REJECTED,
          adminNotes: dto.adminNotes,
          resolvedAt: new Date(),
        },
      });

      // Release deposit back to customer
      await this.depositsService.releaseDeposit(
        claim.bookingId,
        adminUserId,
        `Damage claim rejected: ${dto.adminNotes}`,
      );

      this.auditLogService.log(
        adminUserId,
        'DAMAGE_CLAIM_REJECTED',
        'DamageClaim',
        claimId,
        {
          bookingId: claim.bookingId,
          adminNotes: dto.adminNotes,
        },
      );

      return updated;
    }

    // Approved or Partially Approved
    const approvedAmount = dto.approvedAmount;
    if (!approvedAmount || approvedAmount <= 0) {
      throw new BadRequestException(
        'Approved amount must be greater than zero for approved claims.',
      );
    }

    if (approvedAmount > claim.claimedAmount.toNumber()) {
      throw new BadRequestException(
        `Approved amount (${approvedAmount}) cannot exceed claimed amount (${claim.claimedAmount.toNumber()}).`,
      );
    }

    const approvedDecimal = new Prisma.Decimal(approvedAmount);
    const targetStatus =
      dto.decision === ClaimDecision.PARTIALLY_APPROVED ||
      approvedAmount < claim.claimedAmount.toNumber()
        ? DamageClaimStatus.PARTIALLY_APPROVED
        : DamageClaimStatus.APPROVED;

    // Settle deduction against security deposit
    await this.depositsService.settleDeduction(
      claim.bookingId,
      approvedAmount,
      adminUserId,
      dto.adminNotes,
    );

    const updated = await this.prisma.damageClaim.update({
      where: { id: claimId },
      data: {
        status: targetStatus,
        approvedAmount: approvedDecimal,
        adminNotes: dto.adminNotes,
        resolvedAt: new Date(),
      },
    });

    this.auditLogService.log(
      adminUserId,
      'DAMAGE_CLAIM_APPROVED',
      'DamageClaim',
      claimId,
      {
        bookingId: claim.bookingId,
        claimedAmount: claim.claimedAmount.toNumber(),
        approvedAmount,
        decision: dto.decision,
        adminNotes: dto.adminNotes,
      },
    );

    return updated;
  }
}

import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BookingStatus, PaymentStatus, Prisma } from '@prisma/client';
import {
  ResolveRiskAssessmentDto,
  RiskResolutionStatus,
} from './dto/resolve-risk-assessment.dto';
import { RiskAssessmentQueryDto } from './dto/risk-assessment-query.dto';

export enum RiskLevel {
  LOW = 'LOW',
  MEDIUM = 'MEDIUM',
  HIGH = 'HIGH',
  CRITICAL = 'CRITICAL',
}

export enum RiskAction {
  ALLOW = 'ALLOW',
  MONITOR = 'MONITOR',
  REVIEW_REQUIRED = 'REVIEW_REQUIRED',
  BLOCK = 'BLOCK',
}

export interface RiskSignal {
  code: string;
  description: string;
  scoreDelta: number;
}

export interface RiskEvaluationContext {
  actionName?: string;
  bookingId?: string;
  fare?: number;
  referralCode?: string;
  referrerId?: string;
}

export interface RiskAssessmentResult {
  userId: string;
  userName: string;
  userPhone: string;
  score: number;
  riskLevel: RiskLevel;
  action: RiskAction;
  signals: RiskSignal[];
  evaluatedAt: Date;
}

@Injectable()
export class FraudService {
  private readonly logger = new Logger(FraudService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Deterministically evaluates a user's risk profile based on identity, booking history,
   * payment records, and referral/wallet anomalies.
   */
  async evaluateUserRisk(
    userId: string,
    context?: RiskEvaluationContext,
  ): Promise<RiskAssessmentResult> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        customerKyc: true,
      },
    });

    if (!user) {
      throw new NotFoundException(`User with ID ${userId} not found`);
    }

    const signals: RiskSignal[] = [];

    // 1. Identity Signal: User Ban Status
    if (user.banned) {
      signals.push({
        code: 'BANNED_USER',
        description: 'User account has been flagged and banned administratively',
        scoreDelta: 100,
      });
    }

    // 2. Identity Signal: Duplicate Driving Licence
    if (user.customerKyc?.licenceNumber) {
      const duplicateLicences = await this.prisma.customerKyc.count({
        where: {
          licenceNumber: user.customerKyc.licenceNumber,
          userId: { not: userId },
        },
      });

      if (duplicateLicences > 0) {
        signals.push({
          code: 'DUPLICATE_DRIVING_LICENCE',
          description: `Driving Licence number ${user.customerKyc.licenceNumber} is registered on ${duplicateLicences} other user account(s)`,
          scoreDelta: 40,
        });
      }
    }

    // Time window cutoffs
    const now = new Date();
    const twoHoursAgo = new Date(now.getTime() - 2 * 60 * 60 * 1000);
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    // 3. Booking Velocity: Bookings created in the last 2 hours
    const recentBookingCount = await this.prisma.booking.count({
      where: {
        customerId: userId,
        createdAt: { gte: twoHoursAgo },
      },
    });

    if (recentBookingCount >= 3) {
      signals.push({
        code: 'HIGH_BOOKING_VELOCITY',
        description: `Rapid booking creation: ${recentBookingCount} booking attempts within the last 2 hours`,
        scoreDelta: 25,
      });
    }

    // 4. Cancellation Velocity: Cancellations in the last 24 hours
    const recentCancellations = await this.prisma.booking.count({
      where: {
        customerId: userId,
        status: BookingStatus.CANCELLED,
        cancelledAt: { gte: oneDayAgo },
      },
    });

    if (recentCancellations >= 3) {
      signals.push({
        code: 'HIGH_CANCELLATION_VELOCITY',
        description: `Suspicious cancellation pattern: ${recentCancellations} cancellations within the last 24 hours`,
        scoreDelta: 30,
      });
    }

    // 5. Payment Failures: Bookings with failed payments in last 24h
    const failedPaymentCount = await this.prisma.payment.count({
      where: {
        booking: { customerId: userId },
        status: PaymentStatus.FAILED,
        createdAt: { gte: oneDayAgo },
      },
    });

    if (failedPaymentCount >= 3) {
      signals.push({
        code: 'REPEATED_PAYMENT_FAILURES',
        description: `Payment distress signal: ${failedPaymentCount} failed payment attempts in the last 24 hours`,
        scoreDelta: 35,
      });
    }

    // 6. Multiple Concurrent Active Trips
    const concurrentActiveBookings = await this.prisma.booking.count({
      where: {
        customerId: userId,
        status: { in: [BookingStatus.ONGOING, BookingStatus.HANDOVER_READY] },
      },
    });

    if (concurrentActiveBookings >= 2) {
      signals.push({
        code: 'MULTIPLE_ACTIVE_BOOKINGS',
        description: `Simultaneous vehicle custody: Customer has ${concurrentActiveBookings} ongoing active rentals concurrently`,
        scoreDelta: 20,
      });
    }

    // 7. Fresh Account Spike: Account < 1 hour old with high activity
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    if (user.createdAt >= oneHourAgo && recentBookingCount >= 2) {
      signals.push({
        code: 'FRESH_ACCOUNT_SPIKE',
        description: 'New account created less than 1 hour ago initiating multiple high-frequency requests',
        scoreDelta: 15,
      });
    }

    // 8. Self-Referral Attempt: Code owned by same user, phone, or driving licence
    let isSelfReferral = false;
    if (context?.referrerId && context.referrerId === userId) {
      isSelfReferral = true;
    }
    if (!isSelfReferral && context?.referralCode) {
      const cleanCode = context.referralCode.trim().toUpperCase();
      if (user.referralCode && user.referralCode.toUpperCase() === cleanCode) {
        isSelfReferral = true;
      } else {
        const codeOwner = await this.prisma.user.findUnique({
          where: { referralCode: cleanCode },
          include: { customerKyc: true },
        });
        if (codeOwner) {
          if (codeOwner.id === userId) {
            isSelfReferral = true;
          } else if (
            user.phone &&
            codeOwner.phone &&
            user.phone.trim() === codeOwner.phone.trim()
          ) {
            isSelfReferral = true;
          } else if (
            user.customerKyc?.licenceNumber &&
            codeOwner.customerKyc?.licenceNumber &&
            user.customerKyc.licenceNumber.trim().toUpperCase() ===
              codeOwner.customerKyc.licenceNumber.trim().toUpperCase()
          ) {
            isSelfReferral = true;
          }
        }
      }
    }

    if (isSelfReferral) {
      signals.push({
        code: 'SELF_REFERRAL_ATTEMPT',
        description:
          'Detected self-referral attempt: referral code owned by the same customer, phone identity, or driving licence',
        scoreDelta: 60,
      });
    }

    // Aggregate score bounded between 0 and 100
    const rawScore = signals.reduce((sum, s) => sum + s.scoreDelta, 0);
    const score = Math.min(100, Math.max(0, rawScore));

    // Determine deterministic risk level
    let riskLevel: RiskLevel;
    let action: RiskAction;

    if (score >= 80) {
      riskLevel = RiskLevel.CRITICAL;
      action = RiskAction.BLOCK;
    } else if (score >= 60) {
      riskLevel = RiskLevel.HIGH;
      action = RiskAction.REVIEW_REQUIRED;
    } else if (score >= 30) {
      riskLevel = RiskLevel.MEDIUM;
      action = RiskAction.MONITOR;
    } else {
      riskLevel = RiskLevel.LOW;
      action = RiskAction.ALLOW;
    }

    // If High or Critical risk, log an auditable Risk Assessment event
    if (riskLevel === RiskLevel.HIGH || riskLevel === RiskLevel.CRITICAL) {
      try {
        await this.prisma.auditLog.create({
          data: {
            adminUserId: userId, // associate with user subject
            action: 'RISK_ASSESSMENT_ALERT',
            targetType: 'User',
            targetId: userId,
            metadata: {
              userName: user.name,
              userPhone: user.phone,
              score,
              riskLevel,
              action,
              signals: signals as any,
              status: 'PENDING_REVIEW',
              context: (context as any) || {},
              createdAt: now.toISOString(),
            } as Prisma.InputJsonValue,
          },
        });
      } catch (err) {
        this.logger.warn(`Failed to persist risk assessment audit log: ${err}`);
      }
    }

    return {
      userId,
      userName: user.name,
      userPhone: user.phone,
      score,
      riskLevel,
      action,
      signals,
      evaluatedAt: now,
    };
  }

  /**
   * Summarizes platform risk events and severity counts for the Admin Dashboard.
   */
  async getFraudSummary() {
    const riskLogs = await this.prisma.auditLog.findMany({
      where: {
        action: 'RISK_ASSESSMENT_ALERT',
      },
      select: {
        metadata: true,
      },
    });

    let criticalCount = 0;
    let highCount = 0;
    let mediumCount = 0;
    let lowCount = 0;
    let pendingReviewCount = 0;

    riskLogs.forEach((log) => {
      const meta = log.metadata as any;
      if (meta) {
        if (meta.riskLevel === RiskLevel.CRITICAL) criticalCount++;
        else if (meta.riskLevel === RiskLevel.HIGH) highCount++;
        else if (meta.riskLevel === RiskLevel.MEDIUM) mediumCount++;
        else lowCount++;

        if (meta.status === 'PENDING_REVIEW') {
          pendingReviewCount++;
        }
      }
    });

    return {
      totalEvents: riskLogs.length,
      criticalCount,
      highCount,
      mediumCount,
      lowCount,
      pendingReviewCount,
    };
  }

  /**
   * Retrieves paginated risk assessment records with filter support.
   */
  async getRiskAssessments(query: RiskAssessmentQueryDto) {
    const page = Number(query.page) || 1;
    const limit = Math.min(100, Number(query.limit) || 20);
    const skip = (page - 1) * limit;

    const where: Prisma.AuditLogWhereInput = {
      action: 'RISK_ASSESSMENT_ALERT',
    };

    if (query.userId) {
      where.targetId = query.userId;
    }

    if (query.startDate || query.endDate) {
      where.createdAt = {};
      if (query.startDate) where.createdAt.gte = new Date(query.startDate);
      if (query.endDate) where.createdAt.lte = new Date(query.endDate);
    }

    const [total, logs] = await Promise.all([
      this.prisma.auditLog.count({ where }),
      this.prisma.auditLog.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    const formattedData = logs.map((log) => {
      const meta = (log.metadata as any) || {};
      return {
        id: log.id,
        userId: log.targetId,
        userName: meta.userName || 'Unknown User',
        userPhone: meta.userPhone || 'N/A',
        score: meta.score ?? 0,
        riskLevel: meta.riskLevel || RiskLevel.LOW,
        action: meta.action || RiskAction.ALLOW,
        signals: meta.signals || [],
        status: meta.status || 'PENDING_REVIEW',
        adminNotes: meta.adminNotes || null,
        resolvedBy: meta.resolvedBy || null,
        createdAt: log.createdAt,
        resolvedAt: meta.resolvedAt || null,
      };
    });

    // Optional in-memory filter on metadata riskLevel or status if provided
    let filtered = formattedData;
    if (query.riskLevel) {
      filtered = filtered.filter((d) => d.riskLevel === query.riskLevel);
    }
    if (query.status) {
      filtered = filtered.filter((d) => d.status === query.status);
    }

    return {
      data: filtered,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * Resolves, dismisses, or escalates a risk event with admin audit logging.
   */
  async resolveRiskAssessment(
    adminUserId: string,
    assessmentId: string,
    dto: ResolveRiskAssessmentDto,
  ) {
    const log = await this.prisma.auditLog.findUnique({
      where: { id: assessmentId },
    });

    if (!log || log.action !== 'RISK_ASSESSMENT_ALERT') {
      throw new NotFoundException(`Risk assessment record ${assessmentId} not found`);
    }

    const existingMeta = (log.metadata as any) || {};
    const updatedMeta = {
      ...existingMeta,
      status: dto.status,
      adminNotes: dto.adminNotes,
      resolvedBy: adminUserId,
      resolvedAt: new Date().toISOString(),
    };

    await this.prisma.auditLog.update({
      where: { id: assessmentId },
      data: {
        metadata: updatedMeta,
      },
    });

    // Log administrative action
    await this.prisma.auditLog.create({
      data: {
        adminUserId,
        action: 'FRAUD_RISK_RESOLUTION',
        targetType: 'RiskAssessment',
        targetId: assessmentId,
        metadata: {
          previousStatus: existingMeta.status || 'PENDING_REVIEW',
          newStatus: dto.status,
          adminNotes: dto.adminNotes,
        },
      },
    });

    this.logger.log(
      `[FRAUD RESOLVE] Admin ${adminUserId} marked assessment ${assessmentId} as ${dto.status}`,
    );

    return {
      success: true,
      assessmentId,
      status: dto.status,
      adminNotes: dto.adminNotes,
    };
  }
}

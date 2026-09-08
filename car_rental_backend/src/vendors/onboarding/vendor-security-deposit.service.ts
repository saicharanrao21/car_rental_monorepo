import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  ConflictException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisCacheService } from '../../redis/redis-cache.service';
import { REDIS_NAMESPACES } from '../../redis/redis-namespace.constants';
import { AuditLogService } from '../../admin/audit-log.service';
import { SystemConfigService } from '../../config-engine/system-config.service';
import {
  VendorDepositStatus,
  VendorDepositTransactionType,
  LedgerDirection,
  RequirementFulfillmentStatus,
  RecordDepositPaymentDto,
  ReleaseDepositDto,
  RefundDepositDto,
  ForfeitDepositDto,
  AdjustDepositDto,
  HoldDepositDto,
  VendorDepositSummary,
} from './onboarding.types';
import { VendorOnboardingRulesConfig } from '../../config-engine/system-config.interface';

@Injectable()
export class VendorSecurityDepositService {
  private readonly logger = new Logger(VendorSecurityDepositService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cacheService: RedisCacheService,
    @Optional() private readonly auditLogService?: AuditLogService,
    @Optional() private readonly systemConfigService?: SystemConfigService,
  ) {}

  /**
   * Retrieves or initializes the security deposit record for a vendor.
   */
  async getDeposit(vendorId: string): Promise<any> {
    let deposit = await this.prisma.vendorSecurityDeposit.findUnique({
      where: { vendorId },
    });

    if (!deposit) {
      // Determine required amount from SystemConfigEngine or default 25,000 INR
      let defaultAmount = 25000;
      if (this.systemConfigService) {
        try {
          const config = await this.systemConfigService.getConfig<VendorOnboardingRulesConfig>(
            'vendor.onboarding.rules',
          );
          if (config?.defaultSecurityDepositAmount) {
            defaultAmount = config.defaultSecurityDepositAmount;
          }
        } catch {
          // Fallback to safe default
        }
      }

      deposit = await this.prisma.vendorSecurityDeposit.create({
        data: {
          vendorId,
          requiredAmount: defaultAmount,
          paidAmount: 0,
          remainingAmount: defaultAmount,
          status: VendorDepositStatus.REQUIRED,
          requirementCode: 'DEP_SECURITY',
          requirementVersion: 1,
        },
      });
    }

    return {
      ...deposit,
      amountRequired: Number(deposit.requiredAmount ?? (deposit as any).amountRequired),
      amountPaid: Number(deposit.paidAmount ?? (deposit as any).amountPaid),
      amountRemaining: Number(deposit.remainingAmount ?? (deposit as any).amountRemaining),
      requiredAmount: Number(deposit.requiredAmount ?? (deposit as any).amountRequired),
      paidAmount: Number(deposit.paidAmount ?? (deposit as any).amountPaid),
      remainingAmount: Number(deposit.remainingAmount ?? (deposit as any).amountRemaining),
    };
  }

  /**
   * Summarizes deposit status for eligibility evaluation.
   */
  async getDepositSummary(vendorId: string): Promise<VendorDepositSummary> {
    const deposit = await this.getDeposit(vendorId);
    const isSatisfied =
      deposit.status === VendorDepositStatus.PAID ||
      deposit.status === VendorDepositStatus.HELD;

    return {
      depositId: deposit.id,
      requiredAmount: Number(deposit.requiredAmount),
      paidAmount: Number(deposit.paidAmount),
      remainingAmount: Number(deposit.remainingAmount),
      status: deposit.status,
      isSatisfied,
    };
  }

  /**
   * Records a deposit payment with strict ACID concurrency, idempotency, and ledger recording.
   */
  async recordPayment(
    vendorId: string,
    dto: RecordDepositPaymentDto,
    actorId: string,
    actorRole: string = 'ADMIN',
  ) {
    const paymentAmount = Number(dto.amount);
    if (paymentAmount <= 0) {
      throw new BadRequestException('Payment amount must be greater than zero.');
    }

    return this.prisma.$transaction(async (tx) => {
      // 1. Idempotency Check
      if (dto.idempotencyKey) {
        const existingEntry = await tx.vendorDepositLedgerEntry.findUnique({
          where: { idempotencyKey: dto.idempotencyKey },
        });
        if (existingEntry) {
          const deposit = await tx.vendorSecurityDeposit.findUnique({
            where: { id: existingEntry.depositId },
          });
          return {
            ...deposit,
            amountPaid: Number(deposit?.paidAmount ?? 0),
            amountRequired: Number(deposit?.requiredAmount ?? 0),
            deposit,
            ledgerEntry: existingEntry,
            isIdempotentReplay: true,
          };
        }
      }

      // 2. Fetch deposit record
      let deposit = await tx.vendorSecurityDeposit.findUnique({
        where: { vendorId },
      });

      if (!deposit) {
        let defaultAmount = 25000;
        if (this.systemConfigService) {
          try {
            const config = await this.systemConfigService.getConfig<VendorOnboardingRulesConfig>(
              'vendor.onboarding.rules',
            );
            if (config?.defaultSecurityDepositAmount) {
              defaultAmount = config.defaultSecurityDepositAmount;
            }
          } catch {}
        }

        deposit = await tx.vendorSecurityDeposit.create({
          data: {
            vendorId,
            requiredAmount: defaultAmount,
            paidAmount: 0,
            remainingAmount: defaultAmount,
            status: VendorDepositStatus.REQUIRED,
            requirementCode: 'DEP_SECURITY',
            requirementVersion: 1,
          },
        });
      }

      if (
        deposit.status === VendorDepositStatus.RELEASED ||
        deposit.status === VendorDepositStatus.REFUNDED ||
        deposit.status === VendorDepositStatus.FORFEITED
      ) {
        throw new BadRequestException(
          `Cannot record payment on deposit in terminal state [${deposit.status}].`,
        );
      }

      const balanceBefore = Number(deposit.paidAmount);
      const requiredAmount = Number(deposit.requiredAmount);

      // Check partial payment rules if first payment
      if (balanceBefore === 0 && this.systemConfigService) {
        try {
          const config = await this.systemConfigService.getConfig<VendorOnboardingRulesConfig>(
            'vendor.onboarding.rules',
          );
          if (config && !config.allowPartialDepositPayment && paymentAmount < requiredAmount) {
            throw new BadRequestException(
              `Partial deposit payments are not permitted. Full required amount is INR ${requiredAmount}.`,
            );
          }
          if (config && config.allowPartialDepositPayment && config.minInitialDepositPercentage > 0) {
            const minRequired = (requiredAmount * config.minInitialDepositPercentage) / 100;
            if (paymentAmount < minRequired) {
              throw new BadRequestException(
                `Initial deposit payment must be at least ${config.minInitialDepositPercentage}% (INR ${minRequired}).`,
              );
            }
          }
        } catch (err: any) {
          if (err instanceof BadRequestException) throw err;
        }
      }

      const balanceAfter = balanceBefore + paymentAmount;
      const remainingAmount = Math.max(0, requiredAmount - balanceAfter);

      let newStatus: VendorDepositStatus = deposit.status;
      if (balanceAfter >= requiredAmount) {
        newStatus = VendorDepositStatus.PAID;
      } else {
        newStatus = VendorDepositStatus.PARTIALLY_PAID;
      }

      const transactionType =
        balanceBefore === 0
          ? VendorDepositTransactionType.INITIAL_PAYMENT
          : VendorDepositTransactionType.TOP_UP;

      // Update deposit
      const updatedDeposit = await tx.vendorSecurityDeposit.update({
        where: { id: deposit.id },
        data: {
          paidAmount: balanceAfter,
          remainingAmount,
          status: newStatus,
        },
      });

      // Insert ledger entry
      const ledgerEntry = await tx.vendorDepositLedgerEntry.create({
        data: {
          depositId: deposit.id,
          amount: paymentAmount,
          direction: LedgerDirection.CREDIT,
          balanceBefore,
          balanceAfter,
          transactionType,
          paymentMethod: dto.paymentMethod,
          reference: dto.reference ?? (dto as any).referenceId,
          reason: dto.reason ?? 'Security deposit payment',
          actorId,
          actorRole,
          idempotencyKey: dto.idempotencyKey,
          metadata: dto.metadata ? dto.metadata : undefined,
        },
      });

      // Synchronize monetary requirement state if fully paid
      if (newStatus === VendorDepositStatus.PAID) {
        const reqDef = await tx.onboardingRequirementDefinition.findFirst({
          where: { code: 'DEP_SECURITY', isActive: true },
        });

        if (reqDef) {
          await tx.vendorRequirementState.upsert({
            where: {
              vendorId_requirementDefinitionId: {
                vendorId,
                requirementDefinitionId: reqDef.id,
              },
            },
            update: {
              status: RequirementFulfillmentStatus.APPROVED,
              reviewedByUserId: actorId,
              reviewedAt: new Date(),
            },
            create: {
              vendorId,
              requirementDefinitionId: reqDef.id,
              status: RequirementFulfillmentStatus.APPROVED,
              reviewedByUserId: actorId,
              reviewedAt: new Date(),
            },
          });
        }
      }

      // Invalidate caches
      await this.invalidateDepositCache(vendorId);

      // Audit log
      if (this.auditLogService) {
        await this.auditLogService.log(
          actorId,
          'RECORD_VENDOR_DEPOSIT_PAYMENT',
          'VENDOR_DEPOSIT',
          deposit.id,
          {
            vendorId,
            amount: paymentAmount,
            balanceBefore,
            balanceAfter,
            status: newStatus,
            reference: dto.reference ?? (dto as any).referenceId,
          },
        );
      }

      return {
        ...updatedDeposit,
        status: updatedDeposit.status,
        amountPaid: Number(updatedDeposit.paidAmount),
        amountRequired: Number(updatedDeposit.requiredAmount),
        paidAmount: Number(updatedDeposit.paidAmount),
        requiredAmount: Number(updatedDeposit.requiredAmount),
        remainingAmount: Number(updatedDeposit.remainingAmount),
        deposit: updatedDeposit,
        ledgerEntry,
        isIdempotentReplay: false,
      };
    });
  }

  /**
   * Holds the deposit (transitions from PAID to HELD).
   */
  async holdDeposit(vendorId: string, adminUserId: string, reason?: string) {
    const deposit = await this.getDeposit(vendorId);

    if (
      deposit.status !== VendorDepositStatus.PAID &&
      deposit.status !== VendorDepositStatus.PARTIALLY_PAID
    ) {
      throw new BadRequestException(
        `Cannot hold deposit with status [${deposit.status}]. Must be PAID or PARTIALLY_PAID.`,
      );
    }

    const updated = await this.prisma.vendorSecurityDeposit.update({
      where: { id: deposit.id },
      data: {
        status: VendorDepositStatus.HELD,
        heldAt: new Date(),
      },
    });

    await this.invalidateDepositCache(vendorId);

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'HOLD_VENDOR_DEPOSIT',
        'VENDOR_DEPOSIT',
        deposit.id,
        { vendorId, previousStatus: deposit.status, newStatus: VendorDepositStatus.HELD, reason },
      );
    }

    return {
      ...updated,
      status: updated.status,
      amountPaid: Number(updated.paidAmount),
      amountRequired: Number(updated.requiredAmount),
      paidAmount: Number(updated.paidAmount),
      requiredAmount: Number(updated.requiredAmount),
      remainingAmount: Number(updated.remainingAmount),
    };
  }

  /**
   * Releases the deposit back to the partner upon verified account closure.
   */
  async releaseDeposit(
    vendorId: string,
    dto: ReleaseDepositDto,
    adminUserId: string,
  ) {
    const deposit = await this.getDeposit(vendorId);

    if (
      deposit.status !== VendorDepositStatus.PAID &&
      deposit.status !== VendorDepositStatus.HELD
    ) {
      throw new BadRequestException(
        `Deposit must be PAID or HELD to release. Current status: [${deposit.status}].`,
      );
    }

    return this.prisma.$transaction(async (tx) => {
      // Idempotency check
      if (dto.idempotencyKey) {
        const existingEntry = await tx.vendorDepositLedgerEntry.findUnique({
          where: { idempotencyKey: dto.idempotencyKey },
        });
        if (existingEntry) {
          return {
            ...deposit,
            amountPaid: Number(deposit.paidAmount),
            amountRequired: Number(deposit.requiredAmount),
            deposit,
            ledgerEntry: existingEntry,
            isIdempotentReplay: true,
          };
        }
      }

      const isHoldRelease = deposit.status === VendorDepositStatus.HELD;
      const newStatus = isHoldRelease ? VendorDepositStatus.PAID : VendorDepositStatus.RELEASED;
      const updatedPaidAmount = isHoldRelease ? deposit.paidAmount : 0;
      const updatedRemainingAmount = isHoldRelease ? deposit.remainingAmount : deposit.requiredAmount;
      const balanceBefore = Number(deposit.paidAmount);
      const balanceAfter = Number(updatedPaidAmount);

      const updatedDeposit = await tx.vendorSecurityDeposit.update({
        where: { id: deposit.id },
        data: {
          status: newStatus,
          releasedAt: new Date(),
          paidAmount: updatedPaidAmount,
          remainingAmount: updatedRemainingAmount,
        },
      });

      const ledgerEntry = await tx.vendorDepositLedgerEntry.create({
        data: {
          depositId: deposit.id,
          amount: isHoldRelease ? 0 : balanceBefore,
          direction: LedgerDirection.DEBIT,
          balanceBefore,
          balanceAfter,
          transactionType: VendorDepositTransactionType.RELEASE,
          paymentMethod: 'ADMIN_RELEASE',
          reference: dto.reference,
          reason: dto.reason,
          actorId: adminUserId,
          actorRole: 'ADMIN',
          idempotencyKey: dto.idempotencyKey,
        },
      });

      await this.invalidateDepositCache(vendorId);

      if (this.auditLogService) {
        await this.auditLogService.log(
          adminUserId,
          'RELEASE_VENDOR_DEPOSIT',
          'VENDOR_DEPOSIT',
          deposit.id,
          { vendorId, releasedAmount: isHoldRelease ? 0 : balanceBefore, reason: dto.reason },
        );
      }

      return {
        ...updatedDeposit,
        status: updatedDeposit.status,
        amountPaid: Number(updatedDeposit.paidAmount),
        amountRequired: Number(updatedDeposit.requiredAmount),
        paidAmount: Number(updatedDeposit.paidAmount),
        requiredAmount: Number(updatedDeposit.requiredAmount),
        remainingAmount: Number(updatedDeposit.remainingAmount),
        deposit: updatedDeposit,
        ledgerEntry,
        isIdempotentReplay: false,
      };
    });
  }

  /**
   * Refunds paid deposit to partner bank/wallet.
   */
  async refundDeposit(
    vendorId: string,
    dto: RefundDepositDto,
    adminUserId: string,
  ) {
    const deposit = await this.getDeposit(vendorId);
    const balanceBefore = Number(deposit.paidAmount);

    if (balanceBefore <= 0) {
      throw new BadRequestException('No refundable deposit balance available.');
    }

    const refundAmount = dto.amount ? Number(dto.amount) : balanceBefore;
    if (refundAmount > balanceBefore) {
      throw new BadRequestException(
        `Refund amount (${refundAmount}) exceeds available balance (${balanceBefore}).`,
      );
    }

    return this.prisma.$transaction(async (tx) => {
      const existingEntry = await tx.vendorDepositLedgerEntry.findUnique({
        where: { idempotencyKey: dto.idempotencyKey },
      });
      if (existingEntry) {
        return { deposit, ledgerEntry: existingEntry, isIdempotentReplay: true };
      }

      const balanceAfter = balanceBefore - refundAmount;
      const newStatus =
        balanceAfter === 0 ? VendorDepositStatus.REFUNDED : deposit.status;

      const updatedDeposit = await tx.vendorSecurityDeposit.update({
        where: { id: deposit.id },
        data: {
          paidAmount: balanceAfter,
          remainingAmount: Number(deposit.requiredAmount) - balanceAfter,
          status: newStatus,
          refundedAt: balanceAfter === 0 ? new Date() : undefined,
        },
      });

      const ledgerEntry = await tx.vendorDepositLedgerEntry.create({
        data: {
          depositId: deposit.id,
          amount: refundAmount,
          direction: LedgerDirection.DEBIT,
          balanceBefore,
          balanceAfter,
          transactionType: VendorDepositTransactionType.REFUND,
          paymentMethod: 'ADMIN_REFUND',
          reference: dto.reference,
          reason: dto.reason,
          actorId: adminUserId,
          actorRole: 'ADMIN',
          idempotencyKey: dto.idempotencyKey,
        },
      });

      // If fully refunded, revert requirement status
      if (balanceAfter === 0) {
        const reqDef = await tx.onboardingRequirementDefinition.findFirst({
          where: { code: 'DEP_SECURITY', isActive: true },
        });
        if (reqDef) {
          await tx.vendorRequirementState.updateMany({
            where: {
              vendorId,
              requirementDefinitionId: reqDef.id,
            },
            data: { status: RequirementFulfillmentStatus.PENDING },
          });
        }
      }

      await this.invalidateDepositCache(vendorId);

      if (this.auditLogService) {
        await this.auditLogService.log(
          adminUserId,
          'REFUND_VENDOR_DEPOSIT',
          'VENDOR_DEPOSIT',
          deposit.id,
          { vendorId, refundAmount, balanceAfter, reason: dto.reason },
        );
      }

      return {
        ...updatedDeposit,
        status: updatedDeposit.status,
        amountPaid: Number(updatedDeposit.paidAmount),
        amountRequired: Number(updatedDeposit.requiredAmount),
        paidAmount: Number(updatedDeposit.paidAmount),
        requiredAmount: Number(updatedDeposit.requiredAmount),
        remainingAmount: Number(updatedDeposit.remainingAmount),
        deposit: updatedDeposit,
        ledgerEntry,
        isIdempotentReplay: false,
      };
    });
  }

  /**
   * Forfeits deposit due to contractual breach or unfulfilled liabilities.
   */
  async forfeitDeposit(
    vendorId: string,
    dto: ForfeitDepositDto,
    adminUserId: string,
  ) {
    const deposit = await this.getDeposit(vendorId);
    const balanceBefore = Number(deposit.paidAmount);

    if (balanceBefore <= 0) {
      throw new BadRequestException('No deposit balance available for forfeiture.');
    }

    const forfeitAmount = dto.amount ? Number(dto.amount) : balanceBefore;
    if (forfeitAmount > balanceBefore) {
      throw new BadRequestException(
        `Forfeiture amount (${forfeitAmount}) exceeds available balance (${balanceBefore}).`,
      );
    }

    return this.prisma.$transaction(async (tx) => {
      const existingEntry = await tx.vendorDepositLedgerEntry.findUnique({
        where: { idempotencyKey: dto.idempotencyKey },
      });
      if (existingEntry) {
        return {
          ...deposit,
          amountPaid: Number(deposit.paidAmount),
          amountRequired: Number(deposit.requiredAmount),
          paidAmount: Number(deposit.paidAmount),
          requiredAmount: Number(deposit.requiredAmount),
          deposit,
          ledgerEntry: existingEntry,
          isIdempotentReplay: true,
        };
      }

      const balanceAfter = balanceBefore - forfeitAmount;

      const updatedDeposit = await tx.vendorSecurityDeposit.update({
        where: { id: deposit.id },
        data: {
          paidAmount: balanceAfter,
          status: VendorDepositStatus.FORFEITED,
          forfeitedAt: new Date(),
          forfeitedReason: dto.reason,
        },
      });

      const ledgerEntry = await tx.vendorDepositLedgerEntry.create({
        data: {
          depositId: deposit.id,
          amount: forfeitAmount,
          direction: LedgerDirection.DEBIT,
          balanceBefore,
          balanceAfter,
          transactionType: VendorDepositTransactionType.FORFEITURE,
          paymentMethod: 'ADMIN_FORFEITURE',
          reference: dto.reference,
          reason: dto.reason,
          actorId: adminUserId,
          actorRole: 'ADMIN',
          idempotencyKey: dto.idempotencyKey,
        },
      });

      // Monetary requirement marked rejected
      const reqDef = await tx.onboardingRequirementDefinition.findFirst({
        where: { code: 'DEP_SECURITY', isActive: true },
      });
      if (reqDef) {
        await tx.vendorRequirementState.updateMany({
          where: { vendorId, requirementDefinitionId: reqDef.id },
          data: {
            status: RequirementFulfillmentStatus.REJECTED,
            rejectionReason: `Security deposit forfeited: ${dto.reason}`,
          },
        });
      }

      await this.invalidateDepositCache(vendorId);

      if (this.auditLogService) {
        await this.auditLogService.log(
          adminUserId,
          'FORFEIT_VENDOR_DEPOSIT',
          'VENDOR_DEPOSIT',
          deposit.id,
          { vendorId, forfeitAmount, reason: dto.reason },
        );
      }

      return {
        ...updatedDeposit,
        status: updatedDeposit.status,
        amountPaid: Number(updatedDeposit.paidAmount),
        amountRequired: Number(updatedDeposit.requiredAmount),
        paidAmount: Number(updatedDeposit.paidAmount),
        requiredAmount: Number(updatedDeposit.requiredAmount),
        remainingAmount: Number(updatedDeposit.remainingAmount),
        deposit: updatedDeposit,
        ledgerEntry,
        isIdempotentReplay: false,
      };
    });
  }

  /**
   * Adjusts deposit balance or required amount by admin with mandatory audit trail.
   */
  async adjustDeposit(
    vendorId: string,
    dto: AdjustDepositDto,
    adminUserId: string,
  ) {
    if (!dto.reason || dto.reason.trim().length === 0) {
      throw new BadRequestException('Audit reason is required for deposit adjustments.');
    }

    const deposit = await this.getDeposit(vendorId);

    return this.prisma.$transaction(async (tx) => {
      if (dto.idempotencyKey) {
        const existing = await tx.vendorDepositLedgerEntry.findUnique({
          where: { idempotencyKey: dto.idempotencyKey },
        });
        if (existing) {
          return { deposit, ledgerEntry: existing, isIdempotentReplay: true };
        }
      }

      const balanceBefore = Number(deposit.paidAmount);
      const isDebit = dto.direction === LedgerDirection.DEBIT || dto.amount < 0;
      const adjustmentAmount = Math.abs(dto.amount);
      const direction = isDebit ? LedgerDirection.DEBIT : LedgerDirection.CREDIT;

      const balanceAfter = isDebit
        ? balanceBefore - adjustmentAmount
        : balanceBefore + adjustmentAmount;

      if (balanceAfter < 0) {
        throw new BadRequestException(
          `Adjustment would result in negative deposit balance (${balanceAfter}). Operations aborted.`,
        );
      }

      const requiredAmount =
        dto.newRequiredAmount !== undefined
          ? Number(dto.newRequiredAmount)
          : Number(deposit.requiredAmount);

      if (requiredAmount < 0) {
        throw new BadRequestException('Required deposit amount cannot be negative.');
      }

      const remainingAmount = Math.max(0, requiredAmount - balanceAfter);

      let newStatus = deposit.status;
      if (balanceAfter >= requiredAmount && requiredAmount > 0) {
        newStatus = VendorDepositStatus.PAID;
      } else if (balanceAfter > 0) {
        newStatus = VendorDepositStatus.PARTIALLY_PAID;
      } else if (balanceAfter === 0) {
        newStatus = VendorDepositStatus.REQUIRED;
      }

      const updatedDeposit = await tx.vendorSecurityDeposit.update({
        where: { id: deposit.id },
        data: {
          paidAmount: balanceAfter,
          requiredAmount,
          remainingAmount,
          status: newStatus,
        },
      });

      const ledgerEntry = await tx.vendorDepositLedgerEntry.create({
        data: {
          depositId: deposit.id,
          amount: adjustmentAmount,
          direction,
          balanceBefore,
          balanceAfter,
          transactionType: VendorDepositTransactionType.ADMIN_ADJUSTMENT,
          paymentMethod: 'ADMIN_ADJUSTMENT',
          reference: dto.reference || `ADJ-${Date.now()}`,
          reason: dto.reason,
          actorId: adminUserId,
          actorRole: 'ADMIN',
          idempotencyKey: dto.idempotencyKey || `adj-${deposit.id}-${Date.now()}`,
        },
      });

      // Synchronize monetary requirement state if now fully paid
      if (newStatus === VendorDepositStatus.PAID) {
        const reqDef = await tx.onboardingRequirementDefinition.findFirst({
          where: { code: 'DEP_SECURITY', isActive: true },
        });
        if (reqDef) {
          await tx.vendorRequirementState.upsert({
            where: {
              vendorId_requirementDefinitionId: {
                vendorId,
                requirementDefinitionId: reqDef.id,
              },
            },
            update: {
              status: RequirementFulfillmentStatus.APPROVED,
              reviewedByUserId: adminUserId,
              reviewedAt: new Date(),
            },
            create: {
              vendorId,
              requirementDefinitionId: reqDef.id,
              status: RequirementFulfillmentStatus.APPROVED,
              reviewedByUserId: adminUserId,
              reviewedAt: new Date(),
            },
          });
        }
      }

      await this.invalidateDepositCache(vendorId);

      if (this.auditLogService) {
        await this.auditLogService.log(
          adminUserId,
          'ADJUST_VENDOR_DEPOSIT',
          'VENDOR_DEPOSIT',
          deposit.id,
          {
            vendorId,
            direction,
            amount: adjustmentAmount,
            balanceBefore,
            balanceAfter,
            requiredAmount,
            reason: dto.reason,
          },
        );
      }

      return {
        ...updatedDeposit,
        status: updatedDeposit.status,
        amountPaid: Number(updatedDeposit.paidAmount),
        amountRequired: Number(updatedDeposit.requiredAmount),
        paidAmount: Number(updatedDeposit.paidAmount),
        requiredAmount: Number(updatedDeposit.requiredAmount),
        remainingAmount: Number(updatedDeposit.remainingAmount),
        deposit: updatedDeposit,
        ledgerEntry,
        isIdempotentReplay: false,
      };
    });
  }

  /**
   * Lists all deposits with optional status and search filtering.
   */
  async listDeposits(filter?: { status?: VendorDepositStatus; search?: string }) {
    const where: any = {};
    if (filter?.status) where.status = filter.status;
    if (filter?.search) {
      where.vendor = {
        OR: [
          { businessName: { contains: filter.search, mode: 'insensitive' } },
          { id: filter.search },
        ],
      };
    }

    const deposits = await this.prisma.vendorSecurityDeposit.findMany({
      where,
      include: {
        vendor: {
          select: {
            id: true,
            businessName: true,
            verificationStatus: true,
            user: { select: { name: true, email: true, phone: true } },
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    return deposits.map((d) => ({
      ...d,
      requiredAmount: Number(d.requiredAmount),
      paidAmount: Number(d.paidAmount),
      remainingAmount: Number(d.remainingAmount),
      amountRequired: Number(d.requiredAmount),
      amountPaid: Number(d.paidAmount),
      amountRemaining: Number(d.remainingAmount),
    }));
  }

  /**
   * Retrieves chronological audit ledger entries for a vendor's deposit.
   */
  async getLedgerEntries(vendorId: string) {
    const deposit = await this.prisma.vendorSecurityDeposit.findUnique({
      where: { vendorId },
    });

    if (!deposit) return [];

    return this.prisma.vendorDepositLedgerEntry.findMany({
      where: { depositId: deposit.id },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Invalidates Redis caches for this vendor's deposit and onboarding eligibility.
   */
  async invalidateDepositCache(vendorId: string): Promise<void> {
    await Promise.all([
      this.cacheService.delete(REDIS_NAMESPACES.CACHE.VENDOR_SECURITY_DEPOSIT(vendorId)),
      this.cacheService.delete(REDIS_NAMESPACES.CACHE.VENDOR_ONBOARDING_ELIGIBILITY(vendorId)),
    ]);
  }
}

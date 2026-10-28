import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  ConflictException,
  Optional,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisCacheService } from '../../redis/redis-cache.service';
import { REDIS_NAMESPACES } from '../../redis/redis-namespace.constants';
import { AuditLogService } from '../../admin/audit-log.service';
import { SystemConfigService } from '../../config-engine/system-config.service';
import Razorpay from 'razorpay';
import { validatePaymentVerification } from 'razorpay/dist/utils/razorpay-utils';
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
  UpdateDepositPolicyDto,
  SetVendorExemptionDto,
  VerifyDepositPaymentDto,
} from './onboarding.types';
import { VendorOnboardingRulesConfig } from '../../config-engine/system-config.interface';

@Injectable()
export class VendorSecurityDepositService {
  private readonly logger = new Logger(VendorSecurityDepositService.name);
  private readonly razorpay: Razorpay | null = null;
  private readonly useMock: boolean = false;
  private readonly keyId: string;
  private readonly keySecret: string;
  private readonly webhookSecret: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly cacheService: RedisCacheService,
    @Optional() private readonly configService?: ConfigService,
    @Optional() private readonly auditLogService?: AuditLogService,
    @Optional() private readonly systemConfigService?: SystemConfigService,
  ) {
    this.keyId =
      this.configService?.get<string>('RAZORPAY_KEY_ID') ||
      process.env.RAZORPAY_KEY_ID ||
      'rzp_test_placeholderKeyId';
    this.keySecret =
      this.configService?.get<string>('RAZORPAY_KEY_SECRET') ||
      process.env.RAZORPAY_KEY_SECRET ||
      'placeholderKeySecret';
    this.webhookSecret =
      this.configService?.get<string>('RAZORPAY_WEBHOOK_SECRET') ||
      process.env.RAZORPAY_WEBHOOK_SECRET ||
      'placeholderWebhookSecret';
    this.useMock =
      (this.configService?.get<string>('RAZORPAY_USE_MOCK') ||
        process.env.RAZORPAY_USE_MOCK) === 'true';

    const nodeEnv =
      this.configService?.get<string>('NODE_ENV') || process.env.NODE_ENV;
    if (this.useMock && nodeEnv === 'production') {
      throw new Error(
        'CRITICAL SECURITY CONFIGURATION ERROR: RAZORPAY_USE_MOCK is set to true, but NODE_ENV is production! Bypassing payment verification in production is forbidden.',
      );
    }

    if (!this.useMock && this.keyId && !this.keyId.includes('placeholder')) {
      try {
        this.razorpay = new Razorpay({
          key_id: this.keyId,
          key_secret: this.keySecret,
        });
      } catch (err: any) {
        if (nodeEnv === 'production') {
          throw new Error(
            `CRITICAL PRODUCTION PAYMENT ERROR: Failed to initialize Razorpay SDK in production: ${err.message}`,
          );
        }
        this.logger.error(
          'Failed to initialize Razorpay SDK in VendorSecurityDepositService',
          err,
        );
      }
    }
  }

  /**
   * Retrieves the active vendor security deposit policy.
   * If none exists in database, bootstraps default policy (₹25,000, 100% refundable).
   */
  async getActivePolicy(): Promise<any> {
    if (!this.prisma.vendorDepositPolicy) {
      let defaultAmount = 25000;
      if (this.systemConfigService) {
        try {
          const config =
            await this.systemConfigService.getConfig<VendorOnboardingRulesConfig>(
              'vendor.onboarding.rules',
            );
          if (config?.defaultSecurityDepositAmount) {
            defaultAmount = Number(config.defaultSecurityDepositAmount);
          }
        } catch {}
      }
      return {
        version: 1,
        isRequired: true,
        amount: defaultAmount,
        currency: 'INR',
        refundPolicy: 'REFUNDABLE',
        deadlineDays: 14,
        isActive: true,
      };
    }

    let policy = await this.prisma.vendorDepositPolicy.findFirst({
      where: { isActive: true },
      orderBy: { version: 'desc' },
    });

    if (!policy) {
      const latestPolicy = await this.prisma.vendorDepositPolicy.findFirst({
        orderBy: { version: 'desc' },
      });
      const nextVersion = (latestPolicy?.version ?? 0) + 1;

      let defaultAmount = 25000;
      if (this.systemConfigService) {
        try {
          const config = await this.systemConfigService.getConfig<VendorOnboardingRulesConfig>(
            'vendor.onboarding.rules',
          );
          if (config?.defaultSecurityDepositAmount) {
            defaultAmount = Number(config.defaultSecurityDepositAmount);
          }
        } catch {}
      }

      policy = await this.prisma.vendorDepositPolicy.create({
        data: {
          version: nextVersion,
          isRequired: true,
          amount: defaultAmount,
          currency: 'INR',
          refundPolicy: 'REFUNDABLE',
          description:
            'DriveGo Partner Standard Security Deposit. 100% refundable upon partner contract termination and account settlement.',
          refundConditions:
            'Refundable within 30 days of contract termination subject to vehicle condition and zero outstanding liabilities.',
          paymentProvider: 'RAZORPAY',
          deadlineDays: 14,
          isActive: true,
          effectiveFrom: new Date(),
          updatedBy: 'SYSTEM_BOOTSTRAP',
        },
      });
    }

    return {
      ...policy,
      amount: Number(policy.amount),
    };
  }

  /**
   * Updates or publishes a new version of the vendor security deposit policy.
   */
  async updatePolicy(
    dto: UpdateDepositPolicyDto,
    adminUserId: string,
  ): Promise<any> {
    const amount = Number(dto.amount);
    if (isNaN(amount) || amount < 0) {
      throw new BadRequestException('Security deposit amount must be a non-negative number.');
    }

    return this.prisma.$transaction(async (tx) => {
      const latestPolicy = await tx.vendorDepositPolicy.findFirst({
        orderBy: { version: 'desc' },
      });
      const nextVersion = (latestPolicy?.version ?? 0) + 1;

      // Deactivate previously active policies
      await tx.vendorDepositPolicy.updateMany({
        where: { isActive: true },
        data: { isActive: false },
      });

      const newPolicy = await tx.vendorDepositPolicy.create({
        data: {
          version: nextVersion,
          isRequired: dto.isRequired !== undefined ? dto.isRequired : true,
          amount,
          currency: dto.currency || 'INR',
          refundPolicy: dto.refundPolicy || 'REFUNDABLE',
          description:
            dto.description || 'DriveGo Partner Standard Security Deposit',
          refundConditions: dto.refundConditions || null,
          paymentProvider: dto.paymentProvider || 'RAZORPAY',
          deadlineDays:
            dto.deadlineDays !== undefined ? Number(dto.deadlineDays) : 14,
          exemptions: dto.exemptions ? (dto.exemptions as any) : undefined,
          isActive: true,
          effectiveFrom: dto.effectiveFrom
            ? new Date(dto.effectiveFrom)
            : new Date(),
          updatedBy: adminUserId,
        },
      });

      if (this.auditLogService) {
        await this.auditLogService.log(
          adminUserId,
          'UPDATE_VENDOR_DEPOSIT_POLICY',
          'VENDOR_DEPOSIT_POLICY',
          newPolicy.id,
          {
            version: nextVersion,
            isRequired: newPolicy.isRequired,
            amount,
            refundPolicy: newPolicy.refundPolicy,
            paymentProvider: newPolicy.paymentProvider,
            effectiveFrom: newPolicy.effectiveFrom,
          },
        );
      }

      return {
        ...newPolicy,
        amount: Number(newPolicy.amount),
      };
    });
  }

  /**
   * Sets or revokes exemption status for a vendor's security deposit.
   */
  async setVendorExemption(
    vendorId: string,
    dto: SetVendorExemptionDto,
    adminUserId: string,
  ): Promise<any> {
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
    });
    if (!vendor) {
      throw new NotFoundException(`Vendor with id ${vendorId} not found.`);
    }

    const deposit = await this.getDeposit(vendorId);

    return this.prisma.$transaction(async (tx) => {
      const isExempt = Boolean(dto.isExempt);
      const newStatus = isExempt
        ? VendorDepositStatus.NOT_REQUIRED
        : Number(deposit.paidAmount) >= Number(deposit.requiredAmount)
        ? VendorDepositStatus.PAID
        : VendorDepositStatus.REQUIRED;

      const updated = await tx.vendorSecurityDeposit.update({
        where: { id: deposit.id },
        data: {
          isExempt,
          exemptionReason: isExempt ? dto.reason : null,
          exemptedBy: isExempt ? adminUserId : null,
          exemptedAt: isExempt ? new Date() : null,
          status: newStatus,
        },
      });

      // Synchronize requirement state for DEP_SECURITY
      const reqDef = await tx.onboardingRequirementDefinition.findFirst({
        where: { code: 'DEP_SECURITY', isActive: true },
      });

      if (reqDef) {
        if (isExempt) {
          await tx.vendorRequirementState.upsert({
            where: {
              vendorId_requirementDefinitionId: {
                vendorId,
                requirementDefinitionId: reqDef.id,
              },
            },
            update: {
              status: RequirementFulfillmentStatus.WAIVED,
              reviewedByUserId: adminUserId,
              reviewedAt: new Date(),
              waivedByUserId: adminUserId,
              waivedReason: dto.reason,
              waivedAt: new Date(),
            },
            create: {
              vendorId,
              requirementDefinitionId: reqDef.id,
              status: RequirementFulfillmentStatus.WAIVED,
              reviewedByUserId: adminUserId,
              reviewedAt: new Date(),
              waivedByUserId: adminUserId,
              waivedReason: dto.reason,
              waivedAt: new Date(),
            },
          });
        } else {
          const reqStatus =
            Number(deposit.paidAmount) >= Number(deposit.requiredAmount)
              ? RequirementFulfillmentStatus.APPROVED
              : RequirementFulfillmentStatus.PENDING;

          await tx.vendorRequirementState.upsert({
            where: {
              vendorId_requirementDefinitionId: {
                vendorId,
                requirementDefinitionId: reqDef.id,
              },
            },
            update: {
              status: reqStatus,
              reviewedByUserId: adminUserId,
              reviewedAt: new Date(),
            },
            create: {
              vendorId,
              requirementDefinitionId: reqDef.id,
              status: reqStatus,
            },
          });
        }
      }

      await this.invalidateDepositCache(vendorId);

      if (this.auditLogService) {
        await this.auditLogService.log(
          adminUserId,
          'SET_VENDOR_DEPOSIT_EXEMPTION',
          'VENDOR_DEPOSIT',
          deposit.id,
          {
            vendorId,
            isExempt,
            reason: dto.reason,
            newStatus,
          },
        );
      }

      return {
        ...updated,
        requiredAmount: Number(updated.requiredAmount),
        paidAmount: Number(updated.paidAmount),
        remainingAmount: Number(updated.remainingAmount),
      };
    });
  }

  /**
   * Creates a Razorpay gateway order for a vendor's security deposit.
   */
  async createDepositPaymentOrder(
    vendorId: string,
    requestingUserId: string,
  ): Promise<any> {
    const policy = await this.getActivePolicy();
    const deposit = await this.getDeposit(vendorId);

    if (deposit.isExempt || !policy.isRequired) {
      throw new BadRequestException(
        'Security deposit is not required or has been exempted for this partner.',
      );
    }

    if (
      deposit.status === VendorDepositStatus.PAID ||
      Number(deposit.remainingAmount) <= 0
    ) {
      throw new BadRequestException(
        'Security deposit is already fully paid.',
      );
    }

    const remaining = Number(deposit.remainingAmount);
    const amountToPay = remaining > 0 ? remaining : Number(policy.amount);
    const amountInPaise = Math.round(amountToPay * 100);

    if (amountInPaise <= 0) {
      throw new BadRequestException('Invalid deposit payment amount.');
    }

    const vendor = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
      include: { user: true },
    });

    let providerOrderId: string;

    if (this.useMock) {
      providerOrderId = `order_vdep_mock_${Date.now()}_${Math.random()
        .toString(36)
        .substring(2, 9)}`;
      this.logger.log(
        `[RAZORPAY-MOCK] Created mock vendor deposit order ${providerOrderId} for vendor ${vendorId} (amount: ₹${amountToPay})`,
      );
    } else if (this.razorpay) {
      try {
        const order = await this.razorpay.orders.create({
          amount: amountInPaise,
          currency: 'INR',
          receipt: `vdep_${vendorId.substring(0, 10)}_${Date.now()}`,
          notes: {
            purpose: 'VENDOR_SECURITY_DEPOSIT',
            vendorId,
            depositId: deposit.id,
            policyVersion: String(policy.version),
          },
        });
        providerOrderId = order.id;
      } catch (err: any) {
        this.logger.error(
          'Failed to create Razorpay order for vendor security deposit',
          err,
        );
        throw new BadRequestException(
          'Failed to create payment order with payment gateway. Please try again.',
        );
      }
    } else {
      providerOrderId = `order_vdep_${Date.now()}_${Math.random()
        .toString(36)
        .substring(2, 9)}`;
    }

    await this.prisma.vendorSecurityDeposit.update({
      where: { id: deposit.id },
      data: {
        provider: 'RAZORPAY',
        providerOrderId,
        policyVersion: policy.version,
        status: VendorDepositStatus.PAYMENT_INITIATED,
      },
    });

    await this.invalidateDepositCache(vendorId);

    return {
      orderId: providerOrderId,
      amount: amountInPaise,
      amountInINR: amountToPay,
      currency: 'INR',
      keyId: this.keyId,
      purpose: 'VENDOR_SECURITY_DEPOSIT',
      policyVersion: policy.version,
      vendor: {
        id: vendorId,
        businessName: vendor?.businessName,
        contactName: vendor?.user?.name,
        email: vendor?.user?.email,
        phone: vendor?.user?.phone,
      },
    };
  }

  /**
   * Verifies Razorpay HMAC signature and records the security deposit payment.
   */
  async verifyDepositPayment(
    vendorId: string,
    dto: VerifyDepositPaymentDto,
    requestingUserId: string,
  ): Promise<any> {
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = dto;

    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      throw new BadRequestException(
        'razorpayOrderId, razorpayPaymentId, and razorpaySignature are required.',
      );
    }

    const deposit = await this.prisma.vendorSecurityDeposit.findUnique({
      where: { vendorId },
    });

    if (!deposit) {
      throw new NotFoundException(
        `Deposit record not found for vendor ${vendorId}.`,
      );
    }

    // Idempotency / replay check
    const existingLedgerWithPaymentId =
      await this.prisma.vendorDepositLedgerEntry.findFirst({
        where: { reference: razorpayPaymentId },
      });

    if (
      existingLedgerWithPaymentId ||
      deposit.providerPaymentId === razorpayPaymentId
    ) {
      this.logger.log(
        `[DEPOSIT-PAYMENT] Replay detection: payment ${razorpayPaymentId} already processed for deposit ${deposit.id}.`,
      );
      return {
        success: true,
        isReplay: true,
        deposit: {
          ...deposit,
          requiredAmount: Number(deposit.requiredAmount),
          paidAmount: Number(deposit.paidAmount),
          remainingAmount: Number(deposit.remainingAmount),
        },
      };
    }

    // Signature verification
    if (this.useMock && razorpaySignature === 'mock_signature') {
      this.logger.log(
        `[RAZORPAY-MOCK] Bypassing HMAC verification for mock_signature in non-production.`,
      );
    } else {
      try {
        const isValid = validatePaymentVerification(
          { order_id: razorpayOrderId, payment_id: razorpayPaymentId },
          razorpaySignature,
          this.keySecret,
        );
        if (!isValid) {
          await this.prisma.vendorSecurityDeposit.update({
            where: { id: deposit.id },
            data: { status: VendorDepositStatus.PAYMENT_FAILED },
          });
          throw new BadRequestException(
            'Invalid payment signature. Payment verification failed.',
          );
        }
      } catch (err: any) {
        if (err instanceof BadRequestException) throw err;
        throw new BadRequestException(
          `Signature verification failed: ${err.message}`,
        );
      }
    }

    let authoritativeAmountINR =
      Number(deposit.requiredAmount) - Number(deposit.paidAmount);
    if (authoritativeAmountINR <= 0) {
      authoritativeAmountINR = Number(deposit.requiredAmount);
    }

    if (!this.useMock && this.razorpay) {
      try {
        const rzpPayment: any =
          await this.razorpay.payments.fetch(razorpayPaymentId);
        if (!rzpPayment) {
          throw new BadRequestException(
            'Payment entity not found on Razorpay.',
          );
        }
        if (rzpPayment.order_id && rzpPayment.order_id !== razorpayOrderId) {
          throw new BadRequestException(
            'Razorpay payment entity does not match order ID.',
          );
        }
        if (
          rzpPayment.currency &&
          rzpPayment.currency.toUpperCase() !== 'INR'
        ) {
          throw new BadRequestException(
            `Currency mismatch: expected INR, got ${rzpPayment.currency}`,
          );
        }
        if (rzpPayment.status === 'failed') {
          await this.prisma.vendorSecurityDeposit.update({
            where: { id: deposit.id },
            data: { status: VendorDepositStatus.PAYMENT_FAILED },
          });
          throw new BadRequestException('Payment failed on payment gateway.');
        }
        if (rzpPayment.amount) {
          authoritativeAmountINR = Number(rzpPayment.amount) / 100;
        }
      } catch (err: any) {
        if (err instanceof BadRequestException) throw err;
        this.logger.warn(`Razorpay fetch check warning: ${err.message}`);
      }
    }

    return this.prisma.$transaction(async (tx) => {
      const balanceBefore = Number(deposit.paidAmount);
      const balanceAfter = balanceBefore + authoritativeAmountINR;
      const requiredAmount = Number(deposit.requiredAmount);
      const remainingAmount = Math.max(0, requiredAmount - balanceAfter);

      const newStatus =
        balanceAfter >= requiredAmount
          ? VendorDepositStatus.PAID
          : VendorDepositStatus.PARTIALLY_PAID;

      const updatedDeposit = await tx.vendorSecurityDeposit.update({
        where: { id: deposit.id },
        data: {
          paidAmount: balanceAfter,
          remainingAmount,
          status: newStatus,
          provider: 'RAZORPAY',
          providerOrderId: razorpayOrderId,
          providerPaymentId: razorpayPaymentId,
          providerSignature: razorpaySignature,
        },
      });

      const ledgerEntry = await tx.vendorDepositLedgerEntry.create({
        data: {
          depositId: deposit.id,
          amount: authoritativeAmountINR,
          direction: LedgerDirection.CREDIT,
          balanceBefore,
          balanceAfter,
          transactionType:
            balanceBefore === 0
              ? VendorDepositTransactionType.INITIAL_PAYMENT
              : VendorDepositTransactionType.TOP_UP,
          paymentMethod: 'RAZORPAY_GATEWAY',
          reference: razorpayPaymentId,
          idempotencyKey: `pay_${razorpayPaymentId}`,
          reason: `Razorpay online payment (Order: ${razorpayOrderId})`,
          actorId: requestingUserId,
          actorRole: 'VENDOR',
          metadata: {
            razorpayOrderId,
            razorpayPaymentId,
            verifiedAt: new Date().toISOString(),
          },
        },
      });

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
              reviewedByUserId: requestingUserId,
              reviewedAt: new Date(),
            },
            create: {
              vendorId,
              requirementDefinitionId: reqDef.id,
              status: RequirementFulfillmentStatus.APPROVED,
              reviewedByUserId: requestingUserId,
              reviewedAt: new Date(),
            },
          });
        }
      }

      await this.invalidateDepositCache(vendorId);

      if (this.auditLogService) {
        await this.auditLogService.log(
          requestingUserId,
          'VERIFY_VENDOR_DEPOSIT_PAYMENT',
          'VENDOR_DEPOSIT',
          deposit.id,
          {
            vendorId,
            amount: authoritativeAmountINR,
            razorpayOrderId,
            razorpayPaymentId,
            newStatus,
          },
        );
      }

      return {
        success: true,
        deposit: {
          ...updatedDeposit,
          requiredAmount: Number(updatedDeposit.requiredAmount),
          paidAmount: Number(updatedDeposit.paidAmount),
          remainingAmount: Number(updatedDeposit.remainingAmount),
        },
        ledgerEntry,
      };
    });
  }

  /**
   * Retrieves or initializes the security deposit record for a vendor.
   */
  async getDeposit(vendorId: string): Promise<any> {
    let deposit = await this.prisma.vendorSecurityDeposit.findUnique({
      where: { vendorId },
    });

    if (!deposit) {
      const policy = await this.getActivePolicy();
      const requiredAmount = policy.isRequired ? Number(policy.amount) : 0;
      const initialStatus = policy.isRequired
        ? VendorDepositStatus.REQUIRED
        : VendorDepositStatus.NOT_REQUIRED;

      deposit = await this.prisma.vendorSecurityDeposit.create({
        data: {
          vendorId,
          requiredAmount,
          paidAmount: 0,
          remainingAmount: requiredAmount,
          status: initialStatus,
          requirementCode: 'DEP_SECURITY',
          requirementVersion: 1,
          policyVersion: policy.version,
          provider: policy.paymentProvider || 'RAZORPAY',
        },
      });
    }

    return {
      ...deposit,
      amountRequired: Number(
        deposit.requiredAmount ?? (deposit as any).amountRequired,
      ),
      amountPaid: Number(deposit.paidAmount ?? (deposit as any).amountPaid),
      amountRemaining: Number(
        deposit.remainingAmount ?? (deposit as any).amountRemaining,
      ),
      requiredAmount: Number(
        deposit.requiredAmount ?? (deposit as any).amountRequired,
      ),
      paidAmount: Number(deposit.paidAmount ?? (deposit as any).amountPaid),
      remainingAmount: Number(
        deposit.remainingAmount ?? (deposit as any).amountRemaining,
      ),
      isExempt: Boolean(deposit.isExempt),
    };
  }

  /**
   * Summarizes deposit status for eligibility evaluation.
   */
  async getDepositSummary(vendorId: string): Promise<VendorDepositSummary> {
    const policy = await this.getActivePolicy();
    const deposit = await this.getDeposit(vendorId);
    const isSatisfied =
      deposit.isExempt === true ||
      policy.isRequired === false ||
      deposit.status === VendorDepositStatus.PAID ||
      deposit.status === VendorDepositStatus.HELD ||
      deposit.status === VendorDepositStatus.NOT_REQUIRED;

    return {
      depositId: deposit.id,
      requiredAmount: Number(deposit.requiredAmount),
      paidAmount: Number(deposit.paidAmount),
      remainingAmount: Number(deposit.remainingAmount),
      status: deposit.status,
      isSatisfied,
      isRequired: policy.isRequired && !deposit.isExempt,
      isExempt: Boolean(deposit.isExempt),
      exemptionReason: deposit.exemptionReason ?? undefined,
      refundPolicy: policy.refundPolicy,
      paymentProvider: deposit.provider ?? policy.paymentProvider ?? 'RAZORPAY',
      providerOrderId: deposit.providerOrderId ?? undefined,
      providerPaymentId: deposit.providerPaymentId ?? undefined,
      policy: {
        version: policy.version,
        isRequired: policy.isRequired,
        amount: Number(policy.amount),
        currency: policy.currency,
        refundPolicy: policy.refundPolicy,
        deadlineDays: policy.deadlineDays,
        description: policy.description,
      },
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

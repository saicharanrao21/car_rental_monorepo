import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  Logger,
  Optional,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ApmMonitoringService } from '../common/apm-monitoring.service';
import Razorpay from 'razorpay';
import { validatePaymentVerification } from 'razorpay/dist/utils/razorpay-utils';
import { SystemConfigService } from '../config-engine/system-config.service';
import {
  WalletStatus,
  WalletBucketType,
  LedgerEntryType,
  LedgerDirection,
  Prisma,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { VerifyDepositDto } from './dto/verify-deposit.dto';
import { AdminAdjustWalletDto } from './dto/admin-adjust-wallet.dto';

export const MAX_SINGLE_DEPOSIT = 50000;
export const MIN_SINGLE_DEPOSIT = 100;
export const MAX_WALLET_BALANCE_CAP = 100000;

@Injectable()
export class WalletsService {
  private readonly logger = new Logger(WalletsService.name);
  private readonly razorpay: Razorpay | null = null;
  private readonly useMock: boolean;
  private readonly keyId: string;
  private readonly keySecret: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
    private readonly auditLogService: AuditLogService,
    private readonly notificationsService: NotificationsService,
    @Optional() private readonly apmMonitoringService?: ApmMonitoringService,
    @Optional() private readonly systemConfigService?: SystemConfigService,
  ) {
    this.keyId =
      this.configService.get<string>('RAZORPAY_KEY_ID') ||
      'rzp_test_placeholderKeyId';
    this.keySecret =
      this.configService.get<string>('RAZORPAY_KEY_SECRET') ||
      'placeholderKeySecret';
    this.useMock =
      this.configService.get<string>('RAZORPAY_USE_MOCK') === 'true';

    if (!this.useMock) {
      try {
        this.razorpay = new Razorpay({
          key_id: this.keyId,
          key_secret: this.keySecret,
        });
      } catch (err: any) {
        this.logger.error(
          'Failed to initialize Razorpay SDK for Wallets. Falling back to mock mode.',
          err,
        );
        this.useMock = true;
      }
    }
  }

  /**
   * Retrieves or automatically initializes a user's wallet with zero balances.
   */
  async getOrCreateWallet(userId: string, tx?: Prisma.TransactionClient) {
    const client = tx || this.prisma;
    let wallet = await client.wallet.findUnique({
      where: { userId },
    });

    if (!wallet) {
      wallet = await client.wallet.create({
        data: {
          userId,
          currency: 'INR',
          availableBalance: new Decimal(0),
          lockedBalance: new Decimal(0),
          realBalance: new Decimal(0),
          promoBalance: new Decimal(0),
          status: WalletStatus.ACTIVE,
        },
      });
      this.logger.log(`Initialized new Wallet for user ${userId}: ${wallet.id}`);
    }

    return wallet;
  }

  /**
   * Retrieves wallet summary for the authenticated user.
   */
  async getWalletByUserId(userId: string) {
    return this.getOrCreateWallet(userId);
  }

  /**
   * Retrieves paginated transaction history for a user's wallet.
   */
  async getWalletTransactions(userId: string, page = 1, limit = 20) {
    const wallet = await this.getOrCreateWallet(userId);
    const skip = (page - 1) * limit;

    const [entries, total] = await Promise.all([
      this.prisma.walletLedgerEntry.findMany({
        where: { walletId: wallet.id },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.walletLedgerEntry.count({
        where: { walletId: wallet.id },
      }),
    ]);

    return {
      entries,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * Lazily checks and expires outdated promotional credits for a wallet.
   */
  async cleanExpiredPromotionalCredits(
    walletId: string,
    tx?: Prisma.TransactionClient,
  ): Promise<Decimal> {
    const client = tx || this.prisma;
    const now = new Date();

    const expiredEntries = await client.walletLedgerEntry.findMany({
      where: {
        walletId,
        bucket: WalletBucketType.PROMOTIONAL,
        direction: LedgerDirection.CREDIT,
        expiresAt: { lt: now },
      },
    });

    if (expiredEntries.length === 0) {
      return new Decimal(0);
    }

    const wallet = await client.wallet.findUnique({ where: { id: walletId } });
    if (!wallet || wallet.promoBalance.lte(0)) {
      return new Decimal(0);
    }

    const totalHistoricalExpiredCredits = expiredEntries.reduce(
      (acc, entry) => acc.add(entry.amount),
      new Decimal(0),
    );

    const alreadyExpiredLedgerSum = await client.walletLedgerEntry.aggregate({
      where: {
        walletId,
        type: LedgerEntryType.EXPIRATION,
      },
      _sum: { amount: true },
    });

    const alreadyExpiredAmount = alreadyExpiredLedgerSum._sum.amount
      ? new Decimal(alreadyExpiredLedgerSum._sum.amount)
      : new Decimal(0);

    const unexpiredDebitRequired = totalHistoricalExpiredCredits.sub(alreadyExpiredAmount);
    const actualExpiredAmount = Decimal.min(unexpiredDebitRequired, wallet.promoBalance);

    if (actualExpiredAmount.gt(0)) {
      const idempotencyKey = `promo_expiry_${walletId}_${now.toISOString().slice(0, 10)}`;
      const newPromo = wallet.promoBalance.sub(actualExpiredAmount);
      const newAvailable = wallet.availableBalance.sub(actualExpiredAmount);

      await client.walletLedgerEntry.create({
        data: {
          walletId,
          type: LedgerEntryType.EXPIRATION,
          direction: LedgerDirection.DEBIT,
          bucket: WalletBucketType.PROMOTIONAL,
          amount: actualExpiredAmount,
          balanceBefore: wallet.availableBalance,
          balanceAfter: newAvailable,
          referenceType: 'SYSTEM',
          referenceId: 'PROMO_EXPIRATION',
          idempotencyKey,
          description: `Expired promotional credit cleanup (-₹${actualExpiredAmount.toFixed(2)})`,
        },
      });

      await client.wallet.update({
        where: { id: walletId },
        data: {
          availableBalance: newAvailable,
          promoBalance: newPromo,
        },
      });

      this.logger.log(
        `[PROMO EXPIRED] Expired ₹${actualExpiredAmount.toFixed(2)} promo credits from wallet ${walletId}`,
      );

      return actualExpiredAmount;
    }

    return new Decimal(0);
  }

  /**
   * Evaluates SystemConfig rules to determine maximum allowable wallet debit for a booking.
   */
  async validateAndCalculateUsableWallet(
    userId: string,
    bookingAmount: number,
    requestedWalletAmount?: number,
  ) {
    const wallet = await this.getOrCreateWallet(userId);
    await this.cleanExpiredPromotionalCredits(wallet.id);

    const refreshedWallet = await this.prisma.wallet.findUnique({
      where: { id: wallet.id },
    });
    const currentWallet = refreshedWallet || wallet;

    const config = this.systemConfigService
      ? await this.systemConfigService.getWalletConfig()
      : {
          maxSingleDeposit: 50000,
          minSingleDeposit: 100,
          maxWalletBalanceCap: 100000,
          maxWalletPaymentPercentage: 100,
          minBookingAmountForWalletUse: 0,
          maxPromoCreditPerBooking: 5000,
          maxDailyWalletUsage: 50000,
          isDepositsEnabled: true,
        };

    const bookingTotal = new Decimal(bookingAmount);

    if (config.minBookingAmountForWalletUse && bookingTotal.lt(config.minBookingAmountForWalletUse)) {
      return {
        allowed: false,
        usableAmount: 0,
        promoAmount: 0,
        realAmount: 0,
        availableBalance: currentWallet.availableBalance.toNumber(),
        reason: `Booking amount must be at least ₹${config.minBookingAmountForWalletUse} to apply DriveGo Wallet balance.`,
      };
    }

    const maxPercent = config.maxWalletPaymentPercentage || 100;
    const maxAllowedByPercentage = bookingTotal.mul(maxPercent).div(100);
    const maxPromoAllowed = new Decimal(config.maxPromoCreditPerBooking || 5000);
    const usablePromo = Decimal.min(currentWallet.promoBalance, maxPromoAllowed);

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const dailyDebits = await this.prisma.walletLedgerEntry.aggregate({
      where: {
        walletId: currentWallet.id,
        direction: LedgerDirection.DEBIT,
        type: { in: [LedgerEntryType.CHECKOUT_DEBIT] },
        createdAt: { gte: startOfToday },
      },
      _sum: { amount: true },
    });

    const usedToday = dailyDebits._sum.amount ? new Decimal(dailyDebits._sum.amount) : new Decimal(0);
    const maxDailyLimit = new Decimal(config.maxDailyWalletUsage || 50000);
    const remainingDailyAllowance = Decimal.max(0, maxDailyLimit.sub(usedToday));

    const maxPossibleDebit = Decimal.min(
      currentWallet.availableBalance,
      bookingTotal,
      maxAllowedByPercentage,
      remainingDailyAllowance,
    );

    const targetAmount = requestedWalletAmount !== undefined
      ? Decimal.min(new Decimal(requestedWalletAmount), maxPossibleDebit)
      : maxPossibleDebit;

    const finalPromo = Decimal.min(targetAmount, usablePromo);
    const finalReal = targetAmount.sub(finalPromo);

    return {
      allowed: targetAmount.gt(0),
      usableAmount: targetAmount.toNumber(),
      promoAmount: finalPromo.toNumber(),
      realAmount: finalReal.toNumber(),
      availableBalance: currentWallet.availableBalance.toNumber(),
      realBalance: currentWallet.realBalance.toNumber(),
      promoBalance: currentWallet.promoBalance.toNumber(),
      maxPercentageAllowed: maxPercent,
    };
  }

  /**
   * Authoritative credit operation with pessimistic row locking and idempotency.
   */
  async creditWallet(
    walletId: string,
    amount: Decimal,
    type: LedgerEntryType,
    bucket: WalletBucketType,
    referenceType: string,
    referenceId: string | null,
    idempotencyKey: string,
    description: string,
    expiresAt?: Date,
    metadata?: any,
    externalTx?: Prisma.TransactionClient,
  ) {
    if (amount.lte(0)) {
      throw new BadRequestException('Credit amount must be strictly greater than zero.');
    }

    const executeCredit = async (tx: Prisma.TransactionClient) => {
      // 1. Check idempotency
      const existingEntry = await tx.walletLedgerEntry.findUnique({
        where: { idempotencyKey },
      });
      if (existingEntry) {
        this.logger.log(
          `Idempotent credit hit for key: ${idempotencyKey}. Returning existing ledger entry.`,
        );
        return existingEntry;
      }

      // 2. Pessimistic Row Lock
      const lockedRows: any[] = await tx.$queryRaw`
        SELECT id, "availableBalance", "lockedBalance", "realBalance", "promoBalance", status
        FROM "Wallet"
        WHERE id = ${walletId}
        FOR UPDATE
      `;

      if (!lockedRows || lockedRows.length === 0) {
        throw new NotFoundException(`Wallet not found: ${walletId}`);
      }

      const lockedWallet = lockedRows[0];
      if (lockedWallet.status !== WalletStatus.ACTIVE) {
        throw new BadRequestException(`Wallet is not active (Status: ${lockedWallet.status})`);
      }

      const currentAvailable = new Decimal(lockedWallet.availableBalance);
      const currentReal = new Decimal(lockedWallet.realBalance);
      const currentPromo = new Decimal(lockedWallet.promoBalance);

      // Check balance cap
      const newAvailable = currentAvailable.add(amount);
      if (newAvailable.gt(MAX_WALLET_BALANCE_CAP)) {
        throw new BadRequestException(
          `Wallet balance cap exceeded. Maximum allowed balance is ₹${MAX_WALLET_BALANCE_CAP.toLocaleString('en-IN')}`,
        );
      }

      let newReal = currentReal;
      let newPromo = currentPromo;

      if (bucket === WalletBucketType.REAL_MONEY || bucket === WalletBucketType.REFUND_CREDIT) {
        newReal = currentReal.add(amount);
      } else {
        newPromo = currentPromo.add(amount);
      }

      // 3. Create immutable ledger entry
      const ledgerEntry = await tx.walletLedgerEntry.create({
        data: {
          walletId,
          type,
          direction: LedgerDirection.CREDIT,
          bucket,
          amount,
          balanceBefore: currentAvailable,
          balanceAfter: newAvailable,
          referenceType,
          referenceId,
          idempotencyKey,
          description,
          expiresAt,
          metadata: metadata || Prisma.JsonNull,
        },
      });

      // 4. Update cached wallet balances
      await tx.wallet.update({
        where: { id: walletId },
        data: {
          availableBalance: newAvailable,
          realBalance: newReal,
          promoBalance: newPromo,
        },
      });

      this.logger.log(
        `[WALLET CREDIT] Wallet: ${walletId} | +₹${amount.toFixed(2)} (${type}) | New Balance: ₹${newAvailable.toFixed(2)}`,
      );

      return ledgerEntry;
    };

    if (externalTx) {
      return executeCredit(externalTx);
    }
    return this.prisma.$transaction(executeCredit);
  }

  /**
   * Authoritative debit operation with pessimistic row locking, deterministic bucket consumption, and zero negative balance guarantees.
   */
  async debitWallet(
    walletId: string,
    amount: Decimal,
    type: LedgerEntryType,
    referenceType: string,
    referenceId: string | null,
    idempotencyKey: string,
    description: string,
    metadata?: any,
    externalTx?: Prisma.TransactionClient,
  ) {
    if (amount.lte(0)) {
      throw new BadRequestException('Debit amount must be strictly greater than zero.');
    }

    const executeDebit = async (tx: Prisma.TransactionClient) => {
      // 1. Check idempotency
      const existingEntry = await tx.walletLedgerEntry.findUnique({
        where: { idempotencyKey },
      });
      if (existingEntry) {
        this.logger.log(
          `Idempotent debit hit for key: ${idempotencyKey}. Returning existing ledger entry.`,
        );
        return existingEntry;
      }

      // 2. Pessimistic Row Lock
      const lockedRows: any[] = await tx.$queryRaw`
        SELECT id, "availableBalance", "lockedBalance", "realBalance", "promoBalance", status
        FROM "Wallet"
        WHERE id = ${walletId}
        FOR UPDATE
      `;

      if (!lockedRows || lockedRows.length === 0) {
        throw new NotFoundException(`Wallet not found: ${walletId}`);
      }

      const lockedWallet = lockedRows[0];
      if (lockedWallet.status !== WalletStatus.ACTIVE) {
        throw new BadRequestException(`Wallet is not active (Status: ${lockedWallet.status})`);
      }

      const currentAvailable = new Decimal(lockedWallet.availableBalance);
      const currentReal = new Decimal(lockedWallet.realBalance);
      const currentPromo = new Decimal(lockedWallet.promoBalance);

      if (currentAvailable.lt(amount)) {
        throw new BadRequestException(
          `Insufficient wallet balance. Available: ₹${currentAvailable.toFixed(2)}, Requested: ₹${amount.toFixed(2)}`,
        );
      }

      const newAvailable = currentAvailable.sub(amount);

      // Deterministic Bucket Consumption: Consume promo first, then real
      let remainingDebit = amount;
      let newPromo = currentPromo;
      let newReal = currentReal;
      let primaryBucket: WalletBucketType = WalletBucketType.REAL_MONEY;

      if (currentPromo.gt(0)) {
        if (currentPromo.gte(remainingDebit)) {
          newPromo = currentPromo.sub(remainingDebit);
          remainingDebit = new Decimal(0);
          primaryBucket = WalletBucketType.PROMOTIONAL;
        } else {
          remainingDebit = remainingDebit.sub(currentPromo);
          newPromo = new Decimal(0);
          newReal = currentReal.sub(remainingDebit);
          primaryBucket = WalletBucketType.PROMOTIONAL;
        }
      } else {
        newReal = currentReal.sub(remainingDebit);
        primaryBucket = WalletBucketType.REAL_MONEY;
      }

      // 3. Create immutable ledger entry
      const ledgerEntry = await tx.walletLedgerEntry.create({
        data: {
          walletId,
          type,
          direction: LedgerDirection.DEBIT,
          bucket: primaryBucket,
          amount,
          balanceBefore: currentAvailable,
          balanceAfter: newAvailable,
          referenceType,
          referenceId,
          idempotencyKey,
          description,
          metadata: metadata || Prisma.JsonNull,
        },
      });

      // 4. Update cached balances
      await tx.wallet.update({
        where: { id: walletId },
        data: {
          availableBalance: newAvailable,
          realBalance: newReal,
          promoBalance: newPromo,
        },
      });

      this.logger.log(
        `[WALLET DEBIT] Wallet: ${walletId} | -₹${amount.toFixed(2)} (${type}) | New Balance: ₹${newAvailable.toFixed(2)}`,
      );

      return ledgerEntry;
    };

    if (externalTx) {
      return executeDebit(externalTx);
    }
    return this.prisma.$transaction(executeDebit);
  }

  /**
   * Creates a Razorpay Order for adding money to the customer's wallet.
   */
  async createDepositOrder(userId: string, amount: number) {
    const config = this.systemConfigService
      ? await this.systemConfigService.getWalletConfig()
      : {
          minSingleDeposit: MIN_SINGLE_DEPOSIT,
          maxSingleDeposit: MAX_SINGLE_DEPOSIT,
          maxWalletBalanceCap: MAX_WALLET_BALANCE_CAP,
          isDepositsEnabled: true,
        };

    if (!config.isDepositsEnabled) {
      throw new BadRequestException('Wallet deposits are currently disabled.');
    }

    if (amount < config.minSingleDeposit || amount > config.maxSingleDeposit) {
      throw new BadRequestException(
        `Deposit amount must be between ₹${config.minSingleDeposit} and ₹${config.maxSingleDeposit.toLocaleString('en-IN')}.`,
      );
    }

    const wallet = await this.getOrCreateWallet(userId);
    const projectedBalance = wallet.availableBalance.add(amount);

    if (projectedBalance.gt(config.maxWalletBalanceCap)) {
      throw new BadRequestException(
        `Deposit of ₹${amount} exceeds the maximum wallet balance cap of ₹${config.maxWalletBalanceCap.toLocaleString('en-IN')}. Current balance: ₹${wallet.availableBalance.toFixed(2)}`,
      );
    }

    const amountInPaise = Math.round(amount * 100);

    if (this.useMock) {
      const mockOrderId = `order_mock_wlt_${Date.now()}`;
      return {
        orderId: mockOrderId,
        amount,
        currency: 'INR',
        keyId: this.keyId,
        isMock: true,
      };
    }

    try {
      const order = await this.razorpay!.orders.create({
        amount: amountInPaise,
        currency: 'INR',
        receipt: `rcpt_wlt_${wallet.id.slice(-8)}_${Date.now().toString().slice(-6)}`,
        notes: {
          walletId: wallet.id,
          userId,
          purpose: 'WALLET_DEPOSIT',
        },
      });

      return {
        orderId: order.id,
        amount,
        currency: 'INR',
        keyId: this.keyId,
        isMock: false,
      };
    } catch (err: any) {
      this.logger.error('Failed to create Razorpay deposit order:', err);
      throw new BadRequestException(`Failed to create deposit order: ${err.message || err}`);
    }
  }

  /**
   * Verifies Razorpay deposit payment signature and credits the user's real balance.
   */
  async verifyDepositPayment(userId: string, dto: VerifyDepositDto) {
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = dto;
    const wallet = await this.getOrCreateWallet(userId);
    const idempotencyKey = `wallet_deposit_${razorpayPaymentId}`;

    // 1. Signature Verification
    if (this.useMock && razorpaySignature === 'mock_signature') {
      this.logger.log(`[RAZORPAY-MOCK] Verified mock wallet deposit signature for user ${userId}`);
    } else {
      let isSignatureValid = false;
      try {
        isSignatureValid = validatePaymentVerification(
          { order_id: razorpayOrderId, payment_id: razorpayPaymentId },
          razorpaySignature,
          this.keySecret,
        );
      } catch (err) {
        this.logger.warn('Razorpay deposit signature verification error:', err);
        isSignatureValid = false;
      }

      if (!isSignatureValid) {
        throw new BadRequestException('Invalid payment signature. Verification failed.');
      }
    }

    // 2. Fetch authoritative payment from Razorpay API
    let depositAmount = new Decimal(0);
    if (!this.useMock) {
      try {
        const payment: any = await this.razorpay!.payments.fetch(razorpayPaymentId);
        if (!payment) {
          throw new BadRequestException('Payment record not found on Razorpay.');
        }

        if (payment.order_id && payment.order_id !== razorpayOrderId) {
          throw new BadRequestException('Razorpay payment is not associated with provided order ID.');
        }

        if (payment.currency && payment.currency.toUpperCase() !== 'INR') {
          throw new BadRequestException(`Currency mismatch: Expected INR, got ${payment.currency}`);
        }

        if (payment.status !== 'captured') {
          throw new BadRequestException(`Payment is not captured on Razorpay (Status: ${payment.status})`);
        }

        depositAmount = new Decimal(payment.amount).div(100);
      } catch (err: any) {
        if (err instanceof BadRequestException) throw err;
        this.logger.error('Failed to verify deposit with Razorpay API:', err);
        throw new BadRequestException(`Payment verification failed: ${err.message || err}`);
      }
    } else {
      // In mock mode, deduce amount from mock context or default ₹1,000 if not verifiable
      depositAmount = new Decimal(1000);
    }

    // 3. Atomic Wallet Credit
    const ledgerEntry = await this.creditWallet(
      wallet.id,
      depositAmount,
      LedgerEntryType.CUSTOMER_DEPOSIT,
      WalletBucketType.REAL_MONEY,
      'PAYMENT',
      razorpayPaymentId,
      idempotencyKey,
      `Added funds to DriveGo Wallet via Razorpay (${razorpayPaymentId})`,
      undefined,
      { razorpayOrderId, razorpayPaymentId },
    );

    // 4. Send Confirmation Notification
    try {
      await this.notificationsService.notifyUser(
        userId,
        'Wallet Recharged',
        `₹${depositAmount.toFixed(2)} has been successfully added to your DriveGo Wallet.`,
      );
    } catch (notifErr: any) {
      this.logger.warn(`Failed to dispatch deposit notification: ${notifErr.message}`);
    }

    return {
      success: true,
      message: 'Wallet recharge successful.',
      amount: depositAmount.toNumber(),
      availableBalance: ledgerEntry.balanceAfter.toNumber(),
      transactionId: ledgerEntry.id,
    };
  }

  /**
   * Admin manual adjustment with mandatory reason and AuditLog.
   */
  async adminAdjustWallet(adminUserId: string, dto: AdminAdjustWalletDto) {
    const { walletId, amount, direction, bucket, reason, clientNonce } = dto;
    const decimalAmount = new Decimal(amount);
    const idempotencyKey = `wallet_admin_adj_${adminUserId}_${walletId}_${clientNonce || Date.now()}`;

    let ledgerEntry;
    if (direction === LedgerDirection.CREDIT) {
      ledgerEntry = await this.creditWallet(
        walletId,
        decimalAmount,
        LedgerEntryType.ADMIN_ADJUSTMENT,
        bucket,
        'ADMIN',
        adminUserId,
        idempotencyKey,
        `Admin Credit: ${reason}`,
        undefined,
        { adminUserId, reason },
      );
    } else {
      ledgerEntry = await this.debitWallet(
        walletId,
        decimalAmount,
        LedgerEntryType.ADMIN_ADJUSTMENT,
        'ADMIN',
        adminUserId,
        idempotencyKey,
        `Admin Debit: ${reason}`,
        { adminUserId, reason },
      );
    }

    // Write to AuditLog
    await this.auditLogService.log(
      adminUserId,
      `WALLET_ADJUSTMENT_${direction}`,
      'Wallet',
      walletId,
      {
        amount,
        direction,
        bucket,
        reason,
        balanceBefore: ledgerEntry.balanceBefore.toNumber(),
        balanceAfter: ledgerEntry.balanceAfter.toNumber(),
      },
    );

    return {
      success: true,
      ledgerEntry,
    };
  }

  /**
   * Reconciles cached wallet balances against authoritative ledger aggregates.
   */
  async reconcileWallet(walletId: string) {
    const wallet = await this.prisma.wallet.findUnique({
      where: { id: walletId },
    });

    if (!wallet) {
      throw new NotFoundException(`Wallet not found: ${walletId}`);
    }

    const aggregate = await this.prisma.walletLedgerEntry.groupBy({
      by: ['direction'],
      where: { walletId },
      _sum: { amount: true },
    });

    let totalCredits = new Decimal(0);
    let totalDebits = new Decimal(0);

    for (const row of aggregate) {
      if (row.direction === LedgerDirection.CREDIT) {
        totalCredits = row._sum.amount ? new Decimal(row._sum.amount) : new Decimal(0);
      } else if (row.direction === LedgerDirection.DEBIT) {
        totalDebits = row._sum.amount ? new Decimal(row._sum.amount) : new Decimal(0);
      }
    }

    const calculatedBalance = totalCredits.sub(totalDebits);
    const isMatched = wallet.availableBalance.equals(calculatedBalance);
    const isBucketSumMatched = wallet.realBalance.add(wallet.promoBalance).equals(wallet.availableBalance);

    if (!isMatched || !isBucketSumMatched) {
      this.logger.error(
        `CRITICAL FINANCIAL DISCREPANCY DETECTED for Wallet ${walletId}! Cached: ₹${wallet.availableBalance}, Computed: ₹${calculatedBalance}, Real: ₹${wallet.realBalance}, Promo: ₹${wallet.promoBalance}`,
      );

      // Freeze wallet on discrepancy
      await this.prisma.wallet.update({
        where: { id: walletId },
        data: { status: WalletStatus.FROZEN },
      });

      if (this.apmMonitoringService) {
        this.apmMonitoringService.captureFinancialInconsistency(
          'WALLET_RECONCILIATION_MISMATCH',
          {
            severity: 'fatal',
            extra: {
              walletId,
              cached: wallet.availableBalance.toString(),
              computed: calculatedBalance.toString(),
            },
          },
        );
      }
    }

    return {
      walletId,
      isMatched: isMatched && isBucketSumMatched,
      cachedAvailable: wallet.availableBalance.toNumber(),
      computedAvailable: calculatedBalance.toNumber(),
      realBalance: wallet.realBalance.toNumber(),
      promoBalance: wallet.promoBalance.toNumber(),
      status: wallet.status,
    };
  }
}

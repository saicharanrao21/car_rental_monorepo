import { PayoutsService } from './payouts.service';
import { PayoutStatus, PaymentStatus, LedgerDirection, Prisma } from '@prisma/client';
import { BadRequestException, NotFoundException } from '@nestjs/common';

describe('PayoutsLifecycle (Phase 27.6)', () => {
  let service: PayoutsService;
  let mockPrisma: any;
  let mockNotifications: any;
  let mockAudit: any;
  let mockSystemConfig: any;
  let mockWallets: any;

  beforeEach(() => {
    mockPrisma = {
      vendor: {
        findUnique: jest.fn().mockResolvedValue({ id: 'v1', businessName: 'Speedy Rentals', userId: 'usr_v1' }),
      },
      booking: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'b1', netToVendor: new Prisma.Decimal(10000), createdAt: new Date(), updatedAt: new Date(Date.now() - 3 * 86400000) },
          { id: 'b2', netToVendor: new Prisma.Decimal(5000), createdAt: new Date(), updatedAt: new Date(Date.now() - 4 * 86400000) },
        ]),
        aggregate: jest.fn().mockResolvedValue({ _sum: { platformFee: new Prisma.Decimal(10000) } }),
      },
      payout: {
        findMany: jest.fn().mockResolvedValue([]),
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        count: jest.fn().mockResolvedValue(0),
        aggregate: jest.fn().mockResolvedValue({ _sum: { amount: new Prisma.Decimal(25000) } }),
      },
      financialAdjustment: {
        findMany: jest.fn().mockResolvedValue([]),
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        count: jest.fn().mockResolvedValue(0),
      },
      payment: {
        aggregate: jest.fn().mockResolvedValue({ _sum: { amount: new Prisma.Decimal(100000) } }),
      },
      securityDeposit: {
        aggregate: jest.fn().mockResolvedValue({ _sum: { amount: new Prisma.Decimal(20000) } }),
      },
      wallet: {
        aggregate: jest.fn().mockResolvedValue({ _sum: { realBalance: new Prisma.Decimal(15000), promoBalance: new Prisma.Decimal(5000) } }),
      },
      $transaction: jest.fn(async (cb) => cb(mockPrisma)),
      $queryRaw: jest.fn().mockResolvedValue([]),
    };

    mockNotifications = {
      notifyUser: jest.fn().mockResolvedValue(undefined),
    };

    mockAudit = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    mockSystemConfig = {
      getPayoutConfig: jest.fn().mockResolvedValue({
        minPayoutAmount: 500,
        maxSinglePayoutAmount: 100000,
        dailyVendorPayoutCap: 200000,
        payoutApprovalThreshold: 25000,
        autoPayoutEnabled: false,
        settlementHoldDays: 2,
      }),
    };

    mockWallets = {
      adminAdjustWallet: jest.fn().mockResolvedValue(undefined),
    };

    service = new PayoutsService(
      mockPrisma,
      mockNotifications,
      mockAudit,
      mockSystemConfig,
      mockWallets,
    );
  });

  describe('Vendor Earnings & Balance Calculation', () => {
    it('should compute total earnings, held earnings, and available payable balance', async () => {
      const summary = await service.getVendorEarningsSummary('v1');

      expect(summary.totalEarnings).toBe(15000);
      expect(summary.heldEarnings).toBe(0); // Both bookings older than 2 days
      expect(summary.availableBalance).toBe(15000);
      expect(summary.outstandingBalance).toBe(15000);
    });

    it('should reserve pending payout amounts from available balance', async () => {
      mockPrisma.payout.findMany.mockImplementation((args: any) => {
        if (args.where.status === PayoutStatus.PAID) {
          return Promise.resolve([{ amount: new Prisma.Decimal(5000) }]);
        }
        if (args.where.status?.in) {
          return Promise.resolve([{ amount: new Prisma.Decimal(3000) }]); // 3k pending
        }
        return Promise.resolve([]);
      });

      const summary = await service.getVendorEarningsSummary('v1');

      expect(summary.totalEarnings).toBe(15000);
      expect(summary.totalPaid).toBe(5000);
      expect(summary.totalPending).toBe(3000);
      expect(summary.availableBalance).toBe(7000); // 15000 - 5000 - 3000
      expect(summary.outstandingBalance).toBe(10000); // 15000 - 5000
    });
  });

  describe('Payout Request Boundaries & Idempotency', () => {
    it('should reject payout request below minimum threshold', async () => {
      await expect(
        service.requestPayout('v1', { vendorId: 'v1', amount: 300 }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject payout request exceeding available balance', async () => {
      await expect(
        service.requestPayout('v1', { vendorId: 'v1', amount: 20000 }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should create PENDING payout when valid', async () => {
      mockPrisma.payout.create.mockImplementation((args: any) => ({
        id: 'po-1',
        ...args.data,
      }));

      const payout = await service.requestPayout(
        'v1',
        { vendorId: 'v1', amount: 5000, notes: 'Weekly settlement' },
        'usr_v1',
      );

      expect(payout.amount.toNumber()).toBe(5000);
      expect(payout.status).toBe(PayoutStatus.PENDING);
      expect(mockAudit.log).toHaveBeenCalled();
      expect(mockNotifications.notifyUser).toHaveBeenCalled();
    });
  });

  describe('Payout Approval & Execution Workflow', () => {
    it('should transition PENDING payout to APPROVED', async () => {
      mockPrisma.payout.findUnique.mockResolvedValue({
        id: 'po-1',
        payoutNumber: 'PO-2026-08-00001',
        amount: new Prisma.Decimal(5000),
        status: PayoutStatus.PENDING,
        vendor: { id: 'v1', userId: 'usr_v1' },
      });

      mockPrisma.payout.update.mockImplementation((args: any) => ({
        id: 'po-1',
        ...args.data,
      }));

      const approved = await service.approvePayout('po-1', 'admin-fin-1', {
        adminNotes: 'Verified bank details match KYC',
      });

      expect(approved.status).toBe(PayoutStatus.APPROVED);
      expect(mockAudit.log).toHaveBeenCalledWith(
        'admin-fin-1',
        'PAYOUT_APPROVED',
        'Payout',
        'po-1',
        expect.any(Object),
      );
    });

    it('should execute APPROVED payout to PAID with provider reference', async () => {
      mockPrisma.payout.findUnique.mockResolvedValue({
        id: 'po-1',
        payoutNumber: 'PO-2026-08-00001',
        amount: new Prisma.Decimal(5000),
        status: PayoutStatus.APPROVED,
        vendor: { id: 'v1', userId: 'usr_v1' },
      });

      mockPrisma.payout.update.mockImplementation((args: any) => ({
        id: 'po-1',
        ...args.data,
      }));

      const paid = await service.executePayout('po-1', 'admin-fin-1', {
        providerTransferId: 'neft_ref_987654321',
        providerFee: 5.0,
      });

      expect(paid.status).toBe(PayoutStatus.PAID);
      expect(paid.providerTransferId).toBe('neft_ref_987654321');
    });

    it('should reject invalid state execution', async () => {
      mockPrisma.payout.findUnique.mockResolvedValue({
        id: 'po-failed',
        status: PayoutStatus.REJECTED,
        vendor: { id: 'v1' },
      });

      await expect(
        service.executePayout('po-failed', 'admin-fin-1'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('Financial Adjustments & Executive Summary', () => {
    it('should record financial adjustment and sync with customer wallet when target is CUSTOMER_WALLET', async () => {
      mockPrisma.financialAdjustment.create.mockImplementation((args: any) => ({
        id: 'adj-1',
        ...args.data,
      }));

      const adj = await service.createFinancialAdjustment('admin-fin-1', {
        targetType: 'CUSTOMER_WALLET',
        targetId: 'w_cust_1',
        amount: 500,
        direction: LedgerDirection.CREDIT,
        reason: 'Goodwill compensation for delayed vehicle delivery',
        category: 'GOODWILL',
        idempotencyKey: 'adj_goodwill_booking_123',
      });

      expect(adj.amount.toNumber()).toBe(500);
      expect(mockWallets.adminAdjustWallet).toHaveBeenCalled();
      expect(mockAudit.log).toHaveBeenCalled();
    });

    it('should aggregate financial summary correctly', async () => {
      const summary = await service.getFinancialSummary();

      expect(summary.grossMerchandiseValue).toBe(100000);
      expect(summary.securityDepositsHeld).toBe(20000);
      expect(summary.customerWalletLiabilities).toBe(20000); // 15000 + 5000
    });
  });
});

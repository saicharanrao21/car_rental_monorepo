import { PayoutsService } from '../payouts.service';
import { RazorpayXPayoutProvider } from '../providers/razorpayx-payout.provider';
import { PayoutStatus, PaymentStatus, Prisma } from '@prisma/client';
import { BadRequestException } from '@nestjs/common';

describe('Phase Q: Payout Integrity & RazorpayX Provider Hardening', () => {
  describe('Concurrent Payout Multi-Drain Protection (CRIT-Q-04)', () => {
    let payoutsService: PayoutsService;
    let mockPrisma: any;
    let mockNotifications: any;
    let mockAuditLog: any;
    let mockSystemConfig: any;

    beforeEach(() => {
      mockPrisma = {
        vendor: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'v_q_01',
            businessName: 'Apex Rentals',
            userId: 'usr_v_01',
            bankDetails: JSON.stringify({
              accountNumber: '1234567890',
              ifscCode: 'HDFC0001234',
              beneficiaryName: 'Apex Rentals Pvt Ltd',
            }),
          }),
        },
        booking: {
          findMany: jest.fn().mockResolvedValue([
            {
              id: 'b_1',
              vendorId: 'v_q_01',
              status: 'COMPLETED',
              payment: { status: PaymentStatus.PAID },
              netToVendor: new Prisma.Decimal(50000),
              createdAt: new Date(Date.now() - 5 * 86400000), // 5 days ago (settled)
              disputeFlag: false,
              damageClaims: [],
            },
          ]),
        },
        payout: {
          findMany: jest.fn(),
          create: jest.fn().mockImplementation((args) =>
            Promise.resolve({ id: 'po_new_01', ...args.data }),
          ),
          findUnique: jest.fn().mockResolvedValue(null),
          count: jest.fn().mockResolvedValue(0),
        },
        financialAdjustment: {
          findMany: jest.fn().mockResolvedValue([]),
        },
        $transaction: jest.fn(async (cb) => cb(mockPrisma)),
        $queryRaw: jest.fn().mockResolvedValue([{ id: 'v_q_01' }]),
      };

      mockNotifications = {
        notifyUser: jest.fn().mockResolvedValue(undefined),
      };

      mockAuditLog = {
        log: jest.fn().mockResolvedValue(undefined),
      };

      mockSystemConfig = {
        getPayoutConfig: jest.fn().mockResolvedValue({
          minPayoutAmount: 500,
          maxSinglePayoutAmount: 100000,
          dailyVendorPayoutCap: 200000,
          settlementHoldDays: 2,
        }),
      };

      payoutsService = new PayoutsService(
        mockPrisma,
        mockNotifications,
        mockAuditLog,
        mockSystemConfig,
      );
    });

    it('rejects a second payout request when funds are reserved in PROCESSING or APPROVED states', async () => {
      // Total earned: 50,000.
      // Already paid: 10,000.
      // Already reserved in PROCESSING: 35,000.
      // Available = 50,000 - 10,000 - 35,000 = 5,000.
      mockPrisma.payout.findMany.mockImplementation((args: any) => {
        if (args.where.status === PayoutStatus.PAID) {
          return Promise.resolve([{ amount: new Prisma.Decimal(10000) }]);
        }
        if (args.where.status?.in) {
          // Reserved payouts query (PENDING, APPROVED, PROCESSING)
          return Promise.resolve([
            { id: 'po_proc_1', status: PayoutStatus.PROCESSING, amount: new Prisma.Decimal(35000) },
          ]);
        }
        return Promise.resolve([]);
      });

      // Requesting 10,000 should be rejected because only 5,000 is available
      await expect(
        payoutsService.requestPayout('v_q_01', { amount: 10000 }),
      ).rejects.toThrow(BadRequestException);

      // Requesting 5,000 should succeed
      const result = await payoutsService.requestPayout('v_q_01', { amount: 5000 });
      expect(result).toBeDefined();
      expect(result.amount).toEqual(new Prisma.Decimal(5000));
      expect(mockPrisma.$queryRaw).toHaveBeenCalled(); // Acquired pessimistic lock on Vendor
    });
  });

  describe('RazorpayX Production Payout Provider (CRIT-Q-03)', () => {
    let originalFetch: any;

    beforeAll(() => {
      originalFetch = global.fetch;
    });

    afterAll(() => {
      global.fetch = originalFetch;
    });

    it('returns BLOCKED_CREDENTIALS when credentials are missing', async () => {
      const mockConfig: any = {
        get: jest.fn().mockReturnValue(undefined),
      };
      const provider = new RazorpayXPayoutProvider(mockConfig);

      expect(provider.isConfigured()).toBe(false);

      const response = await provider.initiateTransfer({
        payoutId: 'po_test_01',
        payoutNumber: 'PO-2026-09-00001',
        vendorId: 'v_test_01',
        amount: 5000,
        currency: 'INR',
        idempotencyKey: 'idemp_test_01',
      });

      expect(response.status).toBe('BLOCKED_CREDENTIALS');
      expect(response.success).toBe(false);
    });

    it('executes live HTTP POST to RazorpayX API and parses successful processed response', async () => {
      const mockConfig: any = {
        get: jest.fn((key: string) => {
          if (key === 'RAZORPAYX_KEY_ID') return 'rzp_live_key123';
          if (key === 'RAZORPAYX_KEY_SECRET') return 'rzp_live_secret456';
          if (key === 'RAZORPAYX_ACCOUNT_NUMBER') return '9876543210';
          if (key === 'RAZORPAYX_API_URL') return 'https://api.razorpay.com/v1/payouts';
          return undefined;
        }),
      };
      const provider = new RazorpayXPayoutProvider(mockConfig);
      expect(provider.isConfigured()).toBe(true);

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        status: 200,
        json: async () => ({
          id: 'pout_live_rzpx_789',
          entity: 'payout',
          amount: 500000,
          currency: 'INR',
          status: 'processed',
          fees: 590,
          tax: 90,
          utr: 'UTR123456789',
        }),
      }) as any;

      const response = await provider.initiateTransfer({
        payoutId: 'po_test_02',
        payoutNumber: 'PO-2026-09-00002',
        vendorId: 'v_test_02',
        amount: 5000,
        currency: 'INR',
        accountNumber: '1122334455',
        ifscCode: 'SBIN0001234',
        beneficiaryName: 'Test Vendor Mobility',
        idempotencyKey: 'idemp_test_02',
      });

      expect(global.fetch).toHaveBeenCalledTimes(1);
      const [url, options] = (global.fetch as jest.Mock).mock.calls[0];

      expect(url).toBe('https://api.razorpay.com/v1/payouts');
      expect(options.method).toBe('POST');
      expect(options.headers['X-Payout-Idempotency']).toBe('idemp_test_02');
      expect(options.headers['Authorization']).toContain('Basic ');

      const parsedPayload = JSON.parse(options.body);
      expect(parsedPayload.amount).toBe(500000); // 5000 * 100 paise
      expect(parsedPayload.account_number).toBe('9876543210');
      expect(parsedPayload.fund_account.bank_account.account_number).toBe('1122334455');
      expect(parsedPayload.fund_account.bank_account.ifsc).toBe('SBIN0001234');

      expect(response.status).toBe('PAID');
      expect(response.providerTransferId).toBe('pout_live_rzpx_789');
      expect(response.providerFee).toBe(5.9);
    });

    it('correctly maps queued/processing response to PROCESSING status', async () => {
      const mockConfig: any = {
        get: jest.fn((key: string) => {
          if (key === 'RAZORPAYX_KEY_ID') return 'rzp_live_key123';
          if (key === 'RAZORPAYX_KEY_SECRET') return 'rzp_live_secret456';
          if (key === 'RAZORPAYX_ACCOUNT_NUMBER') return '9876543210';
          return undefined;
        }),
      };
      const provider = new RazorpayXPayoutProvider(mockConfig);

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        status: 201,
        json: async () => ({
          id: 'pout_queued_123',
          entity: 'payout',
          amount: 250000,
          status: 'queued',
        }),
      }) as any;

      const response = await provider.initiateTransfer({
        payoutId: 'po_test_03',
        payoutNumber: 'PO-2026-09-00003',
        vendorId: 'v_test_03',
        amount: 2500,
        currency: 'INR',
        accountNumber: '9988776655',
        ifscCode: 'ICIC0000001',
        beneficiaryName: 'Queued Vendor',
        idempotencyKey: 'idemp_test_03',
      });

      expect(response.status).toBe('PROCESSING');
      expect(response.providerTransferId).toBe('pout_queued_123');
      expect(response.success).toBe(true);
    });

    it('correctly maps gateway failure response without leaking credentials', async () => {
      const mockConfig: any = {
        get: jest.fn((key: string) => {
          if (key === 'RAZORPAYX_KEY_ID') return 'rzp_live_key123';
          if (key === 'RAZORPAYX_KEY_SECRET') return 'rzp_live_secret456';
          if (key === 'RAZORPAYX_ACCOUNT_NUMBER') return '9876543210';
          return undefined;
        }),
      };
      const provider = new RazorpayXPayoutProvider(mockConfig);

      global.fetch = jest.fn().mockResolvedValue({
        ok: false,
        status: 400,
        json: async () => ({
          error: {
            code: 'BAD_REQUEST_ERROR',
            description: 'Beneficiary account number is invalid according to checksum',
          },
        }),
      }) as any;

      const response = await provider.initiateTransfer({
        payoutId: 'po_test_04',
        payoutNumber: 'PO-2026-09-00004',
        vendorId: 'v_test_04',
        amount: 1000,
        currency: 'INR',
        accountNumber: '00000000',
        ifscCode: 'HDFC0000001',
        beneficiaryName: 'Failed Vendor',
        idempotencyKey: 'idemp_test_04',
      });

      expect(response.status).toBe('FAILED');
      expect(response.success).toBe(false);
      expect(response.failureReason).toBe(
        'Beneficiary account number is invalid according to checksum',
      );
    });
  });
});

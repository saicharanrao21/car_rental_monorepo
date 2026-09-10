import { PayoutsService } from '../payouts.service';
import { PayoutStatus, Prisma, LedgerAccountType, LedgerEntrySide, Role } from '@prisma/client';
import { BadRequestException } from '@nestjs/common';
import { WebhookProcessor } from '../../queues/processors/webhook.processor';
import { CorporateAccountsService } from '../../corporate/corporate-accounts.service';
import { MetaWhatsAppProvider } from '../../whatsapp/whatsapp-provider.service';
import { ConfigService } from '@nestjs/config';

describe('Phase R: Enterprise Payout Webhooks, Reversals, Corporate Billing & Queue Integration', () => {
  let payoutsService: PayoutsService;
  let mockPrisma: any;
  let mockNotifications: any;
  let mockAuditLog: any;
  let mockSystemConfig: any;
  let mockLedgerCore: any;

  beforeEach(() => {
    mockPrisma = {
      vendor: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'v_enterprise_01',
          businessName: 'Apex Enterprise Rentals',
          userId: 'usr_v_01',
          bankDetails: JSON.stringify({
            accountNumber: '9876543210',
            ifscCode: 'HDFC0001234',
            beneficiaryName: 'Apex Enterprise Rentals',
          }),
        }),
      },
      payout: {
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn().mockImplementation((args) => {
          const existing = mockPrisma.payout.findUnique.mock.results?.[0]?.value;
          return Promise.resolve({
            id: args.where.id,
            vendorId: 'v_enterprise_01',
            vendor: { userId: 'usr_v_01' },
            amount: existing?.amount || new Prisma.Decimal(25000),
            payoutNumber: existing?.payoutNumber || 'PO-2026-09-00001',
            ...args.data,
          });
        }),
        create: jest.fn(),
        count: jest.fn().mockResolvedValue(1),
      },
      webhookEvent: {
        create: jest.fn().mockResolvedValue({ id: 'wh_evt_01' }),
        update: jest.fn().mockResolvedValue({ id: 'wh_evt_01' }),
      },
      $transaction: jest.fn(async (cb) => cb(mockPrisma)),
      $queryRaw: jest.fn().mockResolvedValue([]),
    };

    mockNotifications = {
      notifyUser: jest.fn().mockResolvedValue(undefined),
    };

    mockAuditLog = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    mockSystemConfig = {
      getPayoutConfig: jest.fn().mockResolvedValue({
        settlementHoldDays: 0,
        dailyVendorPayoutCap: 500000,
      }),
    };

    mockLedgerCore = {
      recordJournal: jest.fn().mockResolvedValue({
        id: 'jrnl_po_test',
        isBalanced: true,
      }),
    };

    payoutsService = new PayoutsService(
      mockPrisma,
      mockNotifications,
      mockAuditLog,
      mockSystemConfig,
      undefined,
      undefined,
      mockLedgerCore,
    );
  });

  describe('1. Payout Webhook Processing (RazorpayX)', () => {
    it('successfully processes payout.processed and writes balanced LedgerCore journal', async () => {
      mockPrisma.payout.findFirst.mockResolvedValue({
        id: 'po_test_01',
        payoutNumber: 'PO-2026-09-00001',
        vendorId: 'v_enterprise_01',
        amount: new Prisma.Decimal(25000),
        status: PayoutStatus.PROCESSING,
        vendor: { userId: 'usr_v_01' },
      });

      const payload = {
        event: 'payout.processed',
        event_id: 'evt_rzpx_001',
        payload: {
          payout: {
            entity: {
              id: 'pout_1234567890',
              reference_id: 'PO-2026-09-00001',
              amount: 2500000,
              fees: 500,
              status: 'processed',
            },
          },
        },
      };

      const result = await payoutsService.handlePayoutWebhook(
        JSON.stringify(payload),
        'mock_signature',
      );

      expect(result.received).toBe(true);
      expect(result.status).toBe(PayoutStatus.PAID);
      expect(mockPrisma.payout.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'po_test_01' },
          data: expect.objectContaining({
            status: PayoutStatus.PAID,
            providerTransferId: 'pout_1234567890',
          }),
        }),
      );

      // Verify double-entry journal was recorded
      expect(mockLedgerCore.recordJournal).toHaveBeenCalledTimes(1);
      const journalCall = mockLedgerCore.recordJournal.mock.calls[0][0];
      expect(journalCall.referenceType).toBe('PAYOUT');
      expect(journalCall.entries).toHaveLength(2);

      const debitEntry = journalCall.entries.find((e: any) => e.entrySide === LedgerEntrySide.DEBIT);
      const creditEntry = journalCall.entries.find((e: any) => e.entrySide === LedgerEntrySide.CREDIT);

      expect(debitEntry.accountType).toBe(LedgerAccountType.VENDOR_PAYABLE);
      expect(creditEntry.accountType).toBe(LedgerAccountType.GATEWAY_CLEARING);
      expect(debitEntry.amount.toString()).toBe(creditEntry.amount.toString());

      expect(mockNotifications.notifyUser).toHaveBeenCalledWith(
        'usr_v_01',
        'Payout Processed',
        expect.stringContaining('25000'),
        'VENDOR',
        'PAYOUT_EXECUTED',
        'Payout',
        'po_test_01',
        expect.any(String),
      );
    });

    it('returns idempotent skip if payout is already marked PAID', async () => {
      mockPrisma.payout.findFirst.mockResolvedValue({
        id: 'po_test_02',
        payoutNumber: 'PO-2026-09-00002',
        vendorId: 'v_enterprise_01',
        amount: new Prisma.Decimal(15000),
        status: PayoutStatus.PAID,
      });

      const payload = {
        event: 'payout.processed',
        event_id: 'evt_rzpx_002',
        payload: {
          payout: {
            entity: {
              id: 'pout_222222',
              reference_id: 'PO-2026-09-00002',
              status: 'processed',
            },
          },
        },
      };

      const result = await payoutsService.handlePayoutWebhook(
        JSON.stringify(payload),
        'mock_signature',
      );

      expect(result.received).toBe(true);
      expect(result.alreadyProcessed).toBe(true);
      expect(mockPrisma.payout.update).not.toHaveBeenCalled();
      expect(mockLedgerCore.recordJournal).not.toHaveBeenCalled();
    });

    it('processes payout.reversed and generates balancing reversal journal', async () => {
      mockPrisma.payout.findFirst.mockResolvedValue({
        id: 'po_test_03',
        payoutNumber: 'PO-2026-09-00003',
        vendorId: 'v_enterprise_01',
        amount: new Prisma.Decimal(40000),
        status: PayoutStatus.PAID,
        vendor: { userId: 'usr_v_01' },
      });

      mockPrisma.payout.findUnique.mockResolvedValue({
        id: 'po_test_03',
        payoutNumber: 'PO-2026-09-00003',
        vendorId: 'v_enterprise_01',
        amount: new Prisma.Decimal(40000),
        status: PayoutStatus.PAID,
        vendor: { userId: 'usr_v_01' },
      });

      const payload = {
        event: 'payout.reversed',
        event_id: 'evt_rzpx_003',
        payload: {
          payout: {
            entity: {
              id: 'pout_333333',
              reference_id: 'PO-2026-09-00003',
              status: 'reversed',
              failure_reason: 'Account closed by beneficiary',
            },
          },
        },
      };

      const result = await payoutsService.handlePayoutWebhook(
        JSON.stringify(payload),
        'mock_signature',
      );

      expect(result.received).toBe(true);
      expect(result.status).toBe(PayoutStatus.REVERSED);

      // Verify reversal journal was recorded with inverted entries
      expect(mockLedgerCore.recordJournal).toHaveBeenCalledTimes(1);
      const revCall = mockLedgerCore.recordJournal.mock.calls[0][0];
      expect(revCall.referenceType).toBe('PAYOUT_REVERSAL');

      const debitEntry = revCall.entries.find((e: any) => e.entrySide === LedgerEntrySide.DEBIT);
      const creditEntry = revCall.entries.find((e: any) => e.entrySide === LedgerEntrySide.CREDIT);

      // Reversal: Gateway clearing is debited (funds returned), Vendor payable is credited (we owe vendor again)
      expect(debitEntry.accountType).toBe(LedgerAccountType.GATEWAY_CLEARING);
      expect(creditEntry.accountType).toBe(LedgerAccountType.VENDOR_PAYABLE);
      expect(debitEntry.amount.toString()).toBe(creditEntry.amount.toString());
    });
  });

  describe('2. Admin Manual Payout Reversal', () => {
    it('reverses an existing paid payout and notifies vendor', async () => {
      mockPrisma.payout.findUnique.mockResolvedValue({
        id: 'po_rev_01',
        payoutNumber: 'PO-2026-09-00010',
        vendorId: 'v_enterprise_01',
        amount: new Prisma.Decimal(30000),
        status: PayoutStatus.PAID,
        vendor: { userId: 'usr_v_01' },
      });

      mockPrisma.payout.update.mockResolvedValueOnce({
        id: 'po_rev_01',
        payoutNumber: 'PO-2026-09-00010',
        vendorId: 'v_enterprise_01',
        amount: new Prisma.Decimal(30000),
        status: PayoutStatus.REVERSED,
        vendor: { userId: 'usr_v_01' },
      });

      const reversed = await payoutsService.reversePayout(
        'po_rev_01',
        'admin_user_01',
        'Manual bank NEFT return verification',
      );

      expect(reversed.status).toBe(PayoutStatus.REVERSED);
      expect(mockLedgerCore.recordJournal).toHaveBeenCalledTimes(1);
      expect(mockAuditLog.log).toHaveBeenCalledWith(
        'admin_user_01',
        'PAYOUT_REVERSED',
        'Payout',
        'po_rev_01',
        expect.objectContaining({
          amount: 30000,
          previousStatus: PayoutStatus.PAID,
        }),
      );
      expect(mockNotifications.notifyUser).toHaveBeenCalledWith(
        'usr_v_01',
        'Payout Reversed',
        expect.stringContaining('30000'),
        'VENDOR',
        'PAYOUT_REVERSED',
        'Payout',
        'po_rev_01',
        expect.any(String),
      );
    });

    it('rejects reversal if payout is in pending or rejected status', async () => {
      mockPrisma.payout.findUnique.mockResolvedValue({
        id: 'po_rev_02',
        status: PayoutStatus.PENDING,
        amount: new Prisma.Decimal(10000),
      });

      await expect(
        payoutsService.reversePayout('po_rev_02', 'admin_01', 'Invalid attempt'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('3. Corporate Accounts Billing Statement & Settlement', () => {
    let corporateService: CorporateAccountsService;
    let mockCorpPrisma: any;

    beforeEach(() => {
      mockCorpPrisma = {
        corporateAccount: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'corp_acc_01',
            corporateCode: 'CORP-DRIVEGO',
            companyName: 'Acme Enterprises Ltd',
            creditLimit: new Prisma.Decimal(1000000),
            usedCredit: new Prisma.Decimal(350000),
            paymentTermsDays: 30,
            isActive: true,
          }),
          update: jest.fn().mockImplementation((args) =>
            Promise.resolve({
              id: 'corp_acc_01',
              corporateCode: 'CORP-DRIVEGO',
              companyName: 'Acme Enterprises Ltd',
              creditLimit: new Prisma.Decimal(1000000),
              usedCredit: new Prisma.Decimal(350000).sub(args.data.usedCredit.decrement),
            }),
          ),
        },
        corporateCreditLedgerEntry: {
          create: jest.fn().mockResolvedValue({ id: 'cc_entry_01' }),
          findMany: jest.fn().mockResolvedValue([
            {
              id: 'cc_1',
              corporateAccountId: 'corp_acc_01',
              type: 'CREDIT_RESERVATION',
              amount: new Prisma.Decimal(50000),
              createdAt: new Date(),
            },
          ]),
          aggregate: jest.fn().mockImplementation((args) => {
            if (args.where.type === 'CREDIT_RESERVATION') {
              return Promise.resolve({ _sum: { amount: new Prisma.Decimal(350000) } });
            }
            if (args.where.type === 'INVOICE_SETTLEMENT') {
              return Promise.resolve({ _sum: { amount: new Prisma.Decimal(150000) } });
            }
            if (args.where.type === 'CREDIT_RELEASE') {
              return Promise.resolve({ _sum: { amount: new Prisma.Decimal(20000) } });
            }
            return Promise.resolve({ _sum: { amount: new Prisma.Decimal(0) } });
          }),
        },
        $transaction: jest.fn(async (cb) => cb(mockCorpPrisma)),
        $queryRaw: jest.fn().mockResolvedValue([]),
      };

      corporateService = new CorporateAccountsService(mockCorpPrisma);
    });

    it('settles corporate credit and creates INVOICE_SETTLEMENT ledger entry', async () => {
      const settled = await corporateService.settleCredit(
        'CORP-DRIVEGO',
        100000,
        'admin_fin_01',
        'book_corp_01',
      );

      expect(settled.usedCredit.toNumber()).toBe(250000);
      expect(mockCorpPrisma.corporateCreditLedgerEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            type: 'INVOICE_SETTLEMENT',
            amount: new Prisma.Decimal(100000),
          }),
        }),
      );
    });

    it('generates accurate billing statement with calculated netBilled and outstandingDue', async () => {
      const statement = await corporateService.getStatement('corp_acc_01');

      expect(statement.corporateAccount.corporateCode).toBe('CORP-DRIVEGO');
      expect(statement.summary.totalReserved).toBe(350000);
      expect(statement.summary.totalSettled).toBe(150000);
      expect(statement.summary.totalReleased).toBe(20000);
      expect(statement.summary.netBilled).toBe(330000); // 350000 - 20000
      expect(statement.summary.outstandingDue).toBe(350000);
      expect(statement.entries).toHaveLength(1);
    });
  });

  describe('4. Asynchronous Webhook Processor Integration', () => {
    let processor: WebhookProcessor;
    let mockQueueFactory: any;
    let mockModuleRef: any;

    beforeEach(() => {
      mockQueueFactory = {
        registerWorker: jest.fn(),
      };
      mockModuleRef = {
        get: jest.fn(),
      };
      processor = new WebhookProcessor(mockQueueFactory, mockPrisma, mockModuleRef);
    });

    it('routes payout_webhook jobs directly to payoutsService.handlePayoutWebhook', async () => {
      const mockPayouts = {
        handlePayoutWebhook: jest.fn().mockResolvedValue({ received: true, status: 'PAID' }),
      };
      mockModuleRef.get.mockReturnValue(mockPayouts);

      const job: any = {
        id: 'job_po_01',
        name: 'payout_webhook',
        data: {
          rawBody: JSON.stringify({ event: 'payout.processed' }),
          signature: 'mock_sig',
          headers: {},
        },
      };

      const res = await processor.process(job);

      expect(mockPayouts.handlePayoutWebhook).toHaveBeenCalledWith(
        job.data.rawBody,
        job.data.signature,
        job.data.headers,
      );
      expect(res.status).toBe('PAID');
    });

    it('routes payment_webhook jobs to paymentsService.handleWebhook', async () => {
      const mockPayments = {
        handleWebhook: jest.fn().mockResolvedValue({ received: true }),
      };
      mockModuleRef.get.mockReturnValue(mockPayments);

      const job: any = {
        id: 'job_pay_01',
        name: 'payment_webhook',
        data: {
          rawBody: JSON.stringify({ event: 'payment.captured' }),
          signature: 'mock_sig',
          headers: {},
        },
      };

      const res = await processor.process(job);

      expect(mockPayments.handleWebhook).toHaveBeenCalledWith(
        job.data.rawBody,
        job.data.signature,
        job.data.headers,
      );
      expect(res.received).toBe(true);
    });
  });

  describe('5. WhatsApp Provider Production Hardening', () => {
    it('fails fast with FAILED status and credential blocker in production if credentials missing', async () => {
      const oldEnv = process.env.NODE_ENV;
      process.env.NODE_ENV = 'production';

      try {
        const mockConfig = {
          get: jest.fn().mockReturnValue(''),
        };
        const provider = new MetaWhatsAppProvider(mockConfig as any);

        const result = await provider.sendMessage(
          '+919876543210',
          'booking_confirmation',
          'en',
          ['Car Model', 'Dates'],
        );

        expect(result.status).toBe('FAILED');
        expect(result.errorMessage).toContain('EXTERNAL CREDENTIAL BLOCKER');
      } finally {
        process.env.NODE_ENV = oldEnv;
      }
    });
  });
});

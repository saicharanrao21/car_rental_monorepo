import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { CheckoutOrchestratorService } from '../checkout-orchestrator.service';
import { MarketplaceQuoteService } from '../marketplace-quote.service';
import { AncillaryProductsService } from '../ancillary-products.service';
import { PaymentRoutingService } from '../../integrations/runtime/payment-routing.service';
import { IntegrationRuntimeService } from '../../integrations/runtime/integration-runtime.service';
import { VehicleAllocationService } from '../../fleet/vehicle-allocation.service';
import { LedgerCoreService } from '../../finance/ledger-core.service';
import {
  BookingStatus,
  CheckoutSessionStatus,
  PaymentStatus,
  SecurityDepositStatus,
  LedgerAccountType,
  LedgerEntrySide,
  Prisma,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('Phase P: Marketplace Checkout Financial Repair & Ledger Integrity (GAP-01)', () => {
  let checkoutOrchestrator: CheckoutOrchestratorService;
  let mockPrisma: any;
  let mockQuoteService: any;
  let mockAncillaryService: any;
  let mockPaymentRouting: any;
  let mockRuntimeService: any;
  let mockAllocationService: any;
  let mockLedgerService: any;

  let paymentsStore: any[] = [];
  let depositsStore: any[] = [];
  let bookingsStore: any[] = [];
  let holdsStore: any[] = [];
  let recordedJournals: any[] = [];

  const mockQuoteWithDeposit = {
    id: 'quote_with_deposit',
    quoteId: 'quote_with_deposit',
    tenantId: 'vendor_speedy',
    customerId: 'cust_alice',
    carId: 'car_honda_city',
    totalPayable: new Decimal(11800), // 8000 rent + 1000 fees + 800 tax + 2000 deposit
    currency: 'INR',
    feesTotal: new Decimal(1000),
    taxTotal: new Decimal(800),
    netToVendor: new Decimal(8000),
    depositTotal: new Decimal(2000),
    lineItems: [
      { type: 'BASE_RENTAL', name: 'Base Fare', amount: new Decimal(8000) },
      { type: 'PLATFORM_FEE', name: 'Service Fee', amount: new Decimal(1000) },
      { type: 'GST_TAX', name: 'GST 18%', amount: new Decimal(800) },
      { type: 'SECURITY_DEPOSIT', name: 'Refundable Deposit', amount: new Decimal(2000) },
    ],
    car: { pickupHubId: 'hub_blr_central', type: 'SEDAN' },
    expiresAt: new Date(Date.now() + 600000),
  };

  const mockQuoteWithoutDeposit = {
    id: 'quote_no_deposit',
    quoteId: 'quote_no_deposit',
    tenantId: 'vendor_speedy',
    customerId: 'cust_bob',
    carId: 'car_hyundai_i20',
    totalPayable: new Decimal(5900), // 4000 rent + 1000 fees + 900 tax + 0 deposit
    currency: 'INR',
    feesTotal: new Decimal(1000),
    taxTotal: new Decimal(900),
    netToVendor: new Decimal(4000),
    depositTotal: new Decimal(0),
    lineItems: [
      { type: 'BASE_RENTAL', name: 'Base Fare', amount: new Decimal(4000) },
      { type: 'PLATFORM_FEE', name: 'Service Fee', amount: new Decimal(1000) },
      { type: 'GST_TAX', name: 'GST 18%', amount: new Decimal(900) },
    ],
    car: { pickupHubId: 'hub_blr_central', type: 'HATCHBACK' },
    expiresAt: new Date(Date.now() + 600000),
  };

  beforeEach(async () => {
    paymentsStore = [];
    depositsStore = [];
    bookingsStore = [];
    holdsStore = [
      { id: 'hold_1', carId: 'car_honda_city', customerId: 'cust_alice', status: 'ACTIVE' },
    ];
    recordedJournals = [];

    mockPrisma = {
      checkoutSession: {
        findUnique: jest.fn().mockImplementation(async ({ where }) => {
          if (where.sessionId === 'session_with_deposit') {
            return {
              sessionId: 'session_with_deposit',
              customerId: 'cust_alice',
              status: CheckoutSessionStatus.QUOTE_LOCKED,
              selectedPaymentProvider: 'RAZORPAY',
              selectedPaymentMethod: 'UPI',
              quote: mockQuoteWithDeposit,
              driverDetails: { fullName: 'Alice Wonderland', phone: '+919999999999', licenseNumber: 'DL12345' },
              metadata: { activeOrderId: 'order_rzp_deposit_123' },
            };
          }
          if (where.sessionId === 'session_no_deposit') {
            return {
              sessionId: 'session_no_deposit',
              customerId: 'cust_bob',
              status: CheckoutSessionStatus.QUOTE_LOCKED,
              selectedPaymentProvider: 'RAZORPAY',
              selectedPaymentMethod: 'CARD',
              quote: mockQuoteWithoutDeposit,
              driverDetails: { fullName: 'Bob Builder', phone: '+918888888888', licenseNumber: 'DL67890' },
              metadata: { activeOrderId: 'order_rzp_nodeposit_456' },
            };
          }
          if (where.sessionId === 'session_already_confirmed') {
            return {
              sessionId: 'session_already_confirmed',
              customerId: 'cust_alice',
              status: CheckoutSessionStatus.CONFIRMED,
              bookingId: 'bk_already_confirmed',
              completedAt: new Date(),
              quote: mockQuoteWithDeposit,
            };
          }
          return null;
        }),
        update: jest.fn().mockImplementation(async ({ where, data }) => {
          return { ...data, sessionId: where.sessionId };
        }),
      },
      payment: {
        findFirst: jest.fn().mockImplementation(async ({ where }) => {
          return paymentsStore.find((p) => p.razorpayPaymentId === where.razorpayPaymentId) || null;
        }),
        create: jest.fn().mockImplementation(async ({ data }) => {
          const rec = { id: `pay_${Date.now()}_${Math.random()}`, ...data };
          paymentsStore.push(rec);
          return rec;
        }),
      },
      securityDeposit: {
        create: jest.fn().mockImplementation(async ({ data }) => {
          const dep = { id: `dep_${Date.now()}_${Math.random()}`, ...data };
          depositsStore.push(dep);
          return dep;
        }),
      },
      vehicleHold: {
        updateMany: jest.fn().mockImplementation(async ({ where, data }) => {
          let count = 0;
          for (const hold of holdsStore) {
            if (hold.carId === where.carId && hold.customerId === where.customerId && hold.status === where.status) {
              Object.assign(hold, data);
              count++;
            }
          }
          return { count };
        }),
      },
      bookingQuote: {
        update: jest.fn().mockResolvedValue({ id: 'quote_updated', status: 'ACCEPTED' }),
      },
      booking: {
        create: jest.fn().mockImplementation(async ({ data }) => {
          const bk = { id: `bk_${Date.now()}`, ...data };
          bookingsStore.push(bk);
          return bk;
        }),
        findUnique: jest.fn().mockImplementation(async ({ where }) => {
          return bookingsStore.find((b) => b.id === where.id) || null;
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      fulfillmentRecord: {
        upsert: jest.fn().mockResolvedValue({}),
      },
      $transaction: jest.fn().mockImplementation(async (callback) => {
        return callback(mockPrisma);
      }),
    };

    mockQuoteService = {
      getVerifiedQuote: jest.fn(),
    };

    mockAncillaryService = {};
    mockPaymentRouting = {};

    mockRuntimeService = {
      execute: jest.fn().mockResolvedValue({
        success: true,
        data: { verified: true },
      }),
    };

    mockAllocationService = {};

    mockLedgerService = {
      recordJournal: jest.fn().mockImplementation(async (input) => {
        recordedJournals.push(input);
        const lines = input.lines || [];
        return {
          journalId: `jnl_${Date.now()}`,
          entryCount: lines.length,
          totalDebits: lines.reduce((sum: number, e: any) => sum + (e.side === 'DEBIT' ? Number(e.amount) : 0), 0),
          totalCredits: lines.reduce((sum: number, e: any) => sum + (e.side === 'CREDIT' ? Number(e.amount) : 0), 0),
        };
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CheckoutOrchestratorService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: MarketplaceQuoteService, useValue: mockQuoteService },
        { provide: AncillaryProductsService, useValue: mockAncillaryService },
        { provide: PaymentRoutingService, useValue: mockPaymentRouting },
        { provide: IntegrationRuntimeService, useValue: mockRuntimeService },
        { provide: VehicleAllocationService, useValue: mockAllocationService },
        { provide: LedgerCoreService, useValue: mockLedgerService },
      ],
    }).compile();

    checkoutOrchestrator = module.get<CheckoutOrchestratorService>(CheckoutOrchestratorService);
  });

  describe('Financial Repair: Payment & Deposit Persistence', () => {
    it('should persist Payment record with PAID status and SecurityDeposit with HELD status when depositTotal > 0', async () => {
      const result = await checkoutOrchestrator.verifyAndConfirmPayment(
        'session_with_deposit',
        'cust_alice',
        {
          orderId: 'order_rzp_deposit_123',
          paymentId: 'pay_rzp_successful_101',
          signature: 'sig_valid_hash',
        },
      );

      expect(result.bookingStatus).toBe(BookingStatus.CONFIRMED);
      expect(result.totalPaid).toBe(11800);

      // Verify Payment record
      expect(paymentsStore).toHaveLength(1);
      const payment = paymentsStore[0];
      expect(payment.status).toBe(PaymentStatus.PAID);
      expect(payment.razorpayPaymentId).toBe('pay_rzp_successful_101');
      expect(payment.gatewayAmountPaise).toBe(1180000);
      expect(payment.bookingId).toBe(result.bookingId);

      // Verify SecurityDeposit record
      expect(depositsStore).toHaveLength(1);
      const deposit = depositsStore[0];
      expect(deposit.status).toBe(SecurityDepositStatus.HELD);
      expect(deposit.amount.toNumber()).toBe(2000);
      expect(deposit.bookingId).toBe(result.bookingId);
      expect(deposit.razorpayPaymentId).toBe('pay_rzp_successful_101');

      // Verify VehicleHold transitioned to CONVERTED
      const hold = holdsStore.find((h) => h.carId === 'car_honda_city');
      expect(hold.status).toBe('CONVERTED');
    });

    it('should NOT create SecurityDeposit when depositTotal is 0', async () => {
      const result = await checkoutOrchestrator.verifyAndConfirmPayment(
        'session_no_deposit',
        'cust_bob',
        {
          orderId: 'order_rzp_nodeposit_456',
          paymentId: 'pay_rzp_successful_102',
          signature: 'sig_valid_hash_2',
        },
      );

      expect(result.bookingStatus).toBe(BookingStatus.CONFIRMED);
      expect(paymentsStore).toHaveLength(1);
      expect(depositsStore).toHaveLength(0);
    });
  });

  describe('LedgerCore Integration & Zero-Sum Invariant', () => {
    it('should write a balanced double-entry journal with debits equaling credits exactly', async () => {
      await checkoutOrchestrator.verifyAndConfirmPayment(
        'session_with_deposit',
        'cust_alice',
        {
          orderId: 'order_rzp_deposit_123',
          paymentId: 'pay_rzp_successful_101',
          signature: 'sig_valid_hash',
        },
      );

      expect(recordedJournals).toHaveLength(1);
      const journal = recordedJournals[0];

      let debits = 0;
      let credits = 0;
      for (const entry of journal.lines) {
        if (entry.side === LedgerEntrySide.DEBIT) {
          debits += Number(entry.amount);
        } else if (entry.side === LedgerEntrySide.CREDIT) {
          credits += Number(entry.amount);
        }
      }

      // Exact mathematical balance invariant
      expect(debits).toBe(11800);
      expect(credits).toBe(11800);
      expect(debits).toBe(credits);

      // Verify account mappings
      const clearingDebit = journal.lines.find((e: any) => e.accountType === LedgerAccountType.GATEWAY_CLEARING);
      expect(clearingDebit).toBeDefined();
      expect(clearingDebit.side).toBe(LedgerEntrySide.DEBIT);
      expect(clearingDebit.amount.toNumber()).toBe(11800);

      const vendorCredit = journal.lines.find((e: any) => e.accountType === LedgerAccountType.VENDOR_PAYABLE);
      expect(vendorCredit).toBeDefined();
      expect(vendorCredit.amount.toNumber()).toBe(8000);

      const depositCredit = journal.lines.find((e: any) => e.accountType === LedgerAccountType.CUSTOMER_DEPOSIT_ESCROW);
      expect(depositCredit).toBeDefined();
      expect(depositCredit.amount.toNumber()).toBe(2000);
    });
  });

  describe('Idempotency Enforcement', () => {
    it('should return confirmed session immediately without creating duplicate payments or journals on retry', async () => {
      const result = await checkoutOrchestrator.verifyAndConfirmPayment(
        'session_already_confirmed',
        'cust_alice',
        {
          orderId: 'order_rzp_prev_999',
          paymentId: 'pay_rzp_prev_999',
          signature: 'sig_prev',
        },
      );

      expect(result.bookingStatus).toBe(BookingStatus.CONFIRMED);
      expect(result.bookingId).toBe('bk_already_confirmed');
      expect(paymentsStore).toHaveLength(0);
      expect(depositsStore).toHaveLength(0);
      expect(recordedJournals).toHaveLength(0);
    });
  });
});

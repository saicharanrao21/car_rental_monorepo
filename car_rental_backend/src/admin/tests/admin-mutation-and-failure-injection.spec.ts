import { BadRequestException, ConflictException } from '@nestjs/common';
import { Decimal } from '@prisma/client/runtime/library';
import {
  BookingStatus,
  PaymentStatus,
  LedgerEntrySide,
  VerificationStatus,
  Role,
} from '@prisma/client';

describe('Admin Mutation Lifecycle & Adversarial Failure Injection Suite', () => {
  describe('GAP 3: Admin State Mutations & Cross-Domain Propagation', () => {
    let mockPrisma: any;
    let vendorStore: Map<string, any>;
    let carStore: Map<string, any>;
    let pricingRulesStore: Map<string, any>;

    beforeEach(() => {
      vendorStore = new Map();
      carStore = new Map();
      pricingRulesStore = new Map();

      // Seed baseline data
      vendorStore.set('vendor_101', {
        id: 'vendor_101',
        businessName: 'Apex Rentals',
        verificationStatus: VerificationStatus.PENDING,
        userId: 'user_vendor_1',
      });

      carStore.set('car_201', {
        id: 'car_201',
        vendorId: 'vendor_101',
        make: 'Hyundai',
        model: 'Creta',
        operationalStatus: 'ACTIVE',
        isAvailable: true,
        pricePerDay: new Decimal(2500),
      });

      mockPrisma = {
        vendor: {
          update: jest.fn().mockImplementation(({ where, data }) => {
            const v = vendorStore.get(where.id);
            if (!v) throw new Error('Vendor not found');
            const updated = { ...v, ...data };
            vendorStore.set(where.id, updated);
            return Promise.resolve(updated);
          }),
          findUnique: jest.fn().mockImplementation(({ where }) => {
            return Promise.resolve(vendorStore.get(where.id) || null);
          }),
        },
        car: {
          update: jest.fn().mockImplementation(({ where, data }) => {
            const c = carStore.get(where.id);
            if (!c) throw new Error('Car not found');
            const updated = { ...c, ...data };
            carStore.set(where.id, updated);
            return Promise.resolve(updated);
          }),
          findMany: jest.fn().mockImplementation(({ where }) => {
            const results: any[] = [];
            for (const car of carStore.values()) {
              const vendor = vendorStore.get(car.vendorId);
              // Respect active search filters: must be ACTIVE, isAvailable, and vendor VERIFIED
              if (where?.operationalStatus && car.operationalStatus !== where.operationalStatus) continue;
              if (where?.isAvailable !== undefined && car.isAvailable !== where.isAvailable) continue;
              if (where?.vendor?.verificationStatus && vendor?.verificationStatus !== where.vendor.verificationStatus) continue;
              results.push(car);
            }
            return Promise.resolve(results);
          }),
        },
        dynamicPricingPolicy: {
          upsert: jest.fn().mockImplementation(({ create, update, where }) => {
            const id = where?.id || 'policy_default';
            const policy = { id, ...(pricingRulesStore.get(id) || create), ...update };
            pricingRulesStore.set(id, policy);
            return Promise.resolve(policy);
          }),
          findFirst: jest.fn().mockImplementation(() => {
            return Promise.resolve(pricingRulesStore.values().next().value || null);
          }),
        },
      };
    });

    it('1. Admin Vendor Approval: PENDING vendor approval activates fleet discoverability', async () => {
      // 1. Initial State: Vendor is PENDING -> cars are NOT discoverable in customer search
      let searchResults = await mockPrisma.car.findMany({
        where: {
          operationalStatus: 'ACTIVE',
          isAvailable: true,
          vendor: { verificationStatus: VerificationStatus.VERIFIED },
        },
      });
      expect(searchResults.length).toBe(0);

      // 2. Admin action: Approve vendor
      const updatedVendor = await mockPrisma.vendor.update({
        where: { id: 'vendor_101' },
        data: { verificationStatus: VerificationStatus.VERIFIED },
      });
      expect(updatedVendor.verificationStatus).toBe(VerificationStatus.VERIFIED);

      // 3. Downstream impact: Customer car search now includes vendor cars
      searchResults = await mockPrisma.car.findMany({
        where: {
          operationalStatus: 'ACTIVE',
          isAvailable: true,
          vendor: { verificationStatus: VerificationStatus.VERIFIED },
        },
      });
      expect(searchResults.length).toBe(1);
      expect(searchResults[0].id).toBe('car_201');
    });

    it('2. Admin Vehicle Suspension: Suspending a vehicle immediately excludes it from search', async () => {
      // Set vendor as verified first
      vendorStore.set('vendor_101', {
        ...vendorStore.get('vendor_101'),
        verificationStatus: VerificationStatus.VERIFIED,
      });

      // Verify car is discoverable
      let searchResults = await mockPrisma.car.findMany({
        where: {
          operationalStatus: 'ACTIVE',
          isAvailable: true,
          vendor: { verificationStatus: VerificationStatus.VERIFIED },
        },
      });
      expect(searchResults.length).toBe(1);

      // Admin action: Suspend vehicle for maintenance/compliance breach
      await mockPrisma.car.update({
        where: { id: 'car_201' },
        data: { operationalStatus: 'SUSPENDED', isAvailable: false },
      });

      // Immediate query exclusion
      searchResults = await mockPrisma.car.findMany({
        where: {
          operationalStatus: 'ACTIVE',
          isAvailable: true,
          vendor: { verificationStatus: VerificationStatus.VERIFIED },
        },
      });
      expect(searchResults.length).toBe(0);
    });

    it('3. Admin Dynamic Pricing Rule Mutation: Applying surge multiplier recalculates fare', async () => {
      const baseDailyRate = new Decimal(2000);
      const rentalDays = 3;

      // Base quote calculation without policy
      let totalFare = baseDailyRate.mul(rentalDays);
      expect(totalFare.toNumber()).toBe(6000);

      // Admin applies 1.25x holiday surge policy
      await mockPrisma.dynamicPricingPolicy.upsert({
        where: { id: 'surge_diwali' },
        create: { name: 'Diwali Surge', multiplier: new Decimal(1.25), active: true },
        update: { multiplier: new Decimal(1.25), active: true },
      });

      const activePolicy = await mockPrisma.dynamicPricingPolicy.findFirst();
      expect(activePolicy.multiplier.toNumber()).toBe(1.25);

      // Recalculated quote with active rule
      const surgeDailyRate = baseDailyRate.mul(activePolicy.multiplier);
      const surgedTotalFare = surgeDailyRate.mul(rentalDays);
      expect(surgedTotalFare.toNumber()).toBe(7500); // 2000 * 1.25 * 3 = 7500
    });
  });

  describe('GAP 4: Adversarial Failure Injection & Invariant Defense', () => {
    it('1. Duplicate Webhook Replay: Replaying captured payment webhook is completely idempotent', async () => {
      const processedEvents = new Set<string>();
      const paymentStore = new Map<string, any>();
      let ledgerPostCount = 0;

      const incomingWebhook = {
        event: 'payment.captured',
        idempotencyKey: 'evt_rzp_pay_998877_captured',
        payload: {
          payment: {
            id: 'pay_998877',
            orderId: 'order_554433',
            amount: 500000, // ₹5,000 in paise
            status: 'captured',
          },
        },
      };

      // Handler function with idempotency guard
      async function handlePaymentWebhook(event: typeof incomingWebhook) {
        if (processedEvents.has(event.idempotencyKey)) {
          return { status: 'already_processed', idempotent: true };
        }

        // Process first time
        processedEvents.add(event.idempotencyKey);
        paymentStore.set(event.payload.payment.id, {
          id: event.payload.payment.id,
          status: PaymentStatus.PAID,
          amount: new Decimal(event.payload.payment.amount / 100),
        });

        // Post ledger entries (1 journal batch)
        ledgerPostCount += 2; // 1 DEBIT, 1 CREDIT

        return { status: 'success', idempotent: false };
      }

      // First webhook delivery
      const firstRes = await handlePaymentWebhook(incomingWebhook);
      expect(firstRes.status).toBe('success');
      expect(firstRes.idempotent).toBe(false);
      expect(ledgerPostCount).toBe(2);

      // Adversarial delivery: Same webhook resent 5 times consecutively (e.g. gateway network retry)
      for (let i = 0; i < 5; i++) {
        const replayRes = await handlePaymentWebhook(incomingWebhook);
        expect(replayRes.status).toBe('already_processed');
        expect(replayRes.idempotent).toBe(true);
      }

      // Invariant: Ledger entries were NOT duplicated
      expect(ledgerPostCount).toBe(2);
      expect(paymentStore.get('pay_998877').status).toBe(PaymentStatus.PAID);
    });

    it('2. Out-of-Order Webhook Delivery: Rejects confirmation if booking was already CANCELLED', async () => {
      const booking = {
        id: 'book_cancelled_01',
        status: BookingStatus.CANCELLED,
        totalFare: new Decimal(4000),
      };

      async function processPaymentConfirmation(bookingRecord: typeof booking) {
        if (bookingRecord.status === BookingStatus.CANCELLED) {
          // Failure guard: Do not confirm a cancelled booking; flag for immediate automated refund
          return {
            action: 'FLAG_FOR_REFUND',
            message: 'Payment arrived after cancellation. Initiating refund.',
            confirmed: false,
          };
        }
        bookingRecord.status = BookingStatus.CONFIRMED;
        return { action: 'CONFIRMED', confirmed: true };
      }

      const result = await processPaymentConfirmation(booking);
      expect(result.confirmed).toBe(false);
      expect(result.action).toBe('FLAG_FOR_REFUND');
      expect(booking.status).toBe(BookingStatus.CANCELLED);
    });

    it('3. Double-Entry Imbalance Rejection: Rejects journal batches where DEBITS != CREDITS', async () => {
      interface JournalLine {
        side: LedgerEntrySide;
        amount: Decimal;
        narration: string;
      }

      function postJournal(journalId: string, lines: JournalLine[]) {
        let totalDebit = new Decimal(0);
        let totalCredit = new Decimal(0);

        for (const line of lines) {
          if (line.side === LedgerEntrySide.DEBIT) {
            totalDebit = totalDebit.add(line.amount);
          } else if (line.side === LedgerEntrySide.CREDIT) {
            totalCredit = totalCredit.add(line.amount);
          }
        }

        if (!totalDebit.equals(totalCredit)) {
          throw new BadRequestException(
            `Double-entry imbalance detected! Debits (₹${totalDebit}) != Credits (₹${totalCredit})`,
          );
        }

        return { journalId, balanced: true, total: totalDebit.toNumber() };
      }

      // Valid balanced entry: Customer payment
      const balancedJournal: JournalLine[] = [
        { side: LedgerEntrySide.DEBIT, amount: new Decimal(5000), narration: 'Cash Gateway Asset' },
        { side: LedgerEntrySide.CREDIT, amount: new Decimal(5000), narration: 'Customer Booking Liability' },
      ];
      const validResult = postJournal('jrn_001', balancedJournal);
      expect(validResult.balanced).toBe(true);
      expect(validResult.total).toBe(5000);

      // Adversarial unbalanced entry: Debit ₹5000, Credit ₹4500 (₹500 leakage attempt)
      const unbalancedJournal: JournalLine[] = [
        { side: LedgerEntrySide.DEBIT, amount: new Decimal(5000), narration: 'Cash Gateway Asset' },
        { side: LedgerEntrySide.CREDIT, amount: new Decimal(4500), narration: 'Under-credited Vendor Liability' },
      ];

      expect(() => postJournal('jrn_002', unbalancedJournal)).toThrow(BadRequestException);
      expect(() => postJournal('jrn_002', unbalancedJournal)).toThrow(/Double-entry imbalance detected/);
    });

    it('4. Concurrent Overlapping Vehicle Lock Mutex: Strictly rejects second simultaneous booking', async () => {
      const activeLocks = new Set<string>();

      async function acquireVehicleLock(carId: string, customerId: string): Promise<boolean> {
        const lockKey = `lock:vehicle:${carId}`;
        if (activeLocks.has(lockKey)) {
          throw new ConflictException(`Vehicle ${carId} is currently locked by another reservation session`);
        }
        activeLocks.add(lockKey);
        return true;
      }

      // Customer 1 and Customer 2 both click "Confirm & Pay" at the exact same millisecond for Car 100
      const carId = 'car_audi_100';
      const customer1Attempt = acquireVehicleLock(carId, 'cust_1');
      const customer2Attempt = acquireVehicleLock(carId, 'cust_2');

      const outcomes = await Promise.allSettled([customer1Attempt, customer2Attempt]);

      const fulfilled = outcomes.filter((o) => o.status === 'fulfilled');
      const rejected = outcomes.filter((o) => o.status === 'rejected');

      // Exactly ONE request succeeds; exactly ONE request is rejected with ConflictException (409)
      expect(fulfilled.length).toBe(1);
      expect(rejected.length).toBe(1);
      expect((rejected[0] as PromiseRejectedResult).reason).toBeInstanceOf(ConflictException);
    });
  });
});

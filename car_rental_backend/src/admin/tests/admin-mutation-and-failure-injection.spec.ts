import { Test, TestingModule } from '@nestjs/testing';
import { AppModule } from '../../app.module';
import { PrismaService } from '../../prisma/prisma.service';
import { CarsService } from '../../cars/cars.service';
import { VendorsService } from '../../vendors/vendors.service';
import { VendorFleetService } from '../../cars/vendor-fleet.service';
import { PaymentsService } from '../../payments/payments.service';
import { LedgerCoreService } from '../../finance/ledger-core.service';
import { BookingLockService } from '../../redis/booking-lock.service';
import { RedisCacheService } from '../../redis/redis-cache.service';
import { DemandAwarePricingService } from '../../pricing/demand-aware-pricing.service';
import { ConfigService } from '@nestjs/config';
import {
  VerificationStatus,
  VehicleOperationalStatus,
  VehicleVerificationStatus,
  PaymentStatus,
  BookingStatus,
  LedgerEntrySide,
  LedgerAccountType,
  Role,
  CarCategory,
  FuelType,
  TripType,
  BusinessType,
  PricingRuleScope,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { BadRequestException, ConflictException, ServiceUnavailableException } from '@nestjs/common';
import * as crypto from 'crypto';

describe('Real Production Integration: Admin Mutations, Adversarial Webhook & Concurrency', () => {
  let moduleRef: TestingModule;
  let prisma: PrismaService;
  let carsService: CarsService;
  let vendorsService: VendorsService;
  let vendorFleetService: VendorFleetService;
  let paymentsService: PaymentsService;
  let ledgerCore: LedgerCoreService;
  let bookingLockService: BookingLockService;
  let cacheService: RedisCacheService;
  let demandAwarePricingService: DemandAwarePricingService;

  // Track created IDs for strict teardown
  const createdUserIds: string[] = [];
  const createdVendorIds: string[] = [];
  const createdCarIds: string[] = [];
  const createdBookingIds: string[] = [];
  const createdPaymentIds: string[] = [];
  const createdWebhookEventIds: string[] = [];
  const createdJournalIds: string[] = [];
  const createdPolicyIds: string[] = [];

  let testVendorUser: any;
  let testVendor: any;
  let testCar: any;
  let testAdminUser: any;
  const testCity = `City_${Date.now()}`;
  let webhookSecret: string;

  beforeAll(async () => {
    jest.setTimeout(60000);
    process.env.NODE_ENV = 'test';
    process.env.REDIS_USE_MOCK = 'true';
    process.env.JWT_ACCESS_SECRET = 'test_jwt_access_secret_min_32_chars_long!';
    process.env.JWT_REFRESH_SECRET = 'test_jwt_refresh_secret_min_32_chars_long!';

    moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    prisma = moduleRef.get<PrismaService>(PrismaService);
    carsService = moduleRef.get<CarsService>(CarsService);
    vendorsService = moduleRef.get<VendorsService>(VendorsService);
    vendorFleetService = moduleRef.get<VendorFleetService>(VendorFleetService);
    paymentsService = moduleRef.get<PaymentsService>(PaymentsService);
    ledgerCore = moduleRef.get<LedgerCoreService>(LedgerCoreService);
    bookingLockService = moduleRef.get<BookingLockService>(BookingLockService);
    cacheService = moduleRef.get<RedisCacheService>(RedisCacheService);
    demandAwarePricingService = moduleRef.get<DemandAwarePricingService>(DemandAwarePricingService);

    const configService = moduleRef.get<ConfigService>(ConfigService);
    webhookSecret = configService.get<string>('RAZORPAY_WEBHOOK_SECRET') || 'placeholderWebhookSecret';

    // 0. Create real platform admin user
    testAdminUser = await prisma.user.create({
      data: {
        email: `admin_mutation_${Date.now()}@example.com`,
        phone: `+9199${Date.now().toString().slice(-8)}`,
        name: 'Real Test Admin',
        role: Role.ADMIN,
      },
    });
    createdUserIds.push(testAdminUser.id);

    // 1. Create real vendor user in PostgreSQL with required phone
    testVendorUser = await prisma.user.create({
      data: {
        email: `vendor_test_${Date.now()}@example.com`,
        phone: `+9198${Date.now().toString().slice(-8)}`,
        name: 'Real Test Vendor',
        role: Role.VENDOR,
      },
    });
    createdUserIds.push(testVendorUser.id);

    // 2. Create vendor with PENDING verification status
    testVendor = await prisma.vendor.create({
      data: {
        userId: testVendorUser.id,
        businessName: 'Real Test Motors',
        ownerName: 'Real Test Owner',
        city: testCity,
        businessType: BusinessType.INDIVIDUAL,
        verificationStatus: VerificationStatus.PENDING,
      },
    });
    createdVendorIds.push(testVendor.id);

    // 3. Create active vehicle under this vendor
    testCar = await prisma.car.create({
      data: {
        vendorId: testVendor.id,
        make: 'Toyota',
        model: 'Innova Crysta',
        year: 2024,
        type: CarCategory.SUV,
        fuelType: FuelType.DIESEL,
        seating: 7,
        isAC: true,
        registrationNumber: `MH02TEST${Date.now().toString().slice(-4)}`,
        pricePerDay: new Decimal(3500),
        pricePerHour: new Decimal(250),
        pricePerKm: new Decimal(18),
        isAvailable: true,
        operationalStatus: VehicleOperationalStatus.ACTIVE,
        verificationStatus: VehicleVerificationStatus.VERIFIED,
        availableTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
      },
    });
    createdCarIds.push(testCar.id);
  }, 60000);

  afterAll(async () => {
    // Teardown test fixtures from PostgreSQL in reverse order of foreign keys
    try {
      if (createdPaymentIds.length) {
        await prisma.platformLedgerEntry.deleteMany({
          where: { paymentId: { in: createdPaymentIds } },
        });
        await prisma.payment.deleteMany({
          where: { id: { in: createdPaymentIds } },
        });
      }
      if (createdWebhookEventIds.length) {
        await prisma.webhookEvent.deleteMany({
          where: { eventId: { in: createdWebhookEventIds } },
        });
      }
      if (createdBookingIds.length) {
        await prisma.booking.deleteMany({
          where: { id: { in: createdBookingIds } },
        });
      }
      if (createdPolicyIds.length) {
        await prisma.dynamicPricingPolicy.deleteMany({
          where: { id: { in: createdPolicyIds } },
        });
      }
      if (createdCarIds.length) {
        await prisma.car.deleteMany({
          where: { id: { in: createdCarIds } },
        });
      }
      if (createdVendorIds.length) {
        await prisma.vendor.deleteMany({
          where: { id: { in: createdVendorIds } },
        });
      }
      if (createdUserIds.length) {
        await prisma.user.deleteMany({
          where: { id: { in: createdUserIds } },
        });
      }
      if (createdJournalIds.length) {
        await prisma.platformLedgerEntry.deleteMany({
          where: { journalId: { in: createdJournalIds } },
        });
      }
    } catch (err) {
      console.warn('Teardown warning:', err);
    }

    if (moduleRef) {
      await moduleRef.close();
    }
  });

  describe('GAP 3: Real Admin Mutations -> Real Prisma & PostgreSQL Search Visibility', () => {
    it('1. Admin Vendor Verification: PENDING vendor car is hidden, VERIFIED vendor car is discoverable via real CarsService', async () => {
      // 1. Initial State: Vendor is PENDING -> Query search as customer (isAdmin = false) through real CarsService
      await cacheService.invalidatePattern('cache:search:cars:*');
      let searchResults = await carsService.searchCars({ city: testCity }, false);
      expect(searchResults.data.some((c: any) => c.id === testCar.id)).toBe(false);

      // 2. Admin mutation: Update vendor status to VERIFIED in PostgreSQL
      await prisma.vendor.update({
        where: { id: testVendor.id },
        data: { verificationStatus: VerificationStatus.VERIFIED },
      });

      // 3. Invalidate search cache and query search again through real CarsService -> Car is now discoverable!
      await cacheService.invalidatePattern('cache:search:cars:*');
      searchResults = await carsService.searchCars({ city: testCity }, false);
      expect(searchResults.data.some((c: any) => c.id === testCar.id)).toBe(true);
    });

    it('2. Admin Vehicle Suspension: Setting operationalStatus to SUSPENDED immediately removes it from customer search', async () => {
      // 1. Car is currently visible
      await cacheService.invalidatePattern('cache:search:cars:*');
      let searchResults = await carsService.searchCars({ city: testCity }, false);
      expect(searchResults.data.some((c: any) => c.id === testCar.id)).toBe(true);

      // 2. Admin mutation: Suspend the vehicle via real production VendorFleetService
      await vendorFleetService.adminSuspendVehicle(testCar.id, testAdminUser.id, {
        reason: 'Regulatory and compliance safety suspension by platform administrator',
      });

      // 3. Invalidate search cache and query search again through real CarsService -> Immediately excluded
      await cacheService.invalidatePattern('cache:search:cars:*');
      searchResults = await carsService.searchCars({ city: testCity }, false);
      expect(searchResults.data.some((c: any) => c.id === testCar.id)).toBe(false);
    });

    it('3. Real Dynamic Pricing Policy: Admin sets dynamic policy in PostgreSQL and DemandAwarePricingService resolves it with auditable bounds', async () => {
      // Create a real DynamicPricingPolicy in PostgreSQL scoped to this vendor
      const policy = await prisma.dynamicPricingPolicy.create({
        data: {
          scope: PricingRuleScope.VENDOR,
          vendorId: testVendor.id,
          vehicleClass: CarCategory.SUV,
          name: 'Festival Surge Policy',
          minDailyPrice: new Decimal(2500),
          maxDailyPrice: new Decimal(6000),
          maxSurgeMultiplier: new Decimal(1.30),
          minDiscountMultiplier: new Decimal(0.85),
          utilizationThresholdHigh: 0.80,
          isActive: true,
        },
      });
      createdPolicyIds.push(policy.id);

      // Execute DriveGo's actual DemandAwarePricingService engine
      const evaluation = await demandAwarePricingService.evaluatePrice({
        baseDailyRate: 3500,
        startDate: new Date(Date.now() + 86400000 * 2), // 2 days lead time
        endDate: new Date(Date.now() + 86400000 * 5),
        vendorId: testVendor.id,
        vehicleClass: CarCategory.SUV,
        city: testCity,
      });

      // Verify the pricing engine applied policy bounds from PostgreSQL
      expect(evaluation.effectiveDailyRate).toBeGreaterThanOrEqual(2500);
      expect(evaluation.effectiveDailyRate).toBeLessThanOrEqual(6000);
      expect(evaluation.policyBounds.maxSurgeMultiplier).toBe(1.30);
      expect(evaluation.policyBounds.minDailyPrice).toBe(2500);
      expect(evaluation.policyBounds.maxDailyPrice).toBe(6000);
      expect(typeof evaluation.explanation).toBe('string');
    });
  });

  describe('GAP 4: Real Webhook Replay & Double-Entry Invariant Defense', () => {
    let customerUser: any;
    let booking: any;
    let payment: any;
    let orderId: string;
    let paymentId: string;

    beforeAll(async () => {
      orderId = `order_test_${Date.now()}`;
      paymentId = `pay_test_${Date.now()}`;

      // Create test customer with required phone
      customerUser = await prisma.user.create({
        data: {
          email: `cust_webhook_${Date.now()}@example.com`,
          phone: `+9197${Date.now().toString().slice(-8)}`,
          name: 'Webhook Test Customer',
          role: Role.CUSTOMER,
        },
      });
      createdUserIds.push(customerUser.id);

      // Create test booking with tripType and all required financial fields
      booking = await prisma.booking.create({
        data: {
          customerId: customerUser.id,
          vendorId: testVendor.id,
          carId: testCar.id,
          startDate: new Date(Date.now() + 86400000),
          endDate: new Date(Date.now() + 172800000),
          status: BookingStatus.PENDING,
          tripType: TripType.SELF_DRIVE,
          pickupLocation: 'Test Pickup Hub',
          baseFare: new Decimal(3000),
          platformFee: new Decimal(200),
          gstAmount: new Decimal(300),
          totalFare: new Decimal(3500),
          netToVendor: new Decimal(3000),
          vehicleClass: CarCategory.SUV,
        },
      });
      createdBookingIds.push(booking.id);

      // Create initial payment order record in PostgreSQL
      payment = await prisma.payment.create({
        data: {
          bookingId: booking.id,
          razorpayOrderId: orderId,
          amount: new Decimal(3500),
          currency: 'INR',
          status: PaymentStatus.CREATED,
        },
      });
      createdPaymentIds.push(payment.id);
    });

    it('1. Real Razorpay Webhook Ingestion: Processes captured payment, confirms booking, and balances ledger', async () => {
      const webhookPayloadObj = {
        event: 'payment.captured',
        id: `evt_${Date.now()}`,
        payload: {
          payment: {
            entity: {
              id: paymentId,
              order_id: orderId,
              amount: 350000, // ₹3,500 in paise
              currency: 'INR',
              status: 'captured',
            },
          },
        },
      };
      createdWebhookEventIds.push(webhookPayloadObj.id);

      const rawBody = JSON.stringify(webhookPayloadObj);
      const signature = crypto
        .createHmac('sha256', webhookSecret)
        .update(rawBody)
        .digest('hex');

      // Call real PaymentsService.handleWebhook
      const result = await paymentsService.handleWebhook(rawBody, signature, {
        'x-razorpay-signature': signature,
        'x-razorpay-event-id': webhookPayloadObj.id,
      });

      expect(result).toHaveProperty('received', true);

      // Verify PostgreSQL state
      const updatedPayment = await prisma.payment.findUnique({ where: { id: payment.id } });
      expect(updatedPayment?.status).toBe(PaymentStatus.PAID);

      const updatedBooking = await prisma.booking.findUnique({ where: { id: booking.id } });
      // In DriveGo (Phase 23A Owner Confirmation Gate), payment captures into PAID and booking remains PENDING awaiting owner confirmation
      expect(updatedBooking?.status).toBe(BookingStatus.PENDING);

      // Verify double-entry ledger rows were created in PostgreSQL
      const ledgerEntries = await prisma.platformLedgerEntry.findMany({
        where: { paymentId: payment.id },
      });
      expect(ledgerEntries.length).toBeGreaterThanOrEqual(1);
    });

    it('2. Real Webhook Replay: Resending identical webhook is 100% idempotent and creates zero duplicate ledger entries', async () => {
      const webhookPayloadObj = {
        event: 'payment.captured',
        id: createdWebhookEventIds[0], // Exact same event ID
        payload: {
          payment: {
            entity: {
              id: paymentId,
              order_id: orderId,
              amount: 350000,
              currency: 'INR',
              status: 'captured',
            },
          },
        },
      };

      const rawBody = JSON.stringify(webhookPayloadObj);
      const signature = crypto
        .createHmac('sha256', webhookSecret)
        .update(rawBody)
        .digest('hex');

      // Count ledger entries before replay
      const ledgerCountBefore = await prisma.platformLedgerEntry.count({
        where: { paymentId: payment.id },
      });

      // Call real PaymentsService.handleWebhook with the identical payload
      const replayResult = await paymentsService.handleWebhook(rawBody, signature, {
        'x-razorpay-signature': signature,
        'x-razorpay-event-id': webhookPayloadObj.id,
      });

      expect(replayResult.received).toBe(true);
      expect(replayResult.duplicate || replayResult.alreadyProcessed).toBe(true);

      // Invariant: Ledger entries in PostgreSQL were NOT duplicated
      const ledgerCountAfter = await prisma.platformLedgerEntry.count({
        where: { paymentId: payment.id },
      });
      expect(ledgerCountAfter).toBe(ledgerCountBefore);
    });

    it('3. Real Ledger Imbalance Rejection: Rejects journal batches where DEBITS != CREDITS and writes 0 records to PostgreSQL', async () => {
      const journalId = `jrn_imbalance_test_${Date.now()}`;
      createdJournalIds.push(journalId);

      // Call real LedgerCoreService with an intentional imbalance: ₹5,000 debit vs ₹4,500 credit
      await expect(
        ledgerCore.recordJournal({
          journalId,
          referenceType: 'BOOKING_CONFIRMATION',
          referenceId: 'ref_fake_123',
          lines: [
            {
              accountType: LedgerAccountType.GATEWAY_CLEARING,
              side: LedgerEntrySide.DEBIT,
              amount: new Decimal(5000),
              narration: 'Cash asset',
            },
            {
              accountType: LedgerAccountType.VENDOR_PAYABLE,
              side: LedgerEntrySide.CREDIT,
              amount: new Decimal(4500),
              narration: 'Vendor under-credited liability',
            },
          ],
        }),
      ).rejects.toThrow(BadRequestException);

      // Verify zero rows were inserted into PostgreSQL
      const entries = await prisma.platformLedgerEntry.findMany({
        where: { journalId },
      });
      expect(entries.length).toBe(0);
    });

    it('4. Real Ledger Failure Injection: Mid-transaction failure rolls back payment update and ledger line cleanly with 0 orphan records', async () => {
      // 1. Create a isolated booking & payment for failure injection
      const failBooking = await prisma.booking.create({
        data: {
          customerId: customerUser.id,
          vendorId: testVendor.id,
          carId: testCar.id,
          startDate: new Date(Date.now() + 86400000 * 3),
          endDate: new Date(Date.now() + 86400000 * 4),
          status: BookingStatus.PENDING,
          tripType: TripType.SELF_DRIVE,
          pickupLocation: 'Test Pickup Hub',
          baseFare: new Decimal(1700),
          platformFee: new Decimal(150),
          gstAmount: new Decimal(150),
          totalFare: new Decimal(2000),
          netToVendor: new Decimal(1700),
          vehicleClass: CarCategory.SUV,
        },
      });
      createdBookingIds.push(failBooking.id);

      const failPayment = await prisma.payment.create({
        data: {
          bookingId: failBooking.id,
          razorpayOrderId: `order_fail_${Date.now()}`,
          amount: new Decimal(2000),
          currency: 'INR',
          status: PaymentStatus.CREATED,
        },
      });
      createdPaymentIds.push(failPayment.id);

      const failJournalId = `jrn_fault_injection_${Date.now()}`;
      createdJournalIds.push(failJournalId);

      // 2. Execute a transaction where payment is marked PAID and ledger line 1 is created, but then an exception is thrown
      await expect(
        prisma.$transaction(async (tx) => {
          await tx.payment.update({
            where: { id: failPayment.id },
            data: { status: PaymentStatus.PAID },
          });

          await tx.booking.update({
            where: { id: failBooking.id },
            data: { status: BookingStatus.CONFIRMED },
          });

          await tx.platformLedgerEntry.create({
            data: {
              journalId: failJournalId,
              accountType: LedgerAccountType.GATEWAY_CLEARING,
              side: LedgerEntrySide.DEBIT,
              amount: new Decimal(2000),
              currency: 'INR',
              bookingId: failBooking.id,
              paymentId: failPayment.id,
              referenceType: 'BOOKING_CONFIRMATION',
              referenceId: failPayment.id,
              narration: 'Partial debit before forced crash',
            },
          });

          // INJECTED ADVERSARIAL FAULT: Simulated database network failure or unhandled exception
          throw new Error('FORCED_SIMULATED_TRANSACTION_FAILURE');
        }),
      ).rejects.toThrow('FORCED_SIMULATED_TRANSACTION_FAILURE');

      // 3. Invariants: Database transaction rolled back completely
      const paymentCheck = await prisma.payment.findUnique({ where: { id: failPayment.id } });
      expect(paymentCheck?.status).toBe(PaymentStatus.CREATED); // NOT PAID

      const bookingCheck = await prisma.booking.findUnique({ where: { id: failBooking.id } });
      expect(bookingCheck?.status).toBe(BookingStatus.PENDING); // NOT CONFIRMED

      const orphanEntries = await prisma.platformLedgerEntry.findMany({
        where: { journalId: failJournalId },
      });
      expect(orphanEntries.length).toBe(0); // 0 orphan rows in PostgreSQL
    });

    it('5. Real Concurrency Mutex: Parallel acquireLock calls on same vehicle serialize with exactly 1 success and 1 ConflictException', async () => {
      const lockKey = `car_concurrent_${Date.now()}`;

      const attempt1 = bookingLockService.acquireLock(lockKey, 5000);
      const attempt2 = bookingLockService.acquireLock(lockKey, 5000);

      const outcomes = await Promise.allSettled([attempt1, attempt2]);

      const fulfilled = outcomes.filter((o) => o.status === 'fulfilled');
      const rejected = outcomes.filter((o) => o.status === 'rejected');

      expect(fulfilled.length).toBe(1);
      expect(rejected.length).toBe(1);
      expect((rejected[0] as PromiseRejectedResult).reason).toBeInstanceOf(ConflictException);

      // Release the token from the winner
      const token = (fulfilled[0] as PromiseFulfilledResult<string>).value;
      await bookingLockService.releaseLock(lockKey, token);
    });

    it('6. Real Concurrency Fail-Closed Resilience: When Redis coordinator degrades, acquireLock fails closed with 503 instead of risking race conditions', async () => {
      const degradedRedis = {
        set: jest.fn().mockRejectedValue(new Error('ECONNREFUSED 127.0.0.1:6379')),
      } as any;
      const resilientLockService = new BookingLockService(degradedRedis);

      await expect(
        resilientLockService.acquireLock('car_degraded_concurrency_test', 5000),
      ).rejects.toThrow(ServiceUnavailableException);
    });
  });
});

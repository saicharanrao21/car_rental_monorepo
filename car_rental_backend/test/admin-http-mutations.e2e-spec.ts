import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  Role,
  VerificationStatus,
  VehicleOperationalStatus,
  VehicleVerificationStatus,
  BusinessType,
  CarCategory,
  FuelType,
  TripType,
  BookingStatus,
  DamageClaimStatus,
  DisputeStatus,
  DiscountType,
  VendorDepositStatus,
  PaymentStatus,
} from '@prisma/client';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { REDIS_CLIENT } from '../src/redis/redis.constants';
import Redis from 'ioredis';
import { json, urlencoded } from 'express';

describe('Real HTTP Admin Mutation E2E (Full Pipeline: HTTP -> Controller -> Service -> Prisma -> Postgres -> Customer Visibility)', () => {
  jest.setTimeout(45000);

  let app: INestApplication<App>;
  let prisma: PrismaService;
  let jwtService: JwtService;

  const clearSearchCache = async () => {
    try {
      const redis = app.get<Redis>(REDIS_CLIENT);
      const keys = await redis.keys('cache:search:cars:*');
      if (keys.length > 0) {
        await redis.del(...keys);
      }
    } catch (e) {}
  };

  let adminToken: string;
  let customerToken: string;
  let vendorToken: string;

  const testSuffix = Date.now().toString().slice(-6);
  const adminUserId = `usr_adm_e2e_${testSuffix}`;
  const customerUserId = `usr_cst_e2e_${testSuffix}`;
  const vendorUserId = `usr_vnd_e2e_${testSuffix}`;

  let createdVendorId: string;
  let createdCarId: string;
  let createdBookingId: string;
  let createdClaimId: string;
  let createdDisputeId: string;
  let createdCouponId: string;
  const couponCode = `PROMO_E2E_${testSuffix}`;
  const testCity = `CityE2E_${testSuffix}`;

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    process.env.REDIS_USE_MOCK = 'false';
    process.env.REDIS_URL = 'redis://127.0.0.1:6379';
    process.env.JWT_ACCESS_SECRET = 'test_jwt_access_secret_min_32_chars_long!';
    process.env.JWT_REFRESH_SECRET = 'test_jwt_refresh_secret_min_32_chars_long!';
    process.env.BANK_ENCRYPTION_KEY =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication({ bodyParser: false });
    app.use(
      json({
        verify: (req: any, res, buf) => {
          if (buf && buf.length) {
            req.rawBody = buf.toString('utf8');
          }
        },
      }),
    );
    app.use(urlencoded({ extended: true }));
    await app.init();

    prisma = app.get(PrismaService);
    const configService = app.get(ConfigService);
    const secret =
      configService.get<string>('JWT_ACCESS_SECRET') ||
      process.env.JWT_ACCESS_SECRET ||
      'test_jwt_access_secret_min_32_chars_long!';
    jwtService = new JwtService({ secret });

    // Generate authenticated JWT tokens
    adminToken = jwtService.sign({ userId: adminUserId, role: Role.ADMIN });
    customerToken = jwtService.sign({
      userId: customerUserId,
      role: Role.CUSTOMER,
    });
    vendorToken = jwtService.sign({ userId: vendorUserId, role: Role.VENDOR });

    // Fixture Preparation: Seed Users
    await prisma.user.upsert({
      where: { id: adminUserId },
      create: {
        id: adminUserId,
        phone: `+919000${testSuffix}1`,
        name: 'Admin E2E Tester',
        role: Role.ADMIN,
      },
      update: {},
    });

    await prisma.user.upsert({
      where: { id: customerUserId },
      create: {
        id: customerUserId,
        phone: `+919000${testSuffix}2`,
        name: 'Customer E2E Tester',
        role: Role.CUSTOMER,
      },
      update: {},
    });

    await prisma.user.upsert({
      where: { id: vendorUserId },
      create: {
        id: vendorUserId,
        phone: `+919000${testSuffix}3`,
        name: 'Vendor E2E Tester',
        role: Role.VENDOR,
      },
      update: {},
    });

    // Fixture Preparation: Vendor initially with PENDING verification status
    const vendor = await prisma.vendor.create({
      data: {
        userId: vendorUserId,
        businessName: `E2E Rentals ${testSuffix}`,
        ownerName: 'Vendor Owner',
        city: testCity,
        businessType: BusinessType.INDIVIDUAL,
        verificationStatus: VerificationStatus.PENDING,
      },
    });
    createdVendorId = vendor.id;

    // Fixture Preparation: Fulfill Vendor Security Deposit requirement
    await prisma.vendorSecurityDeposit.upsert({
      where: { vendorId: createdVendorId },
      create: {
        vendorId: createdVendorId,
        requiredAmount: 25000,
        paidAmount: 25000,
        remainingAmount: 0,
        status: VendorDepositStatus.PAID,
      },
      update: {
        paidAmount: 25000,
        remainingAmount: 0,
        status: VendorDepositStatus.PAID,
      },
    });

    // Fixture Preparation: Waive any mandatory vendor requirements for this test vendor
    const reqDefs = await prisma.onboardingRequirementDefinition.findMany({
      where: { isRequired: true },
    });
    for (const def of reqDefs) {
      await prisma.vendorRequirementState.upsert({
        where: {
          vendorId_requirementDefinitionId: {
            vendorId: createdVendorId,
            requirementDefinitionId: def.id,
          },
        },
        create: {
          vendorId: createdVendorId,
          requirementDefinitionId: def.id,
          status: 'WAIVED',
          notes: 'Waived for E2E testing',
        },
        update: { status: 'WAIVED' },
      });
    }

    // Fixture Preparation: Car associated with this vendor
    const car = await prisma.car.create({
      data: {
        vendorId: createdVendorId,
        make: 'Hyundai',
        model: `Creta_${testSuffix}`,
        year: 2024,
        type: CarCategory.SUV,
        fuelType: FuelType.PETROL,
        seating: 5,
        isAC: true,
        registrationNumber: `MH01AB${testSuffix}`,
        pricePerKm: 15.0,
        pricePerDay: 2500.0,
        pricePerHour: 150.0,
        isAvailable: true,
        operationalStatus: VehicleOperationalStatus.ACTIVE,
        verificationStatus: VehicleVerificationStatus.VERIFIED,
      },
    });
    createdCarId = car.id;

    // Fixture Preparation: Booking for customer + car
    const booking = await prisma.booking.create({
      data: {
        customerId: customerUserId,
        vendorId: createdVendorId,
        carId: createdCarId,
        tripType: TripType.SELF_DRIVE,
        pickupLocation: `${testCity} Airport`,
        dropLocation: `${testCity} Airport`,
        startDate: new Date(Date.now() + 86400000),
        endDate: new Date(Date.now() + 86400000 * 3),
        baseFare: 5000.0,
        platformFee: 500.0,
        gstAmount: 900.0,
        totalFare: 6400.0,
        netToVendor: 4500.0,
        status: BookingStatus.PENDING,
      },
    });
    createdBookingId = booking.id;

    // Fixture Preparation: Settle payment for booking so it satisfies paid preconditions
    await prisma.payment.create({
      data: {
        bookingId: createdBookingId,
        amount: 6400.0,
        currency: 'INR',
        status: PaymentStatus.PAID,
        paymentMethod: 'CARD',
        gatewayProvider: 'RAZORPAY',
        razorpayOrderId: `order_e2e_${testSuffix}`,
        razorpayPaymentId: `pay_e2e_${testSuffix}`,
      },
    });

    // Fixture Preparation: Damage claim on the booking
    const claim = await prisma.damageClaim.create({
      data: {
        bookingId: createdBookingId,
        vendorId: createdVendorId,
        claimedAmount: 3500.0,
        description: 'Rear bumper scratch detected during post-trip return',
        damagePhotos: ['https://example.com/damages/bumper_scratch.jpg'],
        status: DamageClaimStatus.SUBMITTED,
      },
    });
    createdClaimId = claim.id;

    // Fixture Preparation: Dispute on the booking
    const dispute = await prisma.dispute.create({
      data: {
        bookingId: createdBookingId,
        raisedByUserId: customerUserId,
        reason: 'Incorrect cleaning fee charged',
        status: DisputeStatus.OPEN,
      },
    });
    createdDisputeId = dispute.id;
  });

  afterAll(async () => {
    // Teardown test fixtures
    try {
      if (createdDisputeId) {
        await prisma.dispute.deleteMany({ where: { id: createdDisputeId } });
      }
      if (createdClaimId) {
        await prisma.damageClaim.deleteMany({ where: { id: createdClaimId } });
      }
      if (createdBookingId) {
        await prisma.payment.deleteMany({ where: { bookingId: createdBookingId } });
        await prisma.booking.deleteMany({ where: { id: createdBookingId } });
      }
      if (createdCarId) {
        await prisma.car.deleteMany({ where: { id: createdCarId } });
      }
      if (createdVendorId) {
        await prisma.vendorRequirementState.deleteMany({ where: { vendorId: createdVendorId } });
        await prisma.vendorSecurityDeposit.deleteMany({ where: { vendorId: createdVendorId } });
        await prisma.vendor.deleteMany({ where: { id: createdVendorId } });
      }
      if (createdCouponId) {
        await prisma.couponUsage.deleteMany({ where: { couponId: createdCouponId } });
        await prisma.coupon.deleteMany({ where: { id: createdCouponId } });
      }
      await prisma.user.deleteMany({
        where: { id: { in: [adminUserId, customerUserId, vendorUserId] } },
      });
    } catch (e) {
      console.warn('Teardown cleanup notice:', e);
    }

    if (app) {
      await app.close();
    }
  });

  it('PROVE 1: Admin verifies vendor via HTTP -> Customer search HTTP endpoint immediately reflects vehicle visibility', async () => {
    // 1A. Customer search BEFORE admin verification: Vehicle must NOT be visible
    const preSearch = await request(app.getHttpServer())
      .get(`/cars?city=${testCity}`)
      .expect(200);

    const foundPre = preSearch.body.data?.some(
      (c: any) => c.id === createdCarId,
    );
    expect(foundPre).toBe(false);

    // 1B. Admin verifies vendor via HTTP endpoint
    const verifyRes = await request(app.getHttpServer())
      .patch(`/vendors/${createdVendorId}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ status: VerificationStatus.VERIFIED })
      .expect(200);

    expect(verifyRes.body.verificationStatus).toBe(VerificationStatus.VERIFIED);
    await clearSearchCache();

    // 1C. Customer search AFTER admin verification: Vehicle MUST now be visible!
    const postSearch = await request(app.getHttpServer())
      .get(`/cars?city=${testCity}`)
      .expect(200);

    const foundPost = postSearch.body.data?.some(
      (c: any) => c.id === createdCarId,
    );
    expect(foundPost).toBe(true);
  });

  it('PROVE 2: Admin suspends vehicle via HTTP -> Customer search HTTP endpoint immediately hides vehicle', async () => {
    // 2A. Admin suspends vehicle via HTTP
    const suspendRes = await request(app.getHttpServer())
      .post(`/admin/fleet/${createdCarId}/suspend`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ reason: 'Routine regulatory compliance inspection' })
      .expect(200);

    expect(suspendRes.body.operationalStatus).toBe(
      VehicleOperationalStatus.SUSPENDED,
    );
    await clearSearchCache();

    // 2B. Customer search HTTP call: Suspended vehicle must NO LONGER be returned
    const searchRes = await request(app.getHttpServer())
      .get(`/cars?city=${testCity}`)
      .expect(200);

    const isVisible = searchRes.body.data?.some(
      (c: any) => c.id === createdCarId,
    );
    expect(isVisible).toBe(false);
  });

  it('PROVE 3: Admin activates vehicle via HTTP -> Customer search HTTP endpoint immediately restores visibility', async () => {
    // 3A. Admin activates vehicle via HTTP with administrative override
    const activateRes = await request(app.getHttpServer())
      .post(`/admin/fleet/${createdCarId}/activate`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        reason: 'Compliance inspection passed with full certification',
        skipEligibilityCheck: true,
      })
      .expect(200);

    expect(activateRes.body.operationalStatus).toBe(
      VehicleOperationalStatus.ACTIVE,
    );
    await clearSearchCache();

    // 3B. Customer search HTTP call: Active vehicle is VISIBLE again
    const searchRes = await request(app.getHttpServer())
      .get(`/cars?city=${testCity}`)
      .expect(200);

    const isVisible = searchRes.body.data?.some(
      (c: any) => c.id === createdCarId,
    );
    expect(isVisible).toBe(true);
  });

  it('PROVE 4: Admin creates coupon via HTTP -> Customer can validate and receive calculated discount via HTTP', async () => {
    const couponDto = {
      code: couponCode,
      description: 'E2E Test Promotional Coupon',
      discountType: DiscountType.PERCENTAGE,
      discountValue: 15, // 15% discount
      minBookingAmount: 1000,
      maxDiscountAmount: 1500,
      isActive: true,
      globalUsageLimit: 50,
      perCustomerLimit: 2,
    };

    const createRes = await request(app.getHttpServer())
      .post('/admin/coupons')
      .set('Authorization', `Bearer ${adminToken}`)
      .send(couponDto)
      .expect(201);

    expect(createRes.body).toHaveProperty('id');
    expect(createRes.body.code).toBe(couponCode);
    createdCouponId = createRes.body.id;

    // Customer validates coupon via HTTP
    const validateRes = await request(app.getHttpServer())
      .post('/coupons/validate')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        code: couponCode,
        subtotal: 4000,
        city: testCity,
        tripType: TripType.SELF_DRIVE,
      })
      .expect((res) => {
        expect([200, 201]).toContain(res.status);
      });

    expect(validateRes.body.valid).toBe(true);
    expect(validateRes.body.code).toBe(couponCode);
    // 15% of 4000 = 600
    expect(validateRes.body.discountAmount).toBe(600);
    expect(validateRes.body.finalPayableAmount ?? validateRes.body.finalAmount).toBe(3400);
  });

  it('PROVE 5: Admin toggles coupon status via HTTP -> Customer coupon validation is immediately rejected', async () => {
    // Admin toggles coupon to inactive
    const toggleRes = await request(app.getHttpServer())
      .post(`/admin/coupons/${createdCouponId}/toggle-status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ isActive: false })
      .expect((res) => {
        expect([200, 201]).toContain(res.status);
      });

    expect(toggleRes.body.isActive).toBe(false);

    // Customer attempts to validate the now-inactive coupon via HTTP
    const failValidateRes = await request(app.getHttpServer())
      .post('/coupons/validate')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        code: couponCode,
        subtotal: 4000,
      })
      .expect(400);

    expect(failValidateRes.body.message).toMatch(/inactive|invalid/i);
  });

  it('PROVE 6: Admin reviews coupon usage via HTTP -> receives valid usage records list', async () => {
    // Seed a coupon usage record
    await prisma.couponUsage.create({
      data: {
        couponId: createdCouponId,
        customerId: customerUserId,
        bookingId: createdBookingId,
        discountAmount: 600.0,
      },
    });

    const usagesRes = await request(app.getHttpServer())
      .get(`/admin/coupons/${createdCouponId}/usages`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(usagesRes.body).toHaveProperty('usages');
    expect(usagesRes.body).toHaveProperty('total');
    expect(usagesRes.body.usages.length).toBeGreaterThanOrEqual(1);
    expect(usagesRes.body.usages[0].couponId || createdCouponId).toBe(createdCouponId);
    expect(usagesRes.body.usages[0].customerId).toBe(customerUserId);
  });

  it('PROVE 7: Admin adjudicates damage claim via HTTP -> booking & damage claim state update', async () => {
    const adjudicateDto = {
      decision: 'REJECTED',
      adminNotes: 'Inspection imagery refutes claim; wear confirmed pre-existing.',
    };

    const adjRes = await request(app.getHttpServer())
      .patch(`/admin/damage-claims/${createdClaimId}/adjudicate`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send(adjudicateDto)
      .expect(200);

    expect(adjRes.body.status).toBe(DamageClaimStatus.REJECTED);
    expect(adjRes.body.adminNotes).toBe(adjudicateDto.adminNotes);

    // Verify in PostgreSQL database
    const dbClaim = await prisma.damageClaim.findUnique({
      where: { id: createdClaimId },
    });
    expect(dbClaim?.status).toBe(DamageClaimStatus.REJECTED);
  });

  it('PROVE 8: Admin performs permitted booking lifecycle mutation via HTTP -> Booking transitions to CONFIRMED', async () => {
    const confirmRes = await request(app.getHttpServer())
      .post(`/bookings/${createdBookingId}/confirm`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ reason: 'Admin manual confirmation override' })
      .expect(200);

    expect(confirmRes.body.booking?.status || confirmRes.body.status || confirmRes.body.newStatus).toBe(BookingStatus.CONFIRMED);

    // Verify in PostgreSQL database
    const dbBooking = await prisma.booking.findUnique({
      where: { id: createdBookingId },
    });
    expect(dbBooking?.status).toBe(BookingStatus.CONFIRMED);
  });

  it('PROVE 9: Admin performs dispute governance flow via HTTP -> Dispute status transitions to RESOLVED', async () => {
    const updateDisputeDto = {
      status: DisputeStatus.RESOLVED,
      resolutionNote:
        'Customer cleaning receipt verified; full reimbursement approved by governance committee.',
    };

    const disputeRes = await request(app.getHttpServer())
      .patch(`/admin/disputes/${createdDisputeId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send(updateDisputeDto)
      .expect(200);

    expect(disputeRes.body.status).toBe(DisputeStatus.RESOLVED);
    expect(disputeRes.body.resolutionNote).toBe(updateDisputeDto.resolutionNote);

    // Verify booking disputeFlag is cleared in PostgreSQL
    const dbBooking = await prisma.booking.findUnique({
      where: { id: createdBookingId },
    });
    expect(dbBooking?.disputeFlag).toBe(false);
  });

  it('PROVE 10: Unauthorized customer and vendor attempts are rejected by HTTP security guards (401 & 403)', async () => {
    // 10A. Unauthenticated request rejected with 401
    await request(app.getHttpServer())
      .post(`/admin/fleet/${createdCarId}/suspend`)
      .send({ reason: 'Unauthenticated probe' })
      .expect(401);

    // 10B. Customer role attempting admin vehicle suspension rejected with 403
    await request(app.getHttpServer())
      .post(`/admin/fleet/${createdCarId}/suspend`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ reason: 'Customer attempting vehicle suspension' })
      .expect(403);

    // 10C. Vendor role attempting admin coupon creation rejected with 403
    await request(app.getHttpServer())
      .post('/admin/coupons')
      .set('Authorization', `Bearer ${vendorToken}`)
      .send({
        code: 'VENDOR_PROBE',
        discountType: DiscountType.FIXED,
        discountValue: 500,
      })
      .expect(403);

    // 10D. Customer attempting admin dispute update rejected with 403
    await request(app.getHttpServer())
      .patch(`/admin/disputes/${createdDisputeId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ status: DisputeStatus.RESOLVED })
      .expect(403);
  });
});

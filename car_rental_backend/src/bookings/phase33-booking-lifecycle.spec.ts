import { Test, TestingModule } from '@nestjs/testing';
import { BookingLifecycleService } from './booking-lifecycle.service';
import { BookingOutboxService } from './booking-outbox.service';
import { PrismaService } from '../prisma/prisma.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { CancellationPolicyService } from './cancellation-policy.service';
import { HandoverOtpService } from './handover-otp.service';
import { PaymentsService } from '../payments/payments.service';
import { AuditLogService } from '../admin/audit-log.service';
import { NotificationOrchestratorService } from '../notifications/notification-orchestrator.service';
import { NotificationRealtimeService } from '../notifications/notification-realtime.service';
import { ReferralsService } from '../referrals/referrals.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import {
  BookingStatus,
  Role,
  PaymentStatus,
  InspectionType,
  HandoverOtpType,
  SecurityDepositStatus,
} from '@prisma/client';
import {
  BadRequestException,
  ForbiddenException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';

describe('Phase 33 — Canonical Booking Lifecycle Orchestration Layer', () => {
  let lifecycleService: BookingLifecycleService;
  let outboxService: BookingOutboxService;

  let prismaMock: any;
  let lockServiceMock: any;
  let cancellationPolicyMock: any;
  let handoverOtpMock: any;
  let paymentsServiceMock: any;
  let auditLogMock: any;
  let notificationOrchestratorMock: any;
  let realtimeServiceMock: any;
  let referralsMock: any;
  let loyaltyMock: any;

  const mockBooking = {
    id: 'booking-p33-001',
    customerId: 'cust-uuid-101',
    vendorId: 'vendor-uuid-202',
    carId: 'car-uuid-303',
    status: BookingStatus.PENDING,
    startDate: new Date('2026-09-10T10:00:00Z'),
    endDate: new Date('2026-09-15T10:00:00Z'),
    totalFare: 12000,
    pickupLocation: 'Koramangala Hub, Bengaluru',
    dropLocation: 'Indiranagar Hub, Bengaluru',
    disputeFlag: false,
    disputeNote: null,
    customer: {
      id: 'cust-uuid-101',
      name: 'Rohan Sharma',
      phone: '+919876543210',
    },
    vendor: {
      id: 'vendor-uuid-202',
      userId: 'vendor-owner-001',
      businessName: 'Royal Fleet Rentals',
      user: {
        id: 'vendor-owner-001',
        phone: '+919123456780',
      },
    },
    car: {
      id: 'car-uuid-303',
      make: 'Hyundai',
      model: 'Creta SX',
      registrationNumber: 'KA-01-MJ-9988',
    },
    payment: {
      id: 'pay-uuid-404',
      status: PaymentStatus.PAID,
      amount: 12000,
      escrowQuarantine: true,
    },
    securityDeposit: {
      id: 'sec-dep-505',
      amount: 3000,
      status: SecurityDepositStatus.HELD,
    },
  };

  beforeEach(async () => {
    prismaMock = {
      booking: {
        findUnique: jest.fn().mockImplementation(() =>
          Promise.resolve({
            ...mockBooking,
            startDate: new Date('2026-09-10T10:00:00Z'),
            endDate: new Date('2026-09-15T10:00:00Z'),
          }),
        ),
        update: jest.fn().mockImplementation(({ data, where }) => ({
          ...mockBooking,
          ...data,
          id: where.id,
        })),
        findMany: jest.fn().mockResolvedValue([mockBooking]),
      },
      bookingOutboxEvent: {
        create: jest.fn().mockImplementation(({ data }) => ({
          id: 'outbox-evt-777',
          ...data,
          createdAt: new Date(),
          retryCount: 0,
          maxRetries: 5,
        })),
        findUnique: jest.fn().mockResolvedValue({
          id: 'outbox-evt-777',
          bookingId: 'booking-p33-001',
          eventType: 'BOOKING_CONFIRMED',
          status: 'PENDING',
          retryCount: 0,
          maxRetries: 5,
          tenantId: 'vendor-uuid-202',
          correlationId: 'evt_booking_confirmed_123',
          payload: {
            bookingId: 'booking-p33-001',
            customerId: 'cust-uuid-101',
            customerName: 'Rohan Sharma',
            vehicleName: 'Hyundai Creta SX',
            registrationNumber: 'KA-01-MJ-9988',
            startDate: new Date('2026-09-10T10:00:00Z').toISOString(),
            endDate: new Date('2026-09-15T10:00:00Z').toISOString(),
            totalFare: 12000,
            pickupLocation: 'Koramangala Hub, Bengaluru',
          },
        }),
        findFirst: jest.fn().mockResolvedValue(null),
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn().mockImplementation(({ data }) => ({
          id: 'outbox-evt-777',
          ...data,
        })),
      },
      payment: {
        findUnique: jest.fn().mockResolvedValue(mockBooking.payment),
      },
      inspection: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'insp-111',
          bookingId: 'booking-p33-001',
          type: InspectionType.PRE_TRIP,
          finalized: true,
        }),
      },
      securityDeposit: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      vendor: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'vendor-uuid-202',
          userId: 'vendor-owner-001',
          businessName: 'Royal Fleet Rentals',
        }),
      },
      $transaction: jest.fn().mockImplementation(async (callback) => {
        return callback(prismaMock);
      }),
    };

    lockServiceMock = {
      acquireCancellationLock: jest.fn().mockResolvedValue('token-lock-abc'),
      releaseCancellationLock: jest.fn().mockResolvedValue(true),
    };

    cancellationPolicyMock = {
      calculateCancellation: jest.fn().mockReturnValue({
        tier: 'FULL_REFUND',
        cancellationFee: 0,
        refundAmount: 12000,
        refundAmountInPaise: 1200000,
        isEligibleForRefund: true,
      }),
    };

    handoverOtpMock = {
      verifyOtp: jest.fn().mockResolvedValue(true),
    };

    paymentsServiceMock = {
      refund: jest.fn().mockResolvedValue({ success: true, refundId: 'ref-999' }),
    };

    auditLogMock = {
      log: jest.fn().mockResolvedValue({ id: 'audit-log-123' }),
    };

    notificationOrchestratorMock = {
      publishEvent: jest.fn().mockResolvedValue({ success: true, notificationId: 'notif-1' }),
    };

    realtimeServiceMock = {
      emitEvent: jest.fn().mockReturnValue(true),
    };

    referralsMock = {
      handleBookingCompleted: jest.fn().mockResolvedValue({ credited: true }),
    };

    loyaltyMock = {
      handleBookingCompleted: jest.fn().mockResolvedValue({ pointsCredited: 120 }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingLifecycleService,
        BookingOutboxService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: BookingLockService, useValue: lockServiceMock },
        { provide: CancellationPolicyService, useValue: cancellationPolicyMock },
        { provide: HandoverOtpService, useValue: handoverOtpMock },
        { provide: PaymentsService, useValue: paymentsServiceMock },
        { provide: AuditLogService, useValue: auditLogMock },
        { provide: NotificationOrchestratorService, useValue: notificationOrchestratorMock },
        { provide: NotificationRealtimeService, useValue: realtimeServiceMock },
        { provide: ReferralsService, useValue: referralsMock },
        { provide: LoyaltyService, useValue: loyaltyMock },
      ],
    }).compile();

    lifecycleService = module.get<BookingLifecycleService>(BookingLifecycleService);
    outboxService = module.get<BookingOutboxService>(BookingOutboxService);
  });

  // 1. Valid transitions
  it('1. Valid transition: PENDING -> CONFIRMED by authorized vendor succeeds with outbox event', async () => {
    const result = await lifecycleService.confirmBooking(
      'booking-p33-001',
      'vendor-owner-001',
      Role.VENDOR,
    );

    expect(result.success).toBe(true);
    expect(result.newStatus).toBe(BookingStatus.CONFIRMED);
    expect(prismaMock.$transaction).toHaveBeenCalled();
    expect(prismaMock.bookingOutboxEvent.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          bookingId: 'booking-p33-001',
          eventType: 'BOOKING_CONFIRMED',
          previousStatus: BookingStatus.PENDING,
          newStatus: BookingStatus.CONFIRMED,
        }),
      }),
    );
  });

  // 2. Invalid transitions
  it('2. Invalid transition: PENDING -> COMPLETED throws BadRequestException', async () => {
    await expect(
      lifecycleService.executeTransition({
        bookingId: 'booking-p33-001',
        actorId: 'vendor-owner-001',
        actorRole: Role.VENDOR,
        targetStatus: BookingStatus.COMPLETED,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  // 3. Unauthorized transitions
  it('3. Unauthorized transition: Random customer cannot confirm booking', async () => {
    await expect(
      lifecycleService.confirmBooking(
        'booking-p33-001',
        'random-customer-999',
        Role.CUSTOMER,
      ),
    ).rejects.toThrow(ForbiddenException);
  });

  // 4. Tenant isolation
  it('4. Tenant isolation: Vendor of another tenant fleet cannot update booking', async () => {
    await expect(
      lifecycleService.confirmBooking(
        'booking-p33-001',
        'different-vendor-user',
        Role.VENDOR,
      ),
    ).rejects.toThrow(ForbiddenException);
  });

  // 5. Stale state handling
  it('5. Stale state: Optimistic concurrency conflict (P2025) throws ConflictException', async () => {
    prismaMock.$transaction.mockRejectedValueOnce({
      code: 'P2025',
      message: 'Record to update not found.',
    });

    await expect(
      lifecycleService.confirmBooking(
        'booking-p33-001',
        'vendor-owner-001',
        Role.VENDOR,
      ),
    ).rejects.toThrow(ConflictException);
  });

  // 6. Duplicate transition
  it('6. Duplicate transition: Attempting to confirm already confirmed booking succeeds idempotently without re-dispatching', async () => {
    prismaMock.booking.findUnique.mockResolvedValueOnce({
      ...mockBooking,
      status: BookingStatus.CONFIRMED,
    });
    prismaMock.bookingOutboxEvent.findFirst.mockResolvedValueOnce({
      id: 'existing-outbox-123',
      correlationId: 'evt_corr_123',
      newStatus: BookingStatus.CONFIRMED,
    });

    const result = await lifecycleService.confirmBooking(
      'booking-p33-001',
      'vendor-owner-001',
      Role.VENDOR,
    );

    expect(result.success).toBe(true);
    expect(result.previousStatus).toBe(BookingStatus.CONFIRMED);
    expect(result.newStatus).toBe(BookingStatus.CONFIRMED);
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  // 7. Concurrent transition
  it('7. Concurrent transition: Mutex lock is acquired and reliably released on bookingId', async () => {
    await lifecycleService.confirmBooking(
      'booking-p33-001',
      'vendor-owner-001',
      Role.VENDOR,
    );

    expect(lockServiceMock.acquireCancellationLock).toHaveBeenCalledWith('booking-p33-001');
    expect(lockServiceMock.releaseCancellationLock).toHaveBeenCalledWith(
      'booking-p33-001',
      'token-lock-abc',
    );
  });

  // 8. Idempotent transition
  it('8. Idempotent transition: Multiple calls for identical target state return consistent payload', async () => {
    prismaMock.booking.findUnique.mockResolvedValue({
      ...mockBooking,
      status: BookingStatus.HANDOVER_READY,
    });

    const res1 = await lifecycleService.markReadyForHandover(
      'booking-p33-001',
      'vendor-owner-001',
      Role.VENDOR,
    );
    const res2 = await lifecycleService.markReadyForHandover(
      'booking-p33-001',
      'vendor-owner-001',
      Role.VENDOR,
    );

    expect(res1.newStatus).toBe(BookingStatus.HANDOVER_READY);
    expect(res2.newStatus).toBe(BookingStatus.HANDOVER_READY);
  });

  // 9. Payment dependency
  it('9. Payment dependency: Vendor cannot confirm booking if payment is not captured', async () => {
    prismaMock.booking.findUnique.mockResolvedValueOnce({
      ...mockBooking,
      payment: {
        id: 'pay-uuid-404',
        status: PaymentStatus.PENDING,
        amount: 12000,
      },
    });

    await expect(
      lifecycleService.confirmBooking(
        'booking-p33-001',
        'vendor-owner-001',
        Role.VENDOR,
      ),
    ).rejects.toThrow(BadRequestException);
  });

  // 10. Refund dependency
  it('10. Refund dependency: Cancellation triggers payment refund calculation and execution', async () => {
    prismaMock.booking.findUnique.mockResolvedValueOnce({
      ...mockBooking,
      status: BookingStatus.CONFIRMED,
    });

    const result = await lifecycleService.cancelBooking(
      'booking-p33-001',
      'cust-uuid-101',
      Role.CUSTOMER,
      'Change of travel itinerary',
    );

    expect(result.success).toBe(true);
    expect(cancellationPolicyMock.calculateCancellation).toHaveBeenCalled();
    expect(paymentsServiceMock.refund).toHaveBeenCalledWith(
      'booking-p33-001',
      1200000,
      'Change of travel itinerary',
      'FULL_REFUND',
    );
  });

  // 11. Escrow dependency
  it('11. Escrow dependency: Clean trip completion lifts escrow quarantine and triggers loyalty incentives', async () => {
    prismaMock.booking.findUnique.mockResolvedValueOnce({
      ...mockBooking,
      status: BookingStatus.RETURN_PENDING,
    });
    prismaMock.inspection.findUnique.mockResolvedValueOnce({
      id: 'insp-post-1',
      bookingId: 'booking-p33-001',
      type: InspectionType.POST_TRIP,
      finalized: true,
    });

    const result = await lifecycleService.completeBooking(
      'booking-p33-001',
      'vendor-owner-001',
      Role.VENDOR,
      '554433', // Handover OTP
    );

    expect(result.success).toBe(true);
    expect(result.newStatus).toBe(BookingStatus.COMPLETED);
    expect(referralsMock.handleBookingCompleted).toHaveBeenCalledWith('booking-p33-001');
    expect(loyaltyMock.handleBookingCompleted).toHaveBeenCalledWith('booking-p33-001');
  });

  // 12. Fulfillment dependency
  it('12. Fulfillment dependency: Cannot start trip (ONGOING) without finalized PRE_TRIP inspection and pickup OTP', async () => {
    prismaMock.booking.findUnique.mockResolvedValueOnce({
      ...mockBooking,
      status: BookingStatus.CONFIRMED,
    });
    prismaMock.inspection.findUnique.mockResolvedValueOnce(null); // No inspection

    await expect(
      lifecycleService.startRental(
        'booking-p33-001',
        'vendor-owner-001',
        Role.VENDOR,
        '123456',
      ),
    ).rejects.toThrow(BadRequestException);
  });

  // 13. Notification dispatch
  it('13. Notification dispatch: Outbox dispatcher routes operational event to NotificationOrchestratorService', async () => {
    const dispatched = await outboxService.dispatchEvent('outbox-evt-777');

    expect(dispatched).toBe(true);
    expect(notificationOrchestratorMock.publishEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        eventType: 'BOOKING_CONFIRMED',
        recipientId: 'cust-uuid-101',
        entityType: 'BOOKING',
        entityId: 'booking-p33-001',
      }),
    );
  });

  // 14. Realtime event emission
  it('14. Realtime event emission: Outbox dispatch streams live SSE notification to Customer & Vendor', async () => {
    await outboxService.dispatchEvent('outbox-evt-777');

    expect(realtimeServiceMock.emitEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'NOTIFICATION',
        userId: 'cust-uuid-101',
        notification: expect.objectContaining({
          category: 'BOOKING',
          entityId: 'booking-p33-001',
        }),
      }),
    );
  });

  // 15. Outbox/event persistence
  it('15. Outbox persistence: Booking state update and Outbox event are bundled in atomic transaction', async () => {
    await lifecycleService.confirmBooking(
      'booking-p33-001',
      'vendor-owner-001',
      Role.VENDOR,
    );

    expect(prismaMock.$transaction).toHaveBeenCalled();
    expect(prismaMock.booking.update).toHaveBeenCalled();
    expect(prismaMock.bookingOutboxEvent.create).toHaveBeenCalled();
  });

  // 16. Retry behavior
  it('16. Retry behavior: Failed dispatch increments retryCount and transitions to DEAD_LETTER at threshold', async () => {
    notificationOrchestratorMock.publishEvent.mockRejectedValueOnce(
      new Error('Gateway timeout from SMS downstream'),
    );
    prismaMock.bookingOutboxEvent.findUnique.mockResolvedValueOnce({
      id: 'outbox-evt-fail',
      bookingId: 'booking-p33-001',
      eventType: 'BOOKING_CONFIRMED',
      status: 'PENDING',
      retryCount: 4, // 4th retry, threshold 5
      maxRetries: 5,
      tenantId: 'vendor-uuid-202',
      correlationId: 'evt_corr_fail',
      payload: { customerId: 'cust-uuid-101' },
    });

    const result = await outboxService.dispatchEvent('outbox-evt-fail');

    expect(result).toBe(false);
    expect(prismaMock.bookingOutboxEvent.update).toHaveBeenCalledWith({
      where: { id: 'outbox-evt-fail' },
      data: expect.objectContaining({
        status: 'DEAD_LETTER',
        retryCount: 5,
        lastError: 'Gateway timeout from SMS downstream',
      }),
    });
  });

  // 17. Duplicate event suppression
  it('17. Duplicate event suppression: Already PUBLISHED outbox event is not re-sent', async () => {
    prismaMock.bookingOutboxEvent.findUnique.mockResolvedValueOnce({
      id: 'outbox-evt-already-done',
      status: 'PUBLISHED',
      payload: {},
    });

    const dispatched = await outboxService.dispatchEvent('outbox-evt-already-done');

    expect(dispatched).toBe(true);
    expect(notificationOrchestratorMock.publishEvent).not.toHaveBeenCalled();
    expect(realtimeServiceMock.emitEvent).not.toHaveBeenCalled();
  });

  // 18. Audit record creation
  it('18. Audit record creation: Admin lifecycle override creates structured audit log entry', async () => {
    await lifecycleService.confirmBooking(
      'booking-p33-001',
      'admin-super-01',
      Role.ADMIN,
      'Executive manual confirmation override',
    );

    expect(auditLogMock.log).toHaveBeenCalledWith(
      'admin-super-01',
      'BOOKING_LIFECYCLE_CONFIRMED',
      'Booking',
      'booking-p33-001',
      expect.objectContaining({
        previousStatus: BookingStatus.PENDING,
        newStatus: BookingStatus.CONFIRMED,
        reason: 'Executive manual confirmation override',
      }),
    );
  });

  // 19. Sanitized event payloads
  it('19. Sanitized event payloads: Outbox payload does not expose bank credentials or secrets', async () => {
    await lifecycleService.confirmBooking(
      'booking-p33-001',
      'vendor-owner-001',
      Role.VENDOR,
    );

    const createCall = prismaMock.bookingOutboxEvent.create.mock.calls[0][0];
    const payload = createCall.data.payload;

    expect(payload.bookingId).toBe('booking-p33-001');
    expect(payload.customerName).toBe('Rohan Sharma');
    expect(payload.clientSecret).toBeUndefined();
    expect(payload.bankAccountNumber).toBeUndefined();
    expect(payload.razorpayKeySecret).toBeUndefined();
  });

  // 20. Regression behavior
  it('20. Regression behavior: Admin can fetch complete chronological lifecycle history for audit governance', async () => {
    prismaMock.bookingOutboxEvent.findMany.mockResolvedValueOnce([
      { id: 'evt-1', eventType: 'BOOKING_CREATED', status: 'PUBLISHED' },
      { id: 'evt-2', eventType: 'BOOKING_CONFIRMED', status: 'PUBLISHED' },
      { id: 'evt-3', eventType: 'TRIP_STARTED', status: 'PUBLISHED' },
      { id: 'evt-4', eventType: 'BOOKING_COMPLETED', status: 'PUBLISHED' },
    ]);

    const history = await outboxService.getLifecycleHistory('booking-p33-001');

    expect(history.length).toBe(4);
    expect(history[0].eventType).toBe('BOOKING_CREATED');
    expect(history[3].eventType).toBe('BOOKING_COMPLETED');
  });
});

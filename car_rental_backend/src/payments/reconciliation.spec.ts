import { Test, TestingModule } from '@nestjs/testing';
import { FinancialReconciliationService } from './reconciliation.service';
import { PrismaService } from '../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { REDIS_CLIENT } from '../redis/redis.constants';
import {
  BookingStatus,
  PaymentStatus,
  RefundStatus,
  Role,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('FinancialReconciliationService — P0 Reconciliation Tests', () => {
  let service: FinancialReconciliationService;
  let mockPrisma: any;
  let mockConfig: any;
  let mockNotifications: any;
  let mockAuditLog: any;
  let mockRedis: any;

  const mockAdminUser = { id: 'admin_123', role: Role.ADMIN };

  beforeEach(async () => {
    mockPrisma = {
      user: {
        findFirst: jest.fn().mockResolvedValue(mockAdminUser),
      },
      payment: {
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn().mockResolvedValue({}),
      },
      booking: {
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn().mockResolvedValue({}),
      },
      $transaction: jest.fn().mockImplementation(async (callback) => {
        return callback(mockPrisma);
      }),
    };

    mockConfig = {
      get: jest.fn((key: string) => {
        if (key === 'RECONCILIATION_ENABLED') return 'true';
        if (key === 'RECONCILIATION_LOOKBACK_MINUTES') return 30;
        if (key === 'STALE_PAYMENT_ORDER_HOURS') return 24;
        if (key === 'RAZORPAY_KEY_ID') return 'rzp_test_mockKey';
        if (key === 'RAZORPAY_KEY_SECRET') return 'mockSecret';
        if (key === 'RAZORPAY_USE_MOCK') return 'false';
        return null;
      }),
    };

    mockNotifications = {
      notifyUser: jest.fn().mockResolvedValue(undefined),
    };

    mockAuditLog = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    mockRedis = {
      set: jest.fn().mockResolvedValue('OK'),
      eval: jest.fn().mockResolvedValue(1),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FinancialReconciliationService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: ConfigService, useValue: mockConfig },
        { provide: NotificationsService, useValue: mockNotifications },
        { provide: AuditLogService, useValue: mockAuditLog },
        { provide: REDIS_CLIENT, useValue: mockRedis },
      ],
    }).compile();

    service = module.get<FinancialReconciliationService>(
      FinancialReconciliationService,
    );
  });

  // 1. Orphaned refund detected and healed
  it('Scenario 1: should detect orphaned Razorpay refund and heal database state', async () => {
    const candidatePayment = {
      id: 'pay_rec_1',
      bookingId: 'booking_1',
      razorpayPaymentId: 'pay_rzp_1',
      razorpayOrderId: 'order_rzp_1',
      amount: new Decimal(3801.2),
      status: PaymentStatus.PAID,
      refundStatus: RefundStatus.NONE,
      booking: {
        id: 'booking_1',
        status: BookingStatus.CONFIRMED,
      },
    };

    mockPrisma.payment.findMany.mockResolvedValue([candidatePayment]);

    (service as any).razorpay = {
      payments: {
        fetchMultipleRefund: jest.fn().mockResolvedValue({
          count: 1,
          items: [
            {
              id: 'rfnd_rzp_1',
              payment_id: 'pay_rzp_1',
              status: 'processed',
              amount: 380120,
              created_at: 1786795773,
            },
          ],
        }),
      },
    };

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileOrphanedRefunds(report);

    expect(report.healed).toBe(1);
    expect(mockPrisma.payment.update).toHaveBeenCalledWith({
      where: { id: 'pay_rec_1' },
      data: {
        status: PaymentStatus.REFUNDED,
        refundStatus: RefundStatus.PROCESSED,
        razorpayRefundId: 'rfnd_rzp_1',
        refundAmount: new Decimal(3801.2),
      },
    });
    expect(mockPrisma.booking.update).toHaveBeenCalledWith({
      where: { id: 'booking_1' },
      data: expect.objectContaining({
        status: BookingStatus.CANCELLED,
        refundAmount: new Decimal(3801.2),
      }),
    });
    expect(mockAuditLog.log).toHaveBeenCalledWith(
      'admin_123',
      'RECONCILIATION_AUTO_HEALED_REFUND',
      'Payment',
      'pay_rec_1',
      expect.objectContaining({ razorpayRefundId: 'rfnd_rzp_1' }),
    );
  });

  // 2. Already reconciled refund is skipped
  it('Scenario 2: should skip payment when no gateway refund exists', async () => {
    const candidatePayment = {
      id: 'pay_rec_2',
      bookingId: 'booking_2',
      razorpayPaymentId: 'pay_rzp_2',
      amount: new Decimal(5000),
      status: PaymentStatus.PAID,
      refundStatus: RefundStatus.NONE,
      booking: { id: 'booking_2', status: BookingStatus.CONFIRMED },
    };

    mockPrisma.payment.findMany.mockResolvedValue([candidatePayment]);

    (service as any).razorpay = {
      payments: {
        fetchMultipleRefund: jest.fn().mockResolvedValue({
          count: 0,
          items: [],
        }),
      },
    };

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileOrphanedRefunds(report);

    expect(report.skipped).toBe(1);
    expect(report.healed).toBe(0);
    expect(mockPrisma.payment.update).not.toHaveBeenCalled();
  });

  // 3. Razorpay refund exists but amount mismatch → no mutation
  it('Scenario 3: should reject healing if refund amount exceeds payment amount', async () => {
    const candidatePayment = {
      id: 'pay_rec_3',
      bookingId: 'booking_3',
      razorpayPaymentId: 'pay_rzp_3',
      amount: new Decimal(1000),
      status: PaymentStatus.PAID,
      refundStatus: RefundStatus.NONE,
      booking: { id: 'booking_3', status: BookingStatus.CONFIRMED },
    };

    mockPrisma.payment.findMany.mockResolvedValue([candidatePayment]);

    (service as any).razorpay = {
      payments: {
        fetchMultipleRefund: jest.fn().mockResolvedValue({
          count: 1,
          items: [
            {
              id: 'rfnd_fraud',
              payment_id: 'pay_rzp_3',
              status: 'processed',
              amount: 500000, // 5000 INR vs 1000 INR paid
              created_at: 1786795773,
            },
          ],
        }),
      },
    };

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileOrphanedRefunds(report);

    expect(report.errors).toBe(1);
    expect(report.healed).toBe(0);
    expect(mockPrisma.payment.update).not.toHaveBeenCalled();
  });

  // 4. Razorpay refund exists for another payment → no mutation
  it('Scenario 4: should skip refund if payment_id does not match candidate', async () => {
    const candidatePayment = {
      id: 'pay_rec_4',
      bookingId: 'booking_4',
      razorpayPaymentId: 'pay_rzp_4',
      amount: new Decimal(2000),
      status: PaymentStatus.PAID,
      refundStatus: RefundStatus.NONE,
      booking: { id: 'booking_4', status: BookingStatus.CONFIRMED },
    };

    mockPrisma.payment.findMany.mockResolvedValue([candidatePayment]);

    (service as any).razorpay = {
      payments: {
        fetchMultipleRefund: jest.fn().mockResolvedValue({
          count: 1,
          items: [
            {
              id: 'rfnd_diff_pay',
              payment_id: 'pay_different_999',
              status: 'processed',
              amount: 200000,
              created_at: 1786795773,
            },
          ],
        }),
      },
    };

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileOrphanedRefunds(report);

    expect(report.skipped).toBe(1);
    expect(report.healed).toBe(0);
    expect(mockPrisma.payment.update).not.toHaveBeenCalled();
  });

  // 5. Pending booking with captured Razorpay payment → confirmed
  it('Scenario 5: should auto-confirm pending booking when captured payment exists', async () => {
    const candidatePayment = {
      id: 'pay_rec_5',
      bookingId: 'booking_5',
      razorpayOrderId: 'order_rzp_5',
      amount: new Decimal(4000),
      status: PaymentStatus.CREATED,
      booking: {
        id: 'booking_5',
        customerId: 'cust_5',
        totalFare: new Decimal(4000),
        status: BookingStatus.PENDING,
        securityDeposit: null,
      },
    };

    mockPrisma.payment.findMany.mockResolvedValue([candidatePayment]);

    (service as any).razorpay = {
      orders: {
        fetchPayments: jest.fn().mockResolvedValue({
          count: 1,
          items: [
            {
              id: 'pay_captured_5',
              order_id: 'order_rzp_5',
              status: 'captured',
              currency: 'INR',
              amount: 400000,
            },
          ],
        }),
      },
    };

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileUnconfirmedPaidBookings(report);

    expect(report.healed).toBe(1);
    expect(mockPrisma.payment.update).toHaveBeenCalledWith({
      where: { id: 'pay_rec_5' },
      data: {
        status: PaymentStatus.PAID,
        razorpayPaymentId: 'pay_captured_5',
      },
    });
    expect(mockPrisma.booking.update).toHaveBeenCalledWith({
      where: { id: 'booking_5' },
      data: { status: BookingStatus.CONFIRMED },
    });
    expect(mockNotifications.notifyUser).toHaveBeenCalledWith(
      'cust_5',
      'Payment Confirmed',
      expect.stringContaining('booking_5'),
    );
  });

  // 6. Pending booking with uncaptured order → remains pending
  it('Scenario 6: should keep pending booking unchanged if order has no captured payment', async () => {
    const candidatePayment = {
      id: 'pay_rec_6',
      bookingId: 'booking_6',
      razorpayOrderId: 'order_rzp_6',
      amount: new Decimal(3000),
      status: PaymentStatus.CREATED,
      booking: {
        id: 'booking_6',
        customerId: 'cust_6',
        totalFare: new Decimal(3000),
        status: BookingStatus.PENDING,
        securityDeposit: null,
      },
    };

    mockPrisma.payment.findMany.mockResolvedValue([candidatePayment]);

    (service as any).razorpay = {
      orders: {
        fetchPayments: jest.fn().mockResolvedValue({
          count: 1,
          items: [
            {
              id: 'pay_failed_6',
              order_id: 'order_rzp_6',
              status: 'failed',
              currency: 'INR',
              amount: 300000,
            },
          ],
        }),
      },
    };

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileUnconfirmedPaidBookings(report);

    expect(report.skipped).toBe(1);
    expect(report.healed).toBe(0);
    expect(mockPrisma.booking.update).not.toHaveBeenCalled();
  });

  // 7. Stale unpaid order → safely handled
  it('Scenario 7: should mark stale payment order FAILED after 24 hours', async () => {
    const stalePayment = {
      id: 'pay_stale_7',
      bookingId: 'booking_7',
      razorpayOrderId: 'order_stale_7',
      amount: new Decimal(2500),
      status: PaymentStatus.CREATED,
    };

    mockPrisma.payment.findMany.mockResolvedValue([stalePayment]);

    (service as any).razorpay = {
      orders: {
        fetchPayments: jest.fn().mockResolvedValue({ count: 0, items: [] }),
      },
    };

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileStalePaymentOrders(report);

    expect(report.healed).toBe(1);
    expect(mockPrisma.payment.update).toHaveBeenCalledWith({
      where: { id: 'pay_stale_7' },
      data: { status: PaymentStatus.FAILED },
    });
  });

  // 8. Cancelled booking + PAID payment without gateway refund → inconsistency detected & alert logged
  it('Scenario 8: should detect cancelled booking with PAID payment and log critical inconsistency without blind mutation', async () => {
    const inconsistentBooking = {
      id: 'booking_inconsistent_8',
      status: BookingStatus.CANCELLED,
      refundAmount: new Decimal(3000),
      payment: {
        id: 'pay_inconsistent_8',
        status: PaymentStatus.PAID,
        refundStatus: RefundStatus.NONE,
        razorpayPaymentId: 'pay_rzp_8',
      },
    };

    mockPrisma.booking.findMany
      .mockResolvedValueOnce([]) // 4A query
      .mockResolvedValueOnce([inconsistentBooking]); // 4B query

    (service as any).razorpay = {
      payments: {
        fetchMultipleRefund: jest.fn().mockResolvedValue({ count: 0, items: [] }),
      },
    };

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileFinancialInconsistencies(report);

    expect(report.errors).toBe(1);
    expect(mockAuditLog.log).toHaveBeenCalledWith(
      'admin_123',
      'RECONCILIATION_INCONSISTENCY_DETECTED',
      'Booking',
      'booking_inconsistent_8',
      expect.objectContaining({ severity: 'CRITICAL' }),
    );
    // Verified: No blind mutation performed on payment or booking
    expect(mockPrisma.payment.update).not.toHaveBeenCalled();
  });

  // 9. Refunded payment + CONFIRMED booking → inconsistency detected & healed to CANCELLED
  it('Scenario 9: should heal CONFIRMED booking to CANCELLED when payment is REFUNDED and PROCESSED', async () => {
    const candidateBooking = {
      id: 'booking_9',
      status: BookingStatus.CONFIRMED,
      payment: {
        id: 'pay_9',
        status: PaymentStatus.REFUNDED,
        refundStatus: RefundStatus.PROCESSED,
        razorpayRefundId: 'rfnd_9',
        refundAmount: new Decimal(2000),
      },
    };

    mockPrisma.booking.findMany
      .mockResolvedValueOnce([candidateBooking]) // 4A query
      .mockResolvedValueOnce([]); // 4B query

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileFinancialInconsistencies(report);

    expect(report.healed).toBe(1);
    expect(mockPrisma.booking.update).toHaveBeenCalledWith({
      where: { id: 'booking_9' },
      data: expect.objectContaining({
        status: BookingStatus.CANCELLED,
        refundAmount: new Decimal(2000),
      }),
    });
  });

  // 10. Razorpay API timeout → no incorrect mutation
  it('Scenario 10: should safely handle Razorpay API timeout without corrupting database', async () => {
    const candidatePayment = {
      id: 'pay_rec_10',
      bookingId: 'booking_10',
      razorpayPaymentId: 'pay_rzp_10',
      amount: new Decimal(1500),
      status: PaymentStatus.PAID,
      refundStatus: RefundStatus.NONE,
      booking: { id: 'booking_10', status: BookingStatus.CONFIRMED },
    };

    mockPrisma.payment.findMany.mockResolvedValue([candidatePayment]);

    (service as any).razorpay = {
      payments: {
        fetchMultipleRefund: jest
          .fn()
          .mockRejectedValue(new Error('Gateway timeout')),
      },
    };

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileOrphanedRefunds(report);

    expect(report.errors).toBe(1);
    expect(report.healed).toBe(0);
    expect(mockPrisma.payment.update).not.toHaveBeenCalled();
    expect(mockPrisma.booking.update).not.toHaveBeenCalled();
  });

  // 11. Database failure → retry-safe
  it('Scenario 11: should handle database error gracefully during transaction', async () => {
    const candidatePayment = {
      id: 'pay_rec_11',
      bookingId: 'booking_11',
      razorpayPaymentId: 'pay_rzp_11',
      amount: new Decimal(1000),
      status: PaymentStatus.PAID,
      refundStatus: RefundStatus.NONE,
      booking: { id: 'booking_11', status: BookingStatus.CONFIRMED },
    };

    mockPrisma.payment.findMany.mockResolvedValue([candidatePayment]);
    mockPrisma.$transaction.mockRejectedValueOnce(
      new Error('PostgreSQL connection dropped'),
    );

    (service as any).razorpay = {
      payments: {
        fetchMultipleRefund: jest.fn().mockResolvedValue({
          count: 1,
          items: [
            {
              id: 'rfnd_11',
              payment_id: 'pay_rzp_11',
              status: 'processed',
              amount: 100000,
              created_at: 1786795773,
            },
          ],
        }),
      },
    };

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileOrphanedRefunds(report);

    expect(report.errors).toBe(1);
    expect(report.healed).toBe(0);
  });

  // 12. Two workers cannot process the same payment simultaneously
  it('Scenario 12: should skip payment if record lock cannot be acquired', async () => {
    const candidatePayment = {
      id: 'pay_rec_12',
      bookingId: 'booking_12',
      razorpayPaymentId: 'pay_rzp_12',
      amount: new Decimal(2000),
      status: PaymentStatus.PAID,
      refundStatus: RefundStatus.NONE,
      booking: { id: 'booking_12', status: BookingStatus.CONFIRMED },
    };

    mockPrisma.payment.findMany.mockResolvedValue([candidatePayment]);
    // Simulate Redis lock already held by another worker
    mockRedis.set.mockResolvedValueOnce(null);

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileOrphanedRefunds(report);

    expect(report.skipped).toBe(1);
    expect(report.healed).toBe(0);
    expect(mockPrisma.payment.update).not.toHaveBeenCalled();
  });

  // 13. Duplicate webhook + reconciliation cannot double-process
  it('Scenario 13: should skip reconciliation when payment is already marked REFUNDED and PROCESSED', async () => {
    // Database returns empty array because query filters for status: PAID and refundStatus: NONE
    mockPrisma.payment.findMany.mockResolvedValue([]);

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileOrphanedRefunds(report);

    expect(report.candidatesFound).toBe(0);
    expect(report.processed).toBe(0);
    expect(report.healed).toBe(0);
    expect(mockPrisma.payment.update).not.toHaveBeenCalled();
  });

  // 14. Existing PAID payment is never changed incorrectly
  it('Scenario 14: should not change normal active paid booking without refund evidence', async () => {
    const activePayment = {
      id: 'pay_active_14',
      bookingId: 'booking_active_14',
      razorpayPaymentId: 'pay_rzp_active_14',
      amount: new Decimal(5366.4),
      status: PaymentStatus.PAID,
      refundStatus: RefundStatus.NONE,
      booking: { id: 'booking_active_14', status: BookingStatus.CONFIRMED },
    };

    mockPrisma.payment.findMany.mockResolvedValue([activePayment]);

    (service as any).razorpay = {
      payments: {
        fetchMultipleRefund: jest.fn().mockResolvedValue({
          count: 0,
          items: [],
        }),
      },
    };

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileOrphanedRefunds(report);

    expect(report.healed).toBe(0);
    expect(report.skipped).toBe(1);
    expect(mockPrisma.payment.update).not.toHaveBeenCalled();
    expect(mockPrisma.booking.update).not.toHaveBeenCalled();
  });

  // 15. Existing benchmark booking remains untouched
  it('Scenario 15: benchmark booking cmsu5sk3m000qgw1zaf9ftksz is never mutated during reconciliation', async () => {
    const benchmarkPayment = {
      id: 'cmsu671uh00049s1yxsa13woy',
      bookingId: 'cmsu5sk3m000qgw1zaf9ftksz',
      razorpayPaymentId: 'pay_TQ2F0i7NrsLqmu',
      razorpayOrderId: 'order_TPzl7SXwjr5HV7',
      amount: new Decimal(5366.4),
      status: PaymentStatus.PAID,
      refundStatus: RefundStatus.NONE,
      booking: {
        id: 'cmsu5sk3m000qgw1zaf9ftksz',
        status: BookingStatus.CONFIRMED,
      },
    };

    mockPrisma.payment.findMany.mockResolvedValue([benchmarkPayment]);

    (service as any).razorpay = {
      payments: {
        fetchMultipleRefund: jest.fn().mockResolvedValue({
          count: 0,
          items: [],
        }),
      },
    };

    const report = {
      candidatesFound: 0,
      processed: 0,
      healed: 0,
      skipped: 0,
      errors: 0,
    };

    await service.reconcileOrphanedRefunds(report);

    expect(report.healed).toBe(0);
    expect(report.skipped).toBe(1);
    expect(mockPrisma.payment.update).not.toHaveBeenCalled();
    expect(mockPrisma.booking.update).not.toHaveBeenCalled();
  });
});

import { CancellationPolicyService } from './cancellation-policy.service';
import { Role } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('CancellationPolicyService — Phase 3B Policy Engine Tests', () => {
  let service: CancellationPolicyService;

  beforeEach(() => {
    service = new CancellationPolicyService();
  });

  const baseStartDate = new Date('2026-08-20T12:00:00.000Z');
  const totalPaid = new Decimal(5000.0);

  it('should calculate 100% refund when cancelled > 24 hours before pickup', () => {
    // 25 hours before
    const cancellationTime = new Date('2026-08-19T11:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalPaid,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('FULL_REFUND_FREE_CANCELLATION');
    expect(result.hoursRemaining).toBe(25);
    expect(result.cancellationFeePercent).toBe(0);
    expect(result.cancellationFee.toNumber()).toBe(0);
    expect(result.refundAmountPercent).toBe(100);
    expect(result.refundAmount.toNumber()).toBe(5000);
    expect(result.refundAmountInPaise).toBe(500000);
    expect(result.isEligibleForRefund).toBe(true);
  });

  it('should calculate 75% refund when cancelled exactly 24 hours before pickup', () => {
    // Exactly 24.0 hours before
    const cancellationTime = new Date('2026-08-19T12:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalPaid,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('MODERATE_CANCELLATION');
    expect(result.hoursRemaining).toBe(24);
    expect(result.cancellationFeePercent).toBe(25);
    expect(result.cancellationFee.toNumber()).toBe(1250);
    expect(result.refundAmountPercent).toBe(75);
    expect(result.refundAmount.toNumber()).toBe(3750);
    expect(result.refundAmountInPaise).toBe(375000);
  });

  it('should calculate 75% refund when cancelled 12 hours before pickup', () => {
    // 12 hours before
    const cancellationTime = new Date('2026-08-20T00:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalPaid,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('MODERATE_CANCELLATION');
    expect(result.hoursRemaining).toBe(12);
    expect(result.cancellationFeePercent).toBe(25);
    expect(result.cancellationFee.toNumber()).toBe(1250);
    expect(result.refundAmountPercent).toBe(75);
    expect(result.refundAmount.toNumber()).toBe(3750);
    expect(result.refundAmountInPaise).toBe(375000);
  });

  it('should calculate 75% refund when cancelled exactly 6 hours before pickup', () => {
    // Exactly 6.0 hours before
    const cancellationTime = new Date('2026-08-20T06:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalPaid,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('MODERATE_CANCELLATION');
    expect(result.hoursRemaining).toBe(6);
    expect(result.cancellationFeePercent).toBe(25);
    expect(result.cancellationFee.toNumber()).toBe(1250);
    expect(result.refundAmountPercent).toBe(75);
    expect(result.refundAmount.toNumber()).toBe(3750);
  });

  it('should calculate 50% refund when cancelled 5 hours 59 minutes before pickup', () => {
    // 5.98 hours before pickup
    const cancellationTime = new Date('2026-08-20T06:01:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalPaid,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('LATE_CANCELLATION');
    expect(result.cancellationFeePercent).toBe(50);
    expect(result.cancellationFee.toNumber()).toBe(2500);
    expect(result.refundAmountPercent).toBe(50);
    expect(result.refundAmount.toNumber()).toBe(2500);
    expect(result.refundAmountInPaise).toBe(250000);
  });

  it('should calculate 0% refund when cancelled after trip start time (no-show)', () => {
    // 30 minutes after trip start
    const cancellationTime = new Date('2026-08-20T12:30:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalPaid,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('NO_REFUND_AFTER_START');
    expect(result.hoursRemaining).toBe(-0.5);
    expect(result.cancellationFeePercent).toBe(100);
    expect(result.cancellationFee.toNumber()).toBe(5000);
    expect(result.refundAmountPercent).toBe(0);
    expect(result.refundAmount.toNumber()).toBe(0);
    expect(result.refundAmountInPaise).toBe(0);
    expect(result.isEligibleForRefund).toBe(false);
  });

  it('should always calculate 100% refund for vendor cancellations regardless of hours remaining', () => {
    // Vendor cancelling 1 hour before pickup
    const cancellationTime = new Date('2026-08-20T11:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalPaid,
      actorRole: Role.VENDOR,
    });

    expect(result.tier).toBe('VENDOR_CANCELLED');
    expect(result.cancellationFeePercent).toBe(0);
    expect(result.cancellationFee.toNumber()).toBe(0);
    expect(result.refundAmountPercent).toBe(100);
    expect(result.refundAmount.toNumber()).toBe(5000);
    expect(result.refundAmountInPaise).toBe(500000);
    expect(result.isEligibleForRefund).toBe(true);
  });

  it('should support admin override with 100% refund', () => {
    const cancellationTime = new Date('2026-08-20T11:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalPaid,
      actorRole: Role.ADMIN,
      isAdminOverride: true,
    });

    expect(result.tier).toBe('ADMIN_OVERRIDE_FULL_REFUND');
    expect(result.cancellationFeePercent).toBe(0);
    expect(result.refundAmountPercent).toBe(100);
  });

  it('should calculate 100% full refund when booking is cancelled while pending confirmation, even if < 6 hours remaining', () => {
    // 3 hours before trip start
    const cancellationTime = new Date('2026-08-20T09:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalPaid,
      actorRole: Role.CUSTOMER,
      isPendingConfirmation: true,
    });

    expect(result.tier).toBe('PENDING_CONFIRMATION_FULL_REFUND');
    expect(result.cancellationFeePercent).toBe(0);
    expect(result.cancellationFee.toNumber()).toBe(0);
    expect(result.refundAmountPercent).toBe(100);
    expect(result.refundAmount.toNumber()).toBe(5000);
    expect(result.refundAmountInPaise).toBe(500000);
    expect(result.isEligibleForRefund).toBe(true);
  });

  it('should protect security deposit from cancellation fee on customer cancellation', () => {
    // 12 hours before pickup (25% cancellation fee tier)
    const cancellationTime = new Date('2026-08-20T00:00:00.000Z');
    const fare = new Decimal(4000.0);
    const deposit = new Decimal(1000.0);
    const totalWithDeposit = new Decimal(5000.0);

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalWithDeposit,
      depositAmount: deposit,
      actorRole: Role.CUSTOMER,
    });

    // 25% fee on 4000 fare = 1000 fee
    // Refund = 5000 - 1000 = 4000 (3000 fare refund + 1000 full deposit refund)
    expect(result.tier).toBe('MODERATE_CANCELLATION');
    expect(result.cancellationFeePercent).toBe(25);
    expect(result.cancellationFee.toNumber()).toBe(1000);
    expect(result.refundAmount.toNumber()).toBe(4000);
    expect(result.refundAmountInPaise).toBe(400000);
  });
});

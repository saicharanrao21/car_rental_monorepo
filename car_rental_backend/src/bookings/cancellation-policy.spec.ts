import { CancellationPolicyService, DEFAULT_CANCELLATION_MATRIX } from './cancellation-policy.service';
import { Role } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

describe('CancellationPolicyService — Authoritative Founder Decision Financial Tests', () => {
  let service: CancellationPolicyService;

  beforeEach(() => {
    service = new CancellationPolicyService();
  });

  const baseStartDate = new Date('2026-08-20T12:00:00.000Z');
  const rentalFare = new Decimal(5000.0);

  it('Tier 1: should calculate 90% refund (10% fee) when cancelled > 48 hours before pickup', () => {
    // 50 hours before pickup
    const cancellationTime = new Date('2026-08-18T10:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: rentalFare,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('TIER_GT_48H');
    expect(result.hoursRemaining).toBe(50);
    expect(result.cancellationFeePercent).toBe(10);
    expect(result.cancellationFee.toNumber()).toBe(500);
    expect(result.refundAmountPercent).toBe(90);
    expect(result.refundAmount.toNumber()).toBe(4500);
    expect(result.totalRefundAmount.toNumber()).toBe(4500);
    expect(result.refundAmountInPaise).toBe(450000);
    expect(result.isEligibleForRefund).toBe(true);
  });

  it('Tier 2: should calculate 75% refund (25% fee) when cancelled exactly 48 hours before pickup', () => {
    // Exactly 48.0 hours before pickup
    const cancellationTime = new Date('2026-08-18T12:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: rentalFare,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('TIER_24_TO_48H');
    expect(result.hoursRemaining).toBe(48);
    expect(result.cancellationFeePercent).toBe(25);
    expect(result.cancellationFee.toNumber()).toBe(1250);
    expect(result.refundAmountPercent).toBe(75);
    expect(result.refundAmount.toNumber()).toBe(3750);
    expect(result.totalRefundAmount.toNumber()).toBe(3750);
    expect(result.refundAmountInPaise).toBe(375000);
  });

  it('Tier 2: should calculate 75% refund (25% fee) when cancelled 36 hours before pickup', () => {
    // 36 hours before pickup
    const cancellationTime = new Date('2026-08-19T00:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: rentalFare,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('TIER_24_TO_48H');
    expect(result.hoursRemaining).toBe(36);
    expect(result.cancellationFeePercent).toBe(25);
    expect(result.cancellationFee.toNumber()).toBe(1250);
    expect(result.refundAmountPercent).toBe(75);
    expect(result.refundAmount.toNumber()).toBe(3750);
    expect(result.totalRefundAmount.toNumber()).toBe(3750);
    expect(result.refundAmountInPaise).toBe(375000);
  });

  it('Tier 2: should calculate 75% refund (25% fee) when cancelled exactly 24 hours before pickup', () => {
    // Exactly 24.0 hours before pickup
    const cancellationTime = new Date('2026-08-19T12:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: rentalFare,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('TIER_24_TO_48H');
    expect(result.hoursRemaining).toBe(24);
    expect(result.cancellationFeePercent).toBe(25);
    expect(result.cancellationFee.toNumber()).toBe(1250);
    expect(result.refundAmountPercent).toBe(75);
    expect(result.refundAmount.toNumber()).toBe(3750);
  });

  it('Tier 3: should calculate 50% refund (50% fee) when cancelled 12 hours before pickup', () => {
    // 12 hours before pickup
    const cancellationTime = new Date('2026-08-20T00:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: rentalFare,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('TIER_6_TO_24H');
    expect(result.hoursRemaining).toBe(12);
    expect(result.cancellationFeePercent).toBe(50);
    expect(result.cancellationFee.toNumber()).toBe(2500);
    expect(result.refundAmountPercent).toBe(50);
    expect(result.refundAmount.toNumber()).toBe(2500);
    expect(result.totalRefundAmount.toNumber()).toBe(2500);
    expect(result.refundAmountInPaise).toBe(250000);
  });

  it('Tier 3: should calculate 50% refund (50% fee) when cancelled exactly 6 hours before pickup', () => {
    // Exactly 6.0 hours before pickup
    const cancellationTime = new Date('2026-08-20T06:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: rentalFare,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('TIER_6_TO_24H');
    expect(result.hoursRemaining).toBe(6);
    expect(result.cancellationFeePercent).toBe(50);
    expect(result.cancellationFee.toNumber()).toBe(2500);
    expect(result.refundAmountPercent).toBe(50);
    expect(result.refundAmount.toNumber()).toBe(2500);
  });

  it('Tier 4: should calculate 0% refund (100% fee) when cancelled less than 6 hours before pickup', () => {
    // 5.98 hours before pickup
    const cancellationTime = new Date('2026-08-20T06:01:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: rentalFare,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('TIER_LT_6H');
    expect(result.cancellationFeePercent).toBe(100);
    expect(result.cancellationFee.toNumber()).toBe(5000);
    expect(result.refundAmountPercent).toBe(0);
    expect(result.refundAmount.toNumber()).toBe(0);
    expect(result.totalRefundAmount.toNumber()).toBe(0);
    expect(result.refundAmountInPaise).toBe(0);
    expect(result.isEligibleForRefund).toBe(false);
  });

  it('Tier 5: should calculate 0% refund when cancelled after trip start time (no-show)', () => {
    // 30 minutes after trip start
    const cancellationTime = new Date('2026-08-20T12:30:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: rentalFare,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('NO_REFUND_AFTER_START');
    expect(result.hoursRemaining).toBe(-0.5);
    expect(result.cancellationFeePercent).toBe(100);
    expect(result.cancellationFee.toNumber()).toBe(5000);
    expect(result.refundAmountPercent).toBe(0);
    expect(result.refundAmount.toNumber()).toBe(0);
    expect(result.totalRefundAmount.toNumber()).toBe(0);
    expect(result.refundAmountInPaise).toBe(0);
    expect(result.isEligibleForRefund).toBe(false);
  });

  it('FND-CONF-12: should always calculate 100% rental fare refund for dealer cancellations', () => {
    // Vendor cancelling 1 hour before pickup
    const cancellationTime = new Date('2026-08-20T11:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: rentalFare,
      actorRole: Role.VENDOR,
    });

    expect(result.tier).toBe('VENDOR_CANCELLED');
    expect(result.cancellationFeePercent).toBe(0);
    expect(result.cancellationFee.toNumber()).toBe(0);
    expect(result.refundAmountPercent).toBe(100);
    expect(result.refundAmount.toNumber()).toBe(5000);
    expect(result.totalRefundAmount.toNumber()).toBe(5000);
    expect(result.refundAmountInPaise).toBe(500000);
    expect(result.isEligibleForRefund).toBe(true);
  });

  it('FND-CONF-10 & FND-CONF-13: Precedence — Pre-acceptance cancellation gets 100% refund regardless of time', () => {
    // Customer cancels 1 hour before scheduled start, but booking was still pending host confirmation
    const cancellationTime = new Date('2026-08-20T11:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: rentalFare,
      actorRole: Role.CUSTOMER,
      isPendingConfirmation: true, // Pre-acceptance flag
    });

    // Takes absolute precedence over < 6 hours tier
    expect(result.tier).toBe('PENDING_CONFIRMATION_FULL_REFUND');
    expect(result.cancellationFeePercent).toBe(0);
    expect(result.cancellationFee.toNumber()).toBe(0);
    expect(result.refundAmountPercent).toBe(100);
    expect(result.refundAmount.toNumber()).toBe(5000);
    expect(result.totalRefundAmount.toNumber()).toBe(5000);
    expect(result.refundAmountInPaise).toBe(500000);
    expect(result.isEligibleForRefund).toBe(true);
  });

  it('Admin override: should support admin override with 100% full refund', () => {
    const cancellationTime = new Date('2026-08-20T11:00:00.000Z');

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: rentalFare,
      actorRole: Role.ADMIN,
      isAdminOverride: true,
    });

    expect(result.tier).toBe('ADMIN_OVERRIDE_FULL_REFUND');
    expect(result.cancellationFeePercent).toBe(0);
    expect(result.refundAmountPercent).toBe(100);
    expect(result.refundAmount.toNumber()).toBe(5000);
  });

  it('FND-CONF-09: Isolation of Monetary Security Deposit from Cancellation Fee', () => {
    // 12 hours before pickup (50% cancellation fee tier)
    const cancellationTime = new Date('2026-08-20T00:00:00.000Z');
    const fare = new Decimal(4000.0);
    const deposit = new Decimal(5000.0);
    const totalPaid = new Decimal(9000.0);

    const result = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalPaid,
      depositAmount: deposit,
      actorRole: Role.CUSTOMER,
    });

    expect(result.tier).toBe('TIER_6_TO_24H');
    expect(result.cancellationFeePercent).toBe(50);
    // Cancellation fee strictly on rental fare (50% of 4000 = 2000)
    expect(result.cancellationFee.toNumber()).toBe(2000);
    // Rental fare refund strictly on fare (50% of 4000 = 2000)
    expect(result.refundAmount.toNumber()).toBe(2000);
    // Security deposit refunded 100% (5000)
    expect(result.depositRefundAmount.toNumber()).toBe(5000);
    // Total cash returned to customer: 2000 fare refund + 5000 deposit refund = 7000
    expect(result.totalRefundAmount.toNumber()).toBe(7000);
    expect(result.refundAmountInPaise).toBe(700000);
    expect(result.fareRefundInPaise).toBe(200000);
    expect(result.depositRefundInPaise).toBe(500000);
  });

  it('FND-UNRES-02: Configurable Doorstep Delivery Fee Treatment in Cancellation Refund Base', () => {
    const cancellationTime = new Date('2026-08-19T00:00:00.000Z'); // 36h before (25% fee tier)
    const fare = new Decimal(4000.0);
    const delivery = new Decimal(500.0);
    const totalPaid = new Decimal(4500.0);

    // Case A: Delivery fee EXCLUDED from refund base (default)
    const resExcluded = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalPaid,
      deliveryFee: delivery,
      includeDeliveryFeeInRefundBase: false,
      actorRole: Role.CUSTOMER,
    });

    // 25% fee on 4000 fare = 1000 fee
    expect(resExcluded.cancellationFee.toNumber()).toBe(1000);
    // 75% refund on 4000 fare = 3000
    expect(resExcluded.refundAmount.toNumber()).toBe(3000);
    // Delivery fee refunded 100% outside cancellation base (500)
    expect(resExcluded.deliveryRefundAmount?.toNumber()).toBe(500);
    // Total refund: 3000 + 500 = 3500
    expect(resExcluded.totalRefundAmount.toNumber()).toBe(3500);

    // Case B: Delivery fee INCLUDED in refund base (when enabled)
    const resIncluded = service.calculateCancellation({
      startDate: baseStartDate,
      cancellationTime,
      amountPaid: totalPaid,
      deliveryFee: delivery,
      includeDeliveryFeeInRefundBase: true,
      actorRole: Role.CUSTOMER,
    });

    // 25% fee on (4000 + 500) = 1125 fee
    expect(resIncluded.cancellationFee.toNumber()).toBe(1125);
    // 75% refund on 4500 = 3375
    expect(resIncluded.refundAmount.toNumber()).toBe(3375);
    expect(resIncluded.totalRefundAmount.toNumber()).toBe(3375);
  });
});

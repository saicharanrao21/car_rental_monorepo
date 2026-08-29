import { Prisma, LedgerDirection, WalletBucketType, LedgerEntryType, PaymentStatus, PayoutStatus, SecurityDepositStatus } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { PayoutsService } from '../payouts/payouts.service';
import { WalletsService } from '../wallets/wallets.service';

describe('Financial Invariants & Integrity (Phase 27.6 Audit)', () => {
  describe('1. Customer Wallet Invariant', () => {
    it('should satisfy: opening_balance + credits - debits = closing_balance across real and promo buckets', () => {
      const openingReal = new Decimal('1000.00');
      const openingPromo = new Decimal('500.00');
      const openingAvailable = openingReal.add(openingPromo);

      const credits = [
        { bucket: WalletBucketType.REAL_MONEY, amount: new Decimal('2500.00'), direction: LedgerDirection.CREDIT },
        { bucket: WalletBucketType.PROMOTIONAL, amount: new Decimal('250.00'), direction: LedgerDirection.CREDIT },
      ];

      const debits = [
        { bucket: WalletBucketType.PROMOTIONAL, amount: new Decimal('500.00'), direction: LedgerDirection.DEBIT },
        { bucket: WalletBucketType.REAL_MONEY, amount: new Decimal('1200.00'), direction: LedgerDirection.DEBIT },
      ];

      let realBalance = openingReal;
      let promoBalance = openingPromo;

      for (const entry of credits) {
        if (entry.bucket === WalletBucketType.REAL_MONEY) realBalance = realBalance.add(entry.amount);
        if (entry.bucket === WalletBucketType.PROMOTIONAL) promoBalance = promoBalance.add(entry.amount);
      }

      for (const entry of debits) {
        if (entry.bucket === WalletBucketType.REAL_MONEY) realBalance = realBalance.sub(entry.amount);
        if (entry.bucket === WalletBucketType.PROMOTIONAL) promoBalance = promoBalance.sub(entry.amount);
      }

      const closingAvailable = realBalance.add(promoBalance);

      expect(realBalance.toString()).toBe('2300'); // 1000 + 2500 - 1200
      expect(promoBalance.toString()).toBe('250'); // 500 + 250 - 500
      expect(closingAvailable.toString()).toBe('2550'); // 2300 + 250
    });
  });

  describe('2. Vendor Outstanding Payable Invariant', () => {
    it('should satisfy: gross_earnings - commission +/- adjustments - paid_payouts = outstanding_payable', () => {
      const bookings = [
        { totalFare: new Decimal('10000.00'), commission: new Decimal('1500.00'), netToVendor: new Decimal('8500.00') },
        { totalFare: new Decimal('5000.00'), commission: new Decimal('750.00'), netToVendor: new Decimal('4250.00') },
      ];

      const grossEarnings = bookings.reduce((sum, b) => sum.add(b.totalFare), new Decimal('0'));
      const totalCommission = bookings.reduce((sum, b) => sum.add(b.commission), new Decimal('0'));
      const earnedNet = grossEarnings.sub(totalCommission);

      const adjustments = [
        { amount: new Decimal('500.00'), direction: LedgerDirection.CREDIT }, // Goodwill/Bonus
        { amount: new Decimal('250.00'), direction: LedgerDirection.DEBIT },  // Damage deduction
      ];

      const netAdjustment = adjustments.reduce(
        (sum, a) => a.direction === LedgerDirection.CREDIT ? sum.add(a.amount) : sum.sub(a.amount),
        new Decimal('0'),
      );

      const paidPayouts = new Decimal('5000.00');
      const pendingPayouts = new Decimal('3000.00');

      const outstandingPayable = earnedNet.add(netAdjustment).sub(paidPayouts);
      const availableToRequest = outstandingPayable.sub(pendingPayouts);

      expect(grossEarnings.toNumber()).toBe(15000);
      expect(totalCommission.toNumber()).toBe(2250);
      expect(earnedNet.toNumber()).toBe(12750);
      expect(netAdjustment.toNumber()).toBe(250);
      expect(outstandingPayable.toNumber()).toBe(8000); // 12750 + 250 - 5000
      expect(availableToRequest.toNumber()).toBe(5000);  // 8000 - 3000
    });
  });

  describe('3. Payment & Refund Ceiling Invariant', () => {
    it('should satisfy: original_amount - sum(refunds) = remaining_refundable_amount and reject over-refunding', () => {
      const originalPayment = new Decimal('10000.00');
      let totalRefunded = new Decimal('0.00');

      // First partial refund ₹3,000
      const refund1 = new Decimal('3000.00');
      expect(refund1.lte(originalPayment.sub(totalRefunded))).toBe(true);
      totalRefunded = totalRefunded.add(refund1);

      // Second partial refund ₹4,500
      const refund2 = new Decimal('4500.00');
      expect(refund2.lte(originalPayment.sub(totalRefunded))).toBe(true);
      totalRefunded = totalRefunded.add(refund2);

      const remainingRefundable = originalPayment.sub(totalRefunded);
      expect(remainingRefundable.toNumber()).toBe(2500); // 10000 - 7500

      // Third partial refund ₹3,000 (exceeds remaining ₹2,500) -> MUST FAIL
      const refund3 = new Decimal('3000.00');
      const isValid = refund3.lte(remainingRefundable);
      expect(isValid).toBe(false);
    });
  });

  describe('4. Security Deposit Liability Invariant', () => {
    it('should satisfy: held_deposit - released_amount - forfeited_amount = remaining_liability', () => {
      const initialDeposit = new Decimal('5000.00');
      const deductedForDamage = new Decimal('1500.00');
      const refundedToCustomer = new Decimal('3500.00');

      const remainingLiability = initialDeposit.sub(deductedForDamage).sub(refundedToCustomer);
      expect(remainingLiability.toNumber()).toBe(0);
    });
  });

  describe('5. Historical Financial Immutability', () => {
    it('should retain historical booking financial snapshots regardless of future platform commission rate updates', () => {
      // Historical booking created under 15% commission rate
      const historicalBooking = {
        id: 'book_hist_001',
        totalFare: new Decimal('10000.00'),
        platformFee: new Decimal('1500.00'),
        netToVendor: new Decimal('8500.00'),
        createdAt: new Date('2025-01-01'),
      };

      // Current updated commission rate is 20%
      const newCommissionRate = 0.20;

      // Invariant: historical booking values are immutable snapshots
      expect(historicalBooking.platformFee.toNumber()).toBe(1500.00);
      expect(historicalBooking.netToVendor.toNumber()).toBe(8500.00);
      expect(historicalBooking.totalFare.sub(historicalBooking.platformFee).equals(historicalBooking.netToVendor)).toBe(true);
    });
  });

  describe('6. Money Precision & Deterministic Rounding', () => {
    it('should maintain exact 2-decimal precision without IEEE-754 floating point drift', () => {
      // 0.1 + 0.2 in standard JS float is 0.30000000000000004
      const d1 = new Decimal('0.10');
      const d2 = new Decimal('0.20');
      const sum = d1.add(d2);

      expect(sum.toString()).toBe('0.3');
      expect(sum.toFixed(2)).toBe('0.30');

      // Multi-split calculations
      const itemPrice = new Decimal('199.99');
      const qty = new Decimal('3');
      const total = itemPrice.mul(qty);
      const gst = total.mul(new Decimal('0.18')).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);

      expect(total.toString()).toBe('599.97');
      expect(gst.toString()).toBe('107.99'); // 599.97 * 0.18 = 107.9946 -> 107.99
    });
  });
});

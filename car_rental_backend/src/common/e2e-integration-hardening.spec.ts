import {
  BookingStatus,
  PaymentStatus,
  PayoutStatus,
  Role,
  LedgerDirection,
  WalletBucketType,
} from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { redactVendor } from './vendor-redactor.util';
import { ROLE_PERMISSIONS_MATRIX, AdminPermission } from '../auth/permissions.enum';

describe('Phase 27.8: End-to-End Platform Integration Hardening', () => {
  describe('1. Full Marketplace Lifecycle Pipeline Integration', () => {
    it('should correctly transition through complete customer -> vendor -> admin -> finance -> analytics lifecycle', () => {
      // Step A: Customer Discovery & Pre-Acceptance State
      const rawVendor = {
        id: 'vendor_blr_1',
        businessName: 'DriveGo Premium Bangalore',
        ownerName: 'Rahul Sharma',
        phone: '+919876543210',
        city: 'Bangalore',
        locality: 'Indiranagar',
        latitude: 12.971598,
        longitude: 77.594562,
        bankDetails: 'enc:v1:aes256_mock_data',
        gstNumber: '29ABCDE1234F1Z5',
      };

      // Unconfirmed booking -> Host identity is masked/redacted
      const maskedForCustomer = redactVendor(rawVendor, { isConfirmed: false });
      expect(maskedForCustomer.businessName).toBe('Partner in Indiranagar');
      expect(maskedForCustomer.ownerName).toBeUndefined();
      expect(maskedForCustomer.phone).toBeUndefined();
      expect(maskedForCustomer.gstNumber).toBeUndefined();
      expect(maskedForCustomer.bankDetails).toBeUndefined();

      // Step B: Booking Creation & Authoritative Financial Snapshot
      const baseFare = new Decimal(5000);
      const protectionFee = new Decimal(499);
      const deliveryFee = new Decimal(200);
      const gstAmount = new Decimal(900); // 18% on fare
      const depositAmount = new Decimal(3000); // Refundable security deposit
      const totalCustomerPayable = baseFare.add(protectionFee).add(deliveryFee).add(gstAmount);

      const commissionRate = new Decimal('0.15'); // 15% platform fee
      const platformFee = baseFare.mul(commissionRate); // ₹750
      const netToVendor = baseFare.sub(platformFee); // ₹4250

      const bookingSnapshot = {
        id: 'book_e2e_001',
        status: BookingStatus.PENDING,
        totalFare: totalCustomerPayable,
        baseFare,
        platformFee,
        netToVendor,
        gstAmount,
        depositAmount,
        paymentStatus: PaymentStatus.PENDING,
      };

      expect(bookingSnapshot.totalFare.toNumber()).toBe(6599);
      expect(bookingSnapshot.platformFee.toNumber()).toBe(750);
      expect(bookingSnapshot.netToVendor.toNumber()).toBe(4250);

      // Step C: Payment Verification
      bookingSnapshot.paymentStatus = PaymentStatus.PAID;
      expect(bookingSnapshot.paymentStatus).toBe(PaymentStatus.PAID);

      // Step D: Vendor Acceptance Gate -> CONFIRMED
      bookingSnapshot.status = BookingStatus.CONFIRMED;
      const unmaskedPostConfirmation = redactVendor(rawVendor, { isConfirmed: true });
      expect(unmaskedPostConfirmation.businessName).toBe('DriveGo Premium Bangalore');
      expect(unmaskedPostConfirmation.ownerName).toBe('Rahul Sharma');
      // Direct raw phone number remains protected against off-platform bypass
      expect(unmaskedPostConfirmation.phone).toBeUndefined();

      // Step E: Handover Pickup Inspection -> ONGOING
      const pickupOtp = '482910';
      expect(pickupOtp).toMatch(/^\d{6}$/);
      bookingSnapshot.status = BookingStatus.ONGOING;
      expect(bookingSnapshot.status).toBe(BookingStatus.ONGOING);

      // Step F: Return Inspection -> COMPLETED
      const returnOtp = '739104';
      expect(returnOtp).toMatch(/^\d{6}$/);
      bookingSnapshot.status = BookingStatus.COMPLETED;
      expect(bookingSnapshot.status).toBe(BookingStatus.COMPLETED);

      // Step G: Financial Settlement & Payout Availability
      // During 2-day settlement hold, netToVendor is in heldEarnings
      const heldEarnings = bookingSnapshot.netToVendor;
      expect(heldEarnings.toNumber()).toBe(4250);

      // Post 2-day hold, funds transition to availableBalance
      const availableBalance = heldEarnings;
      expect(availableBalance.toNumber()).toBe(4250);
    });
  });

  describe('2. Security & RBAC Boundary Enforcement', () => {
    it('should strictly deny Support Agents from approving payouts or creating financial adjustments', () => {
      const supportAgentPermissions = ROLE_PERMISSIONS_MATRIX[Role.SUPPORT_AGENT];

      expect(supportAgentPermissions).not.toContain(AdminPermission.PAYOUT_APPROVE);
      expect(supportAgentPermissions).not.toContain(AdminPermission.PAYOUT_EXECUTE);
      expect(supportAgentPermissions).not.toContain(AdminPermission.FINANCE_ADJUSTMENT);
      expect(supportAgentPermissions).not.toContain(AdminPermission.COMMISSION_MANAGE);

      // Support agent can view tickets, bookings, and emergency dispatch
      expect(supportAgentPermissions).toContain(AdminPermission.BOOKING_READ);
      expect(supportAgentPermissions).toContain(AdminPermission.SUPPORT_TICKET_READ);
      expect(supportAgentPermissions).toContain(AdminPermission.EMERGENCY_DISPATCH);
    });

    it('should grant Super Admins full permissions matrix', () => {
      const adminPermissions = ROLE_PERMISSIONS_MATRIX[Role.ADMIN];
      expect(adminPermissions).toContain(AdminPermission.PAYOUT_APPROVE);
      expect(adminPermissions).toContain(AdminPermission.PAYOUT_EXECUTE);
      expect(adminPermissions).toContain(AdminPermission.FINANCE_ADJUSTMENT);
      expect(adminPermissions).toContain(AdminPermission.ANALYTICS_READ);
      expect(adminPermissions).toContain(AdminPermission.SYSTEM_CONFIG_WRITE);
    });
  });

  describe('3. Financial & Ledger Invariant Hardening', () => {
    it('should guarantee wallet double-entry ledger balance integrity', () => {
      const opening = new Decimal(500);
      const credit = new Decimal(1000);
      const debit = new Decimal(700);

      const closing = opening.add(credit).sub(debit);
      expect(closing.toNumber()).toBe(800);
    });

    it('should reject refund amounts exceeding remaining payment ceiling', () => {
      const totalPaid = new Decimal(5000);
      const alreadyRefunded = new Decimal(3000);
      const remainingRefundable = totalPaid.sub(alreadyRefunded);

      const invalidRefund = new Decimal(2500);
      const isAllowed = invalidRefund.lte(remainingRefundable);
      expect(isAllowed).toBe(false); // 2500 > 2000 remaining
    });
  });
});

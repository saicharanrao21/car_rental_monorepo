import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/features/vendors/domain/models/vendor_onboarding_models.dart';

void main() {
  group('Admin Panel - Vendor Deposit Policy & Management Suite', () {
    test('VendorDepositPolicyModel serializes and deserializes correctly', () {
      final json = {
        'id': 'pol_test_001',
        'version': 3,
        'isRequired': true,
        'amount': 35000,
        'currency': 'INR',
        'refundPolicy': 'PARTIALLY_REFUNDABLE',
        'description': 'Updated commercial partner deposit policy 2026',
        'refundConditions': 'Subject to vehicle inspection and account closure clearance',
        'paymentProvider': 'RAZORPAY',
        'deadlineDays': 21,
        'isActive': true,
        'effectiveFrom': '2026-10-28T20:00:00.000Z',
        'updatedBy': 'usr_admin_001',
      };

      final model = VendorDepositPolicyModel.fromJson(json);

      expect(model.id, 'pol_test_001');
      expect(model.version, 3);
      expect(model.isRequired, true);
      expect(model.amount, 35000.0);
      expect(model.currency, 'INR');
      expect(model.refundPolicy, 'PARTIALLY_REFUNDABLE');
      expect(model.paymentProvider, 'RAZORPAY');
      expect(model.deadlineDays, 21);
      expect(model.isActive, true);

      final payload = model.toJson();
      expect(payload['amount'], 35000.0);
      expect(payload['refundPolicy'], 'PARTIALLY_REFUNDABLE');
      expect(payload['paymentProvider'], 'RAZORPAY');
      expect(payload['deadlineDays'], 21);
    });

    test('VendorSecurityDepositModel parses gateway references and exemption status', () {
      final json = {
        'id': 'dep_live_001',
        'vendorId': 'vnd_partner_77',
        'requiredAmount': 25000,
        'paidAmount': 25000,
        'remainingAmount': 0,
        'status': 'PAID',
        'provider': 'RAZORPAY',
        'providerOrderId': 'order_rzp_vendor_001',
        'providerPaymentId': 'pay_rzp_vendor_999',
        'policyVersion': 2,
        'isExempt': false,
        'vendor': {
          'businessName': 'Grand Prix Wheels',
          'user': {
            'name': 'Karan Singh',
            'email': 'karan@grandprix.in',
            'phone': '+919988776655',
          },
        },
      };

      final deposit = VendorSecurityDepositModel.fromJson(json);

      expect(deposit.id, 'dep_live_001');
      expect(deposit.vendorId, 'vnd_partner_77');
      expect(deposit.status, 'PAID');
      expect(deposit.requiredAmount, 25000.0);
      expect(deposit.paidAmount, 25000.0);
      expect(deposit.remainingAmount, 0.0);
      expect(deposit.provider, 'RAZORPAY');
      expect(deposit.providerOrderId, 'order_rzp_vendor_001');
      expect(deposit.providerPaymentId, 'pay_rzp_vendor_999');
      expect(deposit.policyVersion, 2);
      expect(deposit.isExempt, false);
      expect(deposit.vendorBusinessName, 'Grand Prix Wheels');
      expect(deposit.vendorContactName, 'Karan Singh');
    });

    test('VendorSecurityDepositModel handles exemption waiver from Super Admin', () {
      final json = {
        'id': 'dep_live_002',
        'vendorId': 'vnd_exempt_88',
        'requiredAmount': 25000,
        'paidAmount': 0,
        'remainingAmount': 0,
        'status': 'NOT_REQUIRED',
        'isExempt': true,
        'exemptionReason': 'Special strategic enterprise partner waiver',
        'exemptedBy': 'admin_super_01',
      };

      final deposit = VendorSecurityDepositModel.fromJson(json);

      expect(deposit.status, 'NOT_REQUIRED');
      expect(deposit.isExempt, true);
      expect(deposit.exemptionReason, 'Special strategic enterprise partner waiver');
      expect(deposit.exemptedBy, 'admin_super_01');
    });
  });
}


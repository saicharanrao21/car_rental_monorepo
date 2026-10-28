import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_app/features/registration/domain/models/vendor_compliance_models.dart';

void main() {
  group('Vendor Security Deposit - Domain Models & Gateway Parsing', () {
    test('VendorDepositSummaryModel correctly parses active policy and deposit from backend JSON', () {
      final json = {
        'depositId': 'dep_live_001',
        'vendorId': 'vnd_apex_88',
        'status': 'REQUIRED',
        'requiredAmount': 25000,
        'paidAmount': 0,
        'remainingAmount': 25000,
        'availableBalance': 0,
        'heldBalance': 0,
        'refundedBalance': 0,
        'forfeitedBalance': 0,
        'isSatisfied': false,
        'isRequired': true,
        'isExempt': false,
        'refundPolicy': 'REFUNDABLE',
        'paymentProvider': 'RAZORPAY',
        'policy': {
          'version': 2,
          'isRequired': true,
          'amount': 25000,
          'currency': 'INR',
          'refundPolicy': 'REFUNDABLE',
          'deadlineDays': 14,
          'description': 'DriveGo Partner Standard Security Deposit. 100% refundable upon account settlement.',
        },
      };

      final model = VendorDepositSummaryModel.fromJson(json);

      expect(model.depositId, 'dep_live_001');
      expect(model.requiredAmount, 25000.0);
      expect(model.paidAmount, 0.0);
      expect(model.remainingAmount, 25000.0);
      expect(model.status, 'REQUIRED');
      expect(model.isRequired, true);
      expect(model.isExempt, false);
      expect(model.refundPolicy, 'REFUNDABLE');
      expect(model.paymentProvider, 'RAZORPAY');
      expect(model.policyDeadlineDays, 14);
      expect(model.policyDescription, contains('100% refundable'));
    });

    test('VendorDepositSummaryModel handles exemption and waived requirement gracefully', () {
      final json = {
        'depositId': 'dep_live_002',
        'vendorId': 'vnd_enterprise_99',
        'status': 'NOT_REQUIRED',
        'requiredAmount': 25000,
        'paidAmount': 0,
        'remainingAmount': 0,
        'isSatisfied': true,
        'isRequired': false,
        'isExempt': true,
        'exemptionReason': 'Enterprise partnership waiver approved by VP Operations',
        'refundPolicy': 'REFUNDABLE',
        'paymentProvider': 'RAZORPAY',
      };

      final model = VendorDepositSummaryModel.fromJson(json);

      expect(model.isExempt, true);
      expect(model.status, 'NOT_REQUIRED');
      expect(model.isFullyPaid, true); // isSatisfied == true
      expect(model.exemptionReason, contains('Enterprise partnership waiver'));
    });

    test('VendorDepositOrderModel correctly parses Razorpay server order payload', () {
      final json = {
        'orderId': 'order_rzp_live_test_7788',
        'amount': 2500000, // in paise
        'amountInINR': 25000,
        'currency': 'INR',
        'keyId': 'rzp_test_DriveGoVendorKey',
        'purpose': 'VENDOR_SECURITY_DEPOSIT',
        'policyVersion': 2,
        'vendor': {
          'id': 'vnd_apex_88',
          'businessName': 'Apex Mobility Ventures',
          'contactName': 'Arjun Verma',
          'email': 'arjun@apexmobility.in',
          'phone': '+919876543210',
        },
      };

      final order = VendorDepositOrderModel.fromJson(json);

      expect(order.orderId, 'order_rzp_live_test_7788');
      expect(order.amount, 2500000);
      expect(order.amountInINR, 25000.0);
      expect(order.currency, 'INR');
      expect(order.keyId, 'rzp_test_DriveGoVendorKey');
      expect(order.purpose, 'VENDOR_SECURITY_DEPOSIT');
      expect(order.policyVersion, 2);
      expect(order.businessName, 'Apex Mobility Ventures');
      expect(order.contactName, 'Arjun Verma');
      expect(order.email, 'arjun@apexmobility.in');
      expect(order.phone, '+919876543210');
    });
  });
}


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/auth/domain/repositories/vendor_auth_repository.dart';
import 'package:vendor_app/features/auth/presentation/pages/otp_verification_page.dart';
import 'package:vendor_app/features/auth/presentation/providers/vendor_auth_providers.dart';

class FakeVendorAuthRepository implements VendorAuthRepository {
  int sendOtpCallCount = 0;
  int verifyOtpCallCount = 0;
  String? lastVerifiedPhone;
  String? lastVerifiedOtp;

  VendorModel? Function(String phone, String otp)? onVerify;

  @override
  Future<void> sendOtp(String phone) async {
    sendOtpCallCount++;
  }

  @override
  Future<VendorModel?> verifyOtp(String phone, String otp) async {
    verifyOtpCallCount++;
    lastVerifiedPhone = phone;
    lastVerifiedOtp = otp;
    if (onVerify != null) {
      return onVerify!(phone, otp);
    }
    return VendorModel(
      id: 'vendor_123',
      businessName: 'DriveGo Test Fleet',
      ownerName: 'Test Owner',
      city: 'Bangalore',
      phone: phone,
      verificationStatus: 'verified',
    );
  }
}

void main() {
  group('Vendor OTP Authentication Tests (Phase 25.1)', () {
    late FakeVendorAuthRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeVendorAuthRepository();
    });

    Widget createTestWidget(Widget child) {
      return ProviderScope(
        overrides: [
          vendorAuthRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('1. OTP screen opens with empty fields and NO automatic verification',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        const OtpVerificationPage(phone: '9876543210'),
      ));
      await tester.pumpAndSettle();

      // Verify all 6 text fields are empty
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));

      for (int i = 0; i < 6; i++) {
        final textField = tester.widget<TextField>(textFields.at(i));
        expect(textField.controller?.text, isEmpty);
      }

      // Verify NO verification API call was made on mount
      expect(fakeRepo.verifyOtpCallCount, equals(0));
      expect(find.text('Invalid or expired OTP'), findsNothing);
    });

    testWidgets('2. Submitting with less than 6 digits shows validation error without calling API',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        const OtpVerificationPage(phone: '9876543210'),
      ));
      await tester.pumpAndSettle();

      // Tap verify button while empty
      await tester.tap(find.text('Verify & Proceed'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter all 6 digits of the OTP'), findsOneWidget);
      expect(fakeRepo.verifyOtpCallCount, equals(0));
    });

    testWidgets('3. Manual OTP entry triggers verification with exact entered digits',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        const OtpVerificationPage(phone: '9876543210'),
      ));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      final digits = ['8', '4', '9', '2', '0', '1'];
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), digits[i]);
      }
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify & Proceed'));
      await tester.pumpAndSettle();

      expect(fakeRepo.verifyOtpCallCount, equals(1));
      expect(fakeRepo.lastVerifiedPhone, equals('9876543210'));
      expect(fakeRepo.lastVerifiedOtp, equals('849201'));
    });

    testWidgets('4. Role mismatch exception displays clear customer account error message',
        (WidgetTester tester) async {
      fakeRepo.onVerify = (phone, otp) {
        throw Exception(
          'This phone number is registered as a customer account. Please use the Customer App to sign in, or use a different number to register as a DriveGo partner.',
        );
      };

      await tester.pumpWidget(createTestWidget(
        const OtpVerificationPage(phone: '9876543210'),
      ));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      final digits = ['1', '2', '3', '4', '5', '6'];
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), digits[i]);
      }
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify & Proceed'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('This phone number is registered as a customer account'),
        findsOneWidget,
      );
    });

    testWidgets('5. Resend OTP triggers sendOtp without referencing mock digits',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        const OtpVerificationPage(phone: '9876543210'),
      ));
      await tester.pumpAndSettle();

      // Wait out cooldown in test
      await tester.pump(const Duration(seconds: 31));

      expect(find.text('Resend OTP'), findsOneWidget);
      await tester.tap(find.text('Resend OTP'));
      await tester.pumpAndSettle();

      expect(fakeRepo.sendOtpCallCount, equals(1));
      expect(find.text('OTP resent successfully.'), findsOneWidget);
      expect(find.textContaining('Enter 123456'), findsNothing);
    });
  });
}

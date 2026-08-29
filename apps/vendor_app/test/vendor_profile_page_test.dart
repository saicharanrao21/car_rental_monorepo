import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';
import 'package:vendor_app/features/profile/presentation/pages/vendor_profile_page.dart';
import 'package:vendor_app/features/profile/presentation/providers/documents_provider.dart';

void main() {
  testWidgets('VendorProfilePage renders without error', (tester) async {
    const testVendor = VendorModel(
      id: 'v-123',
      businessName: 'DriveGo Staging Rentals',
      ownerName: 'Amit Shah',
      city: 'Mumbai',
      phone: '9876543001',
      verificationStatus: 'verified',
      subscriptionTier: 'BASIC',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorSessionProvider.overrideWith(() => MockSessionNotifier(testVendor)),
          vendorDocumentsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          home: VendorProfilePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('DriveGo Staging Rentals'), findsNWidgets(2));
    expect(find.text('Amit Shah'), findsOneWidget);
  });
}

class MockSessionNotifier extends VendorSessionNotifier {
  final VendorModel _vendor;
  MockSessionNotifier(this._vendor);

  @override
  VendorAuthState build() {
    return VendorAuthState.authenticated(_vendor);
  }
}

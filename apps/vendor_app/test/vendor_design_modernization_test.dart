import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:vendor_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:vendor_app/features/auth/presentation/pages/phone_entry_page.dart';

void main() {
  setUp(() {
    DDSTypography.useSystemFallbackInTests = true;
  });

  tearDown(() {
    DDSTypography.useSystemFallbackInTests = false;
  });

  group('DriveGo Partner (Vendor App) — Design Modernization Suite', () {
    testWidgets('1. Vendor OnboardingPage renders DriveGo brand mark, fleet feature cards, and CTA',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DriveGoBrandMark), findsOneWidget);
      expect(find.text('Grow Your Fleet Business'), findsOneWidget);
      expect(find.text('Complete Fleet Visibility'), findsOneWidget);
      expect(find.text('Verified Customer Network'), findsOneWidget);
      expect(find.text('Automated Daily Payouts'), findsOneWidget);
      expect(find.text('Partner Sign In'), findsOneWidget);
    });

    testWidgets('2. Vendor PhoneEntryPage renders partner branding, +91 code, and clean layout without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PhoneEntryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DriveGoBrandMark), findsOneWidget);
      expect(find.text('Partner Verification'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Send OTP Verification'), findsOneWidget);
      expect(find.textContaining('fleet owners'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}

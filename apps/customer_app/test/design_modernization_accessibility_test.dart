import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:customer_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:customer_app/features/auth/presentation/pages/phone_entry_page.dart';
import 'package:customer_app/features/auth/presentation/pages/otp_verification_page.dart';

double _calculateRelativeLuminance(Color color) {
  double getComponentLuminance(int component) {
    final c = component / 255.0;
    return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = getComponentLuminance(color.red);
  final g = getComponentLuminance(color.green);
  final b = getComponentLuminance(color.blue);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _calculateContrastRatio(Color foreground, Color background) {
  final l1 = _calculateRelativeLuminance(foreground);
  final l2 = _calculateRelativeLuminance(background);

  final lighter = max(l1, l2);
  final darker = min(l1, l2);

  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUp(() {
    DDSTypography.useSystemFallbackInTests = true;
  });

  tearDown(() {
    DDSTypography.useSystemFallbackInTests = false;
  });

  group('DriveGo Automotive Design System (DDS) — Accessibility & Contrast Suite', () {
    test('1. Core semantic color contrast strictly meets WCAG 2.1 AA/AAA thresholds', () {
      // Primary text on white surface
      final textOnWhiteRatio = _calculateContrastRatio(DDSColors.textPrimary, Colors.white);
      expect(textOnWhiteRatio, greaterThanOrEqualTo(14.0),
          reason: 'Primary text must provide high contrast (>= 7.0 for AAA, actual: $textOnWhiteRatio)');

      // Primary text on canvas background (#F5F7FB)
      final textOnCanvasRatio = _calculateContrastRatio(DDSColors.textPrimary, DDSColors.bgCanvas);
      expect(textOnCanvasRatio, greaterThanOrEqualTo(13.0),
          reason: 'Primary text on light canvas must exceed WCAG AAA');

      // White text on primary navy (#14243A)
      final whiteOnNavyRatio = _calculateContrastRatio(Colors.white, DDSColors.primaryNavy);
      expect(whiteOnNavyRatio, greaterThanOrEqualTo(14.0),
          reason: 'White text on Navy headers must exceed WCAG AAA');

      // White text on primary blue (#2457D6)
      final whiteOnBlueRatio = _calculateContrastRatio(Colors.white, DDSColors.primaryBlue);
      expect(whiteOnBlueRatio, greaterThanOrEqualTo(5.5),
          reason: 'White text on primary blue button must exceed WCAG AA (>= 4.5:1)');

      // Secondary text (#64748B) on white
      final secondaryOnWhiteRatio = _calculateContrastRatio(DDSColors.textSecondary, Colors.white);
      expect(secondaryOnWhiteRatio, greaterThanOrEqualTo(4.5),
          reason: 'Secondary text on white must satisfy WCAG AA (>= 4.5:1, actual: $secondaryOnWhiteRatio)');

      // White text on success green (#16845B)
      final whiteOnSuccessRatio = _calculateContrastRatio(Colors.white, DDSColors.successGreen);
      expect(whiteOnSuccessRatio, greaterThanOrEqualTo(4.5),
          reason: 'White text on success green badge must satisfy WCAG AA (>= 4.5:1)');

      // White text on error red (#C62828)
      final whiteOnErrorRatio = _calculateContrastRatio(Colors.white, DDSColors.errorRed);
      expect(whiteOnErrorRatio, greaterThanOrEqualTo(5.5),
          reason: 'White text on error red must satisfy WCAG AA (>= 4.5:1)');
    });

    testWidgets('2. DriveGoButton satisfies minimum 48x48dp interactive touch target and semantics',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: DriveGoButton(
                text: 'Confirm Booking',
                onPressed: () {},
                size: DriveGoButtonSize.standard,
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(DriveGoButton);
      expect(buttonFinder, findsOneWidget);

      final buttonSize = tester.getSize(buttonFinder);
      expect(buttonSize.height, greaterThanOrEqualTo(48.0),
          reason: 'Button height must be at least 48dp for touch target accessibility');

      // Verify Semantics
      expect(find.bySemanticsLabel('Confirm Booking'), findsOneWidget);
    });

    testWidgets('3. SocialAuthButtons adhere to platform guidelines and >= 48dp touch targets',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                SocialAuthButton.google(onPressed: () {}),
                const SizedBox(height: 12),
                SocialAuthButton.apple(onPressed: () {}),
              ],
            ),
          ),
        ),
      );

      final googleFinder = find.byKey(const Key('google_signin_button'));
      final appleFinder = find.byKey(const Key('apple_signin_button'));

      expect(googleFinder, findsOneWidget);
      expect(appleFinder, findsOneWidget);

      final googleSize = tester.getSize(googleFinder);
      final appleSize = tester.getSize(appleFinder);

      expect(googleSize.height, greaterThanOrEqualTo(48.0));
      expect(appleSize.height, greaterThanOrEqualTo(48.0));

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
    });

    testWidgets('4. OnboardingPage renders 3 automotive slides, indicators, and Get Started action',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Slide 1: Find Your Drive
      expect(find.text('Find Your Drive'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Advance to Slide 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Book With Confidence'), findsOneWidget);

      // Advance to Slide 3
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Ready When You Are'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('5. PhoneEntryPage renders DriveGo brand mark, input with +91, and social buttons without overflow',
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
      expect(find.text('Welcome to DriveGo'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Continue with Phone'), findsOneWidget);
      expect(find.byKey(const Key('google_signin_button')), findsOneWidget);
      expect(find.byKey(const Key('apple_signin_button')), findsOneWidget);
      expect(find.textContaining('Terms of Service'), findsOneWidget);

      // Ensure no rendering overflow on small screen
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. OtpVerificationPage renders clean 6-digit input and cooldown timer',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OtpVerificationPage(phone: '9876543210'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Verify Phone'), findsOneWidget);
      expect(find.textContaining('9876543210'), findsOneWidget);
      expect(find.text('Verify & Continue'), findsOneWidget);
      expect(find.textContaining('Resend in'), findsOneWidget);
    });
  });
}

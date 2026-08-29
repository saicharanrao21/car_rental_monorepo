import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DriveGo Design System (DDS) — Tokens Test Suite', () {
    test('DDSColors defines approved brand and semantic tokens', () {
      expect(DDSColors.primaryNavy, const Color(0xFF0F172A));
      expect(DDSColors.primaryBlue, const Color(0xFF1E40AF));
      expect(DDSColors.accentAmber, const Color(0xFFF59E0B));
      expect(DDSColors.electricCobalt, const Color(0xFF2563EB));

      expect(DDSColors.bgCanvas, const Color(0xFFF8FAFC));
      expect(DDSColors.surfaceCard, const Color(0xFFFFFFFF));
      expect(DDSColors.surfaceSubtle, const Color(0xFFF1F5F9));
      expect(DDSColors.borderLight, const Color(0xFFE2E8F0));
      expect(DDSColors.borderMedium, const Color(0xFFCBD5E1));

      expect(DDSColors.bgDark, const Color(0xFF0B0F19));
      expect(DDSColors.surfaceDark, const Color(0xFF151C2C));
      expect(DDSColors.borderDark, const Color(0xFF232D42));

      expect(DDSColors.textPrimary, const Color(0xFF0F172A));
      expect(DDSColors.textSecondary, const Color(0xFF475569));
      expect(DDSColors.textMuted, const Color(0xFF94A3B8));

      expect(DDSColors.successGreen, const Color(0xFF10B981));
      expect(DDSColors.successGreenBg, const Color(0xFFECFDF5));
      expect(DDSColors.warningOrange, const Color(0xFFF97316));
      expect(DDSColors.warningOrangeBg, const Color(0xFFFFF7ED));
      expect(DDSColors.errorRed, const Color(0xFFEF4444));
      expect(DDSColors.errorRedBg, const Color(0xFFFEF2F2));
      expect(DDSColors.infoBlue, const Color(0xFF3B82F6));
      expect(DDSColors.infoBlueBg, const Color(0xFFEFF6FF));

      expect(DDSColors.sponsoredGold, const Color(0xFFD97706));
      expect(DDSColors.sponsoredBg, const Color(0xFFFEF3C7));
    });

    test('AppColors backwards compatibility aliases map correctly', () {
      expect(AppColors.primary, DDSColors.primaryBlue);
      expect(AppColors.accent, DDSColors.accentAmber);
      expect(AppColors.error, DDSColors.errorRed);
      expect(AppColors.success, DDSColors.successGreen);
      expect(AppColors.backgroundLight, DDSColors.bgCanvas);
      expect(AppColors.surfaceLight, DDSColors.surfaceCard);
    });

    test('DDSSpacing tokens verify approved spacing scale and insets', () {
      expect(DDSSpacing.xxs, 4.0);
      expect(DDSSpacing.xs, 8.0);
      expect(DDSSpacing.sm, 12.0);
      expect(DDSSpacing.md, 16.0);
      expect(DDSSpacing.lg, 24.0);
      expect(DDSSpacing.xl, 32.0);
      expect(DDSSpacing.xxl, 48.0);

      expect(DDSSpacing.screenPadding, const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0));
      expect(DDSSpacing.cardPadding, const EdgeInsets.all(16.0));
      expect(DDSSpacing.modalPadding, const EdgeInsets.all(24.0));
    });

    test('DDSRadius tokens verify radius scale and helper borders', () {
      expect(DDSRadius.small, 6.0);
      expect(DDSRadius.medium, 12.0);
      expect(DDSRadius.large, 18.0);
      expect(DDSRadius.pill, 999.0);

      expect(DDSRadius.smallBorderRadius, BorderRadius.circular(6.0));
      expect(DDSRadius.mediumBorderRadius, BorderRadius.circular(12.0));
      expect(DDSRadius.largeBorderRadius, BorderRadius.circular(18.0));
      expect(DDSRadius.pillBorderRadius, BorderRadius.circular(999.0));
    });

    test('DDSElevation shadows are defined', () {
      expect(DDSElevation.subtleShadow.length, 1);
      expect(DDSElevation.cardShadow.length, 1);
      expect(DDSElevation.floatingShadow.length, 1);
      expect(DDSElevation.modalShadow.length, 1);
    });

    test('DDSMotion tokens define approved durations and curves', () {
      expect(DDSMotion.fast, const Duration(milliseconds: 150));
      expect(DDSMotion.standard, const Duration(milliseconds: 250));
      expect(DDSMotion.emphasis, const Duration(milliseconds: 350));
      expect(DDSMotion.sheet, const Duration(milliseconds: 300));
      expect(DDSMotion.standardCurve, Curves.easeInOutCubic);
    });

    test('DDSBreakpoints defines discrete screen widths', () {
      expect(DDSBreakpoints.compactMobile, 360.0);
      expect(DDSBreakpoints.standardMobile, 600.0);
      expect(DDSBreakpoints.tablet, 900.0);
      expect(DDSBreakpoints.desktop, 1200.0);
      expect(DDSBreakpoints.wideDesktop, 1440.0);
    });

    test('AppTheme generates valid Material 3 light and dark themes', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.useMaterial3, true);
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.colorScheme.primary, DDSColors.primaryBlue);
      expect(lightTheme.colorScheme.surface, DDSColors.surfaceCard);

      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.useMaterial3, true);
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.colorScheme.surface, DDSColors.surfaceDark);
    });
  });
}

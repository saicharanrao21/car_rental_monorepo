import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dds_colors.dart';

/// DriveGo Design System (DDS) — Approved Typographic Scale
/// Standardized on GoogleFonts.plusJakartaSans across 8 semantic hierarchy steps.
abstract class DDSTypography {
  /// When true, renders standard TextStyle without remote GoogleFonts fetching.
  /// Used in headless test harnesses and golden evidence captures.
  static bool useSystemFallbackInTests = false;

  static TextStyle _font({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required double letterSpacing,
    required Color color,
  }) {
    if (useSystemFallbackInTests) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );
    }
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  // 1. Display Large: 32px / 700 / 40px
  static TextStyle get displayLarge => _font(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: -0.5,
        color: DDSColors.textPrimary,
      );

  // 2. Headline Medium: 24px / 600 / 32px
  static TextStyle get headlineMedium => _font(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        letterSpacing: -0.25,
        color: DDSColors.textPrimary,
      );

  // 3. Title Large: 18px / 600 / 24px
  static TextStyle get titleLarge => _font(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        letterSpacing: 0.0,
        color: DDSColors.textPrimary,
      );

  // 4. Title Medium: 16px / 500 / 22px
  static TextStyle get titleMedium => _font(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 22 / 16,
        letterSpacing: 0.0,
        color: DDSColors.textPrimary,
      );

  // 5. Body Large: 15px / 400 / 22px
  static TextStyle get bodyLarge => _font(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 22 / 15,
        letterSpacing: 0.0,
        color: DDSColors.textPrimary,
      );

  // 6. Body Medium: 14px / 400 / 20px
  static TextStyle get bodyMedium => _font(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        letterSpacing: 0.0,
        color: DDSColors.textSecondary,
      );

  // 7. Label Large: 14px / 600 / 18px
  static TextStyle get labelLarge => _font(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 18 / 14,
        letterSpacing: 0.2,
        color: DDSColors.textPrimary,
      );

  // 8. Label Small: 11px / 600 / 14px
  static TextStyle get labelSmall => _font(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 14 / 11,
        letterSpacing: 0.4,
        color: DDSColors.textSecondary,
      );

  // Special Numeric Tariff / Price Display: 20px / 800 / 24px
  static TextStyle get priceDisplay => _font(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 24 / 20,
        letterSpacing: -0.5,
        color: DDSColors.accentAmber,
      );

  /// Convert to Material 3 TextTheme
  static TextTheme get lightTextTheme => TextTheme(
        displayLarge: displayLarge,
        headlineMedium: headlineMedium,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        labelLarge: labelLarge,
        labelSmall: labelSmall,
      );

  /// Convert to Material 3 Dark TextTheme
  static TextTheme get darkTextTheme => TextTheme(
        displayLarge: displayLarge.copyWith(color: DDSColors.textPrimaryDark),
        headlineMedium: headlineMedium.copyWith(color: DDSColors.textPrimaryDark),
        titleLarge: titleLarge.copyWith(color: DDSColors.textPrimaryDark),
        titleMedium: titleMedium.copyWith(color: DDSColors.textPrimaryDark),
        bodyLarge: bodyLarge.copyWith(color: DDSColors.textPrimaryDark),
        bodyMedium: bodyMedium.copyWith(color: DDSColors.textSecondaryDark),
        labelLarge: labelLarge.copyWith(color: DDSColors.textPrimaryDark),
        labelSmall: labelSmall.copyWith(color: DDSColors.textSecondaryDark),
      );
}

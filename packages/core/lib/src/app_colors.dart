import 'package:flutter/material.dart';
import 'dds_colors.dart';

/// Legacy AppColors wrapper pointing directly to DDSColors
/// Maintained for 100% backward compatibility across existing feature pages.
class AppColors {
  // --- Brand Colors ---
  static const Color primary = DDSColors.primaryBlue;
  static const Color primaryNavy = DDSColors.primaryNavy;
  static const Color accent = DDSColors.accentAmber;
  static const Color error = DDSColors.errorRed;
  static const Color success = DDSColors.successGreen;
  static const Color onPrimary = Colors.white;

  // --- Light Mode Surfaces ---
  static const Color backgroundLight = DDSColors.bgCanvas;
  static const Color surfaceLight = DDSColors.surfaceCard;
  static const Color cardLight = DDSColors.surfaceCard;
  static const Color inputFillLight = DDSColors.surfaceSubtle;
  static const Color dividerLight = DDSColors.borderLight;

  // --- Dark Mode Surfaces ---
  static const Color backgroundDark = DDSColors.bgDark;
  static const Color surfaceDark = DDSColors.surfaceDark;
  static const Color cardDark = DDSColors.surfaceDark;
  static const Color inputFillDark = Color(0xFF1E2638);
  static const Color dividerDark = DDSColors.borderDark;

  // --- Light Mode Text ---
  static const Color textPrimaryLight = DDSColors.textPrimary;
  static const Color textSecondaryLight = DDSColors.textSecondary;
  static const Color textHintLight = DDSColors.textMuted;

  // --- Dark Mode Text ---
  static const Color textPrimaryDark = DDSColors.textPrimaryDark;
  static const Color textSecondaryDark = DDSColors.textSecondaryDark;
  static const Color textHintDark = DDSColors.textMutedDark;

  // --- Semantic / Status ---
  static const Color starYellow = DDSColors.accentAmber;
  static const Color sponsored = DDSColors.sponsoredGold;

  // Legacy aliases
  static const Color background = backgroundLight;
  static const Color surface = surfaceLight;
}

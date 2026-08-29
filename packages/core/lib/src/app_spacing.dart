import 'package:flutter/material.dart';
import 'dds_spacing.dart';

/// Legacy AppSpacing wrapper pointing directly to DDSSpacing tokens.
/// Maintained for 100% backward compatibility across all apps.
class AppSpacing {
  AppSpacing._();

  // --- Base Spacing Scale ---
  static const double xxs = DDSSpacing.xxs;
  static const double xs = DDSSpacing.xxs; // 4.0
  static const double sm = DDSSpacing.xs;  // 8.0
  static const double md = DDSSpacing.md;  // 16.0
  static const double lg = DDSSpacing.lg;  // 24.0
  static const double xl = DDSSpacing.xl;  // 32.0
  static const double xxl = DDSSpacing.xxl; // 48.0

  // --- Standard Inset Presets ---
  static const EdgeInsets pagePadding = DDSSpacing.screenPadding;
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: DDSSpacing.md);
  static const EdgeInsets pageVertical = EdgeInsets.symmetric(vertical: DDSSpacing.md);
  
  static const EdgeInsets cardPadding = DDSSpacing.cardPadding;
  static const EdgeInsets cardPaddingSm = DDSSpacing.cardPaddingCompact;
  static const EdgeInsets cardPaddingXs = EdgeInsets.all(DDSSpacing.xxs);

  static const EdgeInsets dialogPadding = DDSSpacing.modalPadding;
  static const EdgeInsets bottomSheetPadding = DDSSpacing.bottomSheetPadding;

  // --- Layout Section & Item Gaps ---
  static const double sectionGap = DDSSpacing.sectionGap;
  static const double itemGap = DDSSpacing.itemGap;
  static const double elementGap = DDSSpacing.elementGap;
  static const double inlineGap = DDSSpacing.inlineGap;

  // --- Component Specific Heights ---
  static const double carCardHorizontalHeight = 360.0;
}

import 'package:flutter/material.dart';

/// Standardized Spacing & Layout Tokens for Car Rental Monorepo
class AppSpacing {
  AppSpacing._();

  // --- Base Spacing Scale ---
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // --- Standard Inset Presets ---
  static const EdgeInsets pagePadding = EdgeInsets.all(md);
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets pageVertical = EdgeInsets.symmetric(vertical: md);
  
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingSm = EdgeInsets.all(sm);
  static const EdgeInsets cardPaddingXs = EdgeInsets.all(xs);

  static const EdgeInsets dialogPadding = EdgeInsets.all(lg);
  static const EdgeInsets bottomSheetPadding = EdgeInsets.all(lg);

  // --- Layout Section & Item Gaps ---
  static const double sectionGap = lg;   // 24.0px standard gap between page sections
  static const double itemGap = md;      // 16.0px gap between list items / cards
  static const double elementGap = sm;   // 8.0px gap between labels, icons, inputs
  static const double inlineGap = xs;    // 4.0px micro-gap between text/icon pairs

  // --- Component Specific Heights ---
  static const double carCardHorizontalHeight = 360.0; // Safe bounded height for CarCard in horizontal lists
}

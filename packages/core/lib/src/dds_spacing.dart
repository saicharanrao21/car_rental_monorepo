import 'package:flutter/material.dart';

/// DriveGo Design System (DDS) — Approved Spacing Tokens
/// Standard 8-step spacing scale and layout insets.
abstract class DDSSpacing {
  // --- Discrete Spacing Scale ---
  static const double xxs = 4.0;
  static const double xs  = 8.0;
  static const double sm  = 12.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;

  // --- Layout Insets & Padding Presets ---
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(12.0);
  static const EdgeInsets modalPadding = EdgeInsets.all(24.0);
  static const EdgeInsets bottomSheetPadding = EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 24.0);

  // --- Gap Constants ---
  static const double sectionGap = 24.0;
  static const double itemGap = 16.0;
  static const double elementGap = 8.0;
  static const double inlineGap = 4.0;
}

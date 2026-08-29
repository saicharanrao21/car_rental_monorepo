import 'package:flutter/material.dart';

/// DriveGo Design System (DDS) — Approved Elevation & Shadow Tokens
abstract class DDSElevation {
  static const double none = 0.0;
  static const double subtle = 1.0;
  static const double card = 2.0;
  static const double floating = 4.0;
  static const double modal = 8.0;

  /// Subtle Elevation Shadow (1dp)
  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Standard Card Elevation Shadow (2dp)
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Floating Action Button & Sticky Bar Shadow (4dp)
  static List<BoxShadow> get floatingShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Bottom Sheet & Dialog Shadow (8dp)
  static List<BoxShadow> get modalShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}

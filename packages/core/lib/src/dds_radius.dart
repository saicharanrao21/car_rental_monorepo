import 'package:flutter/material.dart';

/// DriveGo Design System (DDS) — Approved Radius Tokens
abstract class DDSRadius {
  // --- Scale Values ---
  static const double small = 6.0;      // Chips, small tags, mini indicators
  static const double medium = 12.0;    // Standard cards, inputs, buttons
  static const double large = 18.0;     // Modals, bottom sheets, hero containers
  static const double pill = 999.0;     // Pill buttons, circular avatars, round chips

  // --- BorderRadius Helpers ---
  static BorderRadius get smallBorderRadius => BorderRadius.circular(small);
  static BorderRadius get mediumBorderRadius => BorderRadius.circular(medium);
  static BorderRadius get largeBorderRadius => BorderRadius.circular(large);
  static BorderRadius get pillBorderRadius => BorderRadius.circular(pill);

  // --- Sheet/Modal Rounded Tops ---
  static const BorderRadius sheetTopRadius = BorderRadius.vertical(top: Radius.circular(large));
}

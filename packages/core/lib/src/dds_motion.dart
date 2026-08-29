import 'package:flutter/material.dart';

/// DriveGo Design System (DDS) — Approved Motion & Animation Tokens
abstract class DDSMotion {
  // --- Durations ---
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration emphasis = Duration(milliseconds: 350);
  static const Duration sheet = Duration(milliseconds: 300);

  // --- Curves ---
  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
}

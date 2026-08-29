import 'package:flutter/material.dart';

/// DriveGo Design System (DDS) — Approved Responsive Breakpoint Tokens
abstract class DDSBreakpoints {
  // --- Breakpoint Widths (px) ---
  static const double compactMobile = 360.0;
  static const double standardMobile = 600.0;
  static const double tablet = 900.0;
  static const double desktop = 1200.0;
  static const double wideDesktop = 1440.0;

  // --- Context Helpers ---
  static bool isCompactMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactMobile;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < standardMobile;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= standardMobile &&
      MediaQuery.sizeOf(context).width < desktop;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideDesktop;
}

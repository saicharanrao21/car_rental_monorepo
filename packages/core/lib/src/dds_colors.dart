import 'package:flutter/material.dart';

/// DriveGo Design System (DDS) — Approved Semantic Color Tokens
/// Unified palette for Customer App, Vendor App, and Admin Control Tower.
abstract class DDSColors {
  // --- Brand Core ---
  static const Color primaryNavy = Color(0xFF14243A);      // Deep Automotive Navy (Headers / Dark elements)
  static const Color primaryBlue = Color(0xFF2457D6);      // Electric Blue (Primary Actions / Brand Identity)
  static const Color accentAmber = Color(0xFFF59E0B);      // Amber (Highlights / Ratings / Pricing accents)
  static const Color accentTeal = Color(0xFF16A394);       // Automotive Teal (Vendor partner / Green energy badges)
  static const Color electricCobalt = Color(0xFF2563EB);   // Electric Blue (Active state / Interactive focus)

  // --- Light Surfaces & Canvases ---
  static const Color bgCanvas = Color(0xFFF5F7FB);         // Modern Light Canvas (Scaffold background)
  static const Color surfaceCard = Color(0xFFFFFFFF);      // Pure White (Cards & Sheets)
  static const Color surfaceSubtle = Color(0xFFEDF2F9);    // Subtle Surface Fill (Input fills & Chips)
  static const Color borderLight = Color(0xFFDFE5EF);      // Subtle Border (Dividers & Subtle borders)
  static const Color borderMedium = Color(0xFFCBD5E1);     // Slate 300 (Input enabled borders)

  // --- Dark Surfaces & Canvases (Admin Sidebar & Dark Mode Foundation) ---
  static const Color bgDark = Color(0xFF0B0F19);           // Midnight Canvas
  static const Color surfaceDark = Color(0xFF141B2D);      // Dark Surface
  static const Color surfaceDarkElevated = Color(0xFF1E2638); // Elevated Dark Card
  static const Color borderDark = Color(0xFF232D42);        // Muted Dark Border

  // --- Typography (Light Mode) ---
  static const Color textPrimary = Color(0xFF172033);      // 95% Contrast Text (WCAG AAA >= 15:1)
  static const Color textSecondary = Color(0xFF64748B);    // 65% Contrast Text (WCAG AA >= 4.5:1)
  static const Color textMuted = Color(0xFF94A3B8);        // 45% Contrast (Hints & Placeholders)

  // --- Typography (Dark Mode) ---
  static const Color textPrimaryDark = Color(0xFFF8FAFC);  // High contrast light text
  static const Color textSecondaryDark = Color(0xFF94A3B8);// Secondary dark text
  static const Color textMutedDark = Color(0xFF64748B);    // Muted dark text

  // --- Status & Functional Colors ---
  static const Color successGreen = Color(0xFF16845B);     // Accessible Emerald Green (WCAG AA >= 4.5:1)
  static const Color successGreenBg = Color(0xFFECFDF5);   // Emerald 50
  static const Color warningOrange = Color(0xFFB76E00);    // Accessible Dark Amber/Warning (WCAG AA >= 4.5:1)
  static const Color warningOrangeBg = Color(0xFFFFFBEB);  // Amber 50
  static const Color errorRed = Color(0xFFC62828);         // Accessible Deep Red (WCAG AA >= 4.5:1)
  static const Color errorRedBg = Color(0xFFFEF2F2);       // Red 50
  static const Color infoBlue = Color(0xFF2457D6);         // Info Blue
  static const Color infoBlueBg = Color(0xFFEFF6FF);       // Blue 50

  // --- Marketplace & Sponsorship ---
  static const Color sponsoredGold = Color(0xFFD97706);    // Amber 600
  static const Color sponsoredBg = Color(0xFFFEF3C7);      // Amber 100
  static const Color verifiedBadge = Color(0xFF059669);    // Emerald 600
}

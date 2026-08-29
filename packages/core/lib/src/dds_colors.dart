import 'package:flutter/material.dart';

/// DriveGo Design System (DDS) — Approved Semantic Color Tokens
/// Unified palette for Customer App, Vendor App, and Admin Control Tower.
abstract class DDSColors {
  // --- Brand Core ---
  static const Color primaryNavy = Color(0xFF0F172A);      // Slate 900 (Enterprise / High-contrast headers)
  static const Color primaryBlue = Color(0xFF1E40AF);      // Deep Indigo (Primary Actions / Brand Identity)
  static const Color accentAmber = Color(0xFFF59E0B);      // Amber (Highlights / Ratings / Pricing accents)
  static const Color electricCobalt = Color(0xFF2563EB);   // Electric Blue (Active state / Interactive focus)

  // --- Light Surfaces & Canvases ---
  static const Color bgCanvas = Color(0xFFF8FAFC);         // Slate 50 (Scaffold background)
  static const Color surfaceCard = Color(0xFFFFFFFF);      // Pure White (Cards & Sheets)
  static const Color surfaceSubtle = Color(0xFFF1F5F9);    // Slate 100 (Input fills & Chips)
  static const Color borderLight = Color(0xFFE2E8F0);      // Slate 200 (Dividers & Subtle borders)
  static const Color borderMedium = Color(0xFFCBD5E1);     // Slate 300 (Input enabled borders)

  // --- Dark Surfaces & Canvases (Admin Sidebar & Dark Mode Foundation) ---
  static const Color bgDark = Color(0xFF0B0F19);           // Midnight Canvas
  static const Color surfaceDark = Color(0xFF151C2C);       // Dark Slate Surface
  static const Color surfaceDarkElevated = Color(0xFF1E2638); // Elevated Dark Card
  static const Color borderDark = Color(0xFF232D42);        // Muted Dark Border

  // --- Typography (Light Mode) ---
  static const Color textPrimary = Color(0xFF0F172A);      // 90% Contrast Text
  static const Color textSecondary = Color(0xFF475569);    // 65% Contrast Text
  static const Color textMuted = Color(0xFF94A3B8);        // 45% Contrast (Hints & Placeholders)

  // --- Typography (Dark Mode) ---
  static const Color textPrimaryDark = Color(0xFFF8FAFC);  // High contrast light text
  static const Color textSecondaryDark = Color(0xFF94A3B8);// Secondary dark text
  static const Color textMutedDark = Color(0xFF64748B);    // Muted dark text

  // --- Status & Functional Colors ---
  static const Color successGreen = Color(0xFF10B981);     // Emerald 500
  static const Color successGreenBg = Color(0xFFECFDF5);   // Emerald 50
  static const Color warningOrange = Color(0xFFF97316);    // Orange 500
  static const Color warningOrangeBg = Color(0xFFFFF7ED);  // Orange 50
  static const Color errorRed = Color(0xFFEF4444);         // Red 500
  static const Color errorRedBg = Color(0xFFFEF2F2);       // Red 50
  static const Color infoBlue = Color(0xFF3B82F6);          // Blue 500
  static const Color infoBlueBg = Color(0xFFEFF6FF);       // Blue 50

  // --- Marketplace & Sponsorship ---
  static const Color sponsoredGold = Color(0xFFD97706);    // Amber 600
  static const Color sponsoredBg = Color(0xFFFEF3C7);      // Amber 100
  static const Color verifiedBadge = Color(0xFF059669);    // Emerald 600
}

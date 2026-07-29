import 'package:flutter/material.dart';

class AppColors {
  // --- Brand Colors ---
  static const Color primary = Color(0xFF1A237E); // Deep Indigo
  static const Color accent = Color(0xFFFF6F00); // Amber Orange
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color onPrimary = Colors.white;

  // --- Light Mode Surfaces ---
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color inputFillLight = Color(0xFFF0F2F5);
  static const Color dividerLight = Color(0xFFE0E3E8);

  // --- Dark Mode Surfaces ---
  static const Color backgroundDark = Color(0xFF121318);
  static const Color surfaceDark = Color(0xFF1E2028);
  static const Color cardDark = Color(0xFF252830);
  static const Color inputFillDark = Color(0xFF2C2F3A);
  static const Color dividerDark = Color(0xFF383B47);

  // --- Light Mode Text ---
  static const Color textPrimaryLight = Color(0xFF1A1C23);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textHintLight = Color(0xFF9CA3AF);

  // --- Dark Mode Text ---
  static const Color textPrimaryDark = Color(0xFFE8EAF0);
  static const Color textSecondaryDark = Color(0xFF9DA5B4);
  static const Color textHintDark = Color(0xFF6B7280);

  // --- Semantic / Status (mode-independent) ---
  static const Color starYellow = Color(0xFFFFB800);
  static const Color sponsored = Color(0xFFFF6F00);

  // Legacy aliases kept for backward compat
  static const Color background = backgroundLight;
  static const Color surface = surfaceLight;
}

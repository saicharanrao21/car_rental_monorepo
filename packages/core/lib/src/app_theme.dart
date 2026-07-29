import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: const Color(0xFFDDE1FF),
        onPrimaryContainer: const Color(0xFF00105C),
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFFFDDB8),
        onSecondaryContainer: const Color(0xFF2C1600),
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: const Color(0xFFFFDAD6),
        onErrorContainer: const Color(0xFF410002),
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        surfaceContainerHighest: AppColors.inputFillLight,
        surfaceContainerHigh: const Color(0xFFE8EBF0),
        onSurfaceVariant: AppColors.textSecondaryLight,
        outline: AppColors.dividerLight,
        outlineVariant: const Color(0xFFCACDD6),
        inverseSurface: const Color(0xFF2E3038),
        onInverseSurface: const Color(0xFFEFF0F7),
        inversePrimary: const Color(0xFFBAC3FF),
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceTint: AppColors.primary,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.onPrimary),
        actionsIconTheme: IconThemeData(color: AppColors.onPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFillLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.dividerLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.dividerLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.textHintLight),
        labelStyle: const TextStyle(color: AppColors.textSecondaryLight),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondaryLight,
        textColor: AppColors.textPrimaryLight,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: const Color(0xFFBAC3FF),
        onPrimary: const Color(0xFF00105C),
        primaryContainer: const Color(0xFF001689),
        onPrimaryContainer: const Color(0xFFDDE1FF),
        secondary: const Color(0xFFFFB77A),
        onSecondary: const Color(0xFF4A2800),
        secondaryContainer: const Color(0xFF6A3C00),
        onSecondaryContainer: const Color(0xFFFFDDB8),
        error: const Color(0xFFFFB4AB),
        onError: const Color(0xFF690005),
        errorContainer: const Color(0xFF93000A),
        onErrorContainer: const Color(0xFFFFDAD6),
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        surfaceContainerHighest: AppColors.inputFillDark,
        surfaceContainerHigh: const Color(0xFF32353F),
        onSurfaceVariant: AppColors.textSecondaryDark,
        outline: AppColors.dividerDark,
        outlineVariant: const Color(0xFF444855),
        inverseSurface: const Color(0xFFE2E2EC),
        onInverseSurface: const Color(0xFF2E3038),
        inversePrimary: AppColors.primary,
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceTint: const Color(0xFFBAC3FF),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
        actionsIconTheme: IconThemeData(color: AppColors.textPrimaryDark),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.dividerDark, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFBAC3FF),
          foregroundColor: const Color(0xFF00105C),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFillDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.dividerDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.dividerDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFBAC3FF), width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.textHintDark),
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: Color(0xFFBAC3FF),
        unselectedItemColor: AppColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondaryDark,
        textColor: AppColors.textPrimaryDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

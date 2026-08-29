import 'package:flutter/material.dart';
import 'dds_colors.dart';
import 'dds_typography.dart';
import 'dds_radius.dart';

/// Modernized Material 3 AppTheme driven by DriveGo Design System (DDS) tokens
class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: DDSColors.primaryBlue,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFDBEAFE),
        onPrimaryContainer: DDSColors.primaryNavy,
        secondary: DDSColors.accentAmber,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFFEF3C7),
        onSecondaryContainer: const Color(0xFF78350F),
        error: DDSColors.errorRed,
        onError: Colors.white,
        errorContainer: DDSColors.errorRedBg,
        onErrorContainer: const Color(0xFF7F1D1D),
        surface: DDSColors.surfaceCard,
        onSurface: DDSColors.textPrimary,
        surfaceContainerHighest: DDSColors.surfaceSubtle,
        surfaceContainerHigh: const Color(0xFFE2E8F0),
        onSurfaceVariant: DDSColors.textSecondary,
        outline: DDSColors.borderMedium,
        outlineVariant: DDSColors.borderLight,
        inverseSurface: DDSColors.surfaceDark,
        onInverseSurface: DDSColors.textPrimaryDark,
        inversePrimary: const Color(0xFF93C5FD),
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceTint: DDSColors.primaryBlue,
      ),
    );

    return base.copyWith(
      textTheme: DDSTypography.lightTextTheme,
      scaffoldBackgroundColor: DDSColors.bgCanvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: DDSColors.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: DDSColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: DDSRadius.mediumBorderRadius,
          side: const BorderSide(color: DDSColors.borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DDSColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: DDSRadius.mediumBorderRadius,
          ),
          textStyle: DDSTypography.labelLarge.copyWith(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DDSColors.primaryBlue,
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: DDSColors.primaryBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: DDSRadius.mediumBorderRadius,
          ),
          textStyle: DDSTypography.labelLarge.copyWith(color: DDSColors.primaryBlue),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DDSColors.primaryBlue,
          textStyle: DDSTypography.labelLarge.copyWith(color: DDSColors.primaryBlue),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DDSColors.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: DDSRadius.mediumBorderRadius,
          borderSide: const BorderSide(color: DDSColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DDSRadius.mediumBorderRadius,
          borderSide: const BorderSide(color: DDSColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DDSRadius.mediumBorderRadius,
          borderSide: const BorderSide(color: DDSColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DDSRadius.mediumBorderRadius,
          borderSide: const BorderSide(color: DDSColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: DDSRadius.mediumBorderRadius,
          borderSide: const BorderSide(color: DDSColors.errorRed, width: 2),
        ),
        hintStyle: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted),
        labelStyle: DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: DDSColors.surfaceCard,
        selectedItemColor: DDSColors.primaryBlue,
        unselectedItemColor: DDSColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: DDSColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: DDSColors.textSecondary,
        textColor: DDSColors.textPrimary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: DDSColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: DDSRadius.largeBorderRadius),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DDSColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: DDSRadius.sheetTopRadius),
      ),
    );
  }

  /// Dark Theme Foundation for Future Adoption
  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: const Color(0xFF60A5FA),
        onPrimary: DDSColors.primaryNavy,
        primaryContainer: DDSColors.surfaceDarkElevated,
        onPrimaryContainer: const Color(0xFFDBEAFE),
        secondary: DDSColors.accentAmber,
        onSecondary: Colors.black,
        secondaryContainer: const Color(0xFF78350F),
        onSecondaryContainer: const Color(0xFFFEF3C7),
        error: DDSColors.errorRed,
        onError: Colors.white,
        errorContainer: const Color(0xFF7F1D1D),
        onErrorContainer: DDSColors.errorRedBg,
        surface: DDSColors.surfaceDark,
        onSurface: DDSColors.textPrimaryDark,
        surfaceContainerHighest: DDSColors.surfaceDarkElevated,
        surfaceContainerHigh: const Color(0xFF232D42),
        onSurfaceVariant: DDSColors.textSecondaryDark,
        outline: DDSColors.borderDark,
        outlineVariant: const Color(0xFF1E2638),
        inverseSurface: DDSColors.surfaceCard,
        onInverseSurface: DDSColors.textPrimary,
        inversePrimary: DDSColors.primaryBlue,
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceTint: const Color(0xFF60A5FA),
      ),
    );

    return base.copyWith(
      textTheme: DDSTypography.darkTextTheme,
      scaffoldBackgroundColor: DDSColors.bgDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: DDSColors.surfaceDark,
        foregroundColor: DDSColors.textPrimaryDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: DDSColors.textPrimaryDark),
        actionsIconTheme: IconThemeData(color: DDSColors.textPrimaryDark),
      ),
      cardTheme: CardThemeData(
        color: DDSColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: DDSRadius.mediumBorderRadius,
          side: const BorderSide(color: DDSColors.borderDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: DDSColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: DDSRadius.largeBorderRadius),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DDSColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: DDSRadius.sheetTopRadius),
      ),
    );
  }
}

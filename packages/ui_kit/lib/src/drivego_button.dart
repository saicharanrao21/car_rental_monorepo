import 'package:flutter/material.dart';
import 'package:core/core.dart';

enum DriveGoButtonVariant {
  primary,
  secondary,
  tertiary,
  destructive,
}

enum DriveGoButtonSize {
  compact,  // 40px height
  standard, // 48px height
  large,    // 54px height
}

/// DriveGo Design System (DDS) — Standard Button Component
/// Accessible, responsive button supporting primary, secondary, tertiary, and destructive variants.
class DriveGoButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final DriveGoButtonVariant variant;
  final DriveGoButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const DriveGoButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = DriveGoButtonVariant.primary,
    this.size = DriveGoButtonSize.standard,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  double get _height {
    switch (size) {
      case DriveGoButtonSize.compact:
        return 40.0;
      case DriveGoButtonSize.standard:
        return 48.0;
      case DriveGoButtonSize.large:
        return 54.0;
    }
  }

  TextStyle get _textStyle {
    switch (size) {
      case DriveGoButtonSize.compact:
        return DDSTypography.labelSmall.copyWith(fontSize: 12, fontWeight: FontWeight.w600);
      case DriveGoButtonSize.standard:
        return DDSTypography.labelLarge;
      case DriveGoButtonSize.large:
        return DDSTypography.labelLarge.copyWith(fontSize: 16, fontWeight: FontWeight.bold);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = _height;

    Widget childContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          icon!,
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            style: _textStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );

    if (isLoading) {
      childContent = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: variant == DriveGoButtonVariant.secondary || variant == DriveGoButtonVariant.tertiary
              ? DDSColors.primaryBlue
              : Colors.white,
        ),
      );
    }

    Widget button;

    switch (variant) {
      case DriveGoButtonVariant.primary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? DDSColors.primaryBlue,
            foregroundColor: foregroundColor ?? Colors.white,
            minimumSize: Size(isFullWidth ? double.infinity : 80, effectiveHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: DDSRadius.mediumBorderRadius),
          ),
          child: childContent,
        );
        break;

      case DriveGoButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: foregroundColor ?? DDSColors.primaryBlue,
            minimumSize: Size(isFullWidth ? double.infinity : 80, effectiveHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            side: BorderSide(color: backgroundColor ?? DDSColors.primaryBlue, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: DDSRadius.mediumBorderRadius),
          ),
          child: childContent,
        );
        break;

      case DriveGoButtonVariant.tertiary:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: foregroundColor ?? DDSColors.primaryBlue,
            minimumSize: Size(isFullWidth ? double.infinity : 80, effectiveHeight),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: DDSRadius.mediumBorderRadius),
          ),
          child: childContent,
        );
        break;

      case DriveGoButtonVariant.destructive:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? DDSColors.errorRed,
            foregroundColor: foregroundColor ?? Colors.white,
            minimumSize: Size(isFullWidth ? double.infinity : 80, effectiveHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: DDSRadius.mediumBorderRadius),
          ),
          child: childContent,
        );
        break;
    }

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

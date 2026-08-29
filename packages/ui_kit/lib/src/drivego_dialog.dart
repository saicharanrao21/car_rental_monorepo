import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'drivego_button.dart';

/// DriveGo Design System (DDS) — Standard Dialog Utilities
class DriveGoDialog {
  /// Show standard confirmation or alert dialog
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DDSColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: DDSRadius.largeBorderRadius),
        contentPadding: DDSSpacing.modalPadding,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDestructive ? DDSColors.errorRedBg : DDSColors.surfaceSubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isDestructive ? DDSColors.errorRed : DDSColors.primaryBlue,
                ),
              ),
              const Gap(16),
            ],
            Text(
              title,
              style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            Text(
              message,
              style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: DriveGoButton(
                    text: cancelText,
                    variant: DriveGoButtonVariant.tertiary,
                    onPressed: () => Navigator.of(context).pop(false),
                    size: DriveGoButtonSize.standard,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: DriveGoButton(
                    text: confirmText,
                    variant: isDestructive ? DriveGoButtonVariant.destructive : DriveGoButtonVariant.primary,
                    onPressed: () => Navigator.of(context).pop(true),
                    size: DriveGoButtonSize.standard,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

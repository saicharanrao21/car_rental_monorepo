import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'drivego_button.dart';

/// DriveGo Design System (DDS) — Standard Empty State Component
class DriveGoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onActionPressed;
  final String? secondaryActionText;
  final VoidCallback? onSecondaryActionPressed;

  const DriveGoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onActionPressed,
    this.secondaryActionText,
    this.onSecondaryActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DDSSpacing.modalPadding,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: DDSColors.surfaceSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(color: DDSColors.borderLight, width: 1),
                ),
                child: Icon(
                  icon,
                  size: 44,
                  color: DDSColors.textMuted,
                ),
              ),
              const Gap(20),
              Text(
                title,
                style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const Gap(8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  subtitle,
                  style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
              if (actionText != null && onActionPressed != null) ...[
                const Gap(24),
                DriveGoButton(
                  text: actionText!,
                  onPressed: onActionPressed,
                  isFullWidth: false,
                  size: DriveGoButtonSize.standard,
                ),
              ],
              if (secondaryActionText != null && onSecondaryActionPressed != null) ...[
                const Gap(12),
                DriveGoButton(
                  text: secondaryActionText!,
                  onPressed: onSecondaryActionPressed,
                  variant: DriveGoButtonVariant.tertiary,
                  isFullWidth: false,
                  size: DriveGoButtonSize.compact,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'drivego_button.dart';

/// DriveGo Design System (DDS) — Standard Error State Component
class DriveGoErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryText;
  final String? secondaryActionText;
  final VoidCallback? onSecondaryAction;

  const DriveGoErrorState({
    super.key,
    this.title = 'Unable to Load Content',
    required this.message,
    required this.onRetry,
    this.retryText = 'Try Again',
    this.secondaryActionText,
    this.onSecondaryAction,
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
                  color: DDSColors.errorRedBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: DDSColors.errorRed.withValues(alpha: 0.2), width: 1),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 44,
                  color: DDSColors.errorRed,
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
                  message,
                  style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
              const Gap(24),
              DriveGoButton(
                text: retryText,
                onPressed: onRetry,
                isFullWidth: false,
                size: DriveGoButtonSize.standard,
              ),
              if (secondaryActionText != null && onSecondaryAction != null) ...[
                const Gap(12),
                DriveGoButton(
                  text: secondaryActionText!,
                  onPressed: onSecondaryAction,
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

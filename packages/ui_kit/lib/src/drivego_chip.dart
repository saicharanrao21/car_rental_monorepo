import 'package:flutter/material.dart';
import 'package:core/core.dart';

/// DriveGo Design System (DDS) — Standard Interactive Chip Component
class DriveGoChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? icon;
  final Widget? avatar;
  final bool showCheckmark;

  const DriveGoChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
    this.avatar,
    this.showCheckmark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DDSRadius.pillBorderRadius,
        child: AnimatedContainer(
          duration: DDSMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? DDSColors.primaryNavy : DDSColors.surfaceCard,
            borderRadius: DDSRadius.pillBorderRadius,
            border: Border.all(
              color: isSelected ? DDSColors.primaryNavy : DDSColors.borderMedium,
              width: 1,
            ),
            boxShadow: isSelected ? DDSElevation.subtleShadow : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected && showCheckmark) ...[
                const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ] else if (icon != null) ...[
                icon!,
                const SizedBox(width: 6),
              ] else if (avatar != null) ...[
                avatar!,
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: DDSTypography.labelLarge.copyWith(
                  fontSize: 13,
                  color: isSelected ? Colors.white : DDSColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

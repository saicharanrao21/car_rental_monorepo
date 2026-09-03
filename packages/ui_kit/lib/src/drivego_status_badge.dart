import 'package:flutter/material.dart';
import 'package:core/core.dart';

enum DriveGoBadgeVariant {
  success,
  warning,
  error,
  info,
  neutral,
  sponsored,
  verified,
}

/// DriveGo Design System (DDS) — Standard Status Badge Component
class DriveGoStatusBadge extends StatelessWidget {
  final String label;
  final DriveGoBadgeVariant? variant;
  final Widget? icon;

  const DriveGoStatusBadge({
    super.key,
    required this.label,
    this.variant,
    this.icon,
  });

  static DriveGoBadgeVariant _deriveVariant(String status) {
    switch (status.toLowerCase().trim()) {
      case 'confirmed':
      case 'completed':
      case 'verified':
      case 'approved':
      case 'active':
        return DriveGoBadgeVariant.success;

      case 'pending':
      case 'under review':
      case 'review':
      case 'return_pending':
      case 'return pending':
        return DriveGoBadgeVariant.warning;

      case 'cancelled':
      case 'rejected':
      case 'suspended':
      case 'error':
      case 'failed':
        return DriveGoBadgeVariant.error;

      case 'ongoing':
      case 'in transit':
      case 'info':
      case 'handover_ready':
      case 'handover ready':
        return DriveGoBadgeVariant.info;

      case 'sponsored':
      case 'featured':
        return DriveGoBadgeVariant.sponsored;

      default:
        return DriveGoBadgeVariant.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveVariant = variant ?? _deriveVariant(label);

    Color fg;
    Color bg;
    Color border;

    switch (effectiveVariant) {
      case DriveGoBadgeVariant.success:
        fg = DDSColors.successGreen;
        bg = DDSColors.successGreenBg;
        border = DDSColors.successGreen.withValues(alpha: 0.3);
        break;
      case DriveGoBadgeVariant.warning:
        fg = DDSColors.warningOrange;
        bg = DDSColors.warningOrangeBg;
        border = DDSColors.warningOrange.withValues(alpha: 0.3);
        break;
      case DriveGoBadgeVariant.error:
        fg = DDSColors.errorRed;
        bg = DDSColors.errorRedBg;
        border = DDSColors.errorRed.withValues(alpha: 0.3);
        break;
      case DriveGoBadgeVariant.info:
        fg = DDSColors.infoBlue;
        bg = DDSColors.infoBlueBg;
        border = DDSColors.infoBlue.withValues(alpha: 0.3);
        break;
      case DriveGoBadgeVariant.sponsored:
        fg = DDSColors.sponsoredGold;
        bg = DDSColors.sponsoredBg;
        border = DDSColors.sponsoredGold.withValues(alpha: 0.3);
        break;
      case DriveGoBadgeVariant.verified:
        fg = DDSColors.verifiedBadge;
        bg = DDSColors.successGreenBg;
        border = DDSColors.verifiedBadge.withValues(alpha: 0.3);
        break;
      case DriveGoBadgeVariant.neutral:
        fg = DDSColors.textSecondary;
        bg = DDSColors.surfaceSubtle;
        border = DDSColors.borderMedium;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DDSRadius.smallBorderRadius,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: DDSTypography.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

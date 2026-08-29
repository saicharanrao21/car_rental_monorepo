import 'package:flutter/material.dart';
import 'package:core/core.dart';

/// DriveGo Design System (DDS) — Standard Card Container Component
class DriveGoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final double borderRadius;
  final Color? backgroundColor;
  final BorderSide? border;
  final VoidCallback? onTap;

  const DriveGoCard({
    super.key,
    required this.child,
    this.padding = DDSSpacing.cardPadding,
    this.margin = const EdgeInsets.only(bottom: DDSSpacing.md),
    this.elevation = DDSElevation.card,
    this.borderRadius = DDSRadius.medium,
    this.backgroundColor,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation ?? 2.0,
      margin: margin,
      color: backgroundColor ?? DDSColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: border ?? const BorderSide(color: DDSColors.borderLight, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            )
          : Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
    );
  }
}

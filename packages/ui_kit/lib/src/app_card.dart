import 'package:flutter/material.dart';
import 'drivego_card.dart';

/// Legacy AppCard maintained for backward compatibility.
/// Forwards directly to DriveGo Design System (DDS) DriveGoCard.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final double borderRadius;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 16),
    this.elevation,
    this.borderRadius = 12.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DriveGoCard(
      padding: padding,
      margin: margin,
      elevation: elevation,
      borderRadius: borderRadius,
      onTap: onTap,
      child: child,
    );
  }
}

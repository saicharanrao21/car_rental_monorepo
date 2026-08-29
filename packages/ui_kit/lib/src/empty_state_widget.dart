import 'package:flutter/material.dart';
import 'drivego_empty_state.dart';

/// Legacy EmptyStateWidget maintained for backward compatibility.
/// Forwards directly to DriveGo Design System (DDS) DriveGoEmptyState.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DriveGoEmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
      actionText: actionText,
      onActionPressed: onActionPressed,
    );
  }
}

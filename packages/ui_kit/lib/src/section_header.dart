import 'package:flutter/material.dart';
import 'drivego_section_header.dart';

/// Legacy SectionHeader maintained for backward compatibility.
/// Forwards directly to DriveGo Design System (DDS) DriveGoSectionHeader.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAllPressed;
  final String actionText;

  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAllPressed,
    this.actionText = 'See all',
  });

  @override
  Widget build(BuildContext context) {
    return DriveGoSectionHeader(
      title: title,
      onActionPressed: onSeeAllPressed,
      actionText: actionText,
    );
  }
}

import 'package:flutter/material.dart';
import 'drivego_status_badge.dart';

/// Legacy StatusBadge maintained for backward compatibility.
/// Forwards directly to DriveGo Design System (DDS) DriveGoStatusBadge.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return DriveGoStatusBadge(label: status);
  }
}

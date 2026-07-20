import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  static const Map<String, Color> _statusColors = {
    // Booking statuses
    'pending': Colors.amber,
    'confirmed': Colors.blue,
    'ongoing': Colors.blue,
    'completed': Colors.green,
    'cancelled': Colors.red,
    // Document / vendor verification statuses
    'verified': Colors.green,
    'approved': Colors.green,
    'rejected': Colors.red,
    'suspended': Colors.red,
    'under review': Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.toLowerCase().trim();
    final color = _statusColors[normalizedStatus] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.24), width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

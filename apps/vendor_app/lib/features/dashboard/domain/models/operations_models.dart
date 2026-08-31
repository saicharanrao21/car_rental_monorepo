import 'package:flutter/material.dart';

enum TriagePriority {
  urgent,
  high,
  today,
  upcoming,
  informational;

  String get label {
    switch (this) {
      case TriagePriority.urgent:
        return 'URGENT';
      case TriagePriority.high:
        return 'HIGH PRIORITY';
      case TriagePriority.today:
        return 'TODAY';
      case TriagePriority.upcoming:
        return 'UPCOMING';
      case TriagePriority.informational:
        return 'INFO';
    }
  }

  Color get color {
    switch (this) {
      case TriagePriority.urgent:
        return const Color(0xFFDC2626); // Red
      case TriagePriority.high:
        return const Color(0xFFEA580C); // Orange
      case TriagePriority.today:
        return const Color(0xFF0284C7); // Blue
      case TriagePriority.upcoming:
        return const Color(0xFF4F46E5); // Indigo
      case TriagePriority.informational:
        return const Color(0xFF64748B); // Slate
    }
  }

  Color get backgroundColor {
    return color.withValues(alpha: 0.12);
  }
}

class TriageItem {
  final String id;
  final String title;
  final String subtitle;
  final TriagePriority priority;
  final String badgeText;
  final String actionLabel;
  final String routePath;
  final String? vehicleName;
  final DateTime? timestamp;
  final String? bookingId;
  final bool isBookingAction;

  const TriageItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.priority,
    required this.badgeText,
    required this.actionLabel,
    required this.routePath,
    this.vehicleName,
    this.timestamp,
    this.bookingId,
    this.isBookingAction = false,
  });
}

enum TimelineEventType {
  pickup,
  vehicleReturn;

  String get label => this == TimelineEventType.pickup ? 'PICKUP' : 'RETURN';
  Color get color => this == TimelineEventType.pickup ? const Color(0xFF16A34A) : const Color(0xFF0284C7);
}

class TodayTimelineItem {
  final String id;
  final String bookingId;
  final TimelineEventType type;
  final DateTime time;
  final String vehicleName;
  final String? registrationNumber;
  final String customerSafeName;
  final String hubLocation;
  final String status;
  final String tripType;

  const TodayTimelineItem({
    required this.id,
    required this.bookingId,
    required this.type,
    required this.time,
    required this.vehicleName,
    this.registrationNumber,
    required this.customerSafeName,
    required this.hubLocation,
    required this.status,
    required this.tripType,
  });
}

class FleetSummary {
  final int totalCars;
  final int availableCars;
  final int onTripCars;
  final int unavailableCars;

  const FleetSummary({
    required this.totalCars,
    required this.availableCars,
    required this.onTripCars,
    required this.unavailableCars,
  });
}

class BookingMatrix {
  final int todayCount;
  final int pendingCount;
  final int upcomingCount;
  final int completedCount;
  final int activeCount;

  const BookingMatrix({
    required this.todayCount,
    required this.pendingCount,
    required this.upcomingCount,
    required this.completedCount,
    required this.activeCount,
  });
}

class EarningsSnapshot {
  final double thisMonthEarnings;
  final double availableBalance;
  final double heldEarnings;
  final double totalEarnings;
  final double totalPaidOut;

  const EarningsSnapshot({
    required this.thisMonthEarnings,
    required this.availableBalance,
    required this.heldEarnings,
    required this.totalEarnings,
    required this.totalPaidOut,
  });
}

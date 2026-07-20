import 'package:flutter/foundation.dart';
import '../domain/repositories/admin_notifications_repository.dart';

class MockAdminNotificationsRepository implements AdminNotificationsRepository {
  final List<SentNotification> _history = [
    SentNotification(
      target: 'All Users',
      title: 'Monsoon Car Checkup Sale 🌧️',
      body: 'Get flat 20% off on all car checkups in Mumbai and Delhi. Limited slots available.',
      sentAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    SentNotification(
      target: 'All Vendors',
      title: 'New Commission Policy Update',
      body: 'Please review the updated platform fees for luxury vehicles effective next week.',
      sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    ),
    SentNotification(
      target: 'City:Bangalore',
      title: 'Traffic Advisory Alert 🚦',
      body: 'Due to roadwork, please expect delays near MG Road. Drive safely!',
      sentAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    SentNotification(
      target: 'Phone:9876543210',
      title: 'Booking Approved',
      body: 'Your ride request for Sedan in Mumbai has been successfully confirmed.',
      sentAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  @override
  Future<void> sendNotification({
    required String target,
    required String title,
    required String body,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final newNotif = SentNotification(
      target: target,
      title: title,
      body: body,
      sentAt: DateTime.now(),
    );
    _history.insert(0, newNotif);
    debugPrint('Mock Notification Sent - Target: $target, Title: $title, Body: $body');
  }

  @override
  Future<List<SentNotification>> getSentHistory() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.from(_history);
  }
}

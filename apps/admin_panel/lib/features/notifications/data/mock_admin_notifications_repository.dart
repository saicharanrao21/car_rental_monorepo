import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
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

  final List<NotificationDeliveryModel> _deliveries = [
    NotificationDeliveryModel(
      id: 'del-01',
      notificationId: 'notif-101',
      channel: 'PUSH',
      status: 'DELIVERED',
      provider: 'FIREBASE_FCM',
      providerMessageId: 'projects/drivego-core/messages/fcm_msg_101',
      recipientTarget: 'device_token_android_cust_01',
      recipientName: 'Arjun Mehta',
      notificationTitle: 'Booking Confirmed: Mahindra Thar',
      eventType: 'BOOKING_CONFIRMED',
      attemptCount: 1,
      maxRetries: 3,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 11)),
      deliveredAt: DateTime.now().subtract(const Duration(minutes: 11)),
    ),
    NotificationDeliveryModel(
      id: 'del-02',
      notificationId: 'notif-101',
      channel: 'SMS',
      status: 'DELIVERED',
      provider: 'TWILIO_REST',
      providerMessageId: 'SMb9274810da84901fbc3492',
      recipientTarget: '+919876543210',
      recipientName: 'Arjun Mehta',
      notificationTitle: 'Booking Confirmed: Mahindra Thar',
      eventType: 'BOOKING_CONFIRMED',
      attemptCount: 1,
      maxRetries: 3,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 11)),
      deliveredAt: DateTime.now().subtract(const Duration(minutes: 11)),
    ),
    NotificationDeliveryModel(
      id: 'del-03',
      notificationId: 'notif-101',
      channel: 'WHATSAPP',
      status: 'DELIVERED',
      provider: 'META_CLOUD_API',
      providerMessageId: 'wamid.HBgMOTE5ODc2NTQzMjEwFQIAERgSQURFRTczMDY4QTlGQURDRkEA',
      recipientTarget: '+919876543210',
      recipientName: 'Arjun Mehta',
      notificationTitle: 'Booking Confirmed: Mahindra Thar',
      eventType: 'BOOKING_CONFIRMED',
      attemptCount: 1,
      maxRetries: 3,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 11)),
      deliveredAt: DateTime.now().subtract(const Duration(minutes: 11)),
    ),
    NotificationDeliveryModel(
      id: 'del-04',
      notificationId: 'notif-102',
      channel: 'EMAIL',
      status: 'DELIVERED',
      provider: 'AWS_SES_SMTP',
      providerMessageId: '01000189a7123bf-f9e4210a-000000',
      recipientTarget: 'arjun.mehta@drivego.in',
      recipientName: 'Arjun Mehta',
      notificationTitle: 'Payment Receipt: ₹4,500.00',
      eventType: 'PAYMENT_CAPTURED',
      attemptCount: 1,
      maxRetries: 3,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 29)),
      deliveredAt: DateTime.now().subtract(const Duration(minutes: 29)),
    ),
    NotificationDeliveryModel(
      id: 'del-05',
      notificationId: 'notif-103',
      channel: 'SMS',
      status: 'FAILED',
      provider: 'TWILIO_REST',
      recipientTarget: '+919123456780',
      recipientName: 'Vikram Rao (Vendor)',
      notificationTitle: 'Urgent Handover Ready',
      eventType: 'HANDOVER_READY',
      attemptCount: 2,
      maxRetries: 3,
      lastError: 'HTTP 504: Gateway Timeout from Carrier Relay',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 50)),
      failedAt: DateTime.now().subtract(const Duration(minutes: 50)),
    ),
    NotificationDeliveryModel(
      id: 'del-06',
      notificationId: 'notif-104',
      channel: 'PUSH',
      status: 'DEAD_LETTER',
      provider: 'FIREBASE_FCM',
      recipientTarget: 'device_expired_token_vendor_99',
      recipientName: 'Pooja Sharma',
      notificationTitle: 'Refund Processed: ₹2,000.00',
      eventType: 'REFUND_PROCESSED',
      attemptCount: 3,
      maxRetries: 3,
      lastError: 'messaging/registration-token-not-registered: Token expired or revoked',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      failedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  @override
  Future<void> sendNotification({
    required String target,
    required String title,
    required String body,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
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
    await Future.delayed(const Duration(milliseconds: 200));
    return List.from(_history);
  }

  @override
  Future<List<NotificationDeliveryModel>> getDeliveries({
    String? status,
    String? channel,
    int limit = 50,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _deliveries.where((d) {
      if (status != null && status.isNotEmpty && status != 'ALL' && d.status != status) {
        return false;
      }
      if (channel != null && channel.isNotEmpty && channel != 'ALL' && d.channel != channel) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> getDeliveryStats() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {
      'total': 248,
      'delivered': 234,
      'failed': 8,
      'queued': 2,
      'deadLetter': 4,
      'successRate': 94.35,
      'deadLetterRate': 1.61,
    };
  }

  @override
  Future<void> retryDelivery(String deliveryId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    for (var i = 0; i < _deliveries.length; i++) {
      if (_deliveries[i].id == deliveryId) {
        _deliveries[i] = NotificationDeliveryModel(
          id: _deliveries[i].id,
          notificationId: _deliveries[i].notificationId,
          channel: _deliveries[i].channel,
          status: 'QUEUED',
          provider: _deliveries[i].provider,
          recipientTarget: _deliveries[i].recipientTarget,
          recipientName: _deliveries[i].recipientName,
          notificationTitle: _deliveries[i].notificationTitle,
          eventType: _deliveries[i].eventType,
          attemptCount: 0,
          maxRetries: _deliveries[i].maxRetries,
          lastError: null,
          createdAt: _deliveries[i].createdAt,
          updatedAt: DateTime.now(),
          queuedAt: DateTime.now(),
        );
        break;
      }
    }
  }
}

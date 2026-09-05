import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/notifications_repository.dart';

class MockNotificationsRepositoryImpl with LatencySimulator implements NotificationsRepository {
  final List<NotificationModel> _list = [];
  bool _initialized = false;

  void _initIfNeeded(String userId) {
    if (_initialized) return;
    _initialized = true;
    _list.addAll([
      NotificationModel(
        id: 'n1',
        userId: userId,
        title: 'Booking Confirmed: Mahindra Thar',
        body: 'Your reservation BK_1001 is confirmed! Vehicle is reserved for pick-up at Bangalore City Hub.',
        type: 'booking',
        category: 'BOOKING',
        eventType: 'BOOKING_CONFIRMED',
        entityType: 'BOOKING',
        entityId: 'BK_1001',
        actionUrl: '/my-bookings/BK_1001',
        priority: 'NORMAL',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      NotificationModel(
        id: 'n2',
        userId: userId,
        title: 'Payment Captured: ₹4,500.00',
        body: 'Payment for booking BK_1001 was successfully verified and captured.',
        type: 'payment',
        category: 'PAYMENT',
        eventType: 'PAYMENT_CAPTURED',
        entityType: 'PAYMENT',
        entityId: 'pay_rzp_1001',
        actionUrl: '/my-bookings/BK_1001',
        priority: 'NORMAL',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      NotificationModel(
        id: 'n3',
        userId: userId,
        title: 'Handover Ready: Vehicle Inspection',
        body: 'Your vehicle is prepared at Host Yard Bangalore. Present your pickup OTP upon arrival.',
        type: 'fulfillment',
        category: 'FULFILLMENT',
        eventType: 'HANDOVER_READY',
        entityType: 'BOOKING',
        entityId: 'BK_1001',
        actionUrl: '/my-bookings/BK_1001',
        priority: 'HIGH',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      NotificationModel(
        id: 'n4',
        userId: userId,
        title: 'Refund Processed: ₹2,000.00',
        body: 'Security deposit refund for booking BK_0998 has been processed to your source account.',
        type: 'refund',
        category: 'REFUND',
        eventType: 'REFUND_PROCESSED',
        entityType: 'BOOKING',
        entityId: 'BK_0998',
        actionUrl: '/my-bookings/BK_0998',
        priority: 'NORMAL',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      NotificationModel(
        id: 'n5',
        userId: userId,
        title: 'Exclusive Weekend Offer 🌟',
        body: 'Get 15% off on your next Self-Drive trip. Use code WEEKEND15 at checkout.',
        type: 'promotion',
        category: 'PROMOTION',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ]);
  }

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    await simulateLatency();
    _initIfNeeded(userId);
    return _list.where((n) => n.userId == userId).toList();
  }

  @override
  Future<void> markAllRead(String userId) async {
    await simulateLatency();
    _initIfNeeded(userId);
    for (var i = 0; i < _list.length; i++) {
      if (_list[i].userId == userId) {
        _list[i] = _list[i].copyWith(isRead: true);
      }
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await simulateLatency();
    for (var i = 0; i < _list.length; i++) {
      if (_list[i].id == notificationId) {
        _list[i] = _list[i].copyWith(isRead: true);
        break;
      }
    }
  }
}

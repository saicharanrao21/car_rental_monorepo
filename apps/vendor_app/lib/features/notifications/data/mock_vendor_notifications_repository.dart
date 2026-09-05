import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/vendor_notifications_repository.dart';

class MockVendorNotificationsRepositoryImpl with LatencySimulator implements VendorNotificationsRepository {
  final List<NotificationModel> _list = [];
  bool _initialized = false;

  void _initIfNeeded(String vendorUserId) {
    if (_initialized) return;
    _initialized = true;
    _list.addAll([
      NotificationModel(
        id: 'vn-01',
        userId: vendorUserId,
        title: 'New Booking Assigned: Mahindra Thar (TS09EA1234)',
        body: 'Booking BK_VND_881 has been confirmed. Prepare vehicle for pickup at Bangalore City Hub.',
        type: 'booking',
        category: 'BOOKING',
        eventType: 'BOOKING_CONFIRMED',
        entityType: 'BOOKING',
        entityId: 'BK_VND_881',
        actionUrl: '/bookings/BK_VND_881',
        priority: 'NORMAL',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      NotificationModel(
        id: 'vn-02',
        userId: vendorUserId,
        title: 'Handover Ready: Customer Arriving',
        body: 'Customer Rajesh Kumar is arriving in 15 mins for pickup. Verify pickup OTP to start rental.',
        type: 'fulfillment',
        category: 'FULFILLMENT',
        eventType: 'HANDOVER_READY',
        entityType: 'BOOKING',
        entityId: 'BK_VND_881',
        actionUrl: '/bookings/BK_VND_881/handover',
        priority: 'HIGH',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
      NotificationModel(
        id: 'vn-03',
        userId: vendorUserId,
        title: 'Return Inspection Required: Hyundai Creta',
        body: 'Trip for BK_VND_875 is concluding at Host Yard. Conduct digital check-in inspection.',
        type: 'fulfillment',
        category: 'FULFILLMENT',
        eventType: 'RETURN_PENDING',
        entityType: 'BOOKING',
        entityId: 'BK_VND_875',
        actionUrl: '/bookings/BK_VND_875/return',
        priority: 'HIGH',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      NotificationModel(
        id: 'vn-04',
        userId: vendorUserId,
        title: 'Escrow Settlement Released: ₹18,500.00',
        body: 'Trip completed without claims. Payout funds have moved to settled balance.',
        type: 'payout',
        category: 'PAYMENT',
        eventType: 'SETTLEMENT_ELIGIBLE',
        entityType: 'PAYMENT',
        entityId: 'pay_vnd_870',
        actionUrl: '/earnings',
        priority: 'NORMAL',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      NotificationModel(
        id: 'vn-05',
        userId: vendorUserId,
        title: 'Damage Claim Dispute Notice',
        body: 'Dispute opened on booking BK_VND_860. ₹5,000 security deposit quarantined pending review.',
        type: 'dispute',
        category: 'SECURITY',
        eventType: 'ESCROW_HOLD_DISPUTED',
        entityType: 'BOOKING',
        entityId: 'BK_VND_860',
        actionUrl: '/bookings/BK_VND_860',
        priority: 'HIGH',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
  }

  @override
  Future<List<NotificationModel>> getNotifications(String vendorUserId) async {
    await simulateLatency();
    _initIfNeeded(vendorUserId);
    return _list.where((n) => n.userId == vendorUserId).toList();
  }

  @override
  Future<void> markAllRead(String vendorUserId) async {
    await simulateLatency();
    _initIfNeeded(vendorUserId);
    for (var i = 0; i < _list.length; i++) {
      if (_list[i].userId == vendorUserId) {
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

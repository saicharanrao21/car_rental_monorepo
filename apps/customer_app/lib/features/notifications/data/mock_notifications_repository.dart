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
        title: 'Booking Confirmed!',
        body: 'Your booking has been confirmed by the vendor.',
        type: 'booking',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      NotificationModel(
        id: 'n2',
        userId: userId,
        title: 'Exclusive Offer For You 🌟',
        body: 'Get 15% off on your next Self-Drive trip. Code: SELFD15.',
        type: 'promotion',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      NotificationModel(
        id: 'n3',
        userId: userId,
        title: 'Security Alert',
        body: 'Your profile details were updated successfully.',
        type: 'security',
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
}

import 'package:models/models.dart';

class SentNotification {
  final String target;
  final String title;
  final String body;
  final DateTime sentAt;

  const SentNotification({
    required this.target,
    required this.title,
    required this.body,
    required this.sentAt,
  });
}

abstract class AdminNotificationsRepository {
  Future<void> sendNotification({
    required String target,
    required String title,
    required String body,
  });

  Future<List<SentNotification>> getSentHistory();

  Future<List<NotificationDeliveryModel>> getDeliveries({
    String? status,
    String? channel,
    int limit = 50,
    int offset = 0,
  });

  Future<Map<String, dynamic>> getDeliveryStats();

  Future<void> retryDelivery(String deliveryId);
}

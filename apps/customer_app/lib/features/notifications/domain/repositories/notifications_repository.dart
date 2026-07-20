import 'package:models/models.dart';

abstract class NotificationsRepository {
  Future<List<NotificationModel>> getNotifications(String userId);
  Future<void> markAllRead(String userId);
}

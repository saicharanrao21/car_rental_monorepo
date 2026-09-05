import 'package:models/models.dart';

abstract class VendorNotificationsRepository {
  Future<List<NotificationModel>> getNotifications(String vendorUserId);
  Future<void> markAllRead(String vendorUserId);
  Future<void> markAsRead(String notificationId);
}

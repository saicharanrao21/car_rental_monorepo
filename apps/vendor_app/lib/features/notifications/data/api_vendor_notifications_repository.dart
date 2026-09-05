import 'package:models/models.dart';
import 'package:core/core.dart';
import '../domain/repositories/vendor_notifications_repository.dart';

class ApiVendorNotificationsRepository implements VendorNotificationsRepository {
  final ApiClient apiClient;

  ApiVendorNotificationsRepository({required this.apiClient});

  @override
  Future<List<NotificationModel>> getNotifications(String vendorUserId) async {
    final response = await apiClient.dio.get('/notifications/me');
    List<dynamic> rawList = [];
    if (response.data is List) {
      rawList = response.data as List;
    } else if (response.data is Map) {
      final map = response.data as Map;
      if (map['notifications'] is List) {
        rawList = map['notifications'] as List;
      } else if (map['data'] is List) {
        rawList = map['data'] as List;
      }
    }
    return rawList.whereType<Map>().map((json) {
      final map = Map<String, dynamic>.from(json);
      return NotificationModel.fromJson(map);
    }).toList();
  }

  @override
  Future<void> markAllRead(String vendorUserId) async {
    await apiClient.dio.patch('/notifications/me/mark-all-read');
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await apiClient.dio.patch('/notifications/$notificationId/read');
  }
}

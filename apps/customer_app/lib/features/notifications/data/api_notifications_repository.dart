import 'package:models/models.dart';
import 'package:core/core.dart';
import '../domain/repositories/notifications_repository.dart';

class ApiNotificationsRepository implements NotificationsRepository {
  final ApiClient apiClient;

  ApiNotificationsRepository({required this.apiClient});

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    final response = await apiClient.dio.get('/notifications/me');
    final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? []);
    return data.map((json) => NotificationModel.fromJson(Map<String, dynamic>.from(json))).toList();
  }

  @override
  Future<void> markAllRead(String userId) async {
    await apiClient.dio.patch('/notifications/me/mark-all-read');
  }
}

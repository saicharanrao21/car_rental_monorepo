import 'package:core/core.dart';
import '../domain/repositories/admin_notifications_repository.dart';

class ApiAdminNotificationsRepository implements AdminNotificationsRepository {
  final ApiClient _apiClient;

  ApiAdminNotificationsRepository(this._apiClient);

  @override
  Future<void> sendNotification({
    required String target,
    required String title,
    required String body,
  }) async {
    await _apiClient.dio.post(
      '/admin/notifications/send',
      data: {
        'target': target,
        'title': title,
        'body': body,
      },
    );
  }

  @override
  Future<List<SentNotification>> getSentHistory() async {
    final response = await _apiClient.dio.get('/admin/notifications/history');
    final data = response.data;
    final list = (data['data'] as List? ?? data as List? ?? []);
    return list.map((json) {
      return SentNotification(
        target: json['target'] ?? 'ALL_USERS',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        sentAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      );
    }).toList();
  }
}

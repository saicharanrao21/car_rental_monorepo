import 'package:core/core.dart';
import 'package:models/models.dart';
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

  @override
  Future<List<NotificationDeliveryModel>> getDeliveries({
    String? status,
    String? channel,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiClient.dio.get(
      '/admin/notifications/deliveries',
      queryParameters: {
        if (status != null && status.isNotEmpty && status != 'ALL') 'status': status,
        if (channel != null && channel.isNotEmpty && channel != 'ALL') 'channel': channel,
        'limit': limit,
        'offset': offset,
      },
    );
    final data = response.data;
    final list = (data is Map && data['deliveries'] is List)
        ? data['deliveries'] as List
        : (data is List ? data : []);
    return list.map((json) => NotificationDeliveryModel.fromJson(Map<String, dynamic>.from(json))).toList();
  }

  @override
  Future<Map<String, dynamic>> getDeliveryStats() async {
    final response = await _apiClient.dio.get('/admin/notifications/stats');
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data);
    }
    return {};
  }

  @override
  Future<void> retryDelivery(String deliveryId) async {
    await _apiClient.dio.post('/admin/notifications/deliveries/$deliveryId/retry');
  }
}

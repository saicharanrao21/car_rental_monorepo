import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

@freezed
class NotificationModel with _$NotificationModel {
  const factory NotificationModel({
    required String id,
    @Default('') String userId,
    @Default('Notification') String title,
    @Default('') String body,
    @Default('SYSTEM') String type,
    @Default(false) bool isRead,
    required DateTime createdAt,
    @Default('GENERAL') String category,
    String? eventType,
    String? entityType,
    String? entityId,
    String? actionUrl,
    @Default('NORMAL') String priority,
    DateTime? readAt,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Notification',
      body: (json['body'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'SYSTEM',
      isRead: (json['isRead'] as bool?) ?? false,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      category: (json['category'] as String?) ?? 'GENERAL',
      eventType: json['eventType'] as String?,
      entityType: json['entityType'] as String?,
      entityId: json['entityId'] as String?,
      actionUrl: json['actionUrl'] as String?,
      priority: (json['priority'] as String?) ?? 'NORMAL',
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
    );
  }
}

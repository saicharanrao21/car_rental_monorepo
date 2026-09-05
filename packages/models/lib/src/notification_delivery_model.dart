import 'package:equatable/equatable.dart';

class NotificationDeliveryModel extends Equatable {
  final String id;
  final String notificationId;
  final String channel; // IN_APP, PUSH, SMS, WHATSAPP, EMAIL
  final String status; // PENDING, QUEUED, SENT, DELIVERED, FAILED, SKIPPED, DEAD_LETTER
  final String? provider;
  final String? providerMessageId;
  final String? recipientTarget;
  final int attemptCount;
  final int maxRetries;
  final String? lastError;
  final String? idempotencyKey;
  final DateTime? queuedAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? failedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notificationTitle;
  final String? recipientName;
  final String? eventType;

  const NotificationDeliveryModel({
    required this.id,
    required this.notificationId,
    required this.channel,
    required this.status,
    this.provider,
    this.providerMessageId,
    this.recipientTarget,
    this.attemptCount = 0,
    this.maxRetries = 3,
    this.lastError,
    this.idempotencyKey,
    this.queuedAt,
    this.sentAt,
    this.deliveredAt,
    this.failedAt,
    required this.createdAt,
    required this.updatedAt,
    this.notificationTitle,
    this.recipientName,
    this.eventType,
  });

  factory NotificationDeliveryModel.fromJson(Map<String, dynamic> json) {
    return NotificationDeliveryModel(
      id: (json['id'] as String?) ?? '',
      notificationId: (json['notificationId'] as String?) ?? '',
      channel: (json['channel'] as String?) ?? 'IN_APP',
      status: (json['status'] as String?) ?? 'PENDING',
      provider: json['provider'] as String?,
      providerMessageId: json['providerMessageId'] as String?,
      recipientTarget: json['recipientTarget'] as String?,
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      maxRetries: (json['maxRetries'] as num?)?.toInt() ?? 3,
      lastError: json['lastError'] as String?,
      idempotencyKey: json['idempotencyKey'] as String?,
      queuedAt: json['queuedAt'] != null ? DateTime.tryParse(json['queuedAt'].toString()) : null,
      sentAt: json['sentAt'] != null ? DateTime.tryParse(json['sentAt'].toString()) : null,
      deliveredAt: json['deliveredAt'] != null ? DateTime.tryParse(json['deliveredAt'].toString()) : null,
      failedAt: json['failedAt'] != null ? DateTime.tryParse(json['failedAt'].toString()) : null,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      notificationTitle: json['notificationTitle'] as String?,
      recipientName: json['recipientName'] as String?,
      eventType: json['eventType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notificationId': notificationId,
      'channel': channel,
      'status': status,
      'provider': provider,
      'providerMessageId': providerMessageId,
      'recipientTarget': recipientTarget,
      'attemptCount': attemptCount,
      'maxRetries': maxRetries,
      'lastError': lastError,
      'idempotencyKey': idempotencyKey,
      'queuedAt': queuedAt?.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'failedAt': failedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'notificationTitle': notificationTitle,
      'recipientName': recipientName,
      'eventType': eventType,
    };
  }

  @override
  List<Object?> get props => [
        id,
        notificationId,
        channel,
        status,
        provider,
        providerMessageId,
        recipientTarget,
        attemptCount,
        maxRetries,
        lastError,
        idempotencyKey,
        queuedAt,
        sentAt,
        deliveredAt,
        failedAt,
        createdAt,
        updatedAt,
      ];
}

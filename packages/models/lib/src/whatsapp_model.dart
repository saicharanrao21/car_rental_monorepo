enum WhatsAppMessageStatus {
  queued,
  sent,
  delivered,
  read,
  failed;

  static WhatsAppMessageStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'SENT':
        return WhatsAppMessageStatus.sent;
      case 'DELIVERED':
        return WhatsAppMessageStatus.delivered;
      case 'READ':
        return WhatsAppMessageStatus.read;
      case 'FAILED':
        return WhatsAppMessageStatus.failed;
      case 'QUEUED':
      default:
        return WhatsAppMessageStatus.queued;
    }
  }

  String get displayName {
    switch (this) {
      case WhatsAppMessageStatus.queued:
        return 'Queued';
      case WhatsAppMessageStatus.sent:
        return 'Sent';
      case WhatsAppMessageStatus.delivered:
        return 'Delivered';
      case WhatsAppMessageStatus.read:
        return 'Read';
      case WhatsAppMessageStatus.failed:
        return 'Failed';
    }
  }
}

enum WhatsAppMessageType {
  bookingConfirmed,
  bookingCancelled,
  paymentSuccessful,
  paymentFailed,
  refundProcessed,
  handoverReady,
  tripReminder,
  emergencyAlert,
  marketingPromo;

  static WhatsAppMessageType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'BOOKING_CONFIRMED':
        return WhatsAppMessageType.bookingConfirmed;
      case 'BOOKING_CANCELLED':
        return WhatsAppMessageType.bookingCancelled;
      case 'PAYMENT_SUCCESSFUL':
        return WhatsAppMessageType.paymentSuccessful;
      case 'PAYMENT_FAILED':
        return WhatsAppMessageType.paymentFailed;
      case 'REFUND_PROCESSED':
        return WhatsAppMessageType.refundProcessed;
      case 'HANDOVER_READY':
        return WhatsAppMessageType.handoverReady;
      case 'TRIP_REMINDER':
        return WhatsAppMessageType.tripReminder;
      case 'EMERGENCY_ALERT':
        return WhatsAppMessageType.emergencyAlert;
      case 'MARKETING_PROMO':
      default:
        return WhatsAppMessageType.marketingPromo;
    }
  }

  String get displayName {
    switch (this) {
      case WhatsAppMessageType.bookingConfirmed:
        return 'Booking Confirmed';
      case WhatsAppMessageType.bookingCancelled:
        return 'Booking Cancelled';
      case WhatsAppMessageType.paymentSuccessful:
        return 'Payment Successful';
      case WhatsAppMessageType.paymentFailed:
        return 'Payment Failed';
      case WhatsAppMessageType.refundProcessed:
        return 'Refund Processed';
      case WhatsAppMessageType.handoverReady:
        return 'Handover Ready';
      case WhatsAppMessageType.tripReminder:
        return 'Trip Reminder';
      case WhatsAppMessageType.emergencyAlert:
        return 'Emergency Alert';
      case WhatsAppMessageType.marketingPromo:
        return 'Marketing Promo';
    }
  }
}

class WhatsAppMessageModel {
  final String id;
  final String? userId;
  final String? bookingId;
  final String phoneNumber;
  final String templateName;
  final String templateLanguage;
  final WhatsAppMessageType messageType;
  final WhatsAppMessageStatus status;
  final String? providerMessageId;
  final String idempotencyKey;
  final Map<String, dynamic>? variables;
  final String? failureCode;
  final String? failureReason;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? failedAt;
  final DateTime createdAt;

  const WhatsAppMessageModel({
    required this.id,
    this.userId,
    this.bookingId,
    required this.phoneNumber,
    required this.templateName,
    this.templateLanguage = 'en_US',
    required this.messageType,
    required this.status,
    this.providerMessageId,
    required this.idempotencyKey,
    this.variables,
    this.failureCode,
    this.failureReason,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.failedAt,
    required this.createdAt,
  });

  factory WhatsAppMessageModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppMessageModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String?,
      bookingId: json['bookingId'] as String?,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      templateName: json['templateName'] as String? ?? '',
      templateLanguage: json['templateLanguage'] as String? ?? 'en_US',
      messageType: WhatsAppMessageType.fromString(json['messageType'] as String?),
      status: WhatsAppMessageStatus.fromString(json['status'] as String?),
      providerMessageId: json['providerMessageId'] as String?,
      idempotencyKey: json['idempotencyKey'] as String? ?? '',
      variables: json['variables'] as Map<String, dynamic>?,
      failureCode: json['failureCode'] as String?,
      failureReason: json['failureReason'] as String?,
      sentAt: json['sentAt'] != null ? DateTime.tryParse(json['sentAt'] as String) : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'] as String)
          : null,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'] as String) : null,
      failedAt: json['failedAt'] != null ? DateTime.tryParse(json['failedAt'] as String) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'bookingId': bookingId,
      'phoneNumber': phoneNumber,
      'templateName': templateName,
      'templateLanguage': templateLanguage,
      'messageType': messageType.name.toUpperCase(),
      'status': status.name.toUpperCase(),
      'providerMessageId': providerMessageId,
      'idempotencyKey': idempotencyKey,
      'variables': variables,
      'failureCode': failureCode,
      'failureReason': failureReason,
      'sentAt': sentAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'failedAt': failedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class WhatsAppSummaryModel {
  final int totalMessages;
  final int sentCount;
  final int deliveredCount;
  final int readCount;
  final int failedCount;
  final double deliveryRatePercent;

  const WhatsAppSummaryModel({
    required this.totalMessages,
    required this.sentCount,
    required this.deliveredCount,
    required this.readCount,
    required this.failedCount,
    required this.deliveryRatePercent,
  });

  factory WhatsAppSummaryModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppSummaryModel(
      totalMessages: (json['totalMessages'] as num?)?.toInt() ?? 0,
      sentCount: (json['sentCount'] as num?)?.toInt() ?? 0,
      deliveredCount: (json['deliveredCount'] as num?)?.toInt() ?? 0,
      readCount: (json['readCount'] as num?)?.toInt() ?? 0,
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
      deliveryRatePercent: (json['deliveryRatePercent'] as num?)?.toDouble() ?? 100.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalMessages': totalMessages,
      'sentCount': sentCount,
      'deliveredCount': deliveredCount,
      'readCount': readCount,
      'failedCount': failedCount,
      'deliveryRatePercent': deliveryRatePercent,
    };
  }
}

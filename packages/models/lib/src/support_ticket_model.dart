enum TicketCategory {
  BOOKING,
  PAYMENT,
  REFUND,
  SECURITY_DEPOSIT,
  VEHICLE,
  PICKUP_DELIVERY,
  KYC_LICENCE,
  TRIP_EXTENSION,
  DAMAGE_DISPUTE,
  EMERGENCY,
  OTHER;

  static TicketCategory fromString(String? value) {
    if (value == null) return TicketCategory.OTHER;
    return TicketCategory.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => TicketCategory.OTHER,
    );
  }

  String get label {
    switch (this) {
      case TicketCategory.BOOKING:
        return 'Booking Issue';
      case TicketCategory.PAYMENT:
        return 'Payment Problem';
      case TicketCategory.REFUND:
        return 'Refund Query';
      case TicketCategory.SECURITY_DEPOSIT:
        return 'Security Deposit';
      case TicketCategory.VEHICLE:
        return 'Vehicle Condition';
      case TicketCategory.PICKUP_DELIVERY:
        return 'Pickup / Delivery';
      case TicketCategory.KYC_LICENCE:
        return 'KYC / Licence';
      case TicketCategory.TRIP_EXTENSION:
        return 'Trip Extension';
      case TicketCategory.DAMAGE_DISPUTE:
        return 'Damage / Dispute';
      case TicketCategory.EMERGENCY:
        return 'Emergency / Breakdown';
      case TicketCategory.OTHER:
        return 'Other';
    }
  }
}

enum TicketPriority {
  LOW,
  NORMAL,
  HIGH,
  URGENT;

  static TicketPriority fromString(String? value) {
    if (value == null) return TicketPriority.NORMAL;
    return TicketPriority.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => TicketPriority.NORMAL,
    );
  }
}

enum TicketStatus {
  OPEN,
  ASSIGNED,
  IN_PROGRESS,
  WAITING_FOR_CUSTOMER,
  WAITING_FOR_VENDOR,
  RESOLVED,
  CLOSED;

  static TicketStatus fromString(String? value) {
    if (value == null) return TicketStatus.OPEN;
    return TicketStatus.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => TicketStatus.OPEN,
    );
  }

  String get label {
    switch (this) {
      case TicketStatus.OPEN:
        return 'Open';
      case TicketStatus.ASSIGNED:
        return 'Assigned';
      case TicketStatus.IN_PROGRESS:
        return 'In Progress';
      case TicketStatus.WAITING_FOR_CUSTOMER:
        return 'Waiting on You';
      case TicketStatus.WAITING_FOR_VENDOR:
        return 'Waiting on Vendor';
      case TicketStatus.RESOLVED:
        return 'Resolved';
      case TicketStatus.CLOSED:
        return 'Closed';
    }
  }
}

class TicketMessageModel {
  final String id;
  final String ticketId;
  final String senderId;
  final String senderRole;
  final String? senderName;
  final String message;
  final List<String> attachments;
  final bool isInternal;
  final DateTime createdAt;

  const TicketMessageModel({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderRole,
    this.senderName,
    required this.message,
    this.attachments = const [],
    this.isInternal = false,
    required this.createdAt,
  });

  factory TicketMessageModel.fromJson(Map<String, dynamic> json) {
    return TicketMessageModel(
      id: json['id'] as String? ?? '',
      ticketId: json['ticketId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderRole: json['senderRole'] as String? ?? 'CUSTOMER',
      senderName: json['sender']?['name'] as String?,
      message: json['message'] as String? ?? '',
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isInternal: json['isInternal'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticketId': ticketId,
        'senderId': senderId,
        'senderRole': senderRole,
        'message': message,
        'attachments': attachments,
        'isInternal': isInternal,
        'createdAt': createdAt.toIso8601String(),
      };
}

class SupportTicketModel {
  final String id;
  final String ticketNumber;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final String? bookingId;
  final TicketCategory category;
  final TicketPriority priority;
  final String subject;
  final String description;
  final TicketStatus status;
  final String? assignedToUserId;
  final String? assignedToUserName;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TicketMessageModel> messages;

  const SupportTicketModel({
    required this.id,
    required this.ticketNumber,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    this.bookingId,
    required this.category,
    this.priority = TicketPriority.NORMAL,
    required this.subject,
    required this.description,
    this.status = TicketStatus.OPEN,
    this.assignedToUserId,
    this.assignedToUserName,
    this.resolvedAt,
    this.closedAt,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: json['id'] as String? ?? '',
      ticketNumber: json['ticketNumber'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      customerName: json['customer']?['name'] as String?,
      customerPhone: json['customer']?['phone'] as String?,
      bookingId: json['bookingId'] as String?,
      category: TicketCategory.fromString(json['category'] as String?),
      priority: TicketPriority.fromString(json['priority'] as String?),
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: TicketStatus.fromString(json['status'] as String?),
      assignedToUserId: json['assignedToUserId'] as String?,
      assignedToUserName: json['assignedToUser']?['name'] as String?,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'] as String)
          : null,
      closedAt: json['closedAt'] != null
          ? DateTime.tryParse(json['closedAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => TicketMessageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticketNumber': ticketNumber,
        'customerId': customerId,
        'bookingId': bookingId,
        'category': category.name,
        'priority': priority.name,
        'subject': subject,
        'description': description,
        'status': status.name,
        'assignedToUserId': assignedToUserId,
        'resolvedAt': resolvedAt?.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}

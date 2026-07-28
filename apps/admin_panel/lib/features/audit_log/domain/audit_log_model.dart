class AuditLogEntry {
  final String id;
  final String adminUserId;
  final String adminUserName;
  final String action;
  final String targetType;
  final String targetId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  AuditLogEntry({
    required this.id,
    required this.adminUserId,
    required this.adminUserName,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.metadata,
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    String adminName = json['adminUserName'] ?? json['adminUserId'] ?? 'Admin';
    if (json['adminUser'] != null && json['adminUser'] is Map) {
      adminName = json['adminUser']['name'] ?? adminName;
    }

    Map<String, dynamic> meta = {};
    if (json['metadata'] != null) {
      if (json['metadata'] is Map) {
        meta = Map<String, dynamic>.from(json['metadata']);
      } else if (json['metadata'] is String) {
        meta = {'info': json['metadata']};
      }
    }

    return AuditLogEntry(
      id: json['id']?.toString() ?? '',
      adminUserId: json['adminUserId']?.toString() ?? '',
      adminUserName: adminName,
      action: json['action']?.toString() ?? 'SYSTEM_ACTION',
      targetType: json['targetType']?.toString() ?? 'SYSTEM',
      targetId: json['targetId']?.toString() ?? '',
      metadata: meta,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}

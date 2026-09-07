class ConfigAuditItem {
  final String id;
  final String action;
  final String key;
  final dynamic previousValue;
  final dynamic newValue;
  final String adminUserId;
  final Map<String, dynamic>? adminUser;
  final int? version;
  final String? reason;
  final DateTime timestamp;

  const ConfigAuditItem({
    required this.id,
    required this.action,
    required this.key,
    this.previousValue,
    this.newValue,
    required this.adminUserId,
    this.adminUser,
    this.version,
    this.reason,
    required this.timestamp,
  });

  String get adminDisplayName {
    if (adminUser != null) {
      final name = adminUser!['name']?.toString();
      final email = adminUser!['email']?.toString();
      if (name != null && name.isNotEmpty) return name;
      if (email != null && email.isNotEmpty) return email;
    }
    return adminUserId;
  }

  factory ConfigAuditItem.fromJson(Map<String, dynamic> json) {
    return ConfigAuditItem(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? 'CONFIG_UPDATED',
      key: json['key'] as String? ?? '',
      previousValue: json['previousValue'],
      newValue: json['newValue'],
      adminUserId: json['adminUserId'] as String? ?? 'system',
      adminUser: json['adminUser'] as Map<String, dynamic>?,
      version: (json['version'] as num?)?.toInt(),
      reason: json['reason'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'key': key,
      'previousValue': previousValue,
      'newValue': newValue,
      'adminUserId': adminUserId,
      'adminUser': adminUser,
      'version': version,
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

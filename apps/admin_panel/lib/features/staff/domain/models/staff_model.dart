class StaffModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String role;
  final String staffRole;
  final bool banned;
  final int activeSessions;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const StaffModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    required this.staffRole,
    required this.banned,
    this.activeSessions = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Staff',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'ADMIN',
      staffRole: json['staffRole'] as String? ?? 'SUPER_ADMIN',
      banned: json['banned'] as bool? ?? false,
      activeSessions: (json['activeSessions'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'staffRole': staffRole,
      'banned': banned,
      'activeSessions': activeSessions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  String get roleDisplayTitle {
    switch (staffRole) {
      case 'SUPER_ADMIN':
        return 'Super Admin';
      case 'OPERATIONS_MANAGER':
        return 'Operations Manager';
      case 'FINANCE_MANAGER':
        return 'Finance Manager';
      case 'CUSTOMER_SUPPORT':
        return 'Customer Support';
      case 'COMPLIANCE_OFFICER':
        return 'Compliance Officer';
      case 'MARKETING_MANAGER':
        return 'Marketing Manager';
      case 'READONLY_ANALYST':
        return 'Read-only Analyst';
      default:
        return staffRole;
    }
  }
}

class StaffRoleDefinitionModel {
  final String role;
  final String title;
  final String description;
  final List<String> permissions;

  const StaffRoleDefinitionModel({
    required this.role,
    required this.title,
    required this.description,
    required this.permissions,
  });

  factory StaffRoleDefinitionModel.fromJson(Map<String, dynamic> json) {
    return StaffRoleDefinitionModel(
      role: json['role'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      permissions: (json['permissions'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_providers.dart';

class AdminSessionState {
  final bool isAuthenticated;
  final String displayName;
  final bool isLoading;
  final String role;
  final String staffRole;
  final List<String> permissions;

  const AdminSessionState({
    required this.isAuthenticated,
    required this.displayName,
    this.isLoading = false,
    this.role = 'ADMIN',
    this.staffRole = 'SUPER_ADMIN',
    this.permissions = const [],
  });

  bool get isReadOnly => staffRole == 'READONLY_ANALYST';

  bool hasPermission(String permission) {
    if (!isAuthenticated) return false;
    if (staffRole == 'SUPER_ADMIN') return true;
    return permissions.contains(permission);
  }

  factory AdminSessionState.unauthenticated() => const AdminSessionState(
        isAuthenticated: false,
        displayName: '',
        isLoading: false,
        role: '',
        staffRole: '',
        permissions: [],
      );

  factory AdminSessionState.authenticated(
    String name, {
    String role = 'ADMIN',
    String staffRole = 'SUPER_ADMIN',
    List<String>? permissions,
  }) {
    final perms = permissions ?? _getDefaultPermissionsForRole(role, staffRole);
    return AdminSessionState(
      isAuthenticated: true,
      displayName: name,
      isLoading: false,
      role: role,
      staffRole: staffRole,
      permissions: perms,
    );
  }

  factory AdminSessionState.loading() => const AdminSessionState(
        isAuthenticated: false,
        displayName: '',
        isLoading: true,
        role: '',
        staffRole: '',
        permissions: [],
      );

  static List<String> _getDefaultPermissionsForRole(String role, String staffRole) {
    if (staffRole == 'SUPER_ADMIN' || (role == 'ADMIN' && staffRole.isEmpty)) {
      return const [
        'system:config:read',
        'system:config:write',
        'audit:log:read',
        'user:read',
        'user:write',
        'kyc:review',
        'vendor:read',
        'vendor:write',
        'fleet:management',
        'fleet:read',
        'fleet:write',
        'location:read',
        'location:write',
        'booking:read',
        'booking:write',
        'emergency:dispatch',
        'finance:read',
        'finance:write',
        'payout:approve',
        'payout:execute',
        'refund:adjudicate',
        'reconciliation:read',
        'reconciliation:manage',
        'commission:manage',
        'wallet:read',
        'wallet:write',
        'support:ticket:read',
        'support:ticket:write',
        'dispute:resolve',
        'coupon:manage',
        'campaign:manage',
        'banner:manage',
        'referral:read',
        'loyalty:read',
        'fraud:view',
        'fraud:resolve',
        'analytics:read',
      ];
    }
    switch (staffRole) {
      case 'OPERATIONS_MANAGER':
        return const [
          'vendor:read',
          'vendor:write',
          'fleet:management',
          'fleet:read',
          'fleet:write',
          'location:read',
          'location:write',
          'booking:read',
          'booking:write',
          'emergency:dispatch',
          'analytics:read',
        ];
      case 'FINANCE_MANAGER':
        return const [
          'finance:read',
          'finance:write',
          'payout:approve',
          'payout:execute',
          'refund:adjudicate',
          'reconciliation:read',
          'reconciliation:manage',
          'commission:manage',
          'wallet:read',
          'wallet:write',
          'booking:read',
          'analytics:read',
        ];
      case 'CUSTOMER_SUPPORT':
        return const [
          'user:read',
          'booking:read',
          'booking:write',
          'support:ticket:read',
          'support:ticket:write',
          'emergency:dispatch',
          'dispute:resolve',
          'vendor:read',
          'fleet:read',
        ];
      case 'COMPLIANCE_OFFICER':
        return const [
          'kyc:review',
          'audit:log:read',
          'fraud:view',
          'dispute:resolve',
          'user:read',
          'vendor:read',
        ];
      case 'MARKETING_MANAGER':
        return const [
          'coupon:manage',
          'campaign:manage',
          'banner:manage',
          'referral:read',
          'loyalty:read',
          'analytics:read',
        ];
      case 'READONLY_ANALYST':
        return const [
          'analytics:read',
          'audit:log:read',
          'booking:read',
          'vendor:read',
          'fleet:read',
          'user:read',
          'finance:read',
          'reconciliation:read',
          'fraud:view',
          'system:config:read',
        ];
      default:
        return const ['analytics:read'];
    }
  }
}

class AdminSessionNotifier extends Notifier<AdminSessionState> {
  @override
  AdminSessionState build() {
    _restoreSession();
    return AdminSessionState.unauthenticated();
  }

  Future<void> _restoreSession() async {
    try {
      final tokenStorage = ref.read(tokenStorageProvider);
      final token = await tokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        final apiClient = ref.read(apiClientProvider);
        final res = await apiClient.dio.get('/auth/me');
        if (res.statusCode == 200) {
          final user = res.data;
          final name = user['name'] ?? user['email'] ?? 'Platform Admin';
          final role = (user['role'] ?? 'ADMIN').toString();
          final staffRole = (user['staffRole'] ?? 'SUPER_ADMIN').toString();
          state = AdminSessionState.authenticated(
            name.toString(),
            role: role,
            staffRole: staffRole,
          );
        }
      }
    } catch (_) {
      await ref.read(tokenStorageProvider).clearTokens();
      state = AdminSessionState.unauthenticated();
    }
  }

  void login(String name, {String role = 'ADMIN', String staffRole = 'SUPER_ADMIN'}) {
    state = AdminSessionState.authenticated(name, role: role, staffRole: staffRole);
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clearTokens();
    state = AdminSessionState.unauthenticated();
  }
}

final adminSessionProvider =
    NotifierProvider<AdminSessionNotifier, AdminSessionState>(AdminSessionNotifier.new);

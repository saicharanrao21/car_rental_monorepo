import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_providers.dart';

class AdminSessionState {
  final bool isAuthenticated;
  final String displayName;
  final bool isLoading;

  const AdminSessionState({
    required this.isAuthenticated,
    required this.displayName,
    this.isLoading = false,
  });

  factory AdminSessionState.unauthenticated() =>
      const AdminSessionState(isAuthenticated: false, displayName: '', isLoading: false);

  factory AdminSessionState.authenticated(String name) =>
      AdminSessionState(isAuthenticated: true, displayName: name, isLoading: false);

  factory AdminSessionState.loading() =>
      const AdminSessionState(isAuthenticated: false, displayName: '', isLoading: true);
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
          state = AdminSessionState.authenticated(name.toString());
        }
      }
    } catch (_) {
      await ref.read(tokenStorageProvider).clearTokens();
      state = AdminSessionState.unauthenticated();
    }
  }

  void login(String name) {
    state = AdminSessionState.authenticated(name);
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clearTokens();
    state = AdminSessionState.unauthenticated();
  }
}

final adminSessionProvider =
    NotifierProvider<AdminSessionNotifier, AdminSessionState>(AdminSessionNotifier.new);

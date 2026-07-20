import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'api_providers.dart';

class AuthState {
  final UserModel? user;
  final bool isAuthenticated;

  const AuthState({this.user, this.isAuthenticated = false});

  factory AuthState.unauthenticated() => const AuthState();
  factory AuthState.authenticated(UserModel user) => AuthState(user: user, isAuthenticated: true);
}

class SessionNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(() => checkSession());
    return AuthState.unauthenticated();
  }

  Future<void> checkSession() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    final accessToken = await tokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    final apiClient = ref.read(apiClientProvider);
    try {
      final response = await apiClient.dio.get('/auth/me');
      final userJson = Map<String, dynamic>.from(response.data);
      if (userJson['profilePhotoUrl'] != null && userJson['profilePhoto'] == null) {
        userJson['profilePhoto'] = userJson['profilePhotoUrl'];
      }
      final user = UserModel.fromJson(userJson);
      state = AuthState.authenticated(user);
      updateFcmTokenPlaceholder();
    } catch (e) {
      await tokenStorage.clearTokens();
      state = AuthState.unauthenticated();
    }
  }

  void authenticate(UserModel user) {
    state = AuthState.authenticated(user);
    updateFcmTokenPlaceholder();
  }

  Future<void> updateProfile({required String name, required String email}) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.dio.patch(
      '/users/me',
      data: {
        'name': name,
        'email': email,
      },
    );
    final userJson = Map<String, dynamic>.from(response.data);
    if (userJson['profilePhotoUrl'] != null && userJson['profilePhoto'] == null) {
      userJson['profilePhoto'] = userJson['profilePhotoUrl'];
    }
    final user = UserModel.fromJson(userJson);
    state = AuthState.authenticated(user);
  }

  Future<void> updateFcmTokenPlaceholder() async {
    // TODO: wire up real firebase_messaging FCM token in a future pass
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.patch(
        '/users/me/fcm-token',
        data: {'token': 'placeholder_device_token'},
      );
    } catch (_) {
      // Fail silently, don't interrupt main authentication flow
    }
  }

  Future<void> logout() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    await tokenStorage.clearTokens();
    state = AuthState.unauthenticated();
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, AuthState>(SessionNotifier.new);

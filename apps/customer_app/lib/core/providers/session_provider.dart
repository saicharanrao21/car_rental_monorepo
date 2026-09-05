import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_providers.dart';

class AuthState {
  final UserModel? user;
  final bool isAuthenticated;
  final bool isInitialized;

  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isInitialized = false,
  });

  factory AuthState.initial() => const AuthState(isInitialized: false);
  factory AuthState.unauthenticated() =>
      const AuthState(isInitialized: true, isAuthenticated: false);
  factory AuthState.authenticated(UserModel user) =>
      AuthState(user: user, isAuthenticated: true, isInitialized: true);
}

class SessionNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState.initial();
  }

  Future<void> checkSession() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    final accessToken = await tokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      state = AuthState.unauthenticated();
      return;
    }

    final apiClient = ref.read(apiClientProvider);
    try {
      final response = await apiClient.dio.get('/auth/me');
      final userJson = Map<String, dynamic>.from(response.data);
      if (userJson['profilePhotoUrl'] != null &&
          userJson['profilePhoto'] == null) {
        userJson['profilePhoto'] = userJson['profilePhotoUrl'];
      }
      final user = UserModel.fromJson(userJson);
      state = AuthState.authenticated(user);
      registerFcmToken();
    } catch (e) {
      await tokenStorage.clearTokens();
      state = AuthState.unauthenticated();
    }
  }

  void authenticate(UserModel user) {
    state = AuthState.authenticated(user);
    registerFcmToken();
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



  String? _currentFcmToken;

  Future<void> registerFcmToken() async {
    try {
      String? fcmToken;
      try {
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          fcmToken = await messaging.getToken();
          debugPrint('REAL_FCM_TOKEN_FROM_SDK: $fcmToken');
        }
      } catch (e) {
        debugPrint('FCM_GET_TOKEN_ERROR: $e');
        return;
      }

      // If the SDK did not return a token, do not store anything.
      if (fcmToken == null || fcmToken.isEmpty) return;
      _currentFcmToken = fcmToken;

      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.post(
        '/notifications/devices/register',
        data: {
          'token': fcmToken,
          'platform': 'ANDROID',
          'appVersion': '1.0.0',
        },
      );

      // Keep the stored token fresh on rotation.
      try {
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          if (newToken.isNotEmpty) {
            _currentFcmToken = newToken;
            await apiClient.dio.post(
              '/notifications/devices/register',
              data: {
                'token': newToken,
                'platform': 'ANDROID',
                'appVersion': '1.0.0',
              },
            );
          }
        });
      } catch (_) {}
    } catch (_) {
      // Fail silently — never interrupt the main authentication flow
    }
  }

  Future<void> logout() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    final apiClient = ref.read(apiClientProvider);

    if (_currentFcmToken != null && _currentFcmToken!.isNotEmpty) {
      try {
        await apiClient.dio.post(
          '/notifications/devices/unregister',
          data: {'token': _currentFcmToken},
        );
      } catch (_) {
        // Best-effort unregister on server
      }
    }

    await tokenStorage.clearTokens();
    _currentFcmToken = null;
    state = AuthState.unauthenticated();
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, AuthState>(SessionNotifier.new);

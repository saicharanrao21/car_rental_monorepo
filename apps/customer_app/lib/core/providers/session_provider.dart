import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
          print('REAL_FCM_TOKEN_FROM_SDK: $fcmToken');
        }
      } catch (e, st) {
        print('FCM_GET_TOKEN_ERROR: $e');
        return;
      }

      // If the SDK did not return a token, do not store anything.
      if (fcmToken == null || fcmToken.isEmpty) return;

      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.patch(
        '/users/me/fcm-token',
        data: {'token': fcmToken},
      );

      // Keep the stored token fresh on rotation.
      try {
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          if (newToken.isNotEmpty) {
            await apiClient.dio.patch(
              '/users/me/fcm-token',
              data: {'token': newToken},
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
    await tokenStorage.clearTokens();
    state = AuthState.unauthenticated();
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, AuthState>(SessionNotifier.new);

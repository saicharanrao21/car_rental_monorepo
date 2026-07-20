import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/api_auth_repository.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/session_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiAuthRepository(apiClient: apiClient);
});

class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Idle state
  }

  Future<bool> sendOtp(String phone) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).sendOtp(phone);
    });
    return !state.hasError;
  }

  Future<UserModel?> verifyOtp(String phone, String otp) async {
    state = const AsyncLoading();
    UserModel? user;
    final res = await AsyncValue.guard(() async {
      user = await ref.read(authRepositoryProvider).verifyOtp(phone, otp);
      if (user != null) {
        ref.read(sessionProvider.notifier).authenticate(user!);
      }
      return user;
    });

    if (res.hasError) {
      state = AsyncError(res.error!, res.stackTrace!);
      throw res.error!;
    } else {
      state = const AsyncData(null);
    }
    return user;
  }

  Future<void> registerUser({
    required String phone,
    required String name,
    String? email,
  }) async {
    state = const AsyncLoading();
    final res = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).registerUser(
            phone: phone,
            name: name,
            email: email,
          );
      ref.read(sessionProvider.notifier).authenticate(user);
    });

    if (res.hasError) {
      state = AsyncError(res.error!, res.stackTrace!);
      throw res.error!;
    } else {
      state = const AsyncData(null);
    }
  }
}

final authControllerProvider = AutoDisposeAsyncNotifierProvider<AuthController, void>(AuthController.new);

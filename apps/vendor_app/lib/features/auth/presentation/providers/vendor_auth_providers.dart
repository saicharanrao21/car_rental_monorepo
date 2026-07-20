import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/vendor_auth_repository.dart';
import '../../data/api_vendor_auth_repository.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';

final vendorAuthRepositoryProvider = Provider<VendorAuthRepository>((ref) {
  return ApiVendorAuthRepository(apiClient: ref.watch(apiClientProvider));
});

class VendorAuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Idle state
  }

  Future<bool> sendOtp(String phone) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(vendorAuthRepositoryProvider).sendOtp(phone);
    });
    return !state.hasError;
  }

  Future<VendorModel?> verifyOtp(String phone, String otp) async {
    state = const AsyncLoading();
    VendorModel? vendor;
    final res = await AsyncValue.guard(() async {
      vendor = await ref.read(vendorAuthRepositoryProvider).verifyOtp(phone, otp);
      if (vendor != null) {
        ref.read(vendorSessionProvider.notifier).authenticate(vendor!);
      }
      return vendor;
    });

    if (res.hasError) {
      state = AsyncError(res.error!, res.stackTrace!);
      throw res.error!;
    } else {
      state = const AsyncData(null);
    }
    return vendor;
  }
}

final vendorAuthControllerProvider =
    AutoDisposeAsyncNotifierProvider<VendorAuthController, void>(VendorAuthController.new);

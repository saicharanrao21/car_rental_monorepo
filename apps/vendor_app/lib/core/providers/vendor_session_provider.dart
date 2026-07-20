import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'api_providers.dart';

class VendorAuthState {
  final VendorModel? vendor;
  final bool isAuthenticated;

  const VendorAuthState({this.vendor, this.isAuthenticated = false});

  factory VendorAuthState.unauthenticated() => const VendorAuthState();
  factory VendorAuthState.authenticated(VendorModel vendor) =>
      VendorAuthState(vendor: vendor, isAuthenticated: true);
}

class VendorSessionNotifier extends Notifier<VendorAuthState> {
  @override
  VendorAuthState build() {
    Future.microtask(() => checkSession());
    return VendorAuthState.unauthenticated();
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
      if (userJson['role'] == 'VENDOR' && userJson['vendor'] != null) {
        final vendorJson = Map<String, dynamic>.from(userJson['vendor']);
        vendorJson['phone'] ??= userJson['phone'];
        vendorJson['email'] ??= userJson['email'];
        final vendor = VendorModel.fromJson(vendorJson);
        state = VendorAuthState.authenticated(vendor);
      } else {
        await tokenStorage.clearTokens();
        state = VendorAuthState.unauthenticated();
      }
    } catch (e) {
      await tokenStorage.clearTokens();
      state = VendorAuthState.unauthenticated();
    }
  }

  void authenticate(VendorModel vendor) {
    state = VendorAuthState.authenticated(vendor);
  }

  Future<void> logout() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    await tokenStorage.clearTokens();
    state = VendorAuthState.unauthenticated();
  }
}

final vendorSessionProvider =
    NotifierProvider<VendorSessionNotifier, VendorAuthState>(VendorSessionNotifier.new);

enum VendorApprovalStatus { pending, verified, suspended, unknown }

final vendorApprovalStatusProvider = Provider<VendorApprovalStatus>((ref) {
  final session = ref.watch(vendorSessionProvider);
  if (!session.isAuthenticated || session.vendor == null) {
    return VendorApprovalStatus.unknown;
  }
  final status = session.vendor!.verificationStatus.toLowerCase();
  switch (status) {
    case 'verified':
      return VendorApprovalStatus.verified;
    case 'pending':
      return VendorApprovalStatus.pending;
    case 'suspended':
      return VendorApprovalStatus.suspended;
    default:
      return VendorApprovalStatus.unknown;
  }
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/vendor_onboarding_models.dart';
import '../../domain/repositories/admin_onboarding_repository.dart';
import '../../data/api_admin_onboarding_repository.dart';
import '../../../../core/providers/api_providers.dart';

// Repository Provider
final adminOnboardingRepositoryProvider = Provider<AdminOnboardingRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiAdminOnboardingRepository(apiClient: apiClient);
});

// ==========================================
// TAB 1: REQUIREMENT DEFINITIONS PROVIDERS
// ==========================================
final requirementCategoryFilterProvider = StateProvider<String?>((ref) => null);
final requirementActiveFilterProvider = StateProvider<bool?>((ref) => null);
final requirementScopeFilterProvider = StateProvider<String?>((ref) => null);

final onboardingDefinitionsProvider =
    FutureProvider.autoDispose<List<RequirementDefinitionModel>>((ref) async {
  final repo = ref.watch(adminOnboardingRepositoryProvider);
  final category = ref.watch(requirementCategoryFilterProvider);
  final isActive = ref.watch(requirementActiveFilterProvider);
  final scope = ref.watch(requirementScopeFilterProvider);

  return repo.getDefinitions(
    category: category,
    isActive: isActive,
    scope: scope,
  );
});

// ==========================================
// TAB 2: SECURITY DEPOSITS PROVIDERS
// ==========================================
final depositStatusFilterProvider = StateProvider<String?>((ref) => null);
final depositSearchQueryProvider = StateProvider<String>((ref) => '');

final adminDepositsProvider =
    FutureProvider.autoDispose<List<VendorSecurityDepositModel>>((ref) async {
  final repo = ref.watch(adminOnboardingRepositoryProvider);
  final status = ref.watch(depositStatusFilterProvider);
  final search = ref.watch(depositSearchQueryProvider);

  return repo.listDeposits(
    status: status,
    search: search.trim().isEmpty ? null : search.trim(),
  );
});

final selectedVendorDepositLedgerProvider =
    FutureProvider.family.autoDispose<List<VendorDepositLedgerEntryModel>, String>(
        (ref, vendorId) async {
  final repo = ref.watch(adminOnboardingRepositoryProvider);
  return repo.getDepositLedger(vendorId);
});

// ==========================================
// TAB 3: VERIFICATION QUEUE PROVIDERS
// ==========================================
final verificationCategoryFilterProvider = StateProvider<String?>((ref) => null);

final pendingVerificationsProvider =
    FutureProvider.autoDispose<List<PendingVerificationItemModel>>((ref) async {
  final repo = ref.watch(adminOnboardingRepositoryProvider);
  final category = ref.watch(verificationCategoryFilterProvider);

  return repo.getPendingVerifications(category: category);
});

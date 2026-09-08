import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_providers.dart';
import '../../data/api_vendor_compliance_repository.dart';
import '../../domain/models/vendor_compliance_models.dart';
import '../../domain/repositories/vendor_compliance_repository.dart';

final vendorComplianceRepositoryProvider = Provider<VendorComplianceRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiVendorComplianceRepository(apiClient: apiClient);
});

final vendorEligibilityProvider = FutureProvider.autoDispose<VendorEligibilityModel>((ref) async {
  final repo = ref.watch(vendorComplianceRepositoryProvider);
  return repo.getEligibility(bypassCache: true);
});

final vendorRequirementsProvider =
    FutureProvider.autoDispose<List<VendorRequirementItemModel>>((ref) async {
  final repo = ref.watch(vendorComplianceRepositoryProvider);
  return repo.getRequirements();
});

final vendorDepositSummaryProvider =
    FutureProvider.autoDispose<VendorDepositSummaryModel>((ref) async {
  final repo = ref.watch(vendorComplianceRepositoryProvider);
  return repo.getDepositSummary();
});

class VendorComplianceController extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> submitDocument({
    required String definitionId,
    required String documentUrl,
    Map<String, dynamic>? metadata,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(vendorComplianceRepositoryProvider);
      await repo.submitRequirement(
        requirementDefinitionId: definitionId,
        documentUrl: documentUrl,
        metadata: metadata,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(vendorRequirementsProvider);
      ref.invalidate(vendorEligibilityProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> payDeposit({
    required double amount,
    required String paymentMethod,
    String? reference,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(vendorComplianceRepositoryProvider);
      await repo.recordDepositPayment(
        amount: amount,
        paymentMethod: paymentMethod,
        referenceTransactionId: reference,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(vendorDepositSummaryProvider);
      ref.invalidate(vendorEligibilityProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  void refreshAll() {
    ref.invalidate(vendorEligibilityProvider);
    ref.invalidate(vendorRequirementsProvider);
    ref.invalidate(vendorDepositSummaryProvider);
  }
}

final vendorComplianceControllerProvider =
    AutoDisposeNotifierProvider<VendorComplianceController, AsyncValue<void>>(
  VendorComplianceController.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';
import '../../domain/dispute_model.dart';
import '../../domain/repositories/admin_disputes_repository.dart';
import '../../data/api_admin_disputes_repository.dart';

final adminDisputesRepositoryProvider = Provider<AdminDisputesRepository>((ref) {
  return ApiAdminDisputesRepository(apiClient: ref.watch(apiClientProvider));
});

final disputeStatusFilterProvider = StateProvider<String>((ref) => 'ALL'); // ALL, OPEN, UNDER_REVIEW, RESOLVED, REJECTED
final damageClaimStatusFilterProvider = StateProvider<String>((ref) => 'ALL'); // ALL, SUBMITTED, UNDER_REVIEW, APPROVED, PARTIALLY_APPROVED, REJECTED

final adminDisputesProvider = FutureProvider.autoDispose<List<DisputeModel>>((ref) async {
  final status = ref.watch(disputeStatusFilterProvider);
  return ref.watch(adminDisputesRepositoryProvider).getDisputes(status: status);
});

final adminDamageClaimsProvider = FutureProvider.autoDispose<List<DamageClaimModel>>((ref) async {
  final status = ref.watch(damageClaimStatusFilterProvider);
  return ref.watch(adminDisputesRepositoryProvider).getDamageClaims(status: status);
});

final disputeDetailProvider = FutureProvider.autoDispose.family<DisputeModel, String>((ref, id) async {
  return ref.watch(adminDisputesRepositoryProvider).getDisputeById(id);
});

class AdminDisputesController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  AdminDisputesController(this._ref) : super(const AsyncValue.data(null));

  Future<void> updateDisputeStatus({
    required String id,
    required String status,
    String? resolutionNote,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminDisputesRepositoryProvider).updateDisputeStatus(
        id: id,
        status: status,
        resolutionNote: resolutionNote,
      );
      _ref.invalidate(adminDisputesProvider);
      _ref.invalidate(disputeDetailProvider(id));
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> adjudicateClaim({
    required String claimId,
    required String decision,
    double? approvedAmount,
    required String adminNotes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminDisputesRepositoryProvider).adjudicateDamageClaim(
        claimId: claimId,
        decision: decision,
        approvedAmount: approvedAmount,
        adminNotes: adminNotes,
      );
      _ref.invalidate(adminDamageClaimsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final adminDisputesControllerProvider = StateNotifierProvider<AdminDisputesController, AsyncValue<void>>((ref) {
  return AdminDisputesController(ref);
});

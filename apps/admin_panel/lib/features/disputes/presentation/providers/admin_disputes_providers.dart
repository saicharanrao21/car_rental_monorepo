import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_providers.dart';
import '../../domain/dispute_model.dart';
import '../../domain/repositories/admin_disputes_repository.dart';
import '../../data/api_admin_disputes_repository.dart';

final adminDisputesRepositoryProvider = Provider<AdminDisputesRepository>((ref) {
  return ApiAdminDisputesRepository(apiClient: ref.watch(apiClientProvider));
});

final disputeStatusFilterProvider = StateProvider<String>((ref) => 'ALL'); // ALL, OPEN, UNDER_REVIEW, RESOLVED, REJECTED

final adminDisputesProvider = FutureProvider.autoDispose<List<DisputeModel>>((ref) async {
  final status = ref.watch(disputeStatusFilterProvider);
  return ref.watch(adminDisputesRepositoryProvider).getDisputes(status: status);
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
}

final adminDisputesControllerProvider = StateNotifierProvider<AdminDisputesController, AsyncValue<void>>((ref) {
  return AdminDisputesController(ref);
});

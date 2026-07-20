import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/commission/domain/repositories/commission_repository.dart';
import 'package:admin_panel/features/commission/data/mock_commission_repository.dart';

final commissionRepositoryProvider = Provider<CommissionRepository>((ref) {
  return MockCommissionRepository();
});

// Future provider for retrieving commission rules
final commissionRulesProvider = FutureProvider<List<CommissionConfigModel>>((ref) async {
  final repo = ref.watch(commissionRepositoryProvider);
  return repo.getRules();
});

// StateNotifier for mutating commission rules
class CommissionController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  CommissionController(this._ref) : super(const AsyncValue.data(null));

  Future<void> addRule(CommissionConfigModel rule) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(commissionRepositoryProvider).addRule(rule);
      _ref.invalidate(commissionRulesProvider);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateRule(CommissionConfigModel rule) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(commissionRepositoryProvider).updateRule(rule);
      _ref.invalidate(commissionRulesProvider);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteRule(String id) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(commissionRepositoryProvider).deleteRule(id);
      _ref.invalidate(commissionRulesProvider);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final commissionControllerProvider = StateNotifierProvider<CommissionController, AsyncValue<void>>((ref) {
  return CommissionController(ref);
});

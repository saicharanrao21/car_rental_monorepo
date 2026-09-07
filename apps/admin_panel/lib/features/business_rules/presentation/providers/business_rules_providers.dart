import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/admin_session_provider.dart';
import '../../domain/models/system_config_detail.dart';
import '../../domain/models/config_audit_item.dart';
import '../../domain/repositories/business_rules_repository.dart';
import '../../data/api_business_rules_repository.dart';

final businessRulesRepositoryProvider = Provider<BusinessRulesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiBusinessRulesRepository(apiClient);
});

class BusinessRulesListNotifier extends AsyncNotifier<List<SystemConfigDetail>> {
  @override
  Future<List<SystemConfigDetail>> build() async {
    final repo = ref.watch(businessRulesRepositoryProvider);
    return repo.getAllConfigs();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(businessRulesRepositoryProvider);
      return repo.getAllConfigs();
    });
  }
}

final businessRulesListProvider =
    AsyncNotifierProvider<BusinessRulesListNotifier, List<SystemConfigDetail>>(
  BusinessRulesListNotifier.new,
);

final selectedCategoryFilterProvider = StateProvider<String>((ref) => 'ALL');
final rulesSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredBusinessRulesProvider =
    Provider<AsyncValue<List<SystemConfigDetail>>>((ref) {
  final rulesAsync = ref.watch(businessRulesListProvider);
  final categoryFilter = ref.watch(selectedCategoryFilterProvider);
  final searchQuery = ref.watch(rulesSearchQueryProvider).toLowerCase().trim();

  return rulesAsync.whenData((rules) {
    return rules.where((rule) {
      // Category / Domain filter
      if (categoryFilter != 'ALL') {
        if (rule.domainGroup != categoryFilter && rule.category != categoryFilter) {
          return false;
        }
      }

      // Search query filter
      if (searchQuery.isNotEmpty) {
        final matchesKey = rule.key.toLowerCase().contains(searchQuery);
        final matchesName = rule.humanReadableName.toLowerCase().contains(searchQuery);
        final matchesDesc = (rule.description ?? '').toLowerCase().contains(searchQuery);
        if (!matchesKey && !matchesName && !matchesDesc) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});

final selectedRuleKeyProvider = StateProvider<String?>((ref) => null);

final selectedRuleDetailProvider = Provider<SystemConfigDetail?>((ref) {
  final key = ref.watch(selectedRuleKeyProvider);
  if (key == null) return null;

  final rules = ref.watch(businessRulesListProvider).valueOrNull;
  if (rules == null) return null;

  try {
    return rules.firstWhere((r) => r.key == key);
  } catch (_) {
    return null;
  }
});

final ruleAuditHistoryProvider =
    FutureProvider.family<List<ConfigAuditItem>, String>((ref, key) async {
  final repo = ref.watch(businessRulesRepositoryProvider);
  return repo.getAuditHistory(key);
});

/// Permission gate provider: distinguishes read-only vs authorized editors.
final canEditConfigurationsProvider = Provider<bool>((ref) {
  final session = ref.watch(adminSessionProvider);
  // Platform admins have full write access
  if (session.isAuthenticated) {
    return true;
  }
  return false;
});

class RuleMutationNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  RuleMutationNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> updateRule({
    required String key,
    required dynamic value,
    int? expectedVersion,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(businessRulesRepositoryProvider);
      await repo.updateConfig(
        key: key,
        value: value,
        expectedVersion: expectedVersion,
        reason: reason,
      );
      // Refresh configurations list
      await _ref.read(businessRulesListProvider.notifier).refresh();
      // Invalidate audit history for this key
      _ref.invalidate(ruleAuditHistoryProvider(key));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> batchUpdateRules({
    required List<BatchConfigItem> items,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(businessRulesRepositoryProvider);
      await repo.batchUpdateConfigs(
        items: items,
        reason: reason,
      );
      await _ref.read(businessRulesListProvider.notifier).refresh();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final ruleMutationControllerProvider =
    StateNotifierProvider<RuleMutationNotifier, AsyncValue<void>>((ref) {
  return RuleMutationNotifier(ref);
});

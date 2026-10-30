import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_providers.dart';
import '../../data/api_admin_operations_repository.dart';
import '../../domain/models/operations_models.dart';

final adminOperationsRepositoryProvider = Provider<ApiAdminOperationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiAdminOperationsRepository(apiClient);
});

class AdminWorkflowsNotifier extends AutoDisposeAsyncNotifier<List<WorkflowDefinitionModel>> {
  @override
  Future<List<WorkflowDefinitionModel>> build() async {
    return ref.watch(adminOperationsRepositoryProvider).getWorkflows();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(adminOperationsRepositoryProvider).getWorkflows());
  }
}

final adminWorkflowsProvider =
    AutoDisposeAsyncNotifierProvider<AdminWorkflowsNotifier, List<WorkflowDefinitionModel>>(
  () => AdminWorkflowsNotifier(),
);

class AdminExecutionsNotifier extends AutoDisposeAsyncNotifier<List<WorkflowExecutionModel>> {
  @override
  Future<List<WorkflowExecutionModel>> build() async {
    return ref.watch(adminOperationsRepositoryProvider).getExecutions();
  }

  Future<void> retry(String id) async {
    await ref.read(adminOperationsRepositoryProvider).retryExecution(id);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(adminOperationsRepositoryProvider).getExecutions());
  }
}

final adminExecutionsProvider =
    AutoDisposeAsyncNotifierProvider<AdminExecutionsNotifier, List<WorkflowExecutionModel>>(
  () => AdminExecutionsNotifier(),
);

class AdminRulesNotifier extends AutoDisposeAsyncNotifier<List<AutomationRuleModel>> {
  @override
  Future<List<AutomationRuleModel>> build() async {
    return ref.watch(adminOperationsRepositoryProvider).getRules();
  }

  Future<void> toggleRule(String id, bool isEnabled) async {
    await ref.read(adminOperationsRepositoryProvider).updateRule(id, {'isEnabled': isEnabled});
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.map((r) => r.id == id ? r.copyWith(isEnabled: isEnabled) : r).toList());
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(adminOperationsRepositoryProvider).getRules());
  }
}

final adminRulesProvider =
    AutoDisposeAsyncNotifierProvider<AdminRulesNotifier, List<AutomationRuleModel>>(
  () => AdminRulesNotifier(),
);

class AdminApprovalsNotifier extends AutoDisposeAsyncNotifier<List<ApprovalRequestModel>> {
  @override
  Future<List<ApprovalRequestModel>> build() async {
    return ref.watch(adminOperationsRepositoryProvider).getApprovals();
  }

  Future<void> recordDecision(String id, {required String decision, int stepIndex = 0}) async {
    await ref.read(adminOperationsRepositoryProvider).recordDecision(id, decision: decision, stepIndex: stepIndex);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(adminOperationsRepositoryProvider).getApprovals());
  }
}

final adminApprovalsProvider =
    AutoDisposeAsyncNotifierProvider<AdminApprovalsNotifier, List<ApprovalRequestModel>>(
  () => AdminApprovalsNotifier(),
);

class AdminSchedulesNotifier extends AutoDisposeAsyncNotifier<List<ScheduledJobModel>> {
  @override
  Future<List<ScheduledJobModel>> build() async {
    return ref.watch(adminOperationsRepositoryProvider).getSchedules();
  }

  Future<void> runJob(String id) async {
    await ref.read(adminOperationsRepositoryProvider).runSchedule(id);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(adminOperationsRepositoryProvider).getSchedules());
  }
}

final adminSchedulesProvider =
    AutoDisposeAsyncNotifierProvider<AdminSchedulesNotifier, List<ScheduledJobModel>>(
  () => AdminSchedulesNotifier(),
);


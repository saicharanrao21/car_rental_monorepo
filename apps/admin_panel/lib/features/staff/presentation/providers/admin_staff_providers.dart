import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/staff_model.dart';
import '../../domain/repositories/admin_staff_repository.dart';
import '../../data/api_admin_staff_repository.dart';
import '../../../../core/providers/api_providers.dart';

final adminStaffRepositoryProvider = Provider<AdminStaffRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiAdminStaffRepository(apiClient: apiClient);
});

final staffSearchQueryProvider = StateProvider<String>((ref) => '');

final staffRoleFilterProvider = StateProvider<String>((ref) => 'ALL');

final staffListProvider = FutureProvider.autoDispose<List<StaffModel>>((ref) async {
  final repo = ref.watch(adminStaffRepositoryProvider);
  final search = ref.watch(staffSearchQueryProvider);
  final roleFilter = ref.watch(staffRoleFilterProvider);

  return repo.getStaffList(search: search, staffRole: roleFilter);
});

final staffRoleDefinitionsProvider = FutureProvider<List<StaffRoleDefinitionModel>>((ref) async {
  final repo = ref.watch(adminStaffRepositoryProvider);
  return repo.getRoleDefinitions();
});


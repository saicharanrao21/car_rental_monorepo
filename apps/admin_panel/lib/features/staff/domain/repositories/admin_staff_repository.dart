import '../models/staff_model.dart';

abstract interface class AdminStaffRepository {
  Future<List<StaffModel>> getStaffList({String? search, String? staffRole});
  Future<List<StaffRoleDefinitionModel>> getRoleDefinitions();
  Future<StaffModel> createStaff({
    required String name,
    required String email,
    required String phone,
    required String staffRole,
    required String password,
  });
  Future<StaffModel> updateStaff(
    String id, {
    String? name,
    String? staffRole,
    bool? banned,
    String? password,
  });
  Future<void> revokeStaffSessions(String id);
}


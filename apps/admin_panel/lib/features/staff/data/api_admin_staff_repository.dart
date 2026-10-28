import 'package:core/core.dart';
import '../domain/models/staff_model.dart';
import '../domain/repositories/admin_staff_repository.dart';

class ApiAdminStaffRepository implements AdminStaffRepository {
  final ApiClient apiClient;

  ApiAdminStaffRepository({required this.apiClient});

  @override
  Future<List<StaffModel>> getStaffList({String? search, String? staffRole}) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (staffRole != null && staffRole != 'ALL') queryParams['staffRole'] = staffRole;

    final res = await apiClient.dio.get('/admin/staff', queryParameters: queryParams);
    final rawData = res.data;
    final List list = rawData is Map ? (rawData['data'] as List? ?? []) : (rawData as List);
    return list.map((e) => StaffModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  @override
  Future<List<StaffRoleDefinitionModel>> getRoleDefinitions() async {
    final res = await apiClient.dio.get('/admin/staff/roles');
    final List list = res.data is List ? res.data as List : [];
    return list.map((e) => StaffRoleDefinitionModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  @override
  Future<StaffModel> createStaff({
    required String name,
    required String email,
    required String phone,
    required String staffRole,
    required String password,
  }) async {
    final res = await apiClient.dio.post('/admin/staff', data: {
      'name': name,
      'email': email,
      'phone': phone,
      'staffRole': staffRole,
      'password': password,
    });
    return StaffModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  @override
  Future<StaffModel> updateStaff(
    String id, {
    String? name,
    String? staffRole,
    bool? banned,
    String? password,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (staffRole != null) body['staffRole'] = staffRole;
    if (banned != null) body['banned'] = banned;
    if (password != null && password.isNotEmpty) body['password'] = password;

    final res = await apiClient.dio.patch('/admin/staff/$id', data: body);
    return StaffModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  @override
  Future<void> revokeStaffSessions(String id) async {
    await apiClient.dio.post('/admin/staff/$id/revoke-sessions');
  }
}

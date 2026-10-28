import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/features/staff/domain/models/staff_model.dart';
import 'package:admin_panel/features/staff/domain/repositories/admin_staff_repository.dart';

class MockAdminStaffRepository implements AdminStaffRepository {
  final List<StaffModel> _staff = [];

  MockAdminStaffRepository(List<StaffModel> initial) {
    _staff.addAll(initial);
  }

  @override
  Future<List<StaffModel>> getStaffList({String? search, String? staffRole}) async {
    return _staff.where((s) {
      if (staffRole != null && staffRole != 'ALL' && s.staffRole != staffRole) {
        return false;
      }
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        return s.name.toLowerCase().contains(q) ||
            (s.email?.toLowerCase().contains(q) ?? false) ||
            (s.phone?.contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  @override
  Future<List<StaffRoleDefinitionModel>> getRoleDefinitions() async {
    return const [
      StaffRoleDefinitionModel(
        role: 'SUPER_ADMIN',
        title: 'Super Admin',
        description: 'Complete unrestricted access',
        permissions: ['*'],
      ),
      StaffRoleDefinitionModel(
        role: 'OPERATIONS_MANAGER',
        title: 'Operations Manager',
        description: 'Fleet and vendor operations',
        permissions: ['vendor:*', 'fleet:*'],
      ),
      StaffRoleDefinitionModel(
        role: 'FINANCE_MANAGER',
        title: 'Finance Manager',
        description: 'Payouts, refunds and ledgers',
        permissions: ['finance:*', 'payout:*'],
      ),
    ];
  }

  @override
  Future<StaffModel> createStaff({
    required String name,
    required String email,
    required String phone,
    required String staffRole,
    required String password,
  }) async {
    final staff = StaffModel(
      id: 'stf_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      phone: phone,
      role: staffRole == 'CUSTOMER_SUPPORT' ? 'SUPPORT_AGENT' : 'ADMIN',
      staffRole: staffRole,
      banned: false,
      activeSessions: 0,
      createdAt: DateTime.now(),
    );
    _staff.add(staff);
    return staff;
  }

  @override
  Future<StaffModel> updateStaff(
    String id, {
    String? name,
    String? staffRole,
    bool? banned,
    String? password,
  }) async {
    final index = _staff.indexKey(id);
    if (index == -1) throw Exception('Staff not found');
    final curr = _staff[index];
    final updated = StaffModel(
      id: curr.id,
      name: name ?? curr.name,
      email: curr.email,
      phone: curr.phone,
      role: staffRole != null
          ? (staffRole == 'CUSTOMER_SUPPORT' ? 'SUPPORT_AGENT' : 'ADMIN')
          : curr.role,
      staffRole: staffRole ?? curr.staffRole,
      banned: banned ?? curr.banned,
      activeSessions: curr.activeSessions,
      createdAt: curr.createdAt,
      updatedAt: DateTime.now(),
    );
    _staff[index] = updated;
    return updated;
  }

  @override
  Future<void> revokeStaffSessions(String id) async {
    final index = _staff.indexKey(id);
    if (index != -1) {
      final curr = _staff[index];
      _staff[index] = StaffModel(
        id: curr.id,
        name: curr.name,
        email: curr.email,
        phone: curr.phone,
        role: curr.role,
        staffRole: curr.staffRole,
        banned: curr.banned,
        activeSessions: 0,
        createdAt: curr.createdAt,
      );
    }
  }
}

extension on List<StaffModel> {
  int indexKey(String id) => indexWhere((e) => e.id == id);
}

void main() {
  group('Admin Panel - Staff Management & RBAC Suite', () {
    test('StaffModel parses JSON, serializes, and formats display role titles', () {
      final json = {
        'id': 'stf_001',
        'name': 'Kavita Menon',
        'email': 'kavita.menon@drivego.in',
        'phone': '9876543210',
        'role': 'ADMIN',
        'staffRole': 'FINANCE_MANAGER',
        'banned': false,
        'activeSessions': 2,
        'createdAt': '2026-10-28T12:00:00.000Z',
      };

      final staff = StaffModel.fromJson(json);

      expect(staff.id, 'stf_001');
      expect(staff.name, 'Kavita Menon');
      expect(staff.email, 'kavita.menon@drivego.in');
      expect(staff.phone, '9876543210');
      expect(staff.role, 'ADMIN');
      expect(staff.staffRole, 'FINANCE_MANAGER');
      expect(staff.roleDisplayTitle, 'Finance Manager');
      expect(staff.banned, false);
      expect(staff.activeSessions, 2);

      final payload = staff.toJson();
      expect(payload['id'], 'stf_001');
      expect(payload['staffRole'], 'FINANCE_MANAGER');
    });

    test('StaffModel formats all 7 granular staff roles accurately', () {
      final roles = {
        'SUPER_ADMIN': 'Super Admin',
        'OPERATIONS_MANAGER': 'Operations Manager',
        'FINANCE_MANAGER': 'Finance Manager',
        'CUSTOMER_SUPPORT': 'Customer Support',
        'COMPLIANCE_OFFICER': 'Compliance Officer',
        'MARKETING_MANAGER': 'Marketing Manager',
        'READONLY_ANALYST': 'Read-only Analyst',
      };

      for (final entry in roles.entries) {
        final staff = StaffModel(
          id: 'id_${entry.key}',
          name: 'Staff ${entry.key}',
          role: 'ADMIN',
          staffRole: entry.key,
          banned: false,
          createdAt: DateTime.now(),
        );
        expect(staff.roleDisplayTitle, entry.value);
      }
    });

    test('MockAdminStaffRepository supports filtering, provisioning, updating, and session revocation', () async {
      final initial = [
        StaffModel(
          id: 'stf_1',
          name: 'Vikram Ops',
          email: 'vikram@drivego.in',
          phone: '9876500001',
          role: 'ADMIN',
          staffRole: 'OPERATIONS_MANAGER',
          banned: false,
          activeSessions: 3,
          createdAt: DateTime.now(),
        ),
        StaffModel(
          id: 'stf_2',
          name: 'Meera Support',
          email: 'meera@drivego.in',
          phone: '9876500002',
          role: 'SUPPORT_AGENT',
          staffRole: 'CUSTOMER_SUPPORT',
          banned: false,
          activeSessions: 1,
          createdAt: DateTime.now(),
        ),
      ];

      final repo = MockAdminStaffRepository(initial);

      // 1. Fetch all
      final all = await repo.getStaffList();
      expect(all.length, 2);

      // 2. Filter by role
      final ops = await repo.getStaffList(staffRole: 'OPERATIONS_MANAGER');
      expect(ops.length, 1);
      expect(ops.first.name, 'Vikram Ops');

      // 3. Search by query
      final searched = await repo.getStaffList(search: 'meera');
      expect(searched.length, 1);
      expect(searched.first.name, 'Meera Support');

      // 4. Provision new staff
      final newStaff = await repo.createStaff(
        name: 'Rohan Finance',
        email: 'rohan@drivego.in',
        phone: '9876500003',
        staffRole: 'FINANCE_MANAGER',
        password: 'Password123!',
      );
      expect(newStaff.staffRole, 'FINANCE_MANAGER');
      final updatedList = await repo.getStaffList();
      expect(updatedList.length, 3);

      // 5. Suspend staff
      final suspended = await repo.updateStaff(newStaff.id, banned: true);
      expect(suspended.banned, true);

      // 6. Revoke sessions
      await repo.revokeStaffSessions('stf_1');
      final checked = (await repo.getStaffList()).firstWhere((s) => s.id == 'stf_1');
      expect(checked.activeSessions, 0);
    });
  });
}


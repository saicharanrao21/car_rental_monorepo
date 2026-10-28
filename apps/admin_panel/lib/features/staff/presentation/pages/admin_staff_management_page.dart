import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../domain/models/staff_model.dart';
import '../providers/admin_staff_providers.dart';

class AdminStaffManagementPage extends ConsumerStatefulWidget {
  const AdminStaffManagementPage({super.key});

  @override
  ConsumerState<AdminStaffManagementPage> createState() =>
      _AdminStaffManagementPageState();
}

class _AdminStaffManagementPageState
    extends ConsumerState<AdminStaffManagementPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getRoleBadgeColor(String staffRole) {
    switch (staffRole) {
      case 'SUPER_ADMIN':
        return const Color(0xFF7C3AED); // Purple
      case 'OPERATIONS_MANAGER':
        return const Color(0xFF2563EB); // Blue
      case 'FINANCE_MANAGER':
        return const Color(0xFFD97706); // Amber
      case 'CUSTOMER_SUPPORT':
        return const Color(0xFF0D9488); // Teal
      case 'COMPLIANCE_OFFICER':
        return const Color(0xFF4F46E5); // Indigo
      case 'MARKETING_MANAGER':
        return const Color(0xFF059669); // Emerald
      case 'READONLY_ANALYST':
        return const Color(0xFF64748B); // Slate
      default:
        return Colors.blueGrey;
    }
  }

  void _showAddStaffDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'OPERATIONS_MANAGER';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add_outlined, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Provision Staff Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Gap(6),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. Sunita Rao', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const Gap(14),
                    const Text('Official Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Gap(6),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. sunita.rao@drivego.in', border: OutlineInputBorder()),
                      validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                    ),
                    const Gap(14),
                    const Text('Mobile Number (10 digits)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Gap(6),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. 9876543210', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().length != 10 ? '10-digit mobile required' : null,
                    ),
                    const Gap(14),
                    const Text('Assigned Role & Scope', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Gap(6),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin (Full Access)')),
                        DropdownMenuItem(value: 'OPERATIONS_MANAGER', child: Text('Operations Manager (Fleet/Vendors/Bookings)')),
                        DropdownMenuItem(value: 'FINANCE_MANAGER', child: Text('Finance Manager (Payouts/Refunds/Ledger)')),
                        DropdownMenuItem(value: 'CUSTOMER_SUPPORT', child: Text('Customer Support (Tickets/Disputes)')),
                        DropdownMenuItem(value: 'COMPLIANCE_OFFICER', child: Text('Compliance Officer (KYC/Audit/Privacy)')),
                        DropdownMenuItem(value: 'MARKETING_MANAGER', child: Text('Marketing Manager (Promos/Coupons/Push)')),
                        DropdownMenuItem(value: 'READONLY_ANALYST', child: Text('Read-only Analyst (View-only)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedRole = val);
                      },
                    ),
                    const Gap(14),
                    const Text('Initial Password (min 8 chars)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Gap(6),
                    TextFormField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(hintText: '••••••••••••', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.length < 8 ? 'At least 8 characters required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Provision Account'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final repo = ref.read(adminStaffRepositoryProvider);
                  await repo.createStaff(
                    name: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    staffRole: selectedRole,
                    password: passCtrl.text,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(staffListProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Staff account for ${nameCtrl.text.trim()} provisioned successfully.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to provision staff: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRevokeSessionsDialog(StaffModel staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock_reset, color: Colors.orange),
            const SizedBox(width: 10),
            Text('Revoke Sessions for ${staff.name}'),
          ],
        ),
        content: Text(
          'Are you sure you want to invalidate all active refresh tokens for ${staff.name} (${staff.email ?? staff.phone})? They will be immediately logged out of all devices and administrative consoles.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(adminStaffRepositoryProvider);
                await repo.revokeStaffSessions(staff.id);
                ref.invalidate(staffListProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Active sessions for ${staff.name} revoked successfully.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to revoke sessions: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Revoke All Sessions'),
          ),
        ],
      ),
    );
  }

  void _showToggleSuspendDialog(StaffModel staff) {
    final willBan = !staff.banned;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(willBan ? Icons.block : Icons.check_circle, color: willBan ? Colors.red : Colors.green),
            const SizedBox(width: 10),
            Text('${willBan ? 'Suspend' : 'Reactivate'} ${staff.name}'),
          ],
        ),
        content: Text(
          willBan
              ? 'Suspending ${staff.name} will immediately block authentication and invalidate administrative permissions. This action is recorded in the immutable audit log.'
              : 'Reactivating ${staff.name} will restore access according to their assigned role (${staff.roleDisplayTitle}).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: willBan ? Colors.red : Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(adminStaffRepositoryProvider);
                await repo.updateStaff(staff.id, banned: willBan);
                ref.invalidate(staffListProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Staff member ${staff.name} ${willBan ? 'suspended' : 'reactivated'}.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(willBan ? 'Suspend Account' : 'Reactivate Account'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);
    final roleFilter = ref.watch(staffRoleFilterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Staff & Role Delegation',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Gap(4),
                    Text(
                      'Role-based access control, employee provisioning, dual-authorization limits, and session governance',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Provision Staff Member'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: _showAddStaffDialog,
                ),
              ],
            ),
            const Gap(20),

            // Summary KPI Cards
            staffAsync.maybeWhen(
              data: (list) {
                final total = list.length;
                final active = list.where((s) => !s.banned).length;
                final suspended = list.where((s) => s.banned).length;
                return Row(
                  children: [
                    _buildKpiCard('Total Staff', total.toString(), Icons.people_outline, const Color(0xFF2563EB)),
                    const Gap(16),
                    _buildKpiCard('Active Accounts', active.toString(), Icons.verified_user_outlined, const Color(0xFF059669)),
                    const Gap(16),
                    _buildKpiCard('Suspended / Locked', suspended.toString(), Icons.lock_clock_outlined, const Color(0xFFDC2626)),
                    const Gap(16),
                    _buildKpiCard('Defined Roles', '7 Workspaces', Icons.shield_outlined, const Color(0xFF7C3AED)),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const Gap(20),

            // Filters & Search Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by staff name, email, or phone...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onSubmitted: (val) {
                          ref.read(staffSearchQueryProvider.notifier).state = val.trim();
                        },
                      ),
                    ),
                    const Gap(16),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: roleFilter,
                        decoration: InputDecoration(
                          labelText: 'Filter by Role',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Staff Roles')),
                          DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin')),
                          DropdownMenuItem(value: 'OPERATIONS_MANAGER', child: Text('Operations Manager')),
                          DropdownMenuItem(value: 'FINANCE_MANAGER', child: Text('Finance Manager')),
                          DropdownMenuItem(value: 'CUSTOMER_SUPPORT', child: Text('Customer Support')),
                          DropdownMenuItem(value: 'COMPLIANCE_OFFICER', child: Text('Compliance Officer')),
                          DropdownMenuItem(value: 'MARKETING_MANAGER', child: Text('Marketing Manager')),
                          DropdownMenuItem(value: 'READONLY_ANALYST', child: Text('Read-only Analyst')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(staffRoleFilterProvider.notifier).state = val;
                          }
                        },
                      ),
                    ),
                    const Gap(16),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Staff List',
                      onPressed: () => ref.invalidate(staffListProvider),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(20),

            // Staff Table
            staffAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => Card(
                color: const Color(0xFFFEF2F2),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Failed to load staff accounts: $err', style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              ),
              data: (staffList) {
                if (staffList.isEmpty) {
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 48, color: Colors.grey),
                            Gap(12),
                            Text('No staff accounts match the filter criteria.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Gap(4),
                            Text('Click "Provision Staff Member" above to create an employee account.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                      columns: const [
                        DataColumn(label: Text('Staff Member', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Assigned Role', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Active Sessions', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Account Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Created Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: staffList.map((staff) {
                        final badgeColor = _getRoleBadgeColor(staff.staffRole);
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: badgeColor.withValues(alpha: 0.15),
                                    child: Text(
                                      staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(staff.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text(staff.email ?? staff.phone ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  staff.roleDisplayTitle,
                                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    staff.activeSessions > 0 ? Icons.check_circle : Icons.circle_outlined,
                                    size: 14,
                                    color: staff.activeSessions > 0 ? Colors.green : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('${staff.activeSessions} session(s)'),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: staff.banned ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  staff.banned ? 'SUSPENDED' : 'ACTIVE',
                                  style: TextStyle(
                                    color: staff.banned ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(DateFormat('dd MMM yyyy').format(staff.createdAt)),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.lock_reset, size: 18),
                                    tooltip: 'Revoke Active Sessions',
                                    onPressed: () => _showRevokeSessionsDialog(staff),
                                  ),
                                  IconButton(
                                    icon: Icon(staff.banned ? Icons.check_circle_outline : Icons.block, size: 18),
                                    tooltip: staff.banned ? 'Reactivate Account' : 'Suspend Account',
                                    color: staff.banned ? Colors.green : Colors.red,
                                    onPressed: () => _showToggleSuspendDialog(staff),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  const Gap(4),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';
import '../../domain/models/vendor_onboarding_models.dart';
import '../providers/admin_onboarding_providers.dart';

class VendorOnboardingConsolePage extends ConsumerStatefulWidget {
  const VendorOnboardingConsolePage({super.key});

  @override
  ConsumerState<VendorOnboardingConsolePage> createState() =>
      _VendorOnboardingConsolePageState();
}

class _VendorOnboardingConsolePageState
    extends ConsumerState<VendorOnboardingConsolePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _depositSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _depositSearchController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(amount);
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'DOCUMENT':
        return Colors.blue;
      case 'MONETARY':
        return Colors.green;
      case 'PHYSICAL_ASSET':
        return Colors.orange;
      case 'VERIFICATION':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }

  Color _getDepositStatusColor(String status) {
    switch (status) {
      case 'PAID':
        return Colors.green;
      case 'PARTIALLY_PAID':
        return Colors.orange;
      case 'PAYMENT_INITIATED':
        return Colors.deepPurple;
      case 'PAYMENT_FAILED':
        return Colors.red;
      case 'NOT_REQUIRED':
        return Colors.teal;
      case 'REFUND_PENDING':
        return Colors.amber[800]!;
      case 'PARTIALLY_REFUNDED':
        return Colors.indigo;
      case 'REVIEW_REQUIRED':
        return Colors.deepOrange;
      case 'HELD':
        return Colors.purple;
      case 'REQUIRED':
      case 'PENDING':
        return Colors.blue;
      case 'FORFEITED':
        return Colors.red[800]!;
      case 'RELEASED':
      case 'REFUNDED':
        return Colors.grey[700]!;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final definitionsAsync = ref.watch(onboardingDefinitionsProvider);
    final depositsAsync = ref.watch(adminDepositsProvider);
    final verificationsAsync = ref.watch(pendingVerificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 28),
                        Gap(10),
                        Text(
                          'Vendor Onboarding & Security Deposits',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      'Server-authoritative compliance governance, dynamic requirement definitions, and deposit ledgers',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await ref
                              .read(adminOnboardingRepositoryProvider)
                              .seedDefinitions();
                          ref.invalidate(onboardingDefinitionsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Standard onboarding definitions seeded successfully.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Seed Defaults'),
                    ),
                    const Gap(10),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh All',
                      onPressed: () {
                        ref.invalidate(onboardingDefinitionsProvider);
                        ref.invalidate(adminDepositsProvider);
                        ref.invalidate(pendingVerificationsProvider);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.rule_folder_outlined, size: 18),
                      const Gap(8),
                      const Text('Requirement Definitions'),
                      definitionsAsync.when(
                        data: (d) => Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${d.length}',
                            style: const TextStyle(fontSize: 11, color: Colors.blue),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.savings_outlined, size: 18),
                      const Gap(8),
                      const Text('Security Deposits'),
                      depositsAsync.when(
                        data: (d) => Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${d.length}',
                            style: const TextStyle(fontSize: 11, color: Colors.green),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fact_check_outlined, size: 18),
                      const Gap(8),
                      const Text('Verification Approvals'),
                      verificationsAsync.when(
                        data: (v) => v.isNotEmpty
                            ? Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${v.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequirementsTab(definitionsAsync),
                _buildDepositsTab(depositsAsync),
                _buildVerificationsTab(verificationsAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: REQUIREMENT DEFINITIONS VIEW
  // ==========================================
  Widget _buildRequirementsTab(AsyncValue<List<RequirementDefinitionModel>> definitionsAsync) {
    return definitionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading requirements: $err')),
      data: (defs) {
        final totalCount = defs.length;
        final activeCount = defs.where((d) => d.isActive).length;
        final mandatoryCount = defs.where((d) => d.isRequired).length;
        final serviceAreaCount = defs.where((d) => d.scope == 'SERVICE_AREA').length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Metric cards
              Row(
                children: [
                  _buildMetricCard(
                    title: 'Total Requirements',
                    value: '$totalCount',
                    icon: Icons.list_alt_rounded,
                    color: Colors.blue,
                  ),
                  const Gap(16),
                  _buildMetricCard(
                    title: 'Active Requirements',
                    value: '$activeCount',
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.green,
                  ),
                  const Gap(16),
                  _buildMetricCard(
                    title: 'Mandatory Compliance',
                    value: '$mandatoryCount',
                    icon: Icons.lock_outline_rounded,
                    color: Colors.amber[800] ?? Colors.amber,
                  ),
                  const Gap(16),
                  _buildMetricCard(
                    title: 'Service Area Scoped',
                    value: '$serviceAreaCount',
                    icon: Icons.location_on_outlined,
                    color: Colors.purple,
                  ),
                ],
              ),
              const Gap(24),

              // Filter & Actions Row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Text('Category:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Gap(8),
                    DropdownButton<String?>(
                      value: ref.watch(requirementCategoryFilterProvider),
                      underline: const SizedBox.shrink(),
                      hint: const Text('All Categories'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Categories')),
                        DropdownMenuItem(value: 'DOCUMENT', child: Text('Document')),
                        DropdownMenuItem(value: 'MONETARY', child: Text('Monetary')),
                        DropdownMenuItem(value: 'PHYSICAL_ASSET', child: Text('Physical Asset')),
                        DropdownMenuItem(value: 'VERIFICATION', child: Text('Verification')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        ref.read(requirementCategoryFilterProvider.notifier).state = val;
                      },
                    ),
                    const Gap(24),
                    const Text('Scope:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Gap(8),
                    DropdownButton<String?>(
                      value: ref.watch(requirementScopeFilterProvider),
                      underline: const SizedBox.shrink(),
                      hint: const Text('All Scopes'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Scopes')),
                        DropdownMenuItem(value: 'GLOBAL', child: Text('Global')),
                        DropdownMenuItem(value: 'SERVICE_AREA', child: Text('Service Area')),
                        DropdownMenuItem(value: 'VEHICLE_CATEGORY', child: Text('Vehicle Category')),
                        DropdownMenuItem(value: 'VENDOR_SPECIFIC', child: Text('Vendor Specific')),
                      ],
                      onChanged: (val) {
                        ref.read(requirementScopeFilterProvider.notifier).state = val;
                      },
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onPressed: () => _showAddRequirementDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Requirement'),
                    ),
                  ],
                ),
              ),
              const Gap(16),

              // Definitions Table Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: defs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('No requirement definitions match filters.')),
                      )
                    : Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2.5),
                          1: FlexColumnWidth(1.2),
                          2: FlexColumnWidth(1.2),
                          3: FlexColumnWidth(0.8),
                          4: FlexColumnWidth(0.8),
                          5: FlexColumnWidth(0.8),
                          6: FlexColumnWidth(1.0),
                        },
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            children: [
                              _buildTh('Requirement Name & Code'),
                              _buildTh('Category'),
                              _buildTh('Scope'),
                              _buildTh('Version'),
                              _buildTh('Type'),
                              _buildTh('Status'),
                              _buildTh('Actions'),
                            ],
                          ),
                          ...defs.map((def) {
                            return TableRow(
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        def.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const Gap(2),
                                      Text(
                                        def.code,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      if (def.description != null && def.description!.isNotEmpty) ...[
                                        const Gap(2),
                                        Text(
                                          def.description!,
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: _buildBadge(
                                    label: def.category,
                                    color: _getCategoryColor(def.category),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        def.scope,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (def.targetScopeValue != null)
                                        Text(
                                          def.targetScopeValue!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text('v${def.version}',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: def.isRequired
                                      ? _buildBadge(label: 'Mandatory', color: Colors.amber[800]!)
                                      : _buildBadge(label: 'Optional', color: Colors.grey),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Switch(
                                    value: def.isActive,
                                    activeThumbColor: AppColors.primary,
                                    onChanged: (newVal) async {
                                      await ref
                                          .read(adminOnboardingRepositoryProvider)
                                          .updateDefinition(def.id, {'isActive': newVal});
                                      ref.invalidate(onboardingDefinitionsProvider);
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: 'New Version',
                                        onPressed: () => _showEditRequirementDialog(context, def),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 2: SECURITY DEPOSITS VIEW
  // ==========================================
  Widget _buildDepositsTab(
      AsyncValue<List<VendorSecurityDepositModel>> depositsAsync) {
    return depositsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading deposits: $err')),
      data: (deposits) {
        final totalRequired =
            deposits.fold<double>(0.0, (acc, d) => acc + d.requiredAmount);
        final totalCollected =
            deposits.fold<double>(0.0, (acc, d) => acc + d.paidAmount);
        final totalRemaining =
            deposits.fold<double>(0.0, (acc, d) => acc + d.remainingAmount);
        final totalHeld = deposits
            .where((d) => d.status == 'HELD')
            .fold<double>(0.0, (acc, d) => acc + d.paidAmount);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Global Policy Banner
              _buildDepositPolicyHeaderCard(context),

              // Financial KPI Cards
              Row(
                children: [
                  _buildMetricCard(
                    title: 'Total Required Deposits',
                    value: _formatCurrency(totalRequired),
                    icon: Icons.account_balance_wallet_outlined,
                    color: Colors.blue,
                  ),
                  const Gap(16),
                  _buildMetricCard(
                    title: 'Total Collected Deposits',
                    value: _formatCurrency(totalCollected),
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  const Gap(16),
                  _buildMetricCard(
                    title: 'Outstanding Balances',
                    value: _formatCurrency(totalRemaining),
                    icon: Icons.pending_actions_outlined,
                    color: Colors.orange,
                  ),
                  const Gap(16),
                  _buildMetricCard(
                    title: 'Deposits on Hold',
                    value: _formatCurrency(totalHeld),
                    icon: Icons.pause_circle_outline,
                    color: Colors.purple,
                  ),
                ],
              ),
              const Gap(24),

              // Filter & Search bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _depositSearchController,
                        decoration: InputDecoration(
                          hintText:
                              'Search by partner name, vendor ID, or order ref...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _depositSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _depositSearchController.clear();
                                    ref
                                        .read(
                                            depositSearchQueryProvider.notifier)
                                        .state = '';
                                  },
                                )
                              : null,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        onSubmitted: (val) {
                          ref.read(depositSearchQueryProvider.notifier).state =
                              val;
                        },
                      ),
                    ),
                    const Gap(16),
                    const Text('Status:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Gap(8),
                    DropdownButton<String?>(
                      value: ref.watch(depositStatusFilterProvider),
                      underline: const SizedBox.shrink(),
                      hint: const Text('All Statuses'),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('All Statuses')),
                        DropdownMenuItem(
                            value: 'NOT_REQUIRED',
                            child: Text('Exempted / Not Required')),
                        DropdownMenuItem(
                            value: 'REQUIRED', child: Text('Required')),
                        DropdownMenuItem(
                            value: 'PAYMENT_INITIATED',
                            child: Text('Payment Initiated')),
                        DropdownMenuItem(
                            value: 'PARTIALLY_PAID',
                            child: Text('Partially Paid')),
                        DropdownMenuItem(
                            value: 'PAID', child: Text('Paid')),
                        DropdownMenuItem(
                            value: 'PAYMENT_FAILED',
                            child: Text('Payment Failed')),
                        DropdownMenuItem(
                            value: 'REFUND_PENDING',
                            child: Text('Refund Pending')),
                        DropdownMenuItem(
                            value: 'PARTIALLY_REFUNDED',
                            child: Text('Partially Refunded')),
                        DropdownMenuItem(
                            value: 'REFUNDED', child: Text('Refunded')),
                        DropdownMenuItem(
                            value: 'REVIEW_REQUIRED',
                            child: Text('Review Required')),
                        DropdownMenuItem(
                            value: 'HELD', child: Text('Held')),
                        DropdownMenuItem(
                            value: 'FORFEITED', child: Text('Forfeited')),
                        DropdownMenuItem(
                            value: 'RELEASED', child: Text('Released')),
                      ],
                      onChanged: (val) {
                        ref.read(depositStatusFilterProvider.notifier).state =
                            val;
                      },
                    ),
                  ],
                ),
              ),
              const Gap(16),

              // Deposits Table
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: deposits.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('No vendor deposits found.')),
                      )
                    : Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2.0),
                          1: FlexColumnWidth(1.0),
                          2: FlexColumnWidth(1.0),
                          3: FlexColumnWidth(1.0),
                          4: FlexColumnWidth(1.2),
                          5: FlexColumnWidth(1.6),
                          6: FlexColumnWidth(2.2),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              border: Border(
                                  bottom: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            children: [
                              _buildTh('Partner Identity'),
                              _buildTh('Required'),
                              _buildTh('Paid'),
                              _buildTh('Remaining'),
                              _buildTh('Status'),
                              _buildTh('Gateway / Order Ref'),
                              _buildTh('Controlled Actions'),
                            ],
                          ),
                          ...deposits.map((dep) {
                            return TableRow(
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom:
                                        BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dep.vendorBusinessName ??
                                            'Partner Account',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Gap(2),
                                      Text(
                                        dep.vendorContactName ?? dep.vendorId,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      if (dep.vendorPhone != null)
                                        Text(
                                          dep.vendorPhone!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                      _formatCurrency(dep.requiredAmount),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    _formatCurrency(dep.paidAmount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    _formatCurrency(dep.remainingAmount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: dep.remainingAmount > 0
                                          ? Colors.orange[800]
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: _buildBadge(
                                    label: dep.isExempt
                                        ? 'EXEMPTED'
                                        : dep.status,
                                    color: dep.isExempt
                                        ? Colors.teal
                                        : _getDepositStatusColor(dep.status),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dep.provider ?? 'RAZORPAY',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (dep.providerOrderId != null)
                                        Text(
                                          dep.providerOrderId!,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      if (dep.providerPaymentId != null)
                                        Text(
                                          'Pay: ${dep.providerPaymentId!}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.teal,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      Text(
                                        'Policy v${dep.policyVersion ?? 1}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.blueGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _buildActionButton(
                                        label: dep.isExempt
                                            ? 'Exempted'
                                            : 'Exempt',
                                        icon: Icons.verified_user_outlined,
                                        color: Colors.teal,
                                        onPressed: () =>
                                            _showExemptionDialog(context, dep),
                                      ),
                                      _buildActionButton(
                                        label: 'Pay',
                                        icon: Icons.add_card_outlined,
                                        color: Colors.green,
                                        onPressed: () =>
                                            _showRecordPaymentDialog(
                                                context, dep),
                                      ),
                                      _buildActionButton(
                                        label: 'Adjust',
                                        icon: Icons.tune_outlined,
                                        color: Colors.blue,
                                        onPressed: () =>
                                            _showAdjustDepositDialog(
                                                context, dep),
                                      ),
                                      if (dep.status == 'PAID' ||
                                          dep.status == 'PARTIALLY_PAID')
                                        _buildActionButton(
                                          label: 'Hold',
                                          icon: Icons.pause_circle_outline,
                                          color: Colors.purple,
                                          onPressed: () =>
                                              _showHoldDepositDialog(
                                                  context, dep),
                                        ),
                                      if (dep.status == 'HELD' ||
                                          dep.status == 'PAID')
                                        _buildActionButton(
                                          label: 'Release',
                                          icon: Icons.lock_open_outlined,
                                          color: Colors.teal,
                                          onPressed: () =>
                                              _showReleaseDepositDialog(
                                                  context, dep),
                                        ),
                                      if (dep.paidAmount > 0)
                                        _buildActionButton(
                                          label: 'Refund',
                                          icon: Icons.reply_outlined,
                                          color: Colors.blueGrey,
                                          onPressed: () =>
                                              _showRefundDepositDialog(
                                                  context, dep),
                                        ),
                                      if (dep.paidAmount > 0)
                                        _buildActionButton(
                                          label: 'Forfeit',
                                          icon: Icons.warning_amber_rounded,
                                          color: Colors.red,
                                          onPressed: () =>
                                              _showForfeitDepositDialog(
                                                  context, dep),
                                        ),
                                      _buildActionButton(
                                        label: 'Ledger',
                                        icon: Icons.history_rounded,
                                        color: Colors.indigo,
                                        onPressed: () =>
                                            _showLedgerDrawer(context, dep),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDepositPolicyHeaderCard(BuildContext context) {
    final policyAsync = ref.watch(adminDepositPolicyProvider);

    return policyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (policy) {
        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0F172A).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shield_outlined,
                            color: Color(0xFF0F172A), size: 20),
                      ),
                      const Gap(12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Centralized Vendor Security Deposit Policy',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Gap(8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Text(
                                  'Policy v${policy.version}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Gap(2),
                          const Text(
                            'Platform-wide financial governance controlling commercial onboarding deposit mandates.',
                            style: TextStyle(
                                fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Configure Policy'),
                    onPressed: () => _showEditPolicyDialog(context, policy),
                  ),
                ],
              ),
              const Gap(16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const Gap(16),
              Row(
                children: [
                  Expanded(
                    child: _buildPolicyDetailPill(
                      label: 'Mandatory Policy',
                      value: policy.isRequired
                          ? 'MANDATORY (Enforced)'
                          : 'OPTIONAL (Waived)',
                      color: policy.isRequired ? Colors.green : Colors.grey,
                      icon: policy.isRequired
                          ? Icons.check_circle
                          : Icons.toggle_off,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _buildPolicyDetailPill(
                      label: 'Standard Deposit',
                      value: '₹${policy.amount.toStringAsFixed(0)} INR',
                      color: Colors.blue,
                      icon: Icons.currency_rupee,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _buildPolicyDetailPill(
                      label: 'Refund Terms',
                      value: policy.refundPolicy.replaceAll('_', ' '),
                      color: Colors.teal,
                      icon: Icons.assignment_return_outlined,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _buildPolicyDetailPill(
                      label: 'Primary Gateway',
                      value: policy.paymentProvider,
                      color: Colors.indigo,
                      icon: Icons.payment,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _buildPolicyDetailPill(
                      label: 'Payment Deadline',
                      value: '${policy.deadlineDays} Days',
                      color: Colors.deepPurple,
                      icon: Icons.timelapse,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPolicyDetailPill({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditPolicyDialog(
      BuildContext context, VendorDepositPolicyModel policy) {
    bool isRequired = policy.isRequired;
    final amountCtrl =
        TextEditingController(text: policy.amount.toStringAsFixed(0));
    String refundPolicy = policy.refundPolicy;
    String provider = policy.paymentProvider;
    final deadlineCtrl =
        TextEditingController(text: policy.deadlineDays.toString());
    final descCtrl = TextEditingController(text: policy.description ?? '');
    final conditionsCtrl =
        TextEditingController(text: policy.refundConditions ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF0F172A)),
                const Gap(8),
                Text('Configure Deposit Policy (Current: v${policy.version})'),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mandatory Security Deposit',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text(
                          'When enabled, new partners must pay deposit before onboarding activation.'),
                      value: isRequired,
                      onChanged: (val) =>
                          setDialogState(() => isRequired = val),
                    ),
                    const Gap(16),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Standard Security Deposit Amount (INR) *',
                        hintText: 'e.g. 25000',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                    ),
                    const Gap(16),
                    DropdownButtonFormField<String>(
                      initialValue: refundPolicy,
                      decoration: const InputDecoration(
                        labelText: 'Refund Policy Terms *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'REFUNDABLE',
                            child: Text('100% Fully Refundable')),
                        DropdownMenuItem(
                            value: 'PARTIALLY_REFUNDABLE',
                            child: Text('Partially Refundable')),
                        DropdownMenuItem(
                            value: 'NON_REFUNDABLE',
                            child: Text('Non-Refundable')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => refundPolicy = val);
                        }
                      },
                    ),
                    const Gap(16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: provider,
                            decoration: const InputDecoration(
                              labelText: 'Payment Gateway',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'RAZORPAY',
                                  child: Text('Razorpay Payment Gateway')),
                              DropdownMenuItem(
                                  value: 'CASHFREE',
                                  child: Text('Cashfree Payments')),
                              DropdownMenuItem(
                                  value: 'STRIPE',
                                  child: Text('Stripe Payments')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => provider = val);
                              }
                            },
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: TextField(
                            controller: deadlineCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Payment Deadline (Days)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Public Policy Description & Partner Terms',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const Gap(16),
                    TextField(
                      controller: conditionsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Refund Conditions / Contract Clauses',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  final deadline =
                      int.tryParse(deadlineCtrl.text.trim()) ?? 14;
                  if (amount < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Please enter a valid deposit amount')),
                    );
                    return;
                  }

                  Navigator.pop(dialogCtx);
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    await ref
                        .read(adminOnboardingRepositoryProvider)
                        .updateDepositPolicy({
                      'isRequired': isRequired,
                      'amount': amount,
                      'currency': 'INR',
                      'refundPolicy': refundPolicy,
                      'paymentProvider': provider,
                      'deadlineDays': deadline,
                      'description': descCtrl.text.trim(),
                      'refundConditions': conditionsCtrl.text.trim(),
                    });

                    ref.invalidate(adminDepositPolicyProvider);
                    ref.invalidate(adminDepositsProvider);

                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Deposit policy updated successfully! New version published.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text('Failed to update policy: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('Publish New Policy Version'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showExemptionDialog(
      BuildContext context, VendorSecurityDepositModel dep) {
    bool isExempt = dep.isExempt;
    final reasonCtrl = TextEditingController(text: dep.exemptionReason ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: Colors.teal),
                const Gap(8),
                Text(
                    'Manage Exemption: ${dep.vendorBusinessName ?? dep.vendorId}'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Grant Security Deposit Exemption',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                        'Exempt partners do not need to pay security deposit to be approved.'),
                    value: isExempt,
                    onChanged: (val) => setDialogState(() => isExempt = val),
                  ),
                  const Gap(16),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Exemption Justification / Audit Reason *',
                      hintText:
                          'e.g. Enterprise partner waiver signed by VP Operations',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final reason = reasonCtrl.text.trim();
                  if (isExempt && reason.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Audit reason is required for exemptions.')),
                    );
                    return;
                  }

                  Navigator.pop(dialogCtx);
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    await ref
                        .read(adminOnboardingRepositoryProvider)
                        .setVendorExemption(
                          dep.vendorId,
                          isExempt: isExempt,
                          reason:
                              reason.isNotEmpty ? reason : 'Exemption revoked',
                        );

                    ref.invalidate(adminDepositsProvider);

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(isExempt
                            ? 'Security deposit exemption granted for ${dep.vendorBusinessName ?? dep.vendorId}.'
                            : 'Exemption revoked. Deposit requirement restored.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text('Failed to update exemption: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('Save Exemption Status'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 3: VERIFICATION APPROVALS QUEUE VIEW
  // ==========================================
  Widget _buildVerificationsTab(
      AsyncValue<List<PendingVerificationItemModel>> verificationsAsync) {
    return verificationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading verification queue: $err')),
      data: (items) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Queue Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inbox_outlined, size: 24, color: AppColors.primary),
                    const Gap(12),
                    Text(
                      'Pending Review Queue (${items.length} items)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    DropdownButton<String?>(
                      value: ref.watch(verificationCategoryFilterProvider),
                      underline: const SizedBox.shrink(),
                      hint: const Text('Filter by Category'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Categories')),
                        DropdownMenuItem(value: 'DOCUMENT', child: Text('Document')),
                        DropdownMenuItem(value: 'MONETARY', child: Text('Monetary')),
                        DropdownMenuItem(value: 'PHYSICAL_ASSET', child: Text('Physical Asset')),
                        DropdownMenuItem(value: 'VERIFICATION', child: Text('Verification')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        ref.read(verificationCategoryFilterProvider.notifier).state = val;
                      },
                    ),
                  ],
                ),
              ),
              const Gap(16),

              // Queue List
              if (items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.verified_outlined, size: 56, color: Colors.green[300]),
                      const Gap(16),
                      const Text(
                        'Verification Queue is Clear',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const Gap(6),
                      const Text(
                        'All partner compliance requirements and documents have been reviewed.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Gap(12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(item.category).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.description_outlined,
                              color: _getCategoryColor(item.category),
                              size: 28,
                            ),
                          ),
                          const Gap(16),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.vendorBusinessName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const Gap(8),
                                    _buildBadge(
                                      label: item.status,
                                      color: Colors.amber[800]!,
                                    ),
                                    const Gap(8),
                                    _buildBadge(
                                      label: item.category,
                                      color: _getCategoryColor(item.category),
                                    ),
                                  ],
                                ),
                                const Gap(6),
                                Text(
                                  'Requirement: ${item.requirementName} (${item.requirementCode})',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                if (item.documentNumber != null) ...[
                                  const Gap(2),
                                  Text(
                                    'Doc Number: ${item.documentNumber}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                                if (item.documentId != null) ...[
                                  const Gap(2),
                                  Text(
                                    'Document Reference: ${item.documentId}',
                                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                  ),
                                ],
                                const Gap(4),
                                Text(
                                  'Submitted: ${_formatDate(item.submittedAt)} • Vendor ID: ${item.vendorId}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Gap(16),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Approve'),
                                onPressed: () => _confirmApproval(context, item),
                              ),
                              const Gap(8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Reject'),
                                onPressed: () => _showRejectDialog(context, item),
                              ),
                              const Gap(8),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.purple,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                icon: const Icon(Icons.handshake_outlined, size: 16),
                                label: const Text('Waive'),
                                onPressed: () => _showWaiveDialog(context, item),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
  }

  // ==========================================
  // ACTION DIALOGS & DRAWERS
  // ==========================================

  void _showAddRequirementDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final targetScopeCtrl = TextEditingController();
    String category = 'DOCUMENT';
    String scope = 'GLOBAL';
    bool isRequired = true;
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Requirement Definition'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Code *',
                      hintText: 'e.g. DOC_SPEED_GOVERNOR',
                    ),
                  ),
                  const Gap(12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Requirement Name *',
                      hintText: 'e.g. Speed Governor Fitment Certificate',
                    ),
                  ),
                  const Gap(12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Operational guidelines for partner compliance',
                    ),
                    maxLines: 2,
                  ),
                  const Gap(12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: const [
                            DropdownMenuItem(value: 'DOCUMENT', child: Text('Document')),
                            DropdownMenuItem(value: 'MONETARY', child: Text('Monetary')),
                            DropdownMenuItem(value: 'PHYSICAL_ASSET', child: Text('Physical Asset')),
                            DropdownMenuItem(value: 'VERIFICATION', child: Text('Verification')),
                            DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => category = val);
                          },
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: scope,
                          decoration: const InputDecoration(labelText: 'Scope'),
                          items: const [
                            DropdownMenuItem(value: 'GLOBAL', child: Text('Global')),
                            DropdownMenuItem(value: 'SERVICE_AREA', child: Text('Service Area')),
                            DropdownMenuItem(value: 'VEHICLE_CATEGORY', child: Text('Vehicle Category')),
                            DropdownMenuItem(value: 'VENDOR_SPECIFIC', child: Text('Vendor Specific')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => scope = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (scope != 'GLOBAL') ...[
                    const Gap(12),
                    TextField(
                      controller: targetScopeCtrl,
                      decoration: InputDecoration(
                        labelText: scope == 'SERVICE_AREA'
                            ? 'Service Area ID *'
                            : scope == 'VEHICLE_CATEGORY'
                                ? 'Vehicle Category (e.g. SUV) *'
                                : 'Vendor ID *',
                      ),
                    ),
                  ],
                  const Gap(16),
                  Row(
                    children: [
                      Checkbox(
                        value: isRequired,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setDialogState(() => isRequired = v ?? true),
                      ),
                      const Text('Mandatory (Blocks Activation)'),
                      const Spacer(),
                      Checkbox(
                        value: isActive,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setDialogState(() => isActive = v ?? true),
                      ),
                      const Text('Active'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code and Name are required.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref.read(adminOnboardingRepositoryProvider).createDefinition({
                    'code': codeCtrl.text.trim().toUpperCase(),
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    'category': category,
                    'scope': scope,
                    'targetScopeValue':
                        targetScopeCtrl.text.trim().isEmpty ? null : targetScopeCtrl.text.trim(),
                    'isRequired': isRequired,
                    'isActive': isActive,
                  });
                  ref.invalidate(onboardingDefinitionsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Requirement definition created successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Create Definition'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRequirementDialog(BuildContext context, RequirementDefinitionModel def) {
    final nameCtrl = TextEditingController(text: def.name);
    final descCtrl = TextEditingController(text: def.description ?? '');
    final reasonCtrl = TextEditingController();
    bool createNewVersion = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit ${def.code} (Current v${def.version})'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const Gap(12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const Gap(16),
                Row(
                  children: [
                    Checkbox(
                      value: createNewVersion,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setDialogState(() => createNewVersion = v ?? true),
                    ),
                    const Text('Increment version non-destructively (Recommended)'),
                  ],
                ),
                if (createNewVersion) ...[
                  const Gap(8),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Versioning Audit Reason *',
                      hintText: 'e.g. Updated standard policy specification',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(adminOnboardingRepositoryProvider).updateDefinition(def.id, {
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'createNewVersion': createNewVersion,
                    if (createNewVersion) 'reason': reasonCtrl.text.trim(),
                  });
                  ref.invalidate(onboardingDefinitionsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Requirement updated successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, VendorSecurityDepositModel dep) {
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String paymentMethod = 'BANK_TRANSFER';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Record Payment — ${dep.vendorBusinessName ?? dep.vendorId}'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Outstanding Remaining: ${_formatCurrency(dep.remainingAmount)} (Required: ${_formatCurrency(dep.requiredAmount)})',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
                ),
                const Gap(16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Payment Amount (₹) *'),
                ),
                const Gap(12),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment Channel *'),
                  items: const [
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT/RTGS)')),
                    DropdownMenuItem(value: 'ONLINE_RAZORPAY', child: Text('Online / Razorpay')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('Demand Draft / Cheque')),
                    DropdownMenuItem(value: 'ADMIN_RECORDED', child: Text('Admin Manual Entry')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => paymentMethod = v);
                  },
                ),
                const Gap(12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Payment Reference / Bank UTR *',
                    hintText: 'e.g. UTR12345678',
                  ),
                ),
                const Gap(12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Audit Reason / Notes',
                    hintText: 'e.g. Verified wire transfer credit receipt',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amt <= 0 || refCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Amount and Reference are mandatory.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref.read(adminOnboardingRepositoryProvider).recordPayment(
                        dep.vendorId,
                        amount: amt,
                        paymentMethod: paymentMethod,
                        reference: refCtrl.text.trim(),
                        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                      );
                  ref.invalidate(adminDepositsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Deposit payment recorded successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustDepositDialog(BuildContext context, VendorSecurityDepositModel dep) {
    final amountCtrl = TextEditingController();
    final newReqCtrl = TextEditingController(text: dep.requiredAmount.toStringAsFixed(0));
    final reasonCtrl = TextEditingController();
    String direction = 'CREDIT';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Adjust Deposit — ${dep.vendorBusinessName ?? dep.vendorId}'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Current Paid: ${_formatCurrency(dep.paidAmount)} | Status: ${dep.status}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
                ),
                const Gap(16),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: direction,
                        decoration: const InputDecoration(labelText: 'Direction'),
                        items: const [
                          DropdownMenuItem(value: 'CREDIT', child: Text('+ Credit')),
                          DropdownMenuItem(value: 'DEBIT', child: Text('- Debit')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => direction = v);
                        },
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Adjustment Amount (₹) *'),
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                TextField(
                  controller: newReqCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Update Required Amount (₹, optional)',
                  ),
                ),
                const Gap(12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mandatory Audit Reason *',
                    hintText: 'e.g. Contractual tier fee revision adjustment',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                final newReq = double.tryParse(newReqCtrl.text.trim());
                if (amt <= 0 || reasonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Amount and Audit Reason are required.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref.read(adminOnboardingRepositoryProvider).adjustDeposit(
                        dep.vendorId,
                        amount: amt,
                        direction: direction,
                        newRequiredAmount: newReq,
                        reason: reasonCtrl.text.trim(),
                      );
                  ref.invalidate(adminDepositsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Deposit adjusted successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Adjustment failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Apply Adjustment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHoldDepositDialog(BuildContext context, VendorSecurityDepositModel dep) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hold Partner Deposit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to put a HOLD on ${dep.vendorBusinessName}\'s deposit (${_formatCurrency(dep.paidAmount)})?',
            ),
            const Gap(12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Mandatory Audit Reason *',
                hintText: 'e.g. Under investigation for unresolved booking claims',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audit reason is mandatory.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref
                    .read(adminOnboardingRepositoryProvider)
                    .holdDeposit(dep.vendorId, reason: reasonCtrl.text.trim());
                ref.invalidate(adminDepositsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deposit put on hold.'), backgroundColor: Colors.purple),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Hold Deposit'),
          ),
        ],
      ),
    );
  }

  void _showReleaseDepositDialog(BuildContext context, VendorSecurityDepositModel dep) {
    final refCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release Deposit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Releasing deposit of ${_formatCurrency(dep.paidAmount)} back to ${dep.vendorBusinessName}.',
            ),
            const Gap(12),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(labelText: 'Clearance Reference Number *'),
            ),
            const Gap(12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Mandatory Audit Reason *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              if (refCtrl.text.trim().isEmpty || reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reference and Reason are required.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(adminOnboardingRepositoryProvider).releaseDeposit(
                      dep.vendorId,
                      reference: refCtrl.text.trim(),
                      reason: reasonCtrl.text.trim(),
                    );
                ref.invalidate(adminDepositsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deposit released successfully.'), backgroundColor: Colors.teal),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Release Deposit'),
          ),
        ],
      ),
    );
  }

  void _showRefundDepositDialog(BuildContext context, VendorSecurityDepositModel dep) {
    final amountCtrl = TextEditingController(text: dep.paidAmount.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refund Security Deposit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Refund Amount (₹) *'),
            ),
            const Gap(12),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(labelText: 'Bank Transfer Reference *'),
            ),
            const Gap(12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Audit Reason *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amt <= 0 || refCtrl.text.trim().isEmpty || reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All fields are mandatory.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(adminOnboardingRepositoryProvider).refundDeposit(
                      dep.vendorId,
                      amount: amt,
                      reference: refCtrl.text.trim(),
                      reason: reasonCtrl.text.trim(),
                    );
                ref.invalidate(adminDepositsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deposit refund executed.'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Execute Refund'),
          ),
        ],
      ),
    );
  }

  void _showForfeitDepositDialog(BuildContext context, VendorSecurityDepositModel dep) {
    final amountCtrl = TextEditingController(text: dep.paidAmount.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            Gap(8),
            Text('Forfeit Security Deposit', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'WARNING: Forfeiture is a non-reversible punitive financial action resulting from severe breach of contract.',
              style: TextStyle(fontSize: 13, color: Colors.red),
            ),
            const Gap(16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Forfeiture Amount (₹) *'),
            ),
            const Gap(12),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(labelText: 'Legal / Breach Case Ref *'),
            ),
            const Gap(12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Mandatory Legal & Audit Reason *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amt <= 0 || refCtrl.text.trim().isEmpty || reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All fields are required.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(adminOnboardingRepositoryProvider).forfeitDeposit(
                      dep.vendorId,
                      amount: amt,
                      reference: refCtrl.text.trim(),
                      reason: reasonCtrl.text.trim(),
                    );
                ref.invalidate(adminDepositsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deposit forfeited.'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Confirm Forfeiture'),
          ),
        ],
      ),
    );
  }

  void _showLedgerDrawer(BuildContext context, VendorSecurityDepositModel dep) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audit Ledger — ${dep.vendorBusinessName ?? dep.vendorId}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const Gap(2),
                    Text(
                      'Chronological, immutable financial ledger of all deposit mutations',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final ledgerAsync =
                      ref.watch(selectedVendorDepositLedgerProvider(dep.vendorId));
                  return ledgerAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error loading ledger: $e')),
                    data: (entries) {
                      if (entries.isEmpty) {
                        return const Center(child: Text('No ledger entries recorded yet.'));
                      }
                      return ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          final isCredit = e.direction == 'CREDIT';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isCredit ? Colors.green : Colors.red)
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCredit
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    size: 20,
                                    color: isCredit ? Colors.green : Colors.red,
                                  ),
                                ),
                                const Gap(16),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.transactionType,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const Gap(2),
                                      Text(
                                        'Ref: ${e.reference} • Channel: ${e.paymentMethod}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      if (e.reason != null && e.reason!.isNotEmpty) ...[
                                        const Gap(2),
                                        Text(
                                          'Reason: ${e.reason!}',
                                          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${isCredit ? "+" : "-"}${_formatCurrency(e.amount)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isCredit ? Colors.green : Colors.red,
                                        ),
                                      ),
                                      const Gap(2),
                                      Text(
                                        'Bal: ${_formatCurrency(e.balanceAfter)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      const Gap(2),
                                      Text(
                                        _formatDate(e.createdAt),
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmApproval(BuildContext context, PendingVerificationItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Submission?'),
        content: Text(
          'Approve requirement "${item.requirementName}" for ${item.vendorBusinessName}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(adminOnboardingRepositoryProvider).reviewRequirement(
                      item.vendorId,
                      item.requirementId,
                      status: 'APPROVED',
                    );
                ref.invalidate(pendingVerificationsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Requirement verified.'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Approval failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, PendingVerificationItemModel item) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Submission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specify mandatory rejection reason for ${item.vendorBusinessName}:'),
            const Gap(12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Rejection Notes *',
                hintText: 'e.g. Document copy is blurred or expired',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rejection reason is mandatory.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(adminOnboardingRepositoryProvider).reviewRequirement(
                      item.vendorId,
                      item.requirementId,
                      status: 'REJECTED',
                      rejectionReason: reasonCtrl.text.trim(),
                    );
                ref.invalidate(pendingVerificationsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Submission rejected.'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Reject Submission'),
          ),
        ],
      ),
    );
  }

  void _showWaiveDialog(BuildContext context, PendingVerificationItemModel item) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Waive Requirement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Waive requirement "${item.requirementName}" for ${item.vendorBusinessName}?'),
            const Gap(12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Mandatory Waiver Justification *',
                hintText: 'e.g. Enterprise SLA partnership exception approved by operations',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Waiver justification is mandatory.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(adminOnboardingRepositoryProvider).waiveRequirement(
                      item.vendorId,
                      item.requirementId,
                      reason: reasonCtrl.text.trim(),
                    );
                ref.invalidate(pendingVerificationsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Requirement waived.'), backgroundColor: Colors.purple),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Waive Requirement'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const Gap(4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTh(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const Gap(4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

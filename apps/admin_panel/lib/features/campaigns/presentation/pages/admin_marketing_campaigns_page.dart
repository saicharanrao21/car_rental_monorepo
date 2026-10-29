import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/admin_detail_drawer.dart';
import '../../../../core/widgets/admin_data_grid.dart';
import '../providers/admin_campaigns_providers.dart';

class AdminMarketingCampaignsPage extends ConsumerStatefulWidget {
  const AdminMarketingCampaignsPage({super.key});

  @override
  ConsumerState<AdminMarketingCampaignsPage> createState() => _AdminMarketingCampaignsPageState();
}

class _AdminMarketingCampaignsPageState extends ConsumerState<AdminMarketingCampaignsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _cityFilter = 'ALL';
  String _statusFilter = 'ALL';
  bool _isDemoMode = false;

  // Isolated Demo Data — only visible when the administrator explicitly enables demo mode
  static final List<Map<String, dynamic>> _demoCampaigns = [
    {
      'id': 'demo_cmp_101',
      'code': 'BLR_ESCAPE_20',
      'name': 'Bangalore Monsoon Getaway 20% OFF (Demo)',
      'type': 'WEEKEND',
      'city': 'Bangalore',
      'carCategory': 'SUV',
      'discountType': 'PERCENTAGE',
      'discountValue': 20.0,
      'maxDiscountAmount': 1500.0,
      'minBookingAmount': 3500.0,
      'budget': 50000.0,
      'spent': 28400.0,
      'redemptions': 142,
      'maxRedemptions': 250,
      'startDate': DateTime.now().subtract(const Duration(days: 10)),
      'endDate': DateTime.now().add(const Duration(days: 20)),
      'status': 'ACTIVE',
      'channels': ['WHATSAPP', 'PUSH', 'BANNER'],
      'audience': 'Weekend Travelers (Bangalore)',
      'attributedGmv': 624000.0,
      'isDemo': true,
    },
    {
      'id': 'demo_cmp_102',
      'code': 'HYD_WELCOME_500',
      'name': 'Hyderabad First Ride Welcome Bonus (Demo)',
      'type': 'FIRST_BOOKING',
      'city': 'Hyderabad',
      'carCategory': 'ANY',
      'discountType': 'FLAT',
      'discountValue': 500.0,
      'maxDiscountAmount': 500.0,
      'minBookingAmount': 2000.0,
      'budget': 75000.0,
      'spent': 34500.0,
      'redemptions': 69,
      'maxRedemptions': 150,
      'startDate': DateTime.now().subtract(const Duration(days: 25)),
      'endDate': DateTime.now().add(const Duration(days: 35)),
      'status': 'ACTIVE',
      'channels': ['PUSH', 'SMS'],
      'audience': 'New Verified Customers (0 Bookings)',
      'attributedGmv': 289000.0,
      'isDemo': true,
    },
    {
      'id': 'demo_cmp_103',
      'code': 'MUM_LUXURY_30',
      'name': 'Mumbai Corporate & Luxury Fleet (Demo)',
      'type': 'SPONSORED',
      'city': 'Mumbai',
      'carCategory': 'LUXURY',
      'discountType': 'PERCENTAGE',
      'discountValue': 15.0,
      'maxDiscountAmount': 3000.0,
      'minBookingAmount': 8000.0,
      'budget': 60000.0,
      'spent': 42000.0,
      'redemptions': 38,
      'maxRedemptions': 50,
      'startDate': DateTime.now().subtract(const Duration(days: 15)),
      'endDate': DateTime.now().add(const Duration(days: 15)),
      'status': 'ACTIVE',
      'channels': ['WHATSAPP', 'EMAIL', 'BANNER'],
      'audience': 'High LTV & Corporate Accounts',
      'attributedGmv': 840000.0,
      'isDemo': true,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateCampaignDrawer() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final discountValCtrl = TextEditingController(text: '20');
    final maxDiscountCtrl = TextEditingController(text: '1500');
    final minBookingCtrl = TextEditingController(text: '3000');
    final budgetCtrl = TextEditingController(text: '50000');
    final maxRedemptionsCtrl = TextEditingController(text: '200');

    String type = 'GENERAL';
    String city = 'ALL';
    String carCategory = 'ANY';
    String discountType = 'PERCENTAGE';
    String audienceSegment = 'ALL_CUSTOMERS';
    final Set<String> channels = {'PUSH', 'WHATSAPP'};
    bool isSaving = false;

    AdminDetailDrawer.show(
      context: context,
      title: 'Create Growth Marketing Campaign',
      subtitle: 'Targeted multi-channel campaign with automated budget caps',
      width: 540,
      child: StatefulBuilder(
        builder: (ctx, setDrawerState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Campaign Name *',
                hintText: 'e.g. Pune Weekend Getaway',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Promo / Campaign Code *',
                hintText: 'e.g. PUNEWEEKEND20',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(14),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Campaign Objective', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'GENERAL', child: Text('General Promotional')),
                      DropdownMenuItem(value: 'FIRST_BOOKING', child: Text('New Customer Acquisition')),
                      DropdownMenuItem(value: 'WEEKEND', child: Text('Weekend Escape')),
                      DropdownMenuItem(value: 'FESTIVAL', child: Text('Festival Special')),
                      DropdownMenuItem(value: 'CITY_LAUNCH', child: Text('City Launch Push')),
                    ],
                    onChanged: (v) => setDrawerState(() => type = v ?? 'GENERAL'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: city,
                    decoration: const InputDecoration(labelText: 'Target City Scope', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Cities (National)')),
                      DropdownMenuItem(value: 'Bangalore', child: Text('Bangalore')),
                      DropdownMenuItem(value: 'Hyderabad', child: Text('Hyderabad')),
                      DropdownMenuItem(value: 'Mumbai', child: Text('Mumbai')),
                      DropdownMenuItem(value: 'Delhi-NCR', child: Text('Delhi-NCR')),
                      DropdownMenuItem(value: 'Pune', child: Text('Pune')),
                      DropdownMenuItem(value: 'Chennai', child: Text('Chennai')),
                    ],
                    onChanged: (v) => setDrawerState(() => city = v ?? 'ALL'),
                  ),
                ),
              ],
            ),
            const Gap(14),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: discountType,
                    decoration: const InputDecoration(labelText: 'Discount Structure', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage (% OFF)')),
                      DropdownMenuItem(value: 'FLAT', child: Text('Flat Cash (₹ OFF)')),
                    ],
                    onChanged: (v) => setDrawerState(() => discountType = v ?? 'PERCENTAGE'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: TextField(
                    controller: discountValCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: discountType == 'PERCENTAGE' ? 'Discount (%) *' : 'Flat Discount (₹) *',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const Gap(14),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: maxDiscountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Discount Cap (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: TextField(
                    controller: minBookingCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min Booking Fare (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const Gap(14),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: budgetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Budget Cap (₹) *',
                      helperText: 'Auto-stops when depleted',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: TextField(
                    controller: maxRedemptionsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Redemptions *',
                      helperText: 'Overall customer limit',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const Gap(14),

            DropdownButtonFormField<String>(
              value: audienceSegment,
              decoration: const InputDecoration(labelText: 'Target Audience Segment', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'ALL_CUSTOMERS', child: Text('All Registered & Verified Customers')),
                DropdownMenuItem(value: 'NEW_USERS_ONLY', child: Text('New Customers (0 Past Bookings)')),
                DropdownMenuItem(value: 'LAPSED_USERS', child: Text('Dormant Customers (No trip in 60+ days)')),
                DropdownMenuItem(value: 'HIGH_LTV_VIP', child: Text('DriveGo Elite VIP Members (5+ trips)')),
              ],
              onChanged: (v) => setDrawerState(() => audienceSegment = v ?? 'ALL_CUSTOMERS'),
            ),
            const Gap(14),

            // Distribution Channels
            const Text('Dispatch & Visibility Channels:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Gap(6),
            Wrap(
              spacing: 8,
              children: ['BANNER', 'PUSH', 'WHATSAPP', 'SMS', 'EMAIL'].map((ch) {
                final isSelected = channels.contains(ch);
                return FilterChip(
                  label: Text(ch),
                  selected: isSelected,
                  onSelected: (selected) {
                    setDrawerState(() {
                      if (selected) {
                        channels.add(ch);
                      } else {
                        channels.remove(ch);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const Gap(20),

            // Budget Protection Notice Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF1E40AF), size: 18),
                  Gap(10),
                  Expanded(
                    child: Text(
                      'Server-Authoritative Safeguard: Concurrent redemptions are serialized via row-level locks. Campaign automatically pauses when budget or redemption cap is exhausted.',
                      style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(24),

            FilledButton.icon(
              icon: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.rocket_launch_outlined),
              label: Text(isSaving ? 'Creating Campaign...' : 'Launch Marketing Campaign'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: isSaving ? null : () async {
                if (nameCtrl.text.isEmpty || codeCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter campaign name and code.')),
                  );
                  return;
                }

                setDrawerState(() => isSaving = true);

                try {
                  await ref.read(adminCampaignsProvider.notifier).createCampaign({
                    'code': codeCtrl.text.trim().toUpperCase(),
                    'name': nameCtrl.text.trim(),
                    'type': type,
                    'city': city == 'ALL' ? null : city,
                    'carCategory': carCategory == 'ANY' ? null : carCategory,
                    'discountType': discountType,
                    'discountValue': double.tryParse(discountValCtrl.text) ?? 20.0,
                    'maxDiscountAmount': double.tryParse(maxDiscountCtrl.text),
                    'minBookingAmount': double.tryParse(minBookingCtrl.text),
                    'budget': double.tryParse(budgetCtrl.text),
                    'maxRedemptions': int.tryParse(maxRedemptionsCtrl.text),
                  });

                  Navigator.of(ctx).pop();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Campaign created and saved to database successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (err) {
                  setDrawerState(() => isSaving = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create campaign: $err'),
                        backgroundColor: Colors.red,
                      ),
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

  void _inspectCampaign(Map<String, dynamic> c) {
    final cur = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final budget = (c['budget'] as num?)?.toDouble() ?? 0.0;
    final spent = (c['spent'] as num?)?.toDouble() ?? 0.0;
    final utilization = budget > 0 ? ((spent / budget) * 100).toStringAsFixed(1) : '0.0';

    AdminDetailDrawer.show(
      context: context,
      title: c['name'] as String,
      subtitle: 'Code: ${c['code']} • Status: ${c['status']}',
      width: 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Attributed GMV', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    Text(
                      cur.format(c['attributedGmv'] ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Budget Utilization ($utilization%)',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    Text(
                      '${cur.format(spent)} / ${budget > 0 ? cur.format(budget) : 'No Cap'}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
                const Gap(8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0,
                    backgroundColor: const Color(0xFFCBD5E1),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF0F172A)),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),
          _buildInfoRow('Campaign Code', c['code'] as String),
          _buildInfoRow('Type', c['type'] as String),
          _buildInfoRow('City Scope', c['city'] as String),
          _buildInfoRow('Discount', '${c['discountValue']}${c['discountType'] == 'PERCENTAGE' ? '%' : '₹'} OFF'),
          _buildInfoRow('Max Cap', cur.format(c['maxDiscountAmount'] ?? 0)),
          _buildInfoRow('Min Booking', cur.format(c['minBookingAmount'] ?? 0)),
          _buildInfoRow('Redemptions', '${c['redemptions']} / ${c['maxRedemptions'] ?? 'Unlimited'}'),
          _buildInfoRow('Audience Segment', c['audience']?.toString() ?? 'All Customers'),
          const Gap(24),
          OutlinedButton.icon(
            icon: Icon(c['status'] == 'ACTIVE' ? Icons.pause_circle_outline : Icons.play_circle_outline),
            label: Text(c['status'] == 'ACTIVE' ? 'Pause Campaign' : 'Resume Campaign'),
            onPressed: () async {
              final newActive = c['status'] != 'ACTIVE';
              Navigator.of(context).pop();

              try {
                await ref.read(adminCampaignsProvider.notifier).toggleCampaign(c['id'].toString(), newActive);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(newActive ? 'Campaign resumed.' : 'Campaign paused.'),
                      backgroundColor: Colors.blueGrey,
                    ),
                  );
                }
              } catch (err) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update campaign status: $err'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cur = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    final asyncCampaigns = ref.watch(adminCampaignsProvider);
    final List<Map<String, dynamic>> rawList = _isDemoMode
        ? _demoCampaigns
        : (asyncCampaigns.value ?? []);

    final filtered = rawList.where((c) {
      if (_cityFilter != 'ALL' && c['city'] != _cityFilter) return false;
      if (_statusFilter != 'ALL' && c['status'] != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (c['name'] as String).toLowerCase();
        final code = (c['code'] as String).toLowerCase();
        if (!name.contains(q) && !code.contains(q)) return false;
      }
      return true;
    }).toList();

    // Dynamically calculate KPIs from actual campaigns list (never hardcoded)
    final activeCount = rawList.where((c) => c['status'] == 'ACTIVE').length;
    final totalRedemptions = rawList.fold<int>(0, (sum, c) => sum + ((c['redemptions'] as num?)?.toInt() ?? 0));
    final totalSpent = rawList.fold<double>(0.0, (sum, c) => sum + ((c['spent'] as num?)?.toDouble() ?? 0.0));
    final totalBudget = rawList.fold<double>(0.0, (sum, c) => sum + ((c['budget'] as num?)?.toDouble() ?? 0.0));
    final totalAttributedGmv = rawList.fold<double>(0.0, (sum, c) => sum + ((c['attributedGmv'] as num?)?.toDouble() ?? 0.0));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Marketing Campaigns & Attribution',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF2F8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFBCFE8)),
                          ),
                          child: const Text(
                            'AUTOMATED BUDGET CAP PROTECTION',
                            style: TextStyle(
                              color: Color(0xFFBE185D),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (_isDemoMode)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Text(
                              'DEMO DATA MODE',
                              style: TextStyle(
                                color: Color(0xFFB45309),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      'Create targeted promotional and sponsored campaigns with city scoping, audience segmentation, and live ROI tracking.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: Icon(_isDemoMode ? Icons.toggle_on : Icons.toggle_off, color: _isDemoMode ? Colors.orange : Colors.grey),
                      label: Text(_isDemoMode ? 'Exit Demo Mode' : 'View Demo Data'),
                      onPressed: () => setState(() => _isDemoMode = !_isDemoMode),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create Campaign'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onPressed: _showCreateCampaignDrawer,
                    ),
                  ],
                ),
              ],
            ),
            const Gap(20),

            // Top Dynamic KPI Bar (Driven authoritatively by data)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSummaryKpi('Active Campaigns', '$activeCount Active', Icons.campaign_outlined, const Color(0xFF059669)),
                _buildSummaryKpi('Total Campaigns', '${rawList.length} Total', Icons.layers_outlined, const Color(0xFF3B82F6)),
                _buildSummaryKpi('Redemptions', '$totalRedemptions trips', Icons.check_circle_outlined, const Color(0xFF6366F1)),
                _buildSummaryKpi('Budget Spent', '${cur.format(totalSpent)} / ${totalBudget > 0 ? cur.format(totalBudget) : 'N/A'}', Icons.currency_rupee_outlined, const Color(0xFFF59E0B)),
                _buildSummaryKpi('Attributed GMV', cur.format(totalAttributedGmv), Icons.trending_up_outlined, const Color(0xFF10B981)),
              ],
            ),
            const Gap(20),

            // Filters Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by campaign name or code...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const Gap(16),
                  DropdownButton<String>(
                    value: _cityFilter,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Cities')),
                      DropdownMenuItem(value: 'Bangalore', child: Text('Bangalore')),
                      DropdownMenuItem(value: 'Hyderabad', child: Text('Hyderabad')),
                      DropdownMenuItem(value: 'Mumbai', child: Text('Mumbai')),
                      DropdownMenuItem(value: 'Delhi-NCR', child: Text('Delhi-NCR')),
                      DropdownMenuItem(value: 'Pune', child: Text('Pune')),
                    ],
                    onChanged: (v) => setState(() => _cityFilter = v ?? 'ALL'),
                  ),
                  const Gap(16),
                  DropdownButton<String>(
                    value: _statusFilter,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active Only')),
                      DropdownMenuItem(value: 'PAUSED', child: Text('Paused')),
                      DropdownMenuItem(value: 'SCHEDULED', child: Text('Scheduled')),
                      DropdownMenuItem(value: 'EXHAUSTED', child: Text('Budget Exhausted')),
                      DropdownMenuItem(value: 'EXPIRED', child: Text('Expired')),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v ?? 'ALL'),
                  ),
                  const Gap(16),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh from Server',
                    onPressed: () => ref.read(adminCampaignsProvider.notifier).refresh(),
                  ),
                ],
              ),
            ),
            const Gap(16),

            // Main Content Area with Explicit Loading, Error, Empty, and Live States
            Expanded(
              child: _isDemoMode
                  ? _buildDataGrid(theme, cur, filtered)
                  : asyncCampaigns.when(
                      loading: () => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            Gap(16),
                            Text('Loading campaigns from server...', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          constraints: const BoxConstraints(maxWidth: 480),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_rounded, color: Colors.red, size: 48),
                              const Gap(12),
                              const Text('Failed to load campaigns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Gap(6),
                              Text(err.toString(), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              const Gap(16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                    onPressed: () => ref.read(adminCampaignsProvider.notifier).refresh(),
                                  ),
                                  const Gap(12),
                                  FilledButton.icon(
                                    icon: const Icon(Icons.play_circle_outline),
                                    label: const Text('View Sample Demo Data'),
                                    onPressed: () => setState(() => _isDemoMode = true),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      data: (campaigns) {
                        if (campaigns.isEmpty) {
                          return Center(
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              constraints: const BoxConstraints(maxWidth: 480),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.campaign_outlined, color: Colors.blueGrey, size: 48),
                                  const Gap(12),
                                  const Text('No Marketing Campaigns Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const Gap(6),
                                  Text(
                                    'No promotional or growth campaigns are currently registered in the database. Create your first campaign to boost bookings.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                  const Gap(16),
                                  FilledButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Create First Campaign'),
                                    onPressed: _showCreateCampaignDrawer,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return _buildDataGrid(theme, cur, filtered);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataGrid(ThemeData theme, NumberFormat cur, List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: AdminDataGrid<Map<String, dynamic>>(
        items: items,
        columns: [
          AdminDataColumn<Map<String, dynamic>>(
            title: 'CAMPAIGN CODE',
            fixedWidth: 160,
            builder: (item) => Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    item['code'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                if (item['isDemo'] == true) ...[
                  const Gap(4),
                  const Text('(DEMO)', style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
          AdminDataColumn<Map<String, dynamic>>(
            title: 'CAMPAIGN DETAILS',
            flex: 2,
            builder: (item) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                    const Gap(4),
                    Text(item['city'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
          ),
          AdminDataColumn<Map<String, dynamic>>(
            title: 'DISCOUNT',
            fixedWidth: 120,
            builder: (item) => Text(
              '${item['discountValue']}${item['discountType'] == 'PERCENTAGE' ? '%' : '₹'} OFF',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF2563EB)),
            ),
          ),
          AdminDataColumn<Map<String, dynamic>>(
            title: 'SPENT / BUDGET',
            fixedWidth: 150,
            builder: (item) => Text(
              '${cur.format(item['spent'])} / ${item['budget'] > 0 ? cur.format(item['budget']) : 'No Cap'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          AdminDataColumn<Map<String, dynamic>>(
            title: 'REDEMPTIONS',
            fixedWidth: 120,
            builder: (item) => Text(
              '${item['redemptions']} / ${item['maxRedemptions'] > 0 ? item['maxRedemptions'] : '∞'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          AdminDataColumn<Map<String, dynamic>>(
            title: 'STATUS',
            fixedWidth: 110,
            builder: (item) {
              final status = item['status'] as String;
              Color bg = const Color(0xFFECFDF5);
              Color fg = const Color(0xFF065F46);
              if (status == 'PAUSED') {
                bg = const Color(0xFFFEF3C7);
                fg = const Color(0xFF92400E);
              } else if (status == 'EXPIRED' || status == 'EXHAUSTED') {
                bg = const Color(0xFFF1F5F9);
                fg = const Color(0xFF475569);
              } else if (status == 'SCHEDULED') {
                bg = const Color(0xFFEFF6FF);
                fg = const Color(0xFF1E40AF);
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
          AdminDataColumn<Map<String, dynamic>>(
            title: 'ACTIONS',
            fixedWidth: 90,
            builder: (item) => IconButton(
              icon: const Icon(Icons.insights_rounded, size: 18),
              tooltip: 'View Performance',
              onPressed: () => _inspectCampaign(item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryKpi(String title, String value, IconData icon, Color color) {
    return Container(
      width: 175,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

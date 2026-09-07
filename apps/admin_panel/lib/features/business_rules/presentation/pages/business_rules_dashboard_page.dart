import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/admin_data_grid.dart';
import '../../domain/models/system_config_detail.dart';
import '../providers/business_rules_providers.dart';
import '../widgets/batch_update_dialog.dart';
import '../widgets/config_detail_drawer.dart';

/// Production-grade administration console for inspecting, configuring,
/// and governing all dynamic business rules in the DriveGo platform.
class BusinessRulesDashboardPage extends ConsumerStatefulWidget {
  const BusinessRulesDashboardPage({super.key});

  @override
  ConsumerState<BusinessRulesDashboardPage> createState() =>
      _BusinessRulesDashboardPageState();
}

class _BusinessRulesDashboardPageState
    extends ConsumerState<BusinessRulesDashboardPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDetailDrawer(SystemConfigDetail rule) {
    ref.read(selectedRuleKeyProvider.notifier).state = rule.key;
    ConfigDetailDrawer.show(context: context, config: rule);
  }

  void _openBatchDialog(List<SystemConfigDetail> rules) {
    BatchUpdateDialog.show(context: context, rules: rules);
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(filteredBusinessRulesProvider);
    final allRulesAsync = ref.watch(businessRulesListProvider);
    final activeCategory = ref.watch(selectedCategoryFilterProvider);
    final canEdit = ref.watch(canEditConfigurationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header & Title ───
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          const Text(
                            'Business Rules Engine',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF2563EB)),
                                Gap(4),
                                Text(
                                  'OCC & REDIS INVALIDATION ACTIVE',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1D4ED8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(6),
                      Text(
                        'Live platform governance: manage pricing matrices, cancellation fees, deposit defaults, and tax parameters backed by Redis cache and optimistic concurrency control.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // Global Action Buttons
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(businessRulesListProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const Gap(12),
                    if (canEdit)
                      ElevatedButton.icon(
                        onPressed: allRulesAsync.maybeWhen(
                          data: (rules) => () => _openBatchDialog(rules),
                          orElse: () => null,
                        ),
                        icon: const Icon(Icons.layers_rounded, size: 16),
                        label: const Text('Atomic Batch Update'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const Gap(24),

            // ─── Metric KPI Cards ───
            allRulesAsync.when(
              data: (rules) => _buildMetricCards(rules),
              loading: () => const SizedBox(height: 96),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const Gap(24),

            // ─── Filter Bar & Category Tabs ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Domain Categories Segmented Control
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCategoryChip('ALL', 'All Rules', activeCategory),
                              _buildCategoryChip('PRICING', 'Pricing', activeCategory),
                              _buildCategoryChip('BOOKING', 'Booking', activeCategory),
                              _buildCategoryChip('FINANCE', 'Finance', activeCategory),
                              _buildCategoryChip('GROWTH', 'Growth', activeCategory),
                              _buildCategoryChip('GOVERNANCE', 'Governance', activeCategory),
                            ],
                          ),
                        ),
                      ),
                      const Gap(16),
                      // Search Input Field
                      SizedBox(
                        width: 280,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            ref.read(rulesSearchQueryProvider.notifier).state = val;
                          },
                          decoration: InputDecoration(
                            hintText: 'Search key, name, domain...',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(rulesSearchQueryProvider.notifier).state = '';
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(16),

            // ─── Data Grid ───
            rulesAsync.when(
              data: (rules) => AdminDataGrid<SystemConfigDetail>(
                columns: [
                  AdminDataColumn<SystemConfigDetail>(
                    title: 'RULE / KEY',
                    flex: 3,
                    builder: (rule) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          rule.humanReadableName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Gap(3),
                        SelectableText(
                          rule.key,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AdminDataColumn<SystemConfigDetail>(
                    title: 'DOMAIN',
                    flex: 1,
                    builder: (rule) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rule.domainGroup,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                  AdminDataColumn<SystemConfigDetail>(
                    title: 'SOURCE STATUS',
                    flex: 2,
                    builder: (rule) {
                      final isDb = rule.isExplicitlyConfigured;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDb ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDb ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDb ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                              size: 13,
                              color: isDb ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                            const Gap(5),
                            Text(
                              isDb ? 'DATABASE' : 'DEFAULT FALLBACK',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isDb ? const Color(0xFF15803D) : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  AdminDataColumn<SystemConfigDetail>(
                    title: 'EFFECTIVE VALUE',
                    flex: 3,
                    builder: (rule) => _buildEffectiveValuePreview(rule),
                  ),
                  AdminDataColumn<SystemConfigDetail>(
                    title: 'VERSION',
                    flex: 1,
                    builder: (rule) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'v${rule.version}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                  AdminDataColumn<SystemConfigDetail>(
                    title: 'UPDATED',
                    flex: 2,
                    builder: (rule) {
                      final formatted = rule.updatedAt != null
                          ? DateFormat('dd MMM yyyy').format(rule.updatedAt!)
                          : 'Seed default';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            formatted,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                          ),
                          Text(
                            rule.updatedBy ?? 'System Init',
                            style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                          ),
                        ],
                      );
                    },
                  ),
                  AdminDataColumn<SystemConfigDetail>(
                    title: 'VISIBILITY',
                    flex: 2,
                    builder: (rule) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: rule.isPublic ? const Color(0xFFE0F2FE) : const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            rule.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                            size: 11,
                            color: rule.isPublic ? const Color(0xFF0369A1) : const Color(0xFF7E22CE),
                          ),
                          const Gap(4),
                          Text(
                            rule.isPublic ? 'PUBLIC' : 'INTERNAL',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: rule.isPublic ? const Color(0xFF0369A1) : const Color(0xFF7E22CE),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AdminDataColumn<SystemConfigDetail>(
                    title: 'ACTIONS',
                    fixedWidth: 130,
                    builder: (rule) => OutlinedButton.icon(
                      onPressed: () => _openDetailDrawer(rule),
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      label: Text(canEdit ? 'Configure' : 'View'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF93C5FD)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
                items: rules,
                onRowTap: (rule) => _openDetailDrawer(rule),
                emptyTitle: 'No business rules match',
                emptyMessage: 'Try adjusting your search query or switching domain categories.',
              ),
              loading: () => const AdminTableSkeleton(),
              error: (err, _) => AdminErrorState(
                message: 'Failed to load configuration rules: $err',
                onRetry: () => ref.invalidate(businessRulesListProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCards(List<SystemConfigDetail> rules) {
    final total = rules.length;
    final dbCount = rules.where((r) => r.isExplicitlyConfigured).length;
    final fallbackCount = total - dbCount;
    final internalCount = rules.where((r) => !r.isPublic).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'TOTAL GOVERNED RULES',
            value: total.toString(),
            icon: Icons.rule_folder_rounded,
            color: const Color(0xFF2563EB),
            badgeText: 'All Domains',
          ),
        ),
        const Gap(16),
        Expanded(
          child: _buildStatCard(
            title: 'ACTIVE IN DATABASE',
            value: dbCount.toString(),
            icon: Icons.storage_rounded,
            color: const Color(0xFF059669),
            badgeText: 'Explicit Overrides',
          ),
        ),
        const Gap(16),
        Expanded(
          child: _buildStatCard(
            title: 'DEFAULT FALLBACKS',
            value: fallbackCount.toString(),
            icon: Icons.hourglass_empty_rounded,
            color: const Color(0xFFD97706),
            badgeText: 'Zero-downtime seeds',
          ),
        ),
        const Gap(16),
        Expanded(
          child: _buildStatCard(
            title: 'INTERNAL GOVERNANCE',
            value: internalCount.toString(),
            icon: Icons.security_rounded,
            color: const Color(0xFF7C3AED),
            badgeText: 'Confidential Rules',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Gap(4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String categoryKey, String label, String activeKey) {
    final isSelected = activeKey == categoryKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            ref.read(selectedCategoryFilterProvider.notifier).state = categoryKey;
          }
        },
        selectedColor: const Color(0xFF2563EB),
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF475569),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }

  Widget _buildEffectiveValuePreview(SystemConfigDetail rule) {
    final val = rule.effectiveValue;

    if (rule.key == 'pricing.tax' && val is Map) {
      final gst = val['gstPercentage'];
      return Text('GST: $gst%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5));
    }

    if (rule.key == 'pricing.quote' && val is Map) {
      final mins = val['validityDurationMinutes'];
      return Text('Validity: $mins mins', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5));
    }

    if (rule.key == 'pricing.duration_discounts' && val is List) {
      return Text('${val.length} Discount Tiers configured',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5));
    }

    if (rule.key == 'booking.cancellation_matrix' && val is Map) {
      final tiers = (val['tiers'] as List?)?.length ?? 0;
      final afterStart = val['afterStartRefundPercent'] ?? 0;
      return Text('$tiers Tiers (After-start: $afterStart% refund)',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5));
    }

    if (rule.key == 'pricing.commission' && val is Map) {
      final comm = val['defaultCommissionPercentage'];
      return Text('Default: $comm%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5));
    }

    if (rule.key == 'deposits.defaults' && val is Map) {
      final categories = val.keys.length;
      return Text('$categories Category Deposits (INR)',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5));
    }

    // Generic display
    final jsonStr = jsonEncode(val);
    final truncated = jsonStr.length > 35 ? '${jsonStr.substring(0, 35)}...' : jsonStr;
    return Text(
      truncated,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF475569)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import '../../../../core/widgets/admin_detail_drawer.dart';
import '../../../../core/widgets/admin_data_grid.dart';
import '../providers/fraud_providers.dart';

class AdminFraudPage extends ConsumerWidget {
  const AdminFraudPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(fraudSummaryProvider);
    final assessmentsAsync = ref.watch(fraudAssessmentsProvider);
    final selectedRiskLevel = ref.watch(fraudRiskLevelFilterProvider);
    final selectedStatus = ref.watch(fraudStatusFilterProvider);

    return Scaffold(
      body: Padding(
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
                      'Fraud Detection & Risk Scoring',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Gap(4),
                    Text(
                      'Deterministic risk intelligence, duplicate KYC detection & velocity controls',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                AppButton(
                  text: 'Refresh Alerts',
                  isFullWidth: false,
                  onPressed: () {
                    ref.invalidate(fraudSummaryProvider);
                    ref.invalidate(fraudAssessmentsProvider);
                  },
                ),
              ],
            ),
            const Gap(20),

            // Summary Metrics Row
            summaryAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: AppLoader()),
              ),
              error: (err, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: Text('Error loading fraud summary: $err')),
                ),
              ),
              data: (summary) => _buildSummaryCards(context, summary),
            ),
            const Gap(20),

            // Filters Bar
            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Filter Risk:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Gap(12),
                  _buildRiskFilterChips(ref, selectedRiskLevel),
                  const Spacer(),
                  const Text(
                    'Status:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Gap(12),
                  _buildStatusFilterChips(ref, selectedStatus),
                ],
              ),
            ),
            const Gap(20),

            // Assessments Data Table
            Expanded(
              child: assessmentsAsync.when(
                loading: () => const AdminTableSkeleton(),
                error: (err, _) => AdminErrorState(
                  message: 'Error loading assessments: $err',
                  onRetry: () => ref.invalidate(fraudAssessmentsProvider),
                ),
                data: (assessments) {
                  return _buildAssessmentsTable(context, ref, assessments);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, FraudSummaryModel summary) {
    final cards = [
      _buildKpiCard('Total Events', '${summary.totalEvents}', Colors.black87, Icons.shield_outlined),
      _buildKpiCard('Critical Alerts', '${summary.criticalCount}', Colors.red, Icons.dangerous),
      _buildKpiCard('High Risk Queue', '${summary.highCount}', Colors.orange, Icons.warning_amber),
      _buildKpiCard('Medium Risk', '${summary.mediumCount}', Colors.amber[800]!, Icons.info_outline),
      _buildKpiCard('Pending Review', '${summary.pendingReviewCount}', Colors.blue, Icons.pending_actions),
    ];

    if (Responsive.isDesktop(context)) {
      return Row(
        children: cards
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ))
            .toList(),
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards
            .map((c) => SizedBox(
                  width: (MediaQuery.of(context).size.width - 64) / 2,
                  child: c,
                ))
            .toList(),
      );
    }
  }

  Widget _buildKpiCard(String label, String value, Color color, IconData icon) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Gap(6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskFilterChips(WidgetRef ref, String? selected) {
    final levels = [null, 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];
    return Wrap(
      spacing: 6,
      children: levels.map((lvl) {
        final isSelected = selected == lvl;
        return ChoiceChip(
          label: Text(lvl ?? 'All'),
          selected: isSelected,
          onSelected: (val) {
            if (val) {
              ref.read(fraudRiskLevelFilterProvider.notifier).state = lvl;
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildStatusFilterChips(WidgetRef ref, String? selected) {
    final statuses = [null, 'PENDING_REVIEW', 'RESOLVED', 'DISMISSED'];
    return Wrap(
      spacing: 6,
      children: statuses.map((st) {
        final isSelected = selected == st;
        return ChoiceChip(
          label: Text(st == null ? 'All' : st.replaceAll('_', ' ')),
          selected: isSelected,
          onSelected: (val) {
            if (val) {
              ref.read(fraudStatusFilterProvider.notifier).state = st;
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildAssessmentsTable(
    BuildContext context,
    WidgetRef ref,
    List<RiskAssessmentModel> assessments,
  ) {
    return AdminDataGrid<RiskAssessmentModel>(
      items: assessments,
      emptyTitle: 'No Risk Alerts',
      emptyMessage: 'No risk alerts matching the active filters.',
      emptyIcon: Icons.security_outlined,
      onRowTap: (assessment) => _showReviewDialog(context, ref, assessment),
      columns: [
        AdminDataColumn(
          title: 'RISK LEVEL / SCORE',
          builder: (assessment) => _buildRiskScoreBadge(assessment),
        ),
        AdminDataColumn(
          title: 'CUSTOMER',
          builder: (assessment) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(assessment.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(assessment.userPhone, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
        AdminDataColumn(
          title: 'TRIGGERED SIGNALS',
          builder: (assessment) => SizedBox(
            width: 250,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: assessment.signals.map((s) {
                return Tooltip(
                  message: s.description,
                  child: Chip(
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      '${s.code} (+${s.scoreDelta})',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        AdminDataColumn(
          title: 'DECISION',
          builder: (assessment) => _buildActionBadge(assessment.action),
        ),
        AdminDataColumn(
          title: 'STATUS',
          builder: (assessment) => _buildStatusBadge(assessment.status),
        ),
        AdminDataColumn(
          title: 'DATE',
          builder: (assessment) => Text(
            DateFormat('dd MMM yyyy, HH:mm').format(assessment.createdAt),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        AdminDataColumn(
          title: 'ACTION',
          builder: (assessment) => TextButton(
            onPressed: () => _showReviewDialog(context, ref, assessment),
            child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
      mobileCardBuilder: (ctx, assessment) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(assessment.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  _buildRiskScoreBadge(assessment),
                ],
              ),
              const Gap(4),
              Text(
                '${assessment.signals.length} signals triggered • ${_buildActionBadge(assessment.action)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRiskScoreBadge(RiskAssessmentModel assessment) {
    Color bg;
    Color fg = Colors.white;

    switch (assessment.riskLevel) {
      case RiskLevel.critical:
        bg = Colors.red[700]!;
        break;
      case RiskLevel.high:
        bg = Colors.orange[800]!;
        break;
      case RiskLevel.medium:
        bg = Colors.amber[700]!;
        break;
      case RiskLevel.low:
        bg = Colors.green[700]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${assessment.riskLevel.displayName} (${assessment.score})',
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionBadge(RiskAction action) {
    Color color;
    switch (action) {
      case RiskAction.block:
        color = Colors.red;
        break;
      case RiskAction.reviewRequired:
        color = Colors.orange;
        break;
      case RiskAction.monitor:
        color = Colors.amber[800]!;
        break;
      case RiskAction.allow:
        color = Colors.green;
        break;
    }

    return Text(
      action.displayName,
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.blue;
    if (status == 'RESOLVED') color = Colors.green;
    if (status == 'DISMISSED') color = Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showReviewDialog(
    BuildContext context,
    WidgetRef ref,
    RiskAssessmentModel assessment,
  ) {
    final notesController = TextEditingController(text: assessment.adminNotes ?? '');
    bool isSaving = false;

    AdminDetailDrawer.show(
      context: context,
      title: 'Review Risk Assessment: ${assessment.userName}',
      subtitle: 'User Phone: ${assessment.userPhone} | Subject ID: ${assessment.userId}',
      width: 480,
      child: StatefulBuilder(
        builder: (context, setModalState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('User Phone: ${assessment.userPhone} | Subject ID: ${assessment.userId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Gap(12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('Calculated Score: ${assessment.score} / 100', style: const TextStyle(fontWeight: FontWeight.bold)),
                _buildRiskScoreBadge(assessment),
              ],
            ),
            const Gap(16),
            const Text('Triggered Security Signals:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Gap(8),
            ...assessment.signals.map((s) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.code} (+${s.scoreDelta})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(s.description, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  ],
                ),
              );
            }),
            const Gap(16),
            const Text('Administrative Notes / Reasoning:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Gap(6),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter reason for resolving, dismissing or escalating...',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final notes = notesController.text.trim();
                            if (notes.isEmpty) return;
                            setModalState(() => isSaving = true);
                            await ref.read(fraudRepositoryProvider).resolveAssessment(
                                  assessment.id,
                                  status: 'DISMISSED',
                                  adminNotes: notes,
                                );
                            if (context.mounted) Navigator.pop(context);
                            ref.invalidate(fraudSummaryProvider);
                            ref.invalidate(fraudAssessmentsProvider);
                          },
                    child: const Text('Dismiss Alert'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final notes = notesController.text.trim();
                            if (notes.isEmpty) return;
                            setModalState(() => isSaving = true);
                            await ref.read(fraudRepositoryProvider).resolveAssessment(
                                  assessment.id,
                                  status: 'RESOLVED',
                                  adminNotes: notes,
                                );
                            if (context.mounted) Navigator.pop(context);
                            ref.invalidate(fraudSummaryProvider);
                            ref.invalidate(fraudAssessmentsProvider);
                          },
                    child: const Text('Resolve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
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
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => Center(
                  child: Text('Error loading assessments: $err'),
                ),
                data: (assessments) {
                  if (assessments.isEmpty) {
                    return const Center(
                      child: Text(
                        'No risk alerts matching the active filters.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    );
                  }
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
    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          columns: const [
            DataColumn(label: Text('Risk Level / Score', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Triggered Signals', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Decision', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: assessments.map((assessment) {
            final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(assessment.createdAt);

            return DataRow(
              cells: [
                DataCell(_buildRiskScoreBadge(assessment)),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(assessment.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(assessment.userPhone, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                DataCell(
                  SizedBox(
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
                DataCell(_buildActionBadge(assessment.action)),
                DataCell(_buildStatusBadge(assessment.status)),
                DataCell(Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                DataCell(
                  TextButton(
                    onPressed: () => _showReviewDialog(context, ref, assessment),
                    child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
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

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.shield, color: Colors.blue),
              const Gap(8),
              Text('Review Risk Assessment: ${assessment.userName}'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('User Phone: ${assessment.userPhone} | Subject ID: ${assessment.userId}'),
                  const Gap(12),
                  Row(
                    children: [
                      Text('Calculated Score: ${assessment.score} / 100', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Gap(12),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
              onPressed: () async {
                final notes = notesController.text.trim();
                if (notes.isEmpty) return;
                await ref.read(fraudRepositoryProvider).resolveAssessment(
                      assessment.id,
                      status: 'DISMISSED',
                      adminNotes: notes,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(fraudSummaryProvider);
                ref.invalidate(fraudAssessmentsProvider);
              },
              child: const Text('Dismiss Alert', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                final notes = notesController.text.trim();
                if (notes.isEmpty) return;
                await ref.read(fraudRepositoryProvider).resolveAssessment(
                      assessment.id,
                      status: 'RESOLVED',
                      adminNotes: notes,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(fraudSummaryProvider);
                ref.invalidate(fraudAssessmentsProvider);
              },
              child: const Text('Resolve', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

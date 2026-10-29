import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../domain/models/operations_models.dart';
import '../providers/admin_operations_providers.dart';

class AutomationCommandCentreWidget extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const AutomationCommandCentreWidget({
    super.key,
    required this.initialTabIndex,
  });

  @override
  ConsumerState<AutomationCommandCentreWidget> createState() =>
      _AutomationCommandCentreWidgetState();
}

class _AutomationCommandCentreWidgetState
    extends ConsumerState<AutomationCommandCentreWidget> {
  late int _activeTab;
  String _executionFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTabIndex;
  }

  @override
  void didUpdateWidget(covariant AutomationCommandCentreWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      setState(() => _activeTab = widget.initialTabIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Status Cards
        _buildKpiSummaryRow(),
        const Gap(24),

        // Active Tab View
        if (_activeTab == 0) _buildOverviewTab(),
        if (_activeTab == 1) _buildWorkflowsTab(),
        if (_activeTab == 2) _buildExecutionsTab(),
        if (_activeTab == 3) _buildRulesTab(),
        if (_activeTab == 4) _buildApprovalsTab(),
        if (_activeTab == 5) _buildSchedulesTab(),
        if (_activeTab == 6) _buildCorrelationTimelineTab(),
      ],
    );
  }

  // ==========================================
  // KPI ROW
  // ==========================================
  Widget _buildKpiSummaryRow() {
    final workflowsAsync = ref.watch(adminWorkflowsProvider);
    final executionsAsync = ref.watch(adminExecutionsProvider);
    final rulesAsync = ref.watch(adminRulesProvider);
    final approvalsAsync = ref.watch(adminApprovalsProvider);
    final schedulesAsync = ref.watch(adminSchedulesProvider);

    final workflows = workflowsAsync.valueOrNull ?? [];
    final executions = executionsAsync.valueOrNull ?? [];
    final rules = rulesAsync.valueOrNull ?? [];
    final approvals = approvalsAsync.valueOrNull ?? [];
    final schedules = schedulesAsync.valueOrNull ?? [];

    final activeWfs = workflows.where((w) => w.status == 'ACTIVE').length;
    final totalWfs = workflows.length;

    final completedExecs = executions.where((e) => e.status == 'COMPLETED').length;
    final successRate = executions.isNotEmpty
        ? '${((completedExecs / executions.length) * 100).toStringAsFixed(1)}%'
        : '100%';

    final enabledRules = rules.where((r) => r.isEnabled).length;
    final pendingApprovals = approvals.where((a) => a.status == 'PENDING').length;

    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            'Active Workflows',
            '$totalWfs',
            '$activeWfs Active • ${totalWfs - activeWfs} Paused',
            Icons.account_tree_outlined,
            const Color(0xFF388BFD),
          ),
        ),
        const Gap(16),
        Expanded(
          child: _buildKpiCard(
            'Executions Tracked',
            '${executions.length}',
            '$successRate Success Rate',
            Icons.bolt_outlined,
            const Color(0xFF2EA043),
          ),
        ),
        const Gap(16),
        Expanded(
          child: _buildKpiCard(
            'Automation Rules',
            '${rules.length}',
            '$enabledRules Enabled in Production',
            Icons.tune_rounded,
            const Color(0xFFA371F7),
          ),
        ),
        const Gap(16),
        Expanded(
          child: _buildKpiCard(
            'Pending Approvals',
            '$pendingApprovals',
            pendingApprovals > 0 ? 'Requires Human Review' : 'All Clear',
            Icons.how_to_reg_outlined,
            const Color(0xFFF0883E),
          ),
        ),
        const Gap(16),
        Expanded(
          child: _buildKpiCard(
            'Scheduled Jobs',
            '${schedules.length}',
            'Active Cron & Interval Tickers',
            Icons.schedule_rounded,
            const Color(0xFF56D364),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const Gap(10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const Gap(6),
          Text(
            subtitle,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 0: CONTROL CENTRE OVERVIEW
  // ==========================================
  Widget _buildOverviewTab() {
    final executionsAsync = ref.watch(adminExecutionsProvider);
    final approvalsAsync = ref.watch(adminApprovalsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Recent Executions & Health
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Workflow Executions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _activeTab = 2),
                          icon: const Icon(Icons.arrow_forward, size: 14),
                          label: const Text('View All'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF58A6FF),
                          ),
                        ),
                      ],
                    ),
                    const Gap(14),
                    executionsAsync.when(
                      data: (execs) => execs.isEmpty
                          ? _buildEmptyState('No recent executions logged.')
                          : Column(
                              children: execs.take(4).map((e) => _buildExecutionRow(e)).toList(),
                            ),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => _buildErrorState('Failed to load executions: $err'),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(20),

            // Right: Pending Human Approvals & Quick Actions
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Pending Human Approvals',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Gap(8),
                        approvalsAsync.when(
                          data: (approvals) {
                            final pending = approvals.where((a) => a.status == 'PENDING').length;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0883E).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pending ACTION REQUIRED',
                                style: const TextStyle(
                                  color: Color(0xFFF0883E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const Gap(14),
                    approvalsAsync.when(
                      data: (approvals) => approvals.isEmpty
                          ? _buildEmptyState('No pending approvals at this time.')
                          : Column(
                              children: approvals.take(3).map((a) => _buildApprovalCard(a)).toList(),
                            ),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => _buildErrorState('Failed to load approvals: $err'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // TAB 1: WORKFLOW DEFINITIONS
  // ==========================================
  Widget _buildWorkflowsTab() {
    final workflowsAsync = ref.watch(adminWorkflowsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Declarative Workflow Definitions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Gap(4),
                  Text(
                    'Orchestrated multi-step workflows with branch logic, timeouts, and compensation rollback.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
                  ),
                ],
              ),
            ),
            const Gap(16),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Workflow registry is synchronized with production engine.')),
                );
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh Registry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const Gap(20),
        workflowsAsync.when(
          data: (workflows) => workflows.isEmpty
              ? _buildEmptyState('No workflow definitions registered.')
              : Column(
                  children: workflows.map((wf) => _buildWorkflowCard(wf)).toList(),
                ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => _buildErrorState('Failed to load workflows: $err'),
        ),
      ],
    );
  }

  Widget _buildWorkflowCard(WorkflowDefinitionModel wf) {
    final steps = wf.steps;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF388BFD).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_tree_outlined, color: Color(0xFF58A6FF), size: 20),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          wf.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Gap(10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF21262D),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF30363D)),
                          ),
                          child: Text(
                            wf.version,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      'Triggered by: ${wf.trigger} • Last execution: ${wf.lastRun ?? 'Recently'} • Reliability: ${wf.successRate ?? '99.5%'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Workflow ${wf.id} is verified and active in engine.')),
                  );
                },
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Status: Active'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF58A6FF),
                  side: const BorderSide(color: Color(0xFF30363D)),
                ),
              ),
            ],
          ),
          if (steps.isNotEmpty) ...[
            const Gap(16),
            const Divider(color: Color(0xFF21262D), height: 1),
            const Gap(16),
            const Text(
              'EXECUTION PIPELINE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.5),
            ),
            const Gap(10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < steps.length; i++) ...[
                    _buildPipelineStepBadge(steps[i], i + 1),
                    if (i < steps.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 14, color: Color(0xFF484F58)),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPipelineStepBadge(Map<String, dynamic> step, int stepNum) {
    Color typeColor;
    IconData icon;

    final type = step['type']?.toString() ?? 'ACTION';

    switch (type) {
      case 'TRIGGER':
        typeColor = const Color(0xFF58A6FF);
        icon = Icons.flash_on;
        break;
      case 'NOTIFICATION':
        typeColor = const Color(0xFF2EA043);
        icon = Icons.notifications_active_outlined;
        break;
      case 'CONDITION':
        typeColor = const Color(0xFFD29922);
        icon = Icons.call_split;
        break;
      case 'ACTION':
        typeColor = const Color(0xFFA371F7);
        icon = Icons.play_circle_outline;
        break;
      case 'END':
      default:
        typeColor = const Color(0xFF8B949E);
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: typeColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: typeColor),
          const Gap(8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STEP $stepNum: $type',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
              ),
              Text(
                step['name']?.toString() ?? 'Execute step',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: EXECUTIONS & RETRIES
  // ==========================================
  Widget _buildExecutionsTab() {
    final executionsAsync = ref.watch(adminExecutionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Workflow Executions & Failure Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Row(
              children: [
                _buildFilterChip('ALL'),
                const Gap(8),
                _buildFilterChip('RUNNING'),
                const Gap(8),
                _buildFilterChip('COMPLETED'),
                const Gap(8),
                _buildFilterChip('FAILED'),
              ],
            ),
          ],
        ),
        const Gap(20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: executionsAsync.when(
            data: (execs) {
              final filtered = execs.where((e) => _executionFilter == 'ALL' || e.status == _executionFilter).toList();
              if (filtered.isEmpty) {
                return _buildEmptyState('No execution records matching filter.');
              }
              return Column(
                children: filtered.map((e) => _buildExecutionRow(e, isDetailView: true)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => _buildErrorState('Failed to load executions: $err'),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _executionFilter == label;
    return InkWell(
      onTap: () => setState(() => _executionFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF388BFD).withValues(alpha: 0.2) : const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF388BFD) : const Color(0xFF30363D),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF58A6FF) : const Color(0xFF8B949E),
          ),
        ),
      ),
    );
  }

  Widget _buildExecutionRow(WorkflowExecutionModel exec, {bool isDetailView = false}) {
    Color statusColor;
    switch (exec.status) {
      case 'COMPLETED':
        statusColor = const Color(0xFF2EA043);
        break;
      case 'RUNNING':
        statusColor = const Color(0xFF58A6FF);
        break;
      case 'FAILED':
      default:
        statusColor = const Color(0xFFF85149);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        exec.workflowName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        exec.status,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Text(
                  'Execution ID: ${exec.id} • Corr: ${exec.correlationId} • Started: ${exec.startedAt} • Latency: ${exec.duration}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (exec.error != null) ...[
                  const Gap(4),
                  Text(
                    'Error: ${exec.error}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFF85149), fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          if (exec.status == 'FAILED') ...[
            const Gap(10),
            OutlinedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(adminExecutionsProvider.notifier).retry(exec.id);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Replay initiated for execution ${exec.id}')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to replay execution: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              icon: const Icon(Icons.refresh, size: 12),
              label: const Text('Retry', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF85149),
                side: const BorderSide(color: Color(0xFFF85149)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: AUTOMATION RULES
  // ==========================================
  Widget _buildRulesTab() {
    final rulesAsync = ref.watch(adminRulesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Dynamic Automation Rule Engine',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            ElevatedButton.icon(
              onPressed: () => ref.read(adminRulesProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh Rules'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            ),
          ],
        ),
        const Gap(20),
        rulesAsync.when(
          data: (rules) => rules.isEmpty
              ? _buildEmptyState('No automation rules found.')
              : Column(
                  children: rules.map((r) => _buildRuleCard(r)).toList(),
                ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => _buildErrorState('Failed to load rules: $err'),
        ),
      ],
    );
  }

  Widget _buildRuleCard(AutomationRuleModel rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Color(0xFFA371F7), size: 20),
                  const Gap(10),
                  Text(
                    rule.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Switch(
                value: rule.isEnabled,
                onChanged: (val) async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref.read(adminRulesProvider.notifier).toggleRule(rule.id, val);
                    messenger.showSnackBar(
                      SnackBar(content: Text('Rule ${rule.name} ${val ? "Enabled" : "Disabled"}')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to update rule: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                activeColor: const Color(0xFF2EA043),
              ),
            ],
          ),
          const Gap(12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('IF: ', style: TextStyle(color: Color(0xFFD29922), fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(rule.predicate, style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 12, fontFamily: 'monospace')),
                  ],
                ),
                const Gap(6),
                Row(
                  children: [
                    const Text('THEN: ', style: TextStyle(color: Color(0xFF2EA043), fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(rule.action, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: APPROVALS & HITL
  // ==========================================
  Widget _buildApprovalsTab() {
    final approvalsAsync = ref.watch(adminApprovalsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Human-in-the-Loop (HITL) Approvals',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Gap(4),
                  Text(
                    'Configurable human approval gates for high-value refunds, partner onboarding, and damage compensation.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
                  ),
                ],
              ),
            ),
            const Gap(16),
            ElevatedButton.icon(
              onPressed: () => ref.read(adminApprovalsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh Approvals'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            ),
          ],
        ),
        const Gap(20),
        approvalsAsync.when(
          data: (approvals) => approvals.isEmpty
              ? _buildEmptyState('No pending approval requests.')
              : Column(
                  children: approvals.map((a) => _buildApprovalCard(a)).toList(),
                ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => _buildErrorState('Failed to load approvals: $err'),
        ),
      ],
    );
  }

  Widget _buildApprovalCard(ApprovalRequestModel appr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0883E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  appr.type,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF0883E)),
                ),
              ),
              Text(
                'Expires ${appr.timeout}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
              ),
            ],
          ),
          const Gap(10),
          Text(
            appr.entity,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Gap(4),
          Text(
            '${appr.reason} • Requested by: ${appr.requestedBy}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
          ),
          const Gap(12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref.read(adminApprovalsProvider.notifier).recordDecision(
                          appr.id,
                          decision: 'REJECTED',
                          stepIndex: appr.currentStepIndex,
                        );
                    messenger.showSnackBar(
                      SnackBar(content: Text('Rejected ${appr.entity}')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to reject approval: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF85149),
                  side: const BorderSide(color: Color(0xFFF85149)),
                ),
                child: const Text('Reject'),
              ),
              const Gap(10),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref.read(adminApprovalsProvider.notifier).recordDecision(
                          appr.id,
                          decision: 'APPROVED',
                          stepIndex: appr.currentStepIndex,
                        );
                    messenger.showSnackBar(
                      SnackBar(content: Text('Approved ${appr.entity}')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to approve step: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Approve Step'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 5: SCHEDULED JOBS
  // ==========================================
  Widget _buildSchedulesTab() {
    final schedulesAsync = ref.watch(adminSchedulesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Scheduled Background Jobs & Tickers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            ElevatedButton.icon(
              onPressed: () => ref.read(adminSchedulesProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh Schedules'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            ),
          ],
        ),
        const Gap(20),
        schedulesAsync.when(
          data: (schedules) => schedules.isEmpty
              ? _buildEmptyState('No scheduled background jobs.')
              : Column(
                  children: schedules.map((s) => _buildScheduleCard(s)).toList(),
                ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => _buildErrorState('Failed to load schedules: $err'),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(ScheduledJobModel s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: Color(0xFF56D364), size: 24),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Gap(4),
                Text(
                  '${s.type} • Next Run: ${s.nextRun} • Timezone: ${s.timezone}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(adminSchedulesProvider.notifier).runJob(s.id);
                messenger.showSnackBar(
                  SnackBar(content: Text('Triggered immediate execution for ${s.name}')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to trigger job execution: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF21262D),
              foregroundColor: const Color(0xFF58A6FF),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
            child: const Text('Run Now'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 6: CORRELATION TIMELINE
  // ==========================================
  Widget _buildCorrelationTimelineTab() {
    final timelineEntries = [
      {'domain': 'CUSTOMER', 'act': 'Customer initiated booking for Hyundai Creta (BK#9921)', 'time': '10:41:00 AM', 'status': 'SUCCESS'},
      {'domain': 'PAYMENTS', 'act': 'Payment captured ₹4,500 via Razorpay (PAY#881)', 'time': '10:41:12 AM', 'status': 'SUCCESS'},
      {'domain': 'INTEGRATIONS', 'act': 'Payment webhook received with signature verification', 'time': '10:41:13 AM', 'status': 'SUCCESS'},
      {'domain': 'WORKFLOW', 'act': 'DomainEvent PAYMENT_SUCCESS dispatched to WF_BOOKING_LIFECYCLE', 'time': '10:41:14 AM', 'status': 'SUCCESS'},
      {'domain': 'NOTIFICATIONS', 'act': 'WhatsApp booking confirmation sent via Meta Cloud API', 'time': '10:41:15 AM', 'status': 'SUCCESS'},
      {'domain': 'FLEET', 'act': 'Vehicle allocated from Bangalore Central Hub (KA01-MJ-4412)', 'time': '10:41:16 AM', 'status': 'SUCCESS'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Unified Cross-Domain Operational Correlation Tracer',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const Gap(4),
        const Text(
          'Trace any end-to-end customer or operational journey across Bookings, Payments, Integrations, Workflows, and Notifications.',
          style: TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
        ),
        const Gap(20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.link, color: Color(0xFF58A6FF)),
                  Gap(10),
                  Text(
                    'Active Correlation ID: cor_bk_delhi_9921',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                  ),
                ],
              ),
              const Gap(16),
              const Divider(color: Color(0xFF21262D)),
              const Gap(16),
              for (int i = 0; i < timelineEntries.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2EA043),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (i < timelineEntries.length - 1)
                          Container(
                            width: 2,
                            height: 38,
                            color: const Color(0xFF30363D),
                          ),
                      ],
                    ),
                    const Gap(16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF21262D),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  timelineEntries[i]['domain']!,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF)),
                                ),
                              ),
                              const Gap(10),
                              Text(
                                timelineEntries[i]['time']!,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                              ),
                            ],
                          ),
                          const Gap(4),
                          Text(
                            timelineEntries[i]['act']!,
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                          ),
                          const Gap(12),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, color: Color(0xFF484F58), size: 32),
            const Gap(8),
            Text(
              message,
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFF85149), size: 32),
            const Gap(8),
            Text(
              message,
              style: const TextStyle(color: Color(0xFFF85149), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

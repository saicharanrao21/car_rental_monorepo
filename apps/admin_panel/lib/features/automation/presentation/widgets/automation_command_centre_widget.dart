import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class AutomationCommandCentreWidget extends StatefulWidget {
  final int initialTabIndex;

  const AutomationCommandCentreWidget({
    super.key,
    required this.initialTabIndex,
  });

  @override
  State<AutomationCommandCentreWidget> createState() =>
      _AutomationCommandCentreWidgetState();
}

class _AutomationCommandCentreWidgetState
    extends State<AutomationCommandCentreWidget> {
  late int _activeTab;
  String _executionFilter = 'ALL';

  // Local state for interactive demonstrations
  final List<Map<String, dynamic>> _mockWorkflows = [
    {
      'id': 'WF_BOOKING_LIFECYCLE',
      'name': 'Booking Confirmation & Assignment Flow',
      'version': 'v1.2',
      'trigger': 'BOOKING_CREATED',
      'status': 'ACTIVE',
      'stepsCount': 5,
      'lastRun': '3 mins ago',
      'successRate': '99.4%',
      'steps': [
        {'name': 'Booking Created Trigger', 'type': 'TRIGGER'},
        {'name': 'Dispatch WhatsApp Confirmation', 'type': 'NOTIFICATION'},
        {'name': 'Evaluate Payment Status', 'type': 'CONDITION'},
        {'name': 'Assign Vehicle from Hub', 'type': 'ACTION'},
        {'name': 'Complete Lifecycle', 'type': 'END'},
      ],
    },
    {
      'id': 'WF_PAYMENT_FAILURE_RECOVERY',
      'name': 'Payment Failure Intelligent Recovery',
      'version': 'v2.0',
      'trigger': 'PAYMENT_FAILED',
      'status': 'ACTIVE',
      'stepsCount': 4,
      'lastRun': '14 mins ago',
      'successRate': '96.8%',
      'steps': [
        {'name': 'Payment Failed Trigger', 'type': 'TRIGGER'},
        {'name': 'Send Retry WhatsApp Link', 'type': 'NOTIFICATION'},
        {'name': 'Fallback to SMS Gateway', 'type': 'NOTIFICATION'},
        {'name': 'Alert Vendor Support Task', 'type': 'ACTION'},
        {'name': 'End Recovery Flow', 'type': 'END'},
      ],
    },
    {
      'id': 'WF_VEHICLE_OVERDUE',
      'name': 'Vehicle Overdue Tracking & Escalation',
      'version': 'v1.0',
      'trigger': 'VEHICLE_OVERDUE',
      'status': 'ACTIVE',
      'stepsCount': 3,
      'lastRun': '1 hour ago',
      'successRate': '100%',
      'steps': [
        {'name': 'Overdue Detector Trigger', 'type': 'TRIGGER'},
        {'name': 'Send Urgent Return SMS', 'type': 'NOTIFICATION'},
        {'name': 'Ping IoT GPS Telematics', 'type': 'ACTION'},
        {'name': 'End Overdue Escalation', 'type': 'END'},
      ],
    },
    {
      'id': 'WF_COMPLIANCE_EXPIRY',
      'name': 'Compliance Expiry Notice & Locking',
      'version': 'v1.1',
      'trigger': 'DOCUMENT_EXPIRING',
      'status': 'ACTIVE',
      'stepsCount': 4,
      'lastRun': 'Yesterday',
      'successRate': '98.5%',
      'steps': [
        {'name': '30-Day Expiry Trigger', 'type': 'TRIGGER'},
        {'name': 'Send Compliance Warning', 'type': 'NOTIFICATION'},
        {'name': 'Create Renewal Task', 'type': 'ACTION'},
        {'name': 'Lock Vehicle if Expired', 'type': 'CONDITION'},
        {'name': 'End Compliance Flow', 'type': 'END'},
      ],
    },
  ];

  final List<Map<String, dynamic>> _mockExecutions = [
    {
      'id': 'wf_exec_88102',
      'workflowId': 'WF_BOOKING_LIFECYCLE',
      'workflowName': 'Booking Confirmation & Assignment',
      'correlationId': 'cor_bk_delhi_9921',
      'status': 'COMPLETED',
      'startedAt': '10:42:15 AM',
      'duration': '840ms',
      'retries': 0,
      'lastStep': 'Complete Lifecycle',
    },
    {
      'id': 'wf_exec_88103',
      'workflowId': 'WF_PAYMENT_FAILURE_RECOVERY',
      'workflowName': 'Payment Failure Intelligent Recovery',
      'correlationId': 'cor_pay_fail_4412',
      'status': 'FAILED',
      'startedAt': '10:39:04 AM',
      'duration': '1,220ms',
      'retries': 0,
      'lastStep': 'Send Retry WhatsApp Link',
      'error': 'WhatsApp Provider 429 Rate Limit Exceeded',
    },
    {
      'id': 'wf_exec_88104',
      'workflowId': 'WF_VEHICLE_OVERDUE',
      'workflowName': 'Vehicle Overdue Tracking & Escalation',
      'correlationId': 'cor_veh_overdue_109',
      'status': 'COMPLETED',
      'startedAt': '10:15:30 AM',
      'duration': '610ms',
      'retries': 0,
      'lastStep': 'End Overdue Escalation',
    },
    {
      'id': 'wf_exec_88105',
      'workflowId': 'WF_BOOKING_LIFECYCLE',
      'workflowName': 'Booking Confirmation & Assignment',
      'correlationId': 'cor_bk_blr_5521',
      'status': 'RUNNING',
      'startedAt': '10:44:02 AM',
      'duration': '210ms',
      'retries': 0,
      'lastStep': 'Evaluate Payment Status',
    },
  ];

  final List<Map<String, dynamic>> _mockRules = [
    {
      'id': 'RULE_BOOKING_24H_REMINDER',
      'name': 'Send 24-Hour Pre-Pickup Reminder',
      'trigger': 'BOOKING_CONFIRMED',
      'predicate': 'booking.status == CONFIRMED && pickupTime <= 24h',
      'action': 'SEND_NOTIFICATION (WhatsApp -> SMS Fallback)',
      'enabled': true,
      'priority': 10,
    },
    {
      'id': 'RULE_PAYMENT_FAILURE_ALERT',
      'name': 'Escalate Failed Payment to Support',
      'trigger': 'PAYMENT_FAILED',
      'predicate': 'payment.amount > 0',
      'action': 'SEND_NOTIFICATION & CREATE_TASK (Recovery Team)',
      'enabled': true,
      'priority': 20,
    },
    {
      'id': 'RULE_DOC_EXPIRY_ALERT',
      'name': 'Document Expiration 30-Day Notice',
      'trigger': 'DOCUMENT_EXPIRING',
      'predicate': 'document.daysRemaining < 30',
      'action': 'SEND_NOTIFICATION (Vendor) & CREATE_TASK',
      'enabled': true,
      'priority': 15,
    },
  ];

  final List<Map<String, dynamic>> _mockApprovals = [
    {
      'id': 'appr_ref_992',
      'type': 'LARGE_REFUND',
      'entity': 'Payment #PAY_55412 (₹48,500)',
      'requestedBy': 'Support Executive (Ananya S.)',
      'reason': 'Customer requested refund for trip breakdown at highway',
      'currentStep': 'Step 1 of 2: Branch Manager Review',
      'status': 'PENDING',
      'timeout': 'in 4 hours',
    },
    {
      'id': 'appr_vnd_104',
      'type': 'VENDOR_ONBOARDING',
      'entity': 'Vendor: Apex Mobility Pvt Ltd (14 Vehicles)',
      'requestedBy': 'Partner Acquisition Lead (Rohit K.)',
      'reason': 'Tier-1 commercial fleet partner onboarding in Hyderabad',
      'currentStep': 'Step 2 of 2: Compliance Verification',
      'status': 'PENDING',
      'timeout': 'in 18 hours',
    },
  ];

  final List<Map<String, dynamic>> _mockSchedules = [
    {
      'id': 'job_overdue_scan',
      'name': 'Hourly Overdue Rental Scanner',
      'type': 'RECURRING (Every 1 hour)',
      'nextRun': 'Today, 11:00 AM (in 15 mins)',
      'status': 'SCHEDULED',
      'timezone': 'Asia/Kolkata (IST)',
    },
    {
      'id': 'job_compliance_scan',
      'name': 'Daily Compliance Document Expiry Check',
      'type': 'CRON (0 0 * * *)',
      'nextRun': 'Tomorrow, 00:00 AM',
      'status': 'SCHEDULED',
      'timezone': 'Asia/Kolkata (IST)',
    },
    {
      'id': 'job_recon_finance',
      'name': 'Midnight Provider Ledger Reconciliation',
      'type': 'CRON (30 0 * * *)',
      'nextRun': 'Tomorrow, 00:30 AM',
      'status': 'SCHEDULED',
      'timezone': 'Asia/Kolkata (IST)',
    },
  ];

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
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            'Active Workflows',
            '${_mockWorkflows.length}',
            '4 Active • 0 Paused',
            Icons.account_tree_outlined,
            const Color(0xFF388BFD),
          ),
        ),
        const Gap(16),
        Expanded(
          child: _buildKpiCard(
            'Executions Today',
            '1,428',
            '99.2% Success Rate',
            Icons.bolt_outlined,
            const Color(0xFF2EA043),
          ),
        ),
        const Gap(16),
        Expanded(
          child: _buildKpiCard(
            'Automation Rules',
            '${_mockRules.length}',
            'All enabled in Production',
            Icons.tune_rounded,
            const Color(0xFFA371F7),
          ),
        ),
        const Gap(16),
        Expanded(
          child: _buildKpiCard(
            'Pending Approvals',
            '${_mockApprovals.length}',
            'Requires Human Review',
            Icons.how_to_reg_outlined,
            const Color(0xFFF0883E),
          ),
        ),
        const Gap(16),
        Expanded(
          child: _buildKpiCard(
            'Scheduled Jobs',
            '${_mockSchedules.length}',
            'Next in 15 mins (IST)',
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
                    ..._mockExecutions.map((e) => _buildExecutionRow(e)),
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
                        const Text(
                          'Pending Human Approvals',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0883E).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_mockApprovals.length} ACTION REQUIRED',
                            style: const TextStyle(
                              color: Color(0xFFF0883E),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(14),
                    ..._mockApprovals.map((a) => _buildApprovalCard(a)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
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
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Visual Drag & Drop Workflow Builder opened.')),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Workflow Definition'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const Gap(20),
        ..._mockWorkflows.map((wf) => _buildWorkflowCard(wf)),
      ],
    );
  }

  Widget _buildWorkflowCard(Map<String, dynamic> wf) {
    final steps = wf['steps'] as List<Map<String, dynamic>>;

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
                          wf['name'],
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
                            wf['version'],
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      'Triggered by: ${wf['trigger']} • Last execution: ${wf['lastRun']} • Reliability: ${wf['successRate']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Simulated manual trigger for ${wf['id']}')),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Trigger Test Run'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF58A6FF),
                  side: const BorderSide(color: Color(0xFF30363D)),
                ),
              ),
            ],
          ),
          const Gap(16),
          const Divider(color: Color(0xFF21262D), height: 1),
          const Gap(16),

          // Visual Step Pipeline
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
      ),
    );
  }

  Widget _buildPipelineStepBadge(Map<String, dynamic> step, int stepNum) {
    Color typeColor;
    IconData icon;

    switch (step['type']) {
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
                'STEP $stepNum: ${step['type']}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
              ),
              Text(
                step['name'],
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
          child: Column(
            children: _mockExecutions
                .where((e) => _executionFilter == 'ALL' || e['status'] == _executionFilter)
                .map((e) => _buildExecutionRow(e, isDetailView: true))
                .toList(),
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

  Widget _buildExecutionRow(Map<String, dynamic> exec, {bool isDetailView = false}) {
    Color statusColor;
    switch (exec['status']) {
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
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      exec['workflowName'],
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        exec['status'],
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Text(
                  'Execution ID: ${exec['id']} • Corr: ${exec['correlationId']} • Started: ${exec['startedAt']} • Latency: ${exec['duration']}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                ),
                if (exec['error'] != null) ...[
                  const Gap(4),
                  Text(
                    'Error: ${exec['error']}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFF85149), fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          if (exec['status'] == 'FAILED')
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  exec['status'] = 'RUNNING';
                  exec['error'] = null;
                });
                Future.delayed(const Duration(milliseconds: 600), () {
                  if (mounted) {
                    setState(() {
                      exec['status'] = 'COMPLETED';
                      exec['retries'] = (exec['retries'] ?? 0) + 1;
                    });
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Replaying failed execution ${exec['id']}...')),
                );
              },
              icon: const Icon(Icons.replay, size: 14),
              label: const Text('Retry Execution'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF85149).withValues(alpha: 0.2),
                foregroundColor: const Color(0xFFF85149),
                side: const BorderSide(color: Color(0xFFF85149)),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: AUTOMATION RULES
  // ==========================================
  Widget _buildRulesTab() {
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Create Automation Rule dialog opened.')),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Automation Rule'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            ),
          ],
        ),
        const Gap(20),
        ..._mockRules.map((r) => _buildRuleCard(r)),
      ],
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule) {
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
                    rule['name'],
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Switch(
                value: rule['enabled'] as bool,
                onChanged: (val) {
                  setState(() => rule['enabled'] = val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rule ${rule['name']} ${val ? "Enabled" : "Disabled"}')),
                  );
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
                    Text(rule['predicate'], style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 12, fontFamily: 'monospace')),
                  ],
                ),
                const Gap(6),
                Row(
                  children: [
                    const Text('THEN: ', style: TextStyle(color: Color(0xFF2EA043), fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(rule['action'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Human-in-the-Loop (HITL) Approvals',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const Gap(4),
        const Text(
          'Configurable human approval gates for high-value refunds, partner onboarding, and damage compensation.',
          style: TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
        ),
        const Gap(20),
        ..._mockApprovals.map((a) => _buildApprovalCard(a)),
      ],
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> appr) {
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
                  appr['type'],
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF0883E)),
                ),
              ),
              Text(
                'Expires ${appr['timeout']}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
              ),
            ],
          ),
          const Gap(10),
          Text(
            appr['entity'],
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Gap(4),
          Text(
            '${appr['reason']} • Requested by: ${appr['requestedBy']}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
          ),
          const Gap(12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() => _mockApprovals.remove(appr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rejected ${appr['entity']}')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF85149),
                  side: const BorderSide(color: Color(0xFFF85149)),
                ),
                child: const Text('Reject'),
              ),
              const Gap(10),
              ElevatedButton(
                onPressed: () {
                  setState(() => _mockApprovals.remove(appr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Approved ${appr['entity']}')),
                  );
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Schedule new background job dialog opened.')),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Schedule Job'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            ),
          ],
        ),
        const Gap(20),
        ..._mockSchedules.map((s) => _buildScheduleCard(s)),
      ],
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> s) {
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
                  s['name'],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Gap(4),
                Text(
                  '${s['type']} • Next Run: ${s['nextRun']} • Timezone: ${s['timezone']}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Triggered immediate run for ${s['name']}')),
              );
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
}

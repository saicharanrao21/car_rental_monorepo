import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/api_providers.dart';
import '../widgets/automation_command_centre_widget.dart';

class AdminAutomationOverviewPage extends ConsumerStatefulWidget {
  const AdminAutomationOverviewPage({super.key});

  @override
  ConsumerState<AdminAutomationOverviewPage> createState() =>
      _AdminAutomationOverviewPageState();
}

class _AdminAutomationOverviewPageState
    extends ConsumerState<AdminAutomationOverviewPage> {
  int _selectedTabIndex = 0;
  bool _isTriggering = false;

  Future<void> _triggerMaintenanceSweep() async {
    setState(() => _isTriggering = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.dio.post('/rental/automation/run');
      if (mounted) {
        final data = res.data is Map ? res.data as Map<String, dynamic> : {};
        final results = data['results'] as Map<String, dynamic>? ?? {};
        final quotes = results['quotes']?['successCount'] ?? results['quotes']?['runCount'] ?? 0;
        final unconfirmed = results['unconfirmed']?['successCount'] ?? results['unconfirmed']?['runCount'] ?? 0;
        final overdue = results['overdue']?['successCount'] ?? results['overdue']?['runCount'] ?? 0;
        final reminders = results['reminders']?['successCount'] ?? results['reminders']?['runCount'] ?? 0;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
                Gap(8),
                Text('Maintenance Sweep Completed', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Automated rental maintenance cycle finished successfully:',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                ),
                const Gap(12),
                _buildSweepResultRow('Expired Stale Quotes', quotes.toString()),
                _buildSweepResultRow('Released Unconfirmed Holds', unconfirmed.toString()),
                _buildSweepResultRow('Detected Overdue Rentals', overdue.toString()),
                _buildSweepResultRow('Dispatched Pickup Reminders', reminders.toString()),
              ],
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF238636)),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Acknowledge'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to execute maintenance sweep: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTriggering = false);
      }
    }
  }

  Widget _buildSweepResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF58A6FF), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: CustomScrollView(
        slivers: [
          // 1. Top Enterprise App Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF161B22),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF30363D), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.precision_manufacturing_outlined,
                                color: Color(0xFF10B981),
                                size: 26,
                              ),
                            ),
                            const Gap(16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'Enterprise Operations & Automation Core',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF10B981),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: const Text(
                                        'PHASE L ACTIVE',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Gap(4),
                                const Text(
                                  'Declarative Workflows • Event Bus • Rule Engine • Scheduler • Human-in-the-loop Approvals • Correlation Tracing',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF8B949E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),
                    FilledButton.icon(
                        icon: _isTriggering
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 16),
                        label: Text(_isTriggering ? 'Executing Sweep...' : 'Trigger Maintenance Sweep'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF238636),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _isTriggering ? null : _triggerMaintenanceSweep,
                      ),
                    ],
                  ),
                  const Gap(20),
                  // Segment Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabButton(0, 'Control Centre', Icons.dashboard_outlined),
                        const Gap(8),
                        _buildTabButton(1, 'Workflow Definitions', Icons.account_tree_outlined),
                        const Gap(8),
                        _buildTabButton(2, 'Executions & Retries', Icons.history_rounded),
                        const Gap(8),
                        _buildTabButton(3, 'Automation Rules', Icons.tune_rounded),
                        const Gap(8),
                        _buildTabButton(4, 'Approvals & HITL', Icons.how_to_reg_outlined),
                        const Gap(8),
                        _buildTabButton(5, 'Scheduled Jobs', Icons.schedule_rounded),
                        const Gap(8),
                        _buildTabButton(6, 'Correlation Timeline', Icons.timeline_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Tab Content Body
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                width: double.infinity,
                child: AutomationCommandCentreWidget(
                  initialTabIndex: _selectedTabIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF238636).withValues(alpha: 0.2)
              : const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF238636) : const Color(0xFF30363D),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF2EA043) : const Color(0xFF8B949E),
            ),
            const Gap(8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFFC9D1D9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

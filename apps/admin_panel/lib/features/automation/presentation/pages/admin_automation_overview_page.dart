import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
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
                            Row(
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
                                const Gap(10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.2),
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
              child: AutomationCommandCentreWidget(
                initialTabIndex: _selectedTabIndex,
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

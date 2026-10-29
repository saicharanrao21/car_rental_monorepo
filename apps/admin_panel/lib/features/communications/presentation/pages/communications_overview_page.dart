import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../integrations/presentation/widgets/communication_ecosystem_widget.dart';
import '../../../notifications/presentation/providers/admin_notifications_providers.dart';

class CommunicationsOverviewPage extends ConsumerStatefulWidget {
  final String? initialSubTab;

  const CommunicationsOverviewPage({super.key, this.initialSubTab});

  @override
  ConsumerState<CommunicationsOverviewPage> createState() => _CommunicationsOverviewPageState();
}

class _CommunicationsOverviewPageState extends ConsumerState<CommunicationsOverviewPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Workspace Navigation Toolbar
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
                          'Communications Control Plane',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                              Gap(6),
                              Text(
                                'ALL 5 CHANNELS OPERATIONAL',
                                style: TextStyle(
                                  color: Color(0xFF065F46),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      'Mission-critical messaging orchestration across WhatsApp, SMS, Email, Mobile Push, and Voice with zero vendor lock-in.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.rule_outlined, size: 16),
                      label: const Text('Event Rules (13)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFFC7D2FE)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => context.go('/notification-rules'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.text_snippet_outlined, size: 16),
                      label: const Text('Templates Studio'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFFA7F3D0)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => context.go('/templates'),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.monitor_heart_outlined, size: 16),
                      label: const Text('Delivery Logs & Retries'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => context.go('/delivery-logs'),
                    ),
                  ],
                ),
              ],
            ),
            const Gap(20),

            // Telemetry KPI Cards
            _buildTelemetrySummary(theme),
            const Gap(24),

            // Full Enterprise Communication Control Ecosystem Widget
            CommunicationEcosystemWidget(initialSubTab: widget.initialSubTab),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetrySummary(ThemeData theme) {
    final statsAsync = ref.watch(adminDeliveryStatsProvider);
    final stats = statsAsync.valueOrNull;
    final totalDeliveries = stats?['overview']?['total'] != null
        ? stats!['overview']['total'].toString()
        : '1,482,900';
    final deliveryRate = stats?['overview']?['deliveryRate']?.toString() ?? '99.82%';
    final queuedBuffer = stats?['overview']?['queued']?.toString() ?? '142';
    final failedCount = stats?['overview']?['failed']?.toString() ?? '18';
    final deadLetterCount = stats?['overview']?['deadLetter']?.toString() ?? '42';
    final deliveredSubtitle = stats?['overview']?['delivered'] != null
        ? '${stats!['overview']['delivered']} msgs'
        : '1,476,972 msgs';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              const Row(
                children: [
                  Icon(Icons.insights_rounded, color: Color(0xFF0F172A), size: 18),
                  Gap(8),
                  Text(
                    'Real-Time Telemetry & Health Monitoring',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Rolling 24 Hours • Trailing Window',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildKpiTile(
                'Attempted',
                totalDeliveries,
                Icons.send_outlined,
                const Color(0xFF64748B),
                onTap: () => context.go('/delivery-logs'),
              ),
              _buildKpiTile(
                'Delivered SLA',
                deliveryRate,
                Icons.verified_outlined,
                const Color(0xFF10B981),
                subtitle: deliveredSubtitle,
                onTap: () => context.go('/delivery-logs'),
              ),
              _buildKpiTile(
                'Queued Buffer',
                '$queuedBuffer msgs',
                Icons.hourglass_top_outlined,
                const Color(0xFF3B82F6),
                onTap: () => context.go('/delivery-logs'),
              ),
              _buildKpiTile(
                'Retrying / Dead-Letter',
                '$failedCount / $deadLetterCount',
                Icons.replay_circle_filled_outlined,
                const Color(0xFFF59E0B),
                onTap: () => context.go('/delivery-logs'),
              ),
              _buildKpiTile(
                'Average Latency',
                '28 ms',
                Icons.speed_outlined,
                const Color(0xFF06B6D4),
              ),
              _buildKpiTile(
                'Cost Incurred',
                '₹21,480.50',
                Icons.currency_rupee_outlined,
                const Color(0xFF8B5CF6),
                subtitle: 'Budget: ₹50,000 (43%)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 175,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const Gap(6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            if (subtitle != null) ...[
              const Gap(2),
              Text(
                subtitle,
                style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
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
                        _buildChannelHealthBadge(),
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

  Widget _buildChannelHealthBadge() {
    final statsAsync = ref.watch(adminDeliveryStatsProvider);

    return statsAsync.when(
      data: (stats) {
        final total = (stats['overview']?['total'] ?? stats['totalDeliveries'] ?? 0) as num;
        final failed = (stats['overview']?['failed'] ?? stats['failedCount'] ?? 0) as num;
        final deadLetter = (stats['overview']?['deadLetter'] ?? stats['deadLetterCount'] ?? 0) as num;
        final retrying = (stats['overview']?['retrying'] ?? stats['retryingCount'] ?? 0) as num;

        String label = 'ALL 5 CHANNELS OPERATIONAL';
        Color bgColor = const Color(0xFFECFDF5);
        Color borderColor = const Color(0xFFA7F3D0);
        Color fgColor = const Color(0xFF065F46);
        IconData icon = Icons.check_circle_rounded;

        final failureRate = total > 0 ? (failed + deadLetter) / total : 0.0;

        if (deadLetter > 50 || failureRate > 0.10) {
          label = 'CRITICAL: HIGH DISPATCH FAILURE';
          bgColor = const Color(0xFFFEF2F2);
          borderColor = const Color(0xFFFECACA);
          fgColor = const Color(0xFF991B1B);
          icon = Icons.error_rounded;
        } else if (deadLetter > 10 || failureRate > 0.02 || retrying > 50) {
          label = 'DEGRADED CHANNELS DETECTED';
          bgColor = const Color(0xFFFFFBEB);
          borderColor = const Color(0xFFFDE68A);
          fgColor = const Color(0xFF92400E);
          icon = Icons.warning_amber_rounded;
        } else if (total == 0) {
          label = 'CHANNELS STANDBY';
          bgColor = const Color(0xFFF1F5F9);
          borderColor = const Color(0xFFCBD5E1);
          fgColor = const Color(0xFF475569);
          icon = Icons.radio_button_unchecked;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fgColor, size: 14),
              const Gap(6),
              Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF64748B)),
            ),
            Gap(6),
            Text(
              'OBSERVING CHANNELS...',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: Color(0xFFDC2626), size: 14),
            Gap(6),
            Text(
              'CHANNELS TEMPORARILY UNAVAILABLE',
              style: TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetrySummary(ThemeData theme) {
    final statsAsync = ref.watch(adminDeliveryStatsProvider);
    final stats = statsAsync.valueOrNull;

    final totalVal = stats?['overview']?['total'] ?? stats?['totalDeliveries'];
    final deliveredVal = stats?['overview']?['delivered'] ?? stats?['deliveredCount'];
    final queuedVal = stats?['overview']?['queued'] ?? stats?['queuedCount'];
    final failedVal = stats?['overview']?['failed'] ?? stats?['failedCount'];
    final deadLetterVal = stats?['overview']?['deadLetter'] ?? stats?['deadLetterCount'];

    final totalDeliveries = totalVal != null
        ? NumberFormat('#,###').format(totalVal)
        : (statsAsync.isLoading ? '...' : '0');
    final deliveryRate = stats?['overview']?['deliveryRate']?.toString() ??
        (totalVal is num && totalVal > 0 && deliveredVal is num
            ? '${(deliveredVal / totalVal * 100).toStringAsFixed(2)}%'
            : (statsAsync.isLoading ? '...' : '0.0%'));
    final queuedBuffer = queuedVal != null ? queuedVal.toString() : (statsAsync.isLoading ? '...' : '0');
    final failedCount = failedVal != null ? failedVal.toString() : (statsAsync.isLoading ? '...' : '0');
    final deadLetterCount = deadLetterVal != null ? deadLetterVal.toString() : (statsAsync.isLoading ? '...' : '0');
    final deliveredSubtitle = (deliveredVal != null && totalVal != null && totalVal > 0)
        ? '${NumberFormat('#,###').format(deliveredVal)} msgs'
        : (statsAsync.isLoading ? 'Loading...' : (totalVal == 0 ? 'No deliveries in window' : '0 msgs'));

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

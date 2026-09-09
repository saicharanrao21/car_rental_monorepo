import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../data/models/marketplace_provider_model.dart';
import '../providers/integration_marketplace_provider.dart';
import 'configure_provider_dialog.dart';
import 'provider_docs_sheet.dart';
import 'test_connection_dialog.dart';

class ProviderCard extends ConsumerWidget {
  final MarketplaceProviderModel provider;

  const ProviderCard({super.key, required this.provider});

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'PAYMENT':
        return Icons.credit_card_rounded;
      case 'MESSAGING_WHATSAPP':
        return Icons.chat_bubble_rounded;
      case 'MESSAGING_SMS':
        return Icons.textsms_rounded;
      case 'MESSAGING_EMAIL':
        return Icons.mail_rounded;
      case 'MESSAGING_PUSH':
        return Icons.notifications_active_rounded;
      case 'STORAGE':
        return Icons.cloud_upload_rounded;
      case 'MAPS':
        return Icons.map_rounded;
      case 'IDENTITY_VERIFICATION':
        return Icons.verified_user_rounded;
      case 'VEHICLE_TRACKING':
        return Icons.navigation_rounded;
      case 'ACCOUNTING':
        return Icons.receipt_long_rounded;
      case 'AI':
        return Icons.auto_awesome_rounded;
      case 'SEARCH':
        return Icons.search_rounded;
      case 'ANALYTICS':
        return Icons.insights_rounded;
      default:
        return Icons.extension_rounded;
    }
  }

  Color _getHealthColor(String status) {
    switch (status.toUpperCase()) {
      case 'HEALTHY':
      case 'ACTIVE':
        return const Color(0xFF10B981); // Emerald green
      case 'DEGRADED':
        return const Color(0xFFF59E0B); // Amber
      case 'DOWN':
        return const Color(0xFFEF4444); // Rose red
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final healthColor = _getHealthColor(provider.health.status);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: provider.isActive
              ? theme.colorScheme.primary.withOpacity(0.6)
              : theme.dividerColor.withOpacity(0.1),
          width: provider.isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: provider.isActive
                ? theme.colorScheme.primary.withOpacity(0.08)
                : Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon, Name, Category, Badges
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Icon(
                    _getCategoryIcon(provider.category),
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                ),
                const Gap(14),
                // Title and tagline
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              provider.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Gap(6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v${provider.version}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (provider.isActive) ...[
                            const Gap(6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Gap(4),
                      Text(
                        provider.tagline,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.65),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // State Switch
                Switch.adaptive(
                  value: provider.isEnabled,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    ref.read(marketplaceNotifierProvider.notifier).toggleProvider(
                          provider.category,
                          provider.providerId,
                          val,
                        );
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Metadata Grid: Region, Environment, Health, Priority, Credentials
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    // Environment Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: provider.activeEnvironment == 'LIVE'
                            ? const Color(0xFF10B981).withOpacity(0.12)
                            : const Color(0xFFF59E0B).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: provider.activeEnvironment == 'LIVE'
                              ? const Color(0xFF10B981).withOpacity(0.3)
                              : const Color(0xFFF59E0B).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            provider.activeEnvironment == 'LIVE'
                                ? Icons.verified_rounded
                                : Icons.science_rounded,
                            size: 13,
                            color: provider.activeEnvironment == 'LIVE'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFD97706),
                          ),
                          const Gap(4),
                          Text(
                            provider.activeEnvironment,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: provider.activeEnvironment == 'LIVE'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),

                    // Health Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: healthColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: healthColor,
                            ),
                          ),
                          const Gap(5),
                          Text(
                            '${provider.health.status} (${provider.health.latencyMs}ms)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: healthColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Priority / Fallback
                    Text(
                      'P${provider.priority}${provider.fallbackProviderId != null ? " → ${provider.fallbackProviderId}" : ""}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const Gap(10),

                // Capabilities Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ...provider.supportedCapabilities.take(4).map(
                          (cap) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              cap,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    // Countries / Currencies
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        provider.supportedCountries.join(', '),
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const Gap(8),

                // Configured Status & Webhooks
                Row(
                  children: [
                    Icon(
                      provider.hasCredentials
                          ? Icons.lock_outline_rounded
                          : Icons.lock_open_rounded,
                      size: 13,
                      color: provider.hasCredentials
                          ? const Color(0xFF10B981)
                          : const Color(0xFF9CA3AF),
                    ),
                    const Gap(4),
                    Text(
                      provider.hasCredentials
                          ? 'Encrypted AES-256 Vault'
                          : 'Credentials Not Configured',
                      style: TextStyle(
                        fontSize: 11,
                        color: provider.hasCredentials
                            ? const Color(0xFF10B981)
                            : const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (provider.supportedWebhookEvents != null &&
                        provider.supportedWebhookEvents!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.webhook_rounded, size: 13, color: Color(0xFF3B82F6)),
                          const Gap(4),
                          Text(
                            '${provider.supportedWebhookEvents!.length} events',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),
          const Divider(height: 1),

          // Bottom Action Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                // Docs Button
                IconButton(
                  tooltip: 'View Documentation',
                  icon: const Icon(Icons.menu_book_rounded, size: 19),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => ProviderDocsSheet(provider: provider),
                    );
                  },
                ),

                // Test Connection Button
                IconButton(
                  tooltip: 'Test Connection',
                  icon: const Icon(Icons.bolt_rounded, size: 20),
                  color: const Color(0xFFD97706),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => TestConnectionDialog(provider: provider),
                    );
                  },
                ),

                const Spacer(),

                // Set Active button if not active
                if (!provider.isActive && provider.isEnabled)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.star_border_rounded, size: 16),
                    label: const Text('Set Active', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      ref
                          .read(marketplaceNotifierProvider.notifier)
                          .setActiveProvider(provider.category, provider.providerId);
                    },
                  ),

                const Gap(6),

                // Configure Button
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Configure', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => ConfigureProviderDialog(provider: provider),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

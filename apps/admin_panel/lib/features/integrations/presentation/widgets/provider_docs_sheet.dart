import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../data/models/marketplace_provider_model.dart';

class ProviderDocsSheet extends StatelessWidget {
  final MarketplaceProviderModel provider;

  const ProviderDocsSheet({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final docs = provider.documentation;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(28.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet Handle
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_book_rounded, color: theme.colorScheme.primary, size: 28),
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            provider.name,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Gap(8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'v${provider.version}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'By ${provider.author} • Category: ${provider.category}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Gap(16),
            const Divider(height: 1),
            const Gap(16),

            // Scrollable Content
            Expanded(
              child: ListView(
                children: [
                  // Overview Section
                  _sectionTitle(theme, 'Architecture & Overview'),
                  const Gap(8),
                  Text(
                    docs.overview.isNotEmpty ? docs.overview : provider.description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const Gap(20),

                  // Setup Guide Section
                  _sectionTitle(theme, 'Integration Setup Guide'),
                  const Gap(8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: Text(
                      docs.setupGuide.isNotEmpty
                          ? docs.setupGuide
                          : 'Follow provider portal setup instructions and generate required credentials.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                  ),
                  const Gap(20),

                  // Webhook Guide Section
                  if (docs.webhookGuide != null ||
                      (provider.supportedWebhookEvents != null &&
                          provider.supportedWebhookEvents!.isNotEmpty)) ...[
                    _sectionTitle(theme, 'Webhooks & Event Dispatching'),
                    const Gap(8),
                    if (docs.webhookGuide != null)
                      Text(
                        docs.webhookGuide!,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    const Gap(8),
                    if (provider.webhookSignatureHeader != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.security_rounded, size: 16, color: Color(0xFF3B82F6)),
                            const Gap(8),
                            Text(
                              'Signature Header: ${provider.webhookSignatureHeader}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Gap(10),
                    if (provider.supportedWebhookEvents != null) ...[
                      Text('Supported Webhook Events:', style: theme.textTheme.labelMedium),
                      const Gap(6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: provider.supportedWebhookEvents!
                            .map(
                              (e) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  e,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const Gap(20),
                  ],

                  // Links Section
                  _sectionTitle(theme, 'External Resources & Support'),
                  const Gap(8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (docs.docsUrl.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Official API Docs'),
                        ),
                      if (provider.websiteUrl.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.language_rounded, size: 16),
                          label: const Text('Provider Website'),
                        ),
                      if (docs.supportEmail != null)
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.mail_outline_rounded, size: 16),
                          label: Text(docs.supportEmail!),
                        ),
                    ],
                  ),
                  const Gap(20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

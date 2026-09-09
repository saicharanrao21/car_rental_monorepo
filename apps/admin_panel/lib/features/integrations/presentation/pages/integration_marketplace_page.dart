import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../providers/integration_marketplace_provider.dart';
import '../widgets/provider_card.dart';

class IntegrationMarketplacePage extends ConsumerStatefulWidget {
  const IntegrationMarketplacePage({super.key});

  @override
  ConsumerState<IntegrationMarketplacePage> createState() =>
      _IntegrationMarketplacePageState();
}

class _IntegrationMarketplacePageState extends ConsumerState<IntegrationMarketplacePage> {
  final TextEditingController _searchController = TextEditingController();

  static const List<Map<String, String>> _categories = [
    {'id': 'ALL', 'label': 'All Categories'},
    {'id': 'PAYMENT', 'label': 'Payments'},
    {'id': 'MESSAGING_WHATSAPP', 'label': 'WhatsApp'},
    {'id': 'MESSAGING_SMS', 'label': 'SMS'},
    {'id': 'MESSAGING_EMAIL', 'label': 'Email'},
    {'id': 'MESSAGING_PUSH', 'label': 'Push Notifications'},
    {'id': 'STORAGE', 'label': 'Cloud Storage'},
    {'id': 'MAPS', 'label': 'Maps & Geocoding'},
    {'id': 'IDENTITY_VERIFICATION', 'label': 'KYC Verification'},
    {'id': 'VEHICLE_TRACKING', 'label': 'Telematics & GPS'},
    {'id': 'ACCOUNTING', 'label': 'Accounting & ERP'},
    {'id': 'AI', 'label': 'AI & LLM'},
    {'id': 'SEARCH', 'label': 'Full-Text Search'},
    {'id': 'ANALYTICS', 'label': 'Product Analytics'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(marketplaceNotifierProvider);
    final notifier = ref.read(marketplaceNotifierProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Integration Marketplace & Provider Catalog',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Gap(6),
                            Text(
                              'Enterprise catalog supporting extensible third-party adapters across 13 domains with AES-256 secret vaulting.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Environment Switcher
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'SANDBOX',
                            label: Text('Sandbox'),
                            icon: Icon(Icons.science_outlined, size: 16),
                          ),
                          ButtonSegment(
                            value: 'LIVE',
                            label: Text('Live'),
                            icon: Icon(Icons.verified_outlined, size: 16),
                          ),
                        ],
                        selected: {state.selectedEnvironment},
                        onSelectionChanged: (val) {
                          notifier.setEnvironment(val.first);
                        },
                      ),
                      const Gap(12),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh Marketplace',
                        onPressed: () => notifier.loadMarketplace(),
                      ),
                    ],
                  ),
                  const Gap(24),

                  // Metrics KPI Row
                  Row(
                    children: [
                      _kpiCard(
                        theme,
                        title: 'Catalog Providers',
                        value: '${state.totalProvidersCount}',
                        icon: Icons.hub_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const Gap(16),
                      _kpiCard(
                        theme,
                        title: 'Configured & Vaulted',
                        value: '${state.configuredCount}',
                        icon: Icons.lock_outline_rounded,
                        color: const Color(0xFF10B981),
                      ),
                      const Gap(16),
                      _kpiCard(
                        theme,
                        title: 'Healthy Handshakes',
                        value: '${state.healthyCount}',
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFF06B6D4),
                      ),
                      const Gap(16),
                      _kpiCard(
                        theme,
                        title: 'Active Routing',
                        value: '${state.activeGatewaysCount}',
                        icon: Icons.alt_route_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                  const Gap(24),

                  // Search & Category Filters
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by provider, capability, currency, or country (e.g. UPI, Stripe, INR)...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      notifier.setSearch('');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (val) => notifier.setSearch(val),
                        ),
                      ),
                    ],
                  ),
                  const Gap(16),

                  // Horizontal Category Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = state.selectedCategory == cat['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(cat['label']!),
                            onSelected: (_) => notifier.setCategory(cat['id']!),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Provider Grid / List
          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    Gap(16),
                    Text('Loading enterprise provider catalog...'),
                  ],
                ),
              ),
            )
          else if (state.filteredProviders.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 56,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const Gap(16),
                    Text(
                      'No matching providers found in catalog',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Gap(6),
                    Text(
                      'Try adjusting your search criteria or domain filter.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final crossAxisCount = width > 1200
                      ? 3
                      : width > 800
                          ? 2
                          : 1;

                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      mainAxisExtent: 310,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final provider = state.filteredProviders[index];
                        return ProviderCard(provider: provider);
                      },
                      childCount: state.filteredProviders.length,
                    ),
                  );
                },
              ),
            ),

          const SliverToBoxAdapter(child: Gap(32)),
        ],
      ),
    );
  }

  Widget _kpiCard(
    ThemeData theme, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Gap(14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
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

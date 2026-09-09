import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../providers/integration_marketplace_provider.dart';
import '../widgets/provider_card.dart';
import '../widgets/provider_comparison_widget.dart';
import '../widgets/runtime_command_centre_widget.dart';
import '../widgets/payment_ecosystem_widget.dart';
import '../widgets/communication_ecosystem_widget.dart';

class IntegrationMarketplacePage extends ConsumerStatefulWidget {
  const IntegrationMarketplacePage({super.key});

  @override
  ConsumerState<IntegrationMarketplacePage> createState() =>
      _IntegrationMarketplacePageState();
}

class _IntegrationMarketplacePageState extends ConsumerState<IntegrationMarketplacePage> {
  final TextEditingController _searchController = TextEditingController();
  String _activeTab = 'CATALOG'; // 'CATALOG' | 'OPERATIONS' | 'COMPARISON'

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
                              'Integration Marketplace & Operations Control Centre',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Gap(6),
                            Text(
                              'Enterprise integration runtime supporting capability-based routing, circuit breakers, automated failover, and telemetry.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // View Switcher (Marketplace vs Runtime Operations vs Comparison)
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'CATALOG',
                            label: Text('Marketplace Catalog'),
                            icon: Icon(Icons.grid_view_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: 'PAYMENTS',
                            label: Text('Payment Ecosystem'),
                            icon: Icon(Icons.account_balance_wallet_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: 'COMMUNICATIONS',
                            label: Text('Communications'),
                            icon: Icon(Icons.mark_chat_unread_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: 'OPERATIONS',
                            label: Text('Runtime & Failover'),
                            icon: Icon(Icons.speed_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: 'COMPARISON',
                            label: Text('Comparison Matrix'),
                            icon: Icon(Icons.compare_arrows_rounded, size: 16),
                          ),
                        ],
                        selected: {_activeTab},
                        onSelectionChanged: (val) {
                          setState(() {
                            _activeTab = val.first;
                          });
                        },
                      ),
                      const Gap(16),
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
                        tooltip: 'Refresh',
                        onPressed: () => notifier.loadMarketplace(),
                      ),
                    ],
                  ),
                  const Gap(24),

                  if (_activeTab == 'CATALOG') ...[
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
                              hintText:
                                  'Search by provider, capability, currency, or country (e.g. UPI, Stripe, INR)...',
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
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
                ],
              ),
            ),
          ),

          // Render Active Tab View
          if (_activeTab == 'PAYMENTS')
            const SliverToBoxAdapter(
              child: PaymentEcosystemWidget(),
            )
          else if (_activeTab == 'COMMUNICATIONS')
            const SliverToBoxAdapter(
              child: CommunicationEcosystemWidget(),
            )
          else if (_activeTab == 'OPERATIONS')
            const SliverToBoxAdapter(
              child: RuntimeCommandCentreWidget(),
            )
          else if (_activeTab == 'COMPARISON')
            const SliverToBoxAdapter(
              child: ProviderComparisonWidget(),
            )
          else ...[
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
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 440,
                    mainAxisExtent: 310,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final provider = state.filteredProviders[index];
                      return ProviderCard(provider: provider);
                    },
                    childCount: state.filteredProviders.length,
                  ),
                ),
              ),
          ],
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
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.65),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

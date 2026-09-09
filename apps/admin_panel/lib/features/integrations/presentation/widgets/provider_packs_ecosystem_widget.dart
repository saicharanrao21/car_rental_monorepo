import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProviderPacksEcosystemWidget extends StatefulWidget {
  const ProviderPacksEcosystemWidget({super.key});

  @override
  State<ProviderPacksEcosystemWidget> createState() => _ProviderPacksEcosystemWidgetState();
}

class _ProviderPacksEcosystemWidgetState extends State<ProviderPacksEcosystemWidget> {
  String _selectedCategory = 'ALL';
  String _selectedCapability = 'UPI';
  String _selectedTenantScope = 'PLATFORM';

  static const List<Map<String, String>> _categories = [
    {'id': 'ALL', 'name': 'All 35 Categories'},
    {'id': 'MAPS', 'name': 'Maps & Geocoding'},
    {'id': 'VEHICLE_TRACKING', 'name': 'Telematics & GPS'},
    {'id': 'IDENTITY_VERIFICATION', 'name': 'KYC Verification'},
    {'id': 'ACCOUNTING', 'name': 'Accounting & ERP'},
    {'id': 'AI', 'name': 'AI & LLMs'},
    {'id': 'SEARCH', 'name': 'Search Engine'},
    {'id': 'ANALYTICS', 'name': 'Product Analytics'},
    {'id': 'PAYMENT', 'name': 'Payments & Gateways'},
    {'id': 'MESSAGING_WHATSAPP', 'name': 'WhatsApp Messaging'},
  ];

  static final List<Map<String, dynamic>> _providerPacks = [
    {
      'id': 'mapbox',
      'name': 'Mapbox Navigation & Geocoding',
      'category': 'MAPS',
      'version': 'v5 (Adapter 1.0.0)',
      'status': 'REAL_ADAPTER',
      'lifecycle': 'ACTIVE',
      'latency': '95ms',
      'uptime': '99.95%',
      'cost': '\$0.005 / request',
      'capabilities': ['GEOCODE', 'REVERSE_GEOCODE', 'ROUTE', 'DISTANCE_MATRIX'],
      'regions': ['GLOBAL', 'IN', 'US', 'EU'],
    },
    {
      'id': 'traccar',
      'name': 'Traccar Open GPS Telematics Hub',
      'category': 'VEHICLE_TRACKING',
      'version': 'v5.10 (Adapter 1.0.0)',
      'status': 'REAL_ADAPTER',
      'lifecycle': 'ACTIVE',
      'latency': '70ms',
      'uptime': '99.99%',
      'cost': '\$0.001 / position',
      'capabilities': ['GPS_POSITION', 'LIVE_LOCATION', 'TRIP_TRACKING', 'IMMOBILIZE', 'GEOFENCE_CHECK'],
      'regions': ['GLOBAL', 'IN', 'EU'],
    },
    {
      'id': 'hyperverge',
      'name': 'HyperVerge AI Identity & Fraud Stack',
      'category': 'IDENTITY_VERIFICATION',
      'version': 'v3.2 (Adapter 1.0.0)',
      'status': 'REAL_ADAPTER',
      'lifecycle': 'ACTIVE',
      'latency': '450ms',
      'uptime': '99.9%',
      'cost': '\$0.08 / check',
      'capabilities': ['PAN_VERIFICATION', 'AADHAAR_VERIFICATION', 'DRIVING_LICENCE_VERIFICATION', 'VEHICLE_RC_VERIFICATION', 'FACE_MATCH', 'LIVENESS'],
      'regions': ['IN', 'GLOBAL'],
    },
    {
      'id': 'zoho_books',
      'name': 'Zoho Books ERP & Invoicing',
      'category': 'ACCOUNTING',
      'version': 'v3 (Adapter 1.0.0)',
      'status': 'REAL_ADAPTER',
      'lifecycle': 'ACTIVE',
      'latency': '380ms',
      'uptime': '99.9%',
      'cost': 'Free with plan',
      'capabilities': ['CREATE_INVOICE', 'SYNC_CUSTOMER', 'SYNC_PAYMENT', 'TAX_CALCULATION'],
      'regions': ['IN', 'GLOBAL'],
    },
    {
      'id': 'gemini',
      'name': 'Google Gemini 1.5/2.0 Multimodal AI',
      'category': 'AI',
      'version': 'v1beta (Adapter 1.0.0)',
      'status': 'REAL_ADAPTER',
      'lifecycle': 'ACTIVE',
      'latency': '400ms',
      'uptime': '99.95%',
      'cost': '\$0.0003 / 1k tokens',
      'capabilities': ['CHAT', 'TEXT_GENERATION', 'SUMMARIZATION', 'CLASSIFICATION', 'EXTRACTION', 'EMBEDDINGS'],
      'regions': ['GLOBAL', 'IN', 'US'],
    },
    {
      'id': 'meilisearch',
      'name': 'Meilisearch Instant Search Engine',
      'category': 'SEARCH',
      'version': 'v1.6 (Adapter 1.0.0)',
      'status': 'REAL_ADAPTER',
      'lifecycle': 'ACTIVE',
      'latency': '15ms',
      'uptime': '99.99%',
      'cost': 'Self-hosted / 0',
      'capabilities': ['INDEX_DOCUMENT', 'SEARCH_QUERY', 'AUTOCOMPLETE'],
      'regions': ['GLOBAL'],
    },
    {
      'id': 'posthog',
      'name': 'PostHog Product Telemetry',
      'category': 'ANALYTICS',
      'version': 'v1 (Adapter 1.0.0)',
      'status': 'REAL_ADAPTER',
      'lifecycle': 'ACTIVE',
      'latency': '25ms',
      'uptime': '99.99%',
      'cost': '\$0.0001 / event',
      'capabilities': ['TRACK_EVENT', 'IDENTIFY_USER', 'BATCH_EVENTS'],
      'regions': ['GLOBAL'],
    },
    {
      'id': 'razorpay',
      'name': 'Razorpay Escrow & Payment Gateway',
      'category': 'PAYMENT',
      'version': 'v1 (Adapter 2.0.0)',
      'status': 'REAL_ADAPTER',
      'lifecycle': 'ACTIVE',
      'latency': '180ms',
      'uptime': '99.95%',
      'cost': '2.0% flat',
      'capabilities': ['CREATE_ORDER', 'VERIFY_PAYMENT', 'CAPTURE', 'REFUND', 'UPI'],
      'regions': ['IN'],
    },
    {
      'id': 'cashfree',
      'name': 'Cashfree Payments & Payouts',
      'category': 'PAYMENT',
      'version': '2023-08 (Adapter 1.0.0)',
      'status': 'REAL_ADAPTER',
      'lifecycle': 'ACTIVE',
      'latency': '190ms',
      'uptime': '99.9%',
      'cost': '1.9% flat',
      'capabilities': ['CREATE_ORDER', 'VERIFY_PAYMENT', 'REFUND', 'UPI'],
      'regions': ['IN'],
    },
    {
      'id': 'stripe',
      'name': 'Stripe Global Financial Infrastructure',
      'category': 'PAYMENT',
      'version': '2023-10 (Adapter 2.0.0)',
      'status': 'REAL_ADAPTER',
      'lifecycle': 'ACTIVE',
      'latency': '220ms',
      'uptime': '99.99%',
      'cost': '2.9% + \$0.30',
      'capabilities': ['CREATE_ORDER', 'CAPTURE', 'REFUND', 'CARD'],
      'regions': ['GLOBAL', 'US', 'EU'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredPacks = _selectedCategory == 'ALL'
        ? _providerPacks
        : _providerPacks.where((p) => p['category'] == _selectedCategory).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Banner
          _buildKpiBanner(theme),
          const Gap(24),

          // Category Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((c) {
                final isSelected = _selectedCategory == c['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(c['name']!),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedCategory = c['id']!;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Gap(20),

          // Provider Packs Grid
          Text(
            'Registered Capability Packs (${filteredPacks.length})',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.6,
            ),
            itemCount: filteredPacks.length,
            itemBuilder: (context, idx) {
              final pack = filteredPacks[idx];
              return _buildPackCard(theme, pack);
            },
          ),
          const Gap(32),

          // Dynamic Capability Comparison Station
          _buildCapabilityComparisonSection(theme),
          const Gap(32),

          // "Why was this provider selected?" Inspector
          _buildRoutingExplanationInspector(theme),
        ],
      ),
    );
  }

  Widget _buildKpiBanner(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildKpiItem(theme, '35', 'Audited Categories', Icons.category_rounded, Colors.indigo),
            _buildKpiItem(theme, '42+', 'Payment Gateways', Icons.account_balance_wallet_rounded, Colors.teal),
            _buildKpiItem(theme, '10', 'Real Adapters', Icons.check_circle_rounded, Colors.green),
            _buildKpiItem(theme, '10-State', 'Connector Lifecycle', Icons.autorenew_rounded, Colors.purple),
            _buildKpiItem(theme, '4-Tier', 'Multi-Tenant Scopes', Icons.apartment_rounded, Colors.amber),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiItem(ThemeData theme, String value, String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const Gap(12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
      ],
    );
  }

  Widget _buildPackCard(ThemeData theme, Map<String, dynamic> pack) {
    final statusColor = pack['status'] == 'REAL_ADAPTER'
        ? Colors.green
        : pack['status'] == 'SIMULATION_MOCK'
            ? Colors.orange
            : Colors.grey;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pack['name'],
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    pack['status'],
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Gap(4),
            Text(
              '${pack['category']} • ${pack['version']}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPackStat('SLA Latency', pack['latency']),
                _buildPackStat('Uptime', pack['uptime']),
                _buildPackStat('Cost Tier', pack['cost']),
              ],
            ),
            const Gap(12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: (pack['capabilities'] as List<String>).take(4).map((c) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(c, style: TextStyle(fontSize: 10, color: theme.colorScheme.primary)),
                );
              }).toList(),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.trip_origin_rounded, size: 12, color: Colors.green),
                const Gap(4),
                Text(
                  'Lifecycle: ${pack['lifecycle']}',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.green),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings_outlined, size: 14),
                  label: const Text('Lifecycle', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showLifecycleTransitionModal(context, pack),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showLifecycleTransitionModal(BuildContext context, Map<String, dynamic> pack) {
    String selectedState = pack['lifecycle'];
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Transition Lifecycle: ${pack['name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select target connector lifecycle state:'),
                  const Gap(8),
                  DropdownButtonFormField<String>(
                    value: selectedState,
                    items: const [
                      DropdownMenuItem(value: 'DISCOVERED', child: Text('DISCOVERED')),
                      DropdownMenuItem(value: 'CONFIGURED', child: Text('CONFIGURED')),
                      DropdownMenuItem(value: 'CREDENTIALS_VALIDATED', child: Text('CREDENTIALS_VALIDATED')),
                      DropdownMenuItem(value: 'SANDBOX_TESTED', child: Text('SANDBOX_TESTED')),
                      DropdownMenuItem(value: 'WEBHOOK_VERIFIED', child: Text('WEBHOOK_VERIFIED')),
                      DropdownMenuItem(value: 'APPROVED', child: Text('APPROVED')),
                      DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                      DropdownMenuItem(value: 'DEGRADED', child: Text('DEGRADED')),
                      DropdownMenuItem(value: 'DISABLED', child: Text('DISABLED')),
                      DropdownMenuItem(value: 'RETIRED', child: Text('RETIRED')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedState = val;
                        });
                      }
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const Gap(16),
                  const Text('Reason for state transition (Audit Log):'),
                  const Gap(8),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Verified sandbox credentials & webhook signature',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      pack['lifecycle'] = selectedState;
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Successfully transitioned ${pack['name']} to $selectedState')),
                    );
                  },
                  child: const Text('Confirm Transition'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCapabilityComparisonSection(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows_rounded, color: theme.colorScheme.primary),
                const Gap(8),
                Text('Dynamic Capability Comparison Station', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                DropdownButton<String>(
                  value: _selectedCapability,
                  items: const [
                    DropdownMenuItem(value: 'UPI', child: Text('Capability: UPI')),
                    DropdownMenuItem(value: 'GEOCODE', child: Text('Capability: GEOCODE')),
                    DropdownMenuItem(value: 'ROUTE', child: Text('Capability: ROUTE')),
                    DropdownMenuItem(value: 'GPS_POSITION', child: Text('Capability: GPS_POSITION')),
                    DropdownMenuItem(value: 'PAN_VERIFICATION', child: Text('Capability: PAN_VERIFICATION')),
                    DropdownMenuItem(value: 'CREATE_INVOICE', child: Text('Capability: CREATE_INVOICE')),
                    DropdownMenuItem(value: 'CHAT', child: Text('Capability: CHAT')),
                    DropdownMenuItem(value: 'SEARCH_QUERY', child: Text('Capability: SEARCH_QUERY')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCapability = val;
                      });
                    }
                  },
                ),
              ],
            ),
            const Gap(16),
            Text(
              'Side-by-side performance, cost, and latency SLAs for capability $_selectedCapability across active connectors:',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.65)),
            ),
            const Gap(16),
            Table(
              border: TableBorder.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.5)),
                  children: const [
                    Padding(padding: EdgeInsets.all(8), child: Text('Provider', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8), child: Text('SLA Latency', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Uptime', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Pricing', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Fallback Suitable', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const TableRow(
                  children: [
                    Padding(padding: EdgeInsets.all(8), child: Text('Razorpay / Mapbox / Traccar (Primary)')),
                    Padding(padding: EdgeInsets.all(8), child: Text('ACTIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8), child: Text('95ms')),
                    Padding(padding: EdgeInsets.all(8), child: Text('99.95%')),
                    Padding(padding: EdgeInsets.all(8), child: Text('Tier 1 negotiated')),
                    Padding(padding: EdgeInsets.all(8), child: Icon(Icons.check_circle, color: Colors.green, size: 16)),
                  ],
                ),
                const TableRow(
                  children: [
                    Padding(padding: EdgeInsets.all(8), child: Text('Cashfree / Google Maps / Surepass (Fallback 1)')),
                    Padding(padding: EdgeInsets.all(8), child: Text('ACTIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8), child: Text('140ms')),
                    Padding(padding: EdgeInsets.all(8), child: Text('99.9%')),
                    Padding(padding: EdgeInsets.all(8), child: Text('Standard')),
                    Padding(padding: EdgeInsets.all(8), child: Icon(Icons.check_circle, color: Colors.green, size: 16)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutingExplanationInspector(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.policy_rounded, color: Colors.indigo),
                const Gap(8),
                Text('"Why was this provider selected?" Policy Inspector', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'PLATFORM', label: Text('Platform')),
                    ButtonSegment(value: 'ORGANIZATION', label: Text('Vendor')),
                    ButtonSegment(value: 'BRANCH', label: Text('Branch')),
                  ],
                  selected: {_selectedTenantScope},
                  onSelectionChanged: (val) {
                    setState(() {
                      _selectedTenantScope = val.first;
                    });
                  },
                ),
              ],
            ),
            const Gap(16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Colors.green, size: 18),
                      const Gap(8),
                      Text(
                        'Selected Provider: Razorpay (Escrow Gateway) for Capability: payment.create_order',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const Text('1. Multi-Tenant Scope Resolution: Evaluated PLATFORM tier binding. No conflicting vendor or branch overrides present.', style: TextStyle(fontSize: 12)),
                  const Gap(6),
                  const Text('2. Health & Circuit Check: CLOSED (healthy). Rolling success rate is 99.98% over last 10,000 executions.', style: TextStyle(fontSize: 12)),
                  const Gap(6),
                  const Text('3. Latency & SLA Match: Average P95 latency is 180ms, well within the 500ms operational budget.', style: TextStyle(fontSize: 12)),
                  const Gap(6),
                  const Text('4. Currency & Regional Compatibility: Region IN & Currency INR matches 100% of transaction criteria.', style: TextStyle(fontSize: 12)),
                  const Gap(6),
                  const Text('5. Dynamic Fallback Chain: Cashfree -> PayU -> Stripe configured in case of transient gateway timeouts.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

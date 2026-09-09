import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

class IntegrationControlPlaneWidget extends ConsumerStatefulWidget {
  const IntegrationControlPlaneWidget({super.key});

  @override
  ConsumerState<IntegrationControlPlaneWidget> createState() =>
      _IntegrationControlPlaneWidgetState();
}

class _IntegrationControlPlaneWidgetState
    extends ConsumerState<IntegrationControlPlaneWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'PAYMENTS';
  String _searchFilter = '';

  // Mock initial state for immediate responsiveness and offline resilience
  final List<Map<String, dynamic>> _providers = [
    {
      'id': 'razorpay',
      'name': 'Razorpay',
      'category': 'PAYMENTS',
      'status': 'ACTIVE',
      'score': 92,
      'reliability': '99.95%',
      'latency': '180ms',
      'pricing': '2.0% + ₹0',
      'certification': 'PRODUCTION_READY',
      'capabilities': ['CREATE_ORDER', 'CAPTURE', 'REFUND', 'UPI', 'SUBSCRIPTIONS', 'WEBHOOK'],
      'regions': ['IN', 'GLOBAL'],
      'currencies': ['INR', 'USD', 'EUR'],
      'circuit': 'CLOSED',
    },
    {
      'id': 'cashfree',
      'name': 'Cashfree Payments',
      'category': 'PAYMENTS',
      'status': 'ACTIVE',
      'score': 94,
      'reliability': '99.92%',
      'latency': '165ms',
      'pricing': '1.9% + ₹0',
      'certification': 'PRODUCTION_READY',
      'capabilities': ['CREATE_ORDER', 'CAPTURE', 'REFUND', 'UPI', 'PAYOUT', 'WEBHOOK'],
      'regions': ['IN'],
      'currencies': ['INR'],
      'circuit': 'CLOSED',
    },
    {
      'id': 'stripe',
      'name': 'Stripe',
      'category': 'PAYMENTS',
      'status': 'ACTIVE',
      'score': 91,
      'reliability': '99.99%',
      'latency': '220ms',
      'pricing': r'2.9% + $0.30',
      'certification': 'PRODUCTION_READY',
      'capabilities': ['CREATE_PAYMENT', 'AUTHORIZE', 'CAPTURE', 'REFUND', 'WEBHOOK'],
      'regions': ['US', 'EU', 'GLOBAL'],
      'currencies': ['USD', 'EUR', 'GBP', 'INR'],
      'circuit': 'CLOSED',
    },
    {
      'id': 'meta_whatsapp',
      'name': 'Meta Cloud WhatsApp',
      'category': 'MESSAGING_WHATSAPP',
      'status': 'ACTIVE',
      'score': 88,
      'reliability': '99.90%',
      'latency': '210ms',
      'pricing': '₹0.75 / conversation',
      'certification': 'PRODUCTION_READY',
      'capabilities': ['SEND_TEXT', 'SEND_TEMPLATE', 'SEND_MEDIA', 'OTP', 'WEBHOOK'],
      'regions': ['GLOBAL'],
      'currencies': ['USD', 'INR'],
      'circuit': 'CLOSED',
    },
    {
      'id': 'gupshup_whatsapp',
      'name': 'Gupshup Enterprise WhatsApp',
      'category': 'MESSAGING_WHATSAPP',
      'status': 'ACTIVE',
      'score': 85,
      'reliability': '99.85%',
      'latency': '240ms',
      'pricing': '₹0.70 / conversation',
      'certification': 'PRODUCTION_READY',
      'capabilities': ['SEND_TEXT', 'SEND_TEMPLATE', 'OTP', 'WEBHOOK'],
      'regions': ['IN', 'GLOBAL'],
      'currencies': ['INR', 'USD'],
      'circuit': 'CLOSED',
    },
    {
      'id': 'surepass_kyc',
      'name': 'Surepass Trust ID',
      'category': 'IDENTITY_VERIFICATION',
      'status': 'ACTIVE',
      'score': 89,
      'reliability': '99.80%',
      'latency': '350ms',
      'pricing': '₹4.50 / verification',
      'certification': 'ENTERPRISE_CERTIFIED',
      'capabilities': ['PAN_VERIFY', 'DL_VERIFY', 'AADHAAR_OTP', 'RC_VERIFY', 'OCR'],
      'regions': ['IN'],
      'currencies': ['INR'],
      'circuit': 'CLOSED',
    },
    {
      'id': 'google_maps',
      'name': 'Google Maps Platform',
      'category': 'MAPS',
      'status': 'ACTIVE',
      'score': 95,
      'reliability': '99.99%',
      'latency': '120ms',
      'pricing': r'$5.00 / 1000 req',
      'certification': 'ENTERPRISE_CERTIFIED',
      'capabilities': ['GEOCODE', 'REVERSE_GEOCODE', 'ROUTE', 'DISTANCE_MATRIX', 'PLACES'],
      'regions': ['GLOBAL'],
      'currencies': ['USD', 'INR'],
      'circuit': 'CLOSED',
    },
  ];

  final List<Map<String, dynamic>> _incidents = [
    {
      'id': 'inc_001',
      'providerId': 'meta_whatsapp',
      'title': 'Elevated delivery latency on template messages',
      'category': 'MESSAGING_WHATSAPP',
      'severity': 'MEDIUM',
      'status': 'INVESTIGATING',
      'detectionSource': 'HEALTH_PROBE',
      'startedAt': '12 mins ago',
      'circuit': 'CLOSED',
      'failureCount': 4,
    },
    {
      'id': 'inc_002',
      'providerId': 'stripe',
      'title': 'Webhook signature validation failure on charge.dispute',
      'category': 'PAYMENTS',
      'severity': 'LOW',
      'status': 'RESOLVED',
      'detectionSource': 'RUNTIME_FAILURE',
      'startedAt': '2 hours ago',
      'circuit': 'CLOSED',
      'failureCount': 1,
      'resolution': 'Re-keyed signing secret in Secret Vault and refreshed webhook listener.',
    },
  ];

  final List<Map<String, dynamic>> _recommendations = [
    {
      'id': 'rec_001',
      'type': 'COST_OPTIMIZATION',
      'category': 'PAYMENTS',
      'target': 'stripe',
      'suggested': 'cashfree',
      'severity': 'MEDIUM',
      'title': 'Shift Domestic INR Checkout to Cashfree',
      'description':
          'Domestic payments on Stripe cost 2.9% + \$0.30 vs 1.9% flat on Cashfree. Switching primary routing for INR volume reduces estimated processing fees by ₹45,000/month.',
      'status': 'PENDING',
      'impact': '₹45,000 / mo savings',
    },
    {
      'id': 'rec_002',
      'type': 'SINGLE_POINT_OF_FAILURE',
      'category': 'MAPS',
      'target': 'google_maps',
      'suggested': 'mapbox_maps',
      'severity': 'HIGH',
      'title': 'Configure Mapbox Secondary Failover Chain',
      'description':
          'Maps routing has no active secondary fallback. If Google Maps experiences an outage, vehicle dispatch and location lookups will halt.',
      'status': 'PENDING',
      'impact': '+99.9% redundancy guarantee',
    },
  ];

  final List<Map<String, dynamic>> _changeAuditLog = [
    {
      'eventId': 'evt_9831',
      'providerId': 'razorpay',
      'type': 'ROUTING_POLICY_CHANGE',
      'actor': 'admin_ops@drivego.in',
      'role': 'SYSTEM_ADMIN',
      'reason': 'Adjusted strategy to SCORE_OPTIMIZED for India market',
      'timestamp': '35 mins ago',
      'diff': 'strategy: PRIORITY -> SCORE_OPTIMIZED',
    },
    {
      'eventId': 'evt_9829',
      'providerId': 'surepass_kyc',
      'type': 'CREDENTIAL_UPDATE',
      'actor': 'compliance_sec@drivego.in',
      'role': 'SECURITY_OFFICER',
      'reason': 'Routine quarterly API key rotation',
      'timestamp': '3 hours ago',
      'diff': 'clientSecret: ***REDACTED*** (Rotated in SecretVault)',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP EXECUTIVE KPI CARDS
          _buildExecutiveKpiBar(theme),
          const Gap(20),

          // 2. CONTROL PLANE SUB-TABS
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Enterprise Directory'),
              Tab(icon: Icon(Icons.analytics_rounded, size: 18), text: 'Multi-Factor Scoring'),
              Tab(icon: Icon(Icons.emergency_rounded, size: 18), text: 'Incident Desk'),
              Tab(icon: Icon(Icons.auto_awesome_rounded, size: 18), text: 'AI & Recommendations'),
              Tab(icon: Icon(Icons.history_edu_rounded, size: 18), text: 'Governance & Change Audit'),
            ],
          ),
          const Gap(16),

          // 3. TAB CONTENT
          SizedBox(
            height: 680,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDirectoryView(theme),
                _buildScoringEngineView(theme),
                _buildIncidentDeskView(theme),
                _buildRecommendationsView(theme),
                _buildGovernanceAuditView(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. EXECUTIVE KPI BAR
  // =========================================================================
  Widget _buildExecutiveKpiBar(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            theme,
            title: 'Directory Ecosystem',
            value: '${_providers.length} Providers',
            subtitle: '50+ Enterprise Categories',
            icon: Icons.hub_rounded,
            color: Colors.blueAccent,
          ),
        ),
        const Gap(12),
        Expanded(
          child: _buildMetricCard(
            theme,
            title: 'Routing Strategy',
            value: 'SCORE_OPTIMIZED',
            subtitle: 'Multi-Factor Deterministic',
            icon: Icons.route_rounded,
            color: Colors.purpleAccent,
          ),
        ),
        const Gap(12),
        Expanded(
          child: _buildMetricCard(
            theme,
            title: 'Active Incidents',
            value: '${_incidents.where((i) => i['status'] != 'RESOLVED').length} Active',
            subtitle: '0 Critical Trips',
            icon: Icons.shield_rounded,
            color: Colors.amber.shade700,
          ),
        ),
        const Gap(12),
        Expanded(
          child: _buildMetricCard(
            theme,
            title: 'Recommendations',
            value: '${_recommendations.where((r) => r['status'] == 'PENDING').length} Pending',
            subtitle: 'Human Approval Boundary',
            icon: Icons.psychology_rounded,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    ThemeData theme, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. DIRECTORY VIEW
  // =========================================================================
  Widget _buildDirectoryView(ThemeData theme) {
    final filtered = _providers.where((p) {
      if (_selectedCategory != 'ALL' && p['category'] != _selectedCategory) {
        return false;
      }
      if (_searchFilter.isNotEmpty) {
        final query = _searchFilter.toLowerCase();
        final nameMatch = (p['name'] as String).toLowerCase().contains(query);
        final idMatch = (p['id'] as String).toLowerCase().contains(query);
        return nameMatch || idMatch;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Category Filter Row
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search provider directory by name, ID, capability...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchFilter = val),
              ),
            ),
            const Gap(16),
            DropdownButton<String>(
              value: _selectedCategory,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
                DropdownMenuItem(value: 'PAYMENTS', child: Text('Payments')),
                DropdownMenuItem(value: 'MESSAGING_WHATSAPP', child: Text('WhatsApp')),
                DropdownMenuItem(value: 'IDENTITY_VERIFICATION', child: Text('KYC Trust')),
                DropdownMenuItem(value: 'MAPS', child: Text('Maps & Geo')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
          ],
        ),
        const Gap(16),

        // Providers List
        Expanded(
          child: ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Gap(12),
            itemBuilder: (context, idx) {
              final p = filtered[idx];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          p['name'][0],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const Gap(16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  p['name'],
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Gap(8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    p['certification'],
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Score: ${p['score']}/100',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Gap(6),
                            Text(
                              'Reliability: ${p['reliability']}  •  Latency p50: ${p['latency']}  •  Pricing: ${p['pricing']}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const Gap(10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: (p['capabilities'] as List<String>)
                                  .map(
                                    (c) => Chip(
                                      label: Text(c, style: const TextStyle(fontSize: 10)),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 3. MULTI-FACTOR SCORING ENGINE VIEW
  // =========================================================================
  Widget _buildScoringEngineView(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deterministic Scoring Formula',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Gap(4),
                Text(
                  'Final Score = (Health*0.25) + (Reliability*0.20) + (Latency*0.15) + (CapabilityMatch*0.15) + (Region*0.10) + (Cost*0.05) + (Priority*0.10) - (Circuit & Degradation Penalties)',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),

          // Provider Score Cards
          ..._providers.where((p) => p['category'] == 'PAYMENTS').map((p) {
            final score = p['score'] as int;
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          p['name'],
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$score / 100',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: score >= 90 ? Colors.green : Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    LinearProgressIndicator(
                      value: score / 100,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        score >= 90 ? Colors.green : Colors.amber.shade700,
                      ),
                    ),
                    const Gap(12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildFactorBadge('Health', '100%'),
                        _buildFactorBadge('Reliability', p['reliability']),
                        _buildFactorBadge('Latency', p['latency']),
                        _buildFactorBadge('Cost Index', '95/100'),
                        _buildFactorBadge('Circuit', p['circuit']),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFactorBadge(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const Gap(2),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // =========================================================================
  // 4. INCIDENT DESK VIEW
  // =========================================================================
  Widget _buildIncidentDeskView(ThemeData theme) {
    return ListView.separated(
      itemCount: _incidents.length,
      separatorBuilder: (_, __) => const Gap(12),
      itemBuilder: (context, idx) {
        final inc = _incidents[idx];
        final isResolved = inc['status'] == 'RESOLVED';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isResolved
                  ? theme.colorScheme.outlineVariant.withOpacity(0.3)
                  : Colors.amber.shade300,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isResolved
                            ? Colors.green.withOpacity(0.12)
                            : Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        inc['status'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isResolved ? Colors.green : Colors.amber.shade800,
                        ),
                      ),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        inc['severity'],
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      inc['startedAt'],
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  inc['title'],
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Gap(4),
                Text(
                  'Provider: ${inc['providerId']}  •  Detection: ${inc['detectionSource']}  •  Failures: ${inc['failureCount']}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                if (inc['resolution'] != null) ...[
                  const Gap(8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Resolution: ${inc['resolution']}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
                ],
                if (!isResolved) ...[
                  const Gap(12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            inc['status'] = 'INVESTIGATING';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Incident acknowledged')),
                          );
                        },
                        child: const Text('Acknowledge'),
                      ),
                      const Gap(8),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            inc['status'] = 'RESOLVED';
                            inc['resolution'] = 'Resolved via operator control console.';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Incident resolved')),
                          );
                        },
                        child: const Text('Resolve Incident'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // 5. RECOMMENDATIONS & AUTOMATION BOUNDARIES VIEW
  // =========================================================================
  Widget _buildRecommendationsView(ThemeData theme) {
    return ListView.separated(
      itemCount: _recommendations.length,
      separatorBuilder: (_, __) => const Gap(12),
      itemBuilder: (context, idx) {
        final rec = _recommendations[idx];
        final isPending = rec['status'] == 'PENDING';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isPending ? theme.colorScheme.primary.withOpacity(0.4) : Colors.grey.shade300,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      rec['type'] == 'COST_OPTIMIZATION'
                          ? Icons.savings_rounded
                          : Icons.warning_amber_rounded,
                      color: rec['type'] == 'COST_OPTIMIZATION' ? Colors.teal : Colors.amber.shade800,
                    ),
                    const Gap(8),
                    Text(
                      rec['title'],
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rec['impact'],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  rec['description'],
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                if (isPending) ...[
                  const Gap(14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            rec['status'] = 'DISMISSED';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Recommendation dismissed')),
                          );
                        },
                        child: const Text('Dismiss'),
                      ),
                      const Gap(8),
                      FilledButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve & Apply'),
                        onPressed: () {
                          setState(() {
                            rec['status'] = 'APPROVED';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recommendation approved! Routing updated safely.'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // 6. GOVERNANCE & CHANGE AUDIT VIEW
  // =========================================================================
  Widget _buildGovernanceAuditView(ThemeData theme) {
    return ListView.separated(
      itemCount: _changeAuditLog.length,
      separatorBuilder: (_, __) => const Gap(10),
      itemBuilder: (context, idx) {
        final evt = _changeAuditLog[idx];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_clock_rounded, color: Colors.indigo, size: 20),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${evt['type']} on ${evt['providerId']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            evt['timestamp'],
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const Gap(4),
                      Text(
                        'Actor: ${evt['actor']} (${evt['role']})',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                      ),
                      const Gap(4),
                      Text(
                        'Reason: ${evt['reason']}',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      ),
                      const Gap(6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          evt['diff'],
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

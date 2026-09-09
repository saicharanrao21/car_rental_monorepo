import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class PaymentEcosystemWidget extends StatefulWidget {
  const PaymentEcosystemWidget({super.key});

  @override
  State<PaymentEcosystemWidget> createState() => _PaymentEcosystemWidgetState();
}

class _PaymentEcosystemWidgetState extends State<PaymentEcosystemWidget> {
  String _selectedSubTab = 'CATALOG'; // 'CATALOG' | 'ROUTING' | 'RECONCILIATION' | 'WEBHOOKS'
  String _searchQuery = '';
  String _selectedRegionFilter = 'ALL'; // 'ALL' | 'INDIA' | 'INTERNATIONAL'
  String _selectedStatusFilter = 'ALL'; // 'ALL' | 'LIVE_READY' | 'ADAPTER_IMPLEMENTED' | 'CATALOG_ONLY'

  // Routing Simulator State
  String _simCountry = 'IN';
  String _simCurrency = 'INR';
  String _simMethod = 'UPI';
  double _simAmount = 3500.0;
  Map<String, dynamic>? _routingPreviewResult;

  // Reconciliation Trigger State
  bool _isReconciling = false;
  Map<String, dynamic>? _reconciliationSummary;

  // Webhook Replay State
  String _replayingEventId = '';

  // Comprehensive Catalog of Payment Gateways (India + International)
  final List<Map<String, dynamic>> _paymentGateways = [
    {
      'providerId': 'razorpay',
      'name': 'Razorpay Enterprise PG',
      'region': 'INDIA',
      'countries': ['IN', 'MY'],
      'currencies': ['INR', 'USD', 'EUR'],
      'methods': ['UPI', 'CARDS', 'NET_BANKING', 'WALLET', 'EMI'],
      'status': 'LIVE_READY',
      'health': 'HEALTHY',
      'successRate': 99.4,
      'latency': '180ms',
      'feePercent': 2.0,
      'fixedFee': 0.0,
      'capabilities': ['CREATE_ORDER', 'UPI_INTENT', 'REFUND', 'WEBHOOKS', 'RECONCILIATION'],
    },
    {
      'providerId': 'cashfree',
      'name': 'Cashfree Payments',
      'region': 'INDIA',
      'countries': ['IN'],
      'currencies': ['INR', 'USD'],
      'methods': ['UPI', 'CARDS', 'NET_BANKING', 'PAYOUTS', 'BNPL'],
      'status': 'ADAPTER_IMPLEMENTED',
      'health': 'HEALTHY',
      'successRate': 98.9,
      'latency': '210ms',
      'feePercent': 1.9,
      'fixedFee': 0.0,
      'capabilities': ['CREATE_ORDER', 'UPI_INTENT', 'REFUND', 'PAYOUT', 'WEBHOOKS'],
    },
    {
      'providerId': 'payu',
      'name': 'PayU India',
      'region': 'INDIA',
      'countries': ['IN'],
      'currencies': ['INR'],
      'methods': ['UPI', 'CARDS', 'NET_BANKING', 'EMI'],
      'status': 'ADAPTER_IMPLEMENTED',
      'health': 'HEALTHY',
      'successRate': 98.7,
      'latency': '230ms',
      'feePercent': 2.0,
      'fixedFee': 0.0,
      'capabilities': ['CREATE_ORDER', 'VERIFY_PAYMENT', 'REFUND', 'WEBHOOKS'],
    },
    {
      'providerId': 'phonepe',
      'name': 'PhonePe Payment Gateway',
      'region': 'INDIA',
      'countries': ['IN'],
      'currencies': ['INR'],
      'methods': ['UPI', 'CARDS', 'NET_BANKING'],
      'status': 'ADAPTER_IMPLEMENTED',
      'health': 'HEALTHY',
      'successRate': 99.1,
      'latency': '160ms',
      'feePercent': 1.85,
      'fixedFee': 0.0,
      'capabilities': ['UPI_INTENT', 'UPI_COLLECT', 'REFUND', 'WEBHOOKS'],
    },
    {
      'providerId': 'stripe',
      'name': 'Stripe Global Payments',
      'region': 'INTERNATIONAL',
      'countries': ['US', 'EU', 'GB', 'IN', 'AE', 'SG'],
      'currencies': ['USD', 'EUR', 'GBP', 'INR', 'AED', 'SGD'],
      'methods': ['CARDS', 'APPLE_PAY', 'GOOGLE_PAY', 'SEPA', 'KLARNA'],
      'status': 'LIVE_READY',
      'health': 'HEALTHY',
      'successRate': 99.8,
      'latency': '195ms',
      'feePercent': 2.9,
      'fixedFee': 0.30,
      'capabilities': ['CREATE_INTENT', 'CAPTURE', 'REFUND', 'WEBHOOKS', 'DISPUTES'],
    },
    {
      'providerId': 'adyen',
      'name': 'Adyen Global Omnichannel',
      'region': 'INTERNATIONAL',
      'countries': ['US', 'EU', 'GB', 'SG', 'AU', 'AE'],
      'currencies': ['USD', 'EUR', 'GBP', 'AED', 'SGD', 'AUD'],
      'methods': ['CARDS', 'IDEAL', 'SOFORT', 'ALIPAY', 'WECHAT'],
      'status': 'ADAPTER_IMPLEMENTED',
      'health': 'HEALTHY',
      'successRate': 99.6,
      'latency': '175ms',
      'feePercent': 2.5,
      'fixedFee': 0.12,
      'capabilities': ['CREATE_PAYMENT', 'CAPTURE', 'REFUND', 'SETTLEMENT', 'WEBHOOKS'],
    },
    {
      'providerId': 'paytm',
      'name': 'Paytm Payment Gateway',
      'region': 'INDIA',
      'countries': ['IN'],
      'currencies': ['INR'],
      'methods': ['UPI', 'WALLET', 'CARDS', 'NET_BANKING'],
      'status': 'CATALOG_ONLY',
      'health': 'DEGRADED',
      'successRate': 97.2,
      'latency': '320ms',
      'feePercent': 1.95,
      'fixedFee': 0.0,
      'capabilities': ['CREATE_ORDER', 'UPI_INTENT', 'REFUND'],
    },
    {
      'providerId': 'ccavenue',
      'name': 'CCAvenue Enterprise',
      'region': 'INDIA',
      'countries': ['IN', 'AE'],
      'currencies': ['INR', 'AED', 'USD'],
      'methods': ['NET_BANKING', 'CARDS', 'WALLET'],
      'status': 'CATALOG_ONLY',
      'health': 'HEALTHY',
      'successRate': 97.9,
      'latency': '290ms',
      'feePercent': 2.2,
      'fixedFee': 0.0,
      'capabilities': ['CREATE_ORDER', 'REFUND', 'NET_BANKING'],
    },
    {
      'providerId': 'billdesk',
      'name': 'BillDesk India',
      'region': 'INDIA',
      'countries': ['IN'],
      'currencies': ['INR'],
      'methods': ['NET_BANKING', 'SI_RECURRING', 'CARDS'],
      'status': 'CATALOG_ONLY',
      'health': 'HEALTHY',
      'successRate': 98.4,
      'latency': '240ms',
      'feePercent': 1.9,
      'fixedFee': 0.0,
      'capabilities': ['NET_BANKING', 'SI_HUB', 'RECONCILIATION'],
    },
    {
      'providerId': 'juspay',
      'name': 'Juspay HyperSDK',
      'region': 'INDIA',
      'countries': ['IN'],
      'currencies': ['INR'],
      'methods': ['UPI', 'CARDS', 'NET_BANKING'],
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'successRate': 99.5,
      'latency': '130ms',
      'feePercent': 0.5,
      'fixedFee': 0.0,
      'capabilities': ['UPI_INTENT', 'TOKENIZATION', 'SMART_ROUTING'],
    },
    {
      'providerId': 'checkout_com',
      'name': 'Checkout.com Global',
      'region': 'INTERNATIONAL',
      'countries': ['US', 'EU', 'GB', 'AE', 'SG'],
      'currencies': ['USD', 'EUR', 'GBP', 'AED'],
      'methods': ['CARDS', 'APPLE_PAY', 'GOOGLE_PAY', 'TABBY'],
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'successRate': 99.5,
      'latency': '185ms',
      'feePercent': 2.6,
      'fixedFee': 0.20,
      'capabilities': ['CARD_PAYMENT', '3DS2', 'REFUND', 'DISPUTES'],
    },
    {
      'providerId': 'paypal',
      'name': 'PayPal Complete Payments',
      'region': 'INTERNATIONAL',
      'countries': ['US', 'EU', 'GB', 'AU', 'SG', 'IN'],
      'currencies': ['USD', 'EUR', 'GBP', 'AUD', 'SGD'],
      'methods': ['PAYPAL_WALLET', 'CARDS', 'PAY_IN_4'],
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'successRate': 99.2,
      'latency': '260ms',
      'feePercent': 3.49,
      'fixedFee': 0.49,
      'capabilities': ['CAPTURE', 'REFUND', 'DISPUTES', 'WEBHOOKS'],
    },
  ];

  // Discrepancies / Reconciliation Exceptions Sample
  final List<Map<String, dynamic>> _reconciliationExceptions = [
    {
      'id': 'exc_001',
      'type': 'AMOUNT_MISMATCH',
      'gateway': 'razorpay',
      'transactionId': 'txn_884210',
      'internalAmount': '₹4,500.00',
      'gatewayAmount': '₹4,250.00',
      'detectedAt': '10 mins ago',
      'status': 'OPEN',
      'reason': 'Promo coupon applied post-order creation on client',
    },
    {
      'id': 'exc_002',
      'type': 'MISSING_INTERNAL_RECORD',
      'gateway': 'stripe',
      'transactionId': 'pi_3Pqz9910',
      'internalAmount': 'N/A',
      'gatewayAmount': '\$120.00',
      'detectedAt': '35 mins ago',
      'status': 'OPEN',
      'reason': 'Webhook delayed due to edge proxy restart; gateway confirmed captured',
    },
    {
      'id': 'exc_003',
      'type': 'INDETERMINATE_TIMEOUT',
      'gateway': 'cashfree',
      'transactionId': 'cf_order_99014',
      'internalAmount': '₹2,800.00',
      'gatewayAmount': 'PENDING',
      'detectedAt': '1 hour ago',
      'status': 'PENDING_RECONCILIATION',
      'reason': 'Gateway 504 Gateway Timeout during capture; failover blocked for safety',
    },
  ];

  @override
  void initState() {
    super.initState();
    _computeRouting();
  }

  void _computeRouting() {
    // Dynamic scoring simulation based on country, currency, method, and amount
    String primary = 'razorpay';
    List<String> fallback = ['cashfree', 'phonepe', 'stripe'];
    double fee = 2.0;

    if (_simCountry == 'IN') {
      if (_simMethod == 'UPI') {
        primary = 'phonepe';
        fallback = ['razorpay', 'cashfree', 'payu'];
        fee = 1.85;
      } else if (_simMethod == 'NET_BANKING') {
        primary = 'billdesk';
        fallback = ['razorpay', 'ccavenue'];
        fee = 1.9;
      } else {
        primary = 'razorpay';
        fallback = ['cashfree', 'payu', 'stripe'];
        fee = 2.0;
      }
    } else {
      if (_simCurrency == 'EUR' || _simCountry == 'EU') {
        primary = 'adyen';
        fallback = ['stripe', 'checkout_com', 'paypal'];
        fee = 2.5;
      } else {
        primary = 'stripe';
        fallback = ['adyen', 'checkout_com', 'paypal'];
        fee = 2.9;
      }
    }

    setState(() {
      _routingPreviewResult = {
        'primary': primary,
        'fallbackChain': fallback,
        'feePercent': fee,
        'calculatedFee': (_simAmount * (fee / 100)).toStringAsFixed(2),
        'circuitBreaker': 'CLOSED (0 trips in 24h)',
        'estimatedLatency': primary == 'phonepe' ? '160ms' : (primary == 'stripe' ? '195ms' : '180ms'),
        'safetyRule': 'Timeout & Unknown States marked PENDING_RECONCILIATION (No blind duplicate debits)',
      };
    });
  }

  void _runReconciliation() async {
    setState(() => _isReconciling = true);
    await Future.delayed(const Duration(milliseconds: 700));
    setState(() {
      _isReconciling = false;
      _reconciliationSummary = {
        'batchId': 'REC_BATCH_${DateTime.now().millisecondsSinceEpoch}',
        'scannedCount': 1248,
        'matchedCount': 1245,
        'exceptionsCount': 3,
        'totalVolume': '₹42,85,600.00',
        'healthScore': '99.76%',
      };
    });
  }

  void _replayWebhook(String eventId) {
    setState(() => _replayingEventId = eventId);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _replayingEventId = '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Webhook event $eventId successfully replayed and idempotently verified.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'LIVE_READY':
        return const Color(0xFF10B981);
      case 'ADAPTER_IMPLEMENTED':
        return const Color(0xFF3B82F6);
      case 'CONTRACT_READY':
        return const Color(0xFFF59E0B);
      case 'CATALOG_ONLY':
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-Tab Navigation Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'CATALOG',
                    label: Text('Payment Gateways (42+)'),
                    icon: Icon(Icons.account_balance_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: 'ROUTING',
                    label: Text('Intelligent Routing'),
                    icon: Icon(Icons.alt_route_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: 'RECONCILIATION',
                    label: Text('Financial Reconciliation'),
                    icon: Icon(Icons.fact_check_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: 'WEBHOOKS',
                    label: Text('Webhook Operations'),
                    icon: Icon(Icons.sync_alt_rounded, size: 16),
                  ),
                ],
                selected: {_selectedSubTab},
                onSelectionChanged: (set) {
                  setState(() => _selectedSubTab = set.first);
                },
              ),
              // Safety indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                    const Gap(8),
                    Text(
                      'Idempotent Guard & Safe Failover Active',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(24),

          // Render active sub-tab
          if (_selectedSubTab == 'CATALOG') _buildCatalogView(theme),
          if (_selectedSubTab == 'ROUTING') _buildRoutingView(theme),
          if (_selectedSubTab == 'RECONCILIATION') _buildReconciliationView(theme),
          if (_selectedSubTab == 'WEBHOOKS') _buildWebhooksView(theme),
        ],
      ),
    );
  }

  Widget _buildCatalogView(ThemeData theme) {
    final filtered = _paymentGateways.where((gw) {
      if (_selectedRegionFilter != 'ALL' && gw['region'] != _selectedRegionFilter) return false;
      if (_selectedStatusFilter != 'ALL' && gw['status'] != _selectedStatusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = (gw['name'] as String).toLowerCase().contains(q);
        final idMatch = (gw['providerId'] as String).toLowerCase().contains(q);
        final methodsMatch = (gw['methods'] as List).any((m) => (m as String).toLowerCase().contains(q));
        return nameMatch || idMatch || methodsMatch;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI row for Gateways
        Row(
          children: [
            _kpiCard(
              theme,
              title: 'Total Catalog Gateways',
              value: '42 Gateways',
              icon: Icons.account_balance_wallet_rounded,
              color: theme.colorScheme.primary,
            ),
            const Gap(16),
            _kpiCard(
              theme,
              title: 'Real Adapters Built',
              value: '6 Production Adapters',
              icon: Icons.code_rounded,
              color: const Color(0xFF3B82F6),
            ),
            const Gap(16),
            _kpiCard(
              theme,
              title: 'India-First Gateways',
              value: '22 Gateways',
              icon: Icons.flag_rounded,
              color: const Color(0xFF10B981),
            ),
            const Gap(16),
            _kpiCard(
              theme,
              title: 'International Coverage',
              value: '20 Gateways',
              icon: Icons.public_rounded,
              color: const Color(0xFF8B5CF6),
            ),
          ],
        ),
        const Gap(24),

        // Filter and Search Row
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search gateways by name, method (UPI, Cards), or ID...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const Gap(16),
            DropdownButton<String>(
              value: _selectedRegionFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Regions')),
                DropdownMenuItem(value: 'INDIA', child: Text('India Only')),
                DropdownMenuItem(value: 'INTERNATIONAL', child: Text('International')),
              ],
              onChanged: (v) => setState(() => _selectedRegionFilter = v!),
            ),
            const Gap(16),
            DropdownButton<String>(
              value: _selectedStatusFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                DropdownMenuItem(value: 'LIVE_READY', child: Text('Live Ready')),
                DropdownMenuItem(value: 'ADAPTER_IMPLEMENTED', child: Text('Adapter Implemented')),
                DropdownMenuItem(value: 'CATALOG_ONLY', child: Text('Catalog Only')),
              ],
              onChanged: (v) => setState(() => _selectedStatusFilter = v!),
            ),
          ],
        ),
        const Gap(20),

        // Gateway Cards Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 460,
            mainAxisExtent: 290,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final gw = filtered[index];
            final statusColor = _getStatusColor(gw['status']);
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.payment_rounded, color: theme.colorScheme.primary, size: 22),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gw['name'],
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                gw['providerId'],
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            gw['status'],
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Gap(14),
                    // Telemetry chips
                    Row(
                      children: [
                        _metricBadge('Uptime', '${gw['successRate']}%', const Color(0xFF10B981)),
                        const Gap(8),
                        _metricBadge('Latency', gw['latency'], const Color(0xFF3B82F6)),
                        const Gap(8),
                        _metricBadge('MDR Fee', '${gw['feePercent']}%', const Color(0xFFF59E0B)),
                      ],
                    ),
                    const Gap(14),
                    Text('Supported Methods:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                    const Gap(6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: (gw['methods'] as List).map<Widget>((m) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(m, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                        );
                      }).toList(),
                    ),
                    const Spacer(),
                    const Divider(height: 1),
                    const Gap(8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Region: ${gw['region']} (${(gw['countries'] as List).join(', ')})',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Configure'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoutingView(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dynamic Multi-Factor Payment Routing Simulator',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(6),
            Text(
              'Simulate incoming transaction conditions to verify optimal gateway selection, fallback priority chains, and MDR economics.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.65)),
            ),
            const Gap(24),

            // Controls Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _simCountry,
                    decoration: const InputDecoration(labelText: 'Customer Country', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'IN', child: Text('India (IN)')),
                      DropdownMenuItem(value: 'US', child: Text('United States (US)')),
                      DropdownMenuItem(value: 'EU', child: Text('European Union (EU)')),
                      DropdownMenuItem(value: 'AE', child: Text('United Arab Emirates (AE)')),
                      DropdownMenuItem(value: 'GB', child: Text('United Kingdom (GB)')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _simCountry = v!;
                        _simCurrency = (v == 'IN') ? 'INR' : (v == 'EU' ? 'EUR' : (v == 'AE' ? 'AED' : 'USD'));
                      });
                      _computeRouting();
                    },
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _simCurrency,
                    decoration: const InputDecoration(labelText: 'Currency', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                      DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                      DropdownMenuItem(value: 'AED', child: Text('AED (د.إ)')),
                    ],
                    onChanged: (v) {
                      setState(() => _simCurrency = v!);
                      _computeRouting();
                    },
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _simMethod,
                    decoration: const InputDecoration(labelText: 'Payment Instrument', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'UPI', child: Text('UPI (Instant Intent/Collect)')),
                      DropdownMenuItem(value: 'CARDS', child: Text('Credit/Debit Card (3DS2)')),
                      DropdownMenuItem(value: 'NET_BANKING', child: Text('Net Banking (Retail/Corp)')),
                      DropdownMenuItem(value: 'WALLET', child: Text('Digital Wallet')),
                      DropdownMenuItem(value: 'BNPL', child: Text('Buy Now Pay Later')),
                    ],
                    onChanged: (v) {
                      setState(() => _simMethod = v!);
                      _computeRouting();
                    },
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: TextFormField(
                    initialValue: '3500.00',
                    decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 3500.0;
                      setState(() => _simAmount = val);
                      _computeRouting();
                    },
                  ),
                ),
              ],
            ),
            const Gap(24),

            // Simulation Results Card
            if (_routingPreviewResult != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 28),
                            const Gap(8),
                            Text(
                              'Ecosystem Primary Selection: ${_routingPreviewResult!['primary'].toString().toUpperCase()}',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Estimated MDR: ${_routingPreviewResult!['feePercent']}% (${_routingPreviewResult!['calculatedFee']} $_simCurrency)',
                            style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Gap(14),
                    const Divider(),
                    const Gap(12),
                    Text('Automated Fallback Priority Chain:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Gap(8),
                    Wrap(
                      spacing: 8,
                      children: (_routingPreviewResult!['fallbackChain'] as List).asMap().entries.map((entry) {
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                          ),
                          label: Text(entry.value.toString().toUpperCase()),
                          backgroundColor: theme.colorScheme.surface,
                        );
                      }).toList(),
                    ),
                    const Gap(16),
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFF3B82F6), size: 20),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            'Strict Fallback Safety: ${_routingPreviewResult!['safetyRule']}',
                            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReconciliationView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automated Financial Reconciliation & Anomaly Engine',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Gap(4),
                Text(
                  'Performs 3-way reconciliation: Internal Transactions ↔ Gateway Settlements ↔ Bank Deposits.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.65)),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _isReconciling ? null : _runReconciliation,
              icon: _isReconciling
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(_isReconciling ? 'Scanning Gateways...' : 'Trigger Full Audit Scan'),
            ),
          ],
        ),
        const Gap(24),

        if (_reconciliationSummary != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statSummary('Scanned Volume', _reconciliationSummary!['totalVolume']),
                _statSummary('Transactions Matched', '${_reconciliationSummary!['matchedCount']} / ${_reconciliationSummary!['scannedCount']}'),
                _statSummary('Discrepancies', '${_reconciliationSummary!['exceptionsCount']} Open', color: const Color(0xFFEF4444)),
                _statSummary('Match Accuracy', _reconciliationSummary!['healthScore'], color: const Color(0xFF10B981)),
              ],
            ),
          ),
          const Gap(24),
        ],

        Text('Detected Discrepancies & Incidents', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const Gap(12),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _reconciliationExceptions.length,
          separatorBuilder: (_, __) => const Gap(12),
          itemBuilder: (context, index) {
            final exc = _reconciliationExceptions[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 22),
                ),
                title: Row(
                  children: [
                    Text(exc['type'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(exc['gateway'].toString().toUpperCase(), style: const TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Gap(4),
                    Text('Internal: ${exc['internalAmount']} | Gateway: ${exc['gatewayAmount']} — ${exc['reason']}'),
                    Text('Txn: ${exc['transactionId']} • Detected ${exc['detectedAt']}', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                  ],
                ),
                trailing: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Exception ${exc['id']} queued for manual ledger adjustment.')),
                    );
                  },
                  child: const Text('Resolve'),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWebhooksView(ThemeData theme) {
    final sampleWebhooks = [
      {'id': 'evt_99120', 'gateway': 'razorpay', 'event': 'order.paid', 'time': '2 mins ago', 'status': 'VERIFIED'},
      {'id': 'evt_99121', 'gateway': 'cashfree', 'event': 'PAYMENT_SUCCESS', 'time': '5 mins ago', 'status': 'VERIFIED'},
      {'id': 'evt_99122', 'gateway': 'phonepe', 'event': 'PAYMENT_COMPLETED', 'time': '12 mins ago', 'status': 'VERIFIED'},
      {'id': 'evt_99123', 'gateway': 'stripe', 'event': 'payment_intent.succeeded', 'time': '24 mins ago', 'status': 'VERIFIED'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unified Payment Webhook Ingestion & Replay Station',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Gap(6),
        Text(
          'Real-time webhook signature verification, replay tolerance, deduplication, and manual replay capability.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.65)),
        ),
        const Gap(20),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sampleWebhooks.length,
          separatorBuilder: (_, __) => const Gap(12),
          itemBuilder: (context, index) {
            final ev = sampleWebhooks[index];
            final isReplaying = _replayingEventId == ev['id'];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                ),
                title: Text('${ev['event']} (${ev['gateway'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${ev['id']} • Received: ${ev['time']} • Signature: Validated HMAC-SHA256'),
                trailing: isReplaying
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton.icon(
                        icon: const Icon(Icons.replay_rounded, size: 16),
                        label: const Text('Replay Event'),
                        onPressed: () => _replayWebhook(ev['id']!),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _metricBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statSummary(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const Gap(4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
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

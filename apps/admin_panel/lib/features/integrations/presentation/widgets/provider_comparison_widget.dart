import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProviderComparisonWidget extends StatefulWidget {
  const ProviderComparisonWidget({super.key});

  @override
  State<ProviderComparisonWidget> createState() => _ProviderComparisonWidgetState();
}

class _ProviderComparisonWidgetState extends State<ProviderComparisonWidget> {
  final List<Map<String, dynamic>> _paymentProviders = [
    {
      'providerId': 'razorpay',
      'name': 'Razorpay',
      'certification': 'PRODUCTION_VALIDATED',
      'lifecycle': 'LIVE_READY',
      'adapterImplemented': true,
      'latencyP50': '24ms',
      'successRate': '99.8%',
      'pricing': '2.0% + ₹0',
      'capabilities': ['UPI Intent', 'Cards', 'Netbanking', 'Instant Refund', 'Mandates'],
      'countries': ['IN', 'AE', 'SG'],
      'currencies': ['INR', 'USD', 'AED'],
      'sla': '99.95%',
      'color': const Color(0xFF2563EB),
    },
    {
      'providerId': 'stripe',
      'name': 'Stripe',
      'certification': 'PRODUCTION_VALIDATED',
      'lifecycle': 'LIVE_READY',
      'adapterImplemented': true,
      'latencyP50': '32ms',
      'successRate': '99.9%',
      'pricing': '2.9% + \$0.30',
      'capabilities': ['Global Cards', 'Apple Pay', 'Google Pay', 'Dispute Guard', 'Vaulting'],
      'countries': ['US', 'GB', 'EU', 'AE', 'IN'],
      'currencies': ['USD', 'EUR', 'GBP', 'AED'],
      'sla': '99.99%',
      'color': const Color(0xFF6366F1),
    },
    {
      'providerId': 'cashfree',
      'name': 'Cashfree Payments',
      'certification': 'SANDBOX_VALIDATED',
      'lifecycle': 'SANDBOX_READY',
      'adapterImplemented': false,
      'latencyP50': '28ms',
      'successRate': '99.4%',
      'pricing': '1.9% + ₹0',
      'capabilities': ['UPI Autopay', 'Instant Payouts', 'Split Settlement', 'Sub-accounts'],
      'countries': ['IN'],
      'currencies': ['INR'],
      'sla': '99.90%',
      'color': const Color(0xFF059669),
    },
    {
      'providerId': 'phonepe',
      'name': 'PhonePe Gateway',
      'certification': 'CATALOG',
      'lifecycle': 'CONFIGURABLE',
      'adapterImplemented': false,
      'latencyP50': '22ms',
      'successRate': '99.7%',
      'pricing': '1.85% + ₹0',
      'capabilities': ['Direct UPI App Switch', 'PhonePe QR', 'Fast Checkout'],
      'countries': ['IN'],
      'currencies': ['INR'],
      'sla': '99.85%',
      'color': const Color(0xFF7C3AED),
    },
    {
      'providerId': 'adyen',
      'name': 'Adyen Global',
      'certification': 'CATALOG',
      'lifecycle': 'CONFIGURABLE',
      'adapterImplemented': false,
      'latencyP50': '35ms',
      'successRate': '99.9%',
      'pricing': '2.1% + €0.15',
      'capabilities': ['3DS2 Direct', 'Omni-channel POS', 'Cross-border Acquiring'],
      'countries': ['US', 'GB', 'EU', 'AE', 'SG'],
      'currencies': ['USD', 'EUR', 'GBP', 'AED'],
      'sla': '99.99%',
      'color': const Color(0xFF0D9488),
    },
    {
      'providerId': 'ccavenue',
      'name': 'CCAvenue',
      'certification': 'CATALOG',
      'lifecycle': 'CONFIGURABLE',
      'adapterImplemented': false,
      'latencyP50': '45ms',
      'successRate': '99.2%',
      'pricing': '1.95% + ₹0',
      'capabilities': ['55+ Bank Netbanking', '200+ Payment Options', 'Multi-currency'],
      'countries': ['IN', 'AE'],
      'currencies': ['INR', 'USD', 'AED'],
      'sla': '99.85%',
      'color': const Color(0xFFD97706),
    },
  ];

  Color _getCertificationColor(String cert) {
    switch (cert) {
      case 'PRODUCTION_VALIDATED':
        return const Color(0xFF10B981); // Emerald
      case 'SANDBOX_VALIDATED':
        return const Color(0xFF3B82F6); // Blue
      case 'CONTRACT_VALIDATED':
        return const Color(0xFF8B5CF6); // Purple
      default:
        return const Color(0xFF6B7280); // Gray
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
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer.withOpacity(0.4),
                  theme.colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.compare_arrows_rounded, color: theme.colorScheme.primary, size: 28),
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enterprise Provider Comparison & Certification Plane',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Gap(4),
                      Text(
                        'Compare latencies, certification levels, pricing economics, and supported payment rails side-by-side.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(24),

          // Comparison Table Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Gateways Comparison Matrix (${_paymentProviders.length} Providers)',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Gap(16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      ),
                      columnSpacing: 28,
                      columns: const [
                        DataColumn(label: Text('Provider', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Certification', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Adapter Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('p50 Latency', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Success Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Economics', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Supported Rails', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Regions', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('SLA', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _paymentProviders.map((p) {
                        final certColor = _getCertificationColor(p['certification']);
                        final isImplemented = p['adapterImplemented'] as bool;

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: (p['color'] as Color).withOpacity(0.2),
                                    child: Icon(Icons.credit_card_rounded, size: 14, color: p['color']),
                                  ),
                                  const Gap(8),
                                  Text(
                                    p['name'],
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: certColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: certColor.withOpacity(0.4)),
                                ),
                                child: Text(
                                  p['certification'],
                                  style: TextStyle(
                                    color: certColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  Icon(
                                    isImplemented ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                    size: 16,
                                    color: isImplemented ? Colors.green : Colors.grey,
                                  ),
                                  const Gap(6),
                                  Text(isImplemented ? 'Live Adapter' : 'Catalog Metadata'),
                                ],
                              ),
                            ),
                            DataCell(Text(p['latencyP50'])),
                            DataCell(Text(p['successRate'])),
                            DataCell(Text(p['pricing'])),
                            DataCell(
                              Wrap(
                                spacing: 4,
                                children: (p['capabilities'] as List<String>)
                                    .take(3)
                                    .map((cap) => Chip(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          label: Text(cap, style: const TextStyle(fontSize: 10)),
                                        ))
                                    .toList(),
                              ),
                            ),
                            DataCell(Text((p['countries'] as List<String>).join(', '))),
                            DataCell(Text(p['sla'])),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

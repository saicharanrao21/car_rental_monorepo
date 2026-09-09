import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class RuntimeCommandCentreWidget extends StatefulWidget {
  const RuntimeCommandCentreWidget({super.key});

  @override
  State<RuntimeCommandCentreWidget> createState() => _RuntimeCommandCentreWidgetState();
}

class _RuntimeCommandCentreWidgetState extends State<RuntimeCommandCentreWidget> {
  String _selectedCategory = 'PAYMENT';
  String _selectedProviderForSim = 'razorpay';
  String _selectedScenario = 'TIMEOUT';
  bool _isSimulating = false;
  Map<String, dynamic>? _lastSimulationResult;

  // Mocked runtime operational state for command centre view
  final Map<String, String> _circuitStates = {
    'razorpay': 'CLOSED',
    'stripe': 'CLOSED',
    'cashfree': 'CLOSED',
    'mock_payment': 'CLOSED',
    'meta_whatsapp': 'CLOSED',
    'gupshup_whatsapp': 'HALF_OPEN',
    'twilio_sms': 'CLOSED',
    'msg91_sms': 'CLOSED',
    'cloudflare_r2': 'CLOSED',
    'aws_s3': 'CLOSED',
    'google_maps': 'CLOSED',
    'surepass_kyc': 'CLOSED',
  };

  final Map<String, Map<String, dynamic>> _healthMetrics = {
    'razorpay': {'successRate': 99.4, 'p50': 180, 'p95': 420, 'p99': 850, 'streak': 0},
    'stripe': {'successRate': 99.8, 'p50': 210, 'p95': 380, 'p99': 620, 'streak': 0},
    'cashfree': {'successRate': 98.2, 'p50': 240, 'p95': 580, 'p99': 1100, 'streak': 0},
    'meta_whatsapp': {'successRate': 99.1, 'p50': 95, 'p95': 220, 'p99': 410, 'streak': 0},
    'gupshup_whatsapp': {'successRate': 84.5, 'p50': 350, 'p95': 1200, 'p99': 2400, 'streak': 3},
    'twilio_sms': {'successRate': 99.6, 'p50': 120, 'p95': 280, 'p99': 510, 'streak': 0},
    'msg91_sms': {'successRate': 98.9, 'p50': 140, 'p95': 310, 'p99': 590, 'streak': 0},
    'cloudflare_r2': {'successRate': 99.9, 'p50': 65, 'p95': 130, 'p99': 240, 'streak': 0},
    'aws_s3': {'successRate': 99.9, 'p50': 85, 'p95': 160, 'p99': 310, 'streak': 0},
  };

  final Map<String, List<String>> _fallbackChains = {
    'PAYMENT': ['razorpay', 'cashfree', 'phonepe', 'stripe', 'mock_payment'],
    'WHATSAPP': ['meta_whatsapp', 'gupshup_whatsapp', 'mock_whatsapp'],
    'SMS': ['msg91_sms', 'twilio_sms', 'mock_sms'],
    'STORAGE': ['cloudflare_r2', 'aws_s3', 'mock_storage'],
    'MAPS': ['google_maps', 'mapbox', 'mock_maps'],
    'KYC': ['surepass_kyc', 'hyperverge_kyc', 'mock_kyc'],
  };

  void _tripCircuit(String providerId) {
    setState(() {
      _circuitStates[providerId] = 'OPEN';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Circuit manually tripped to OPEN for $providerId'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  void _resetCircuit(String providerId) {
    setState(() {
      _circuitStates[providerId] = 'CLOSED';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Circuit reset to CLOSED for $providerId'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Future<void> _runSimulation() async {
    setState(() {
      _isSimulating = true;
      _lastSimulationResult = null;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    final chain = _fallbackChains[_selectedCategory] ?? ['mock_provider'];
    final primary = _selectedProviderForSim;
    final fallbackIndex = chain.indexOf(primary) + 1;
    final fallbackProvider = fallbackIndex < chain.length ? chain[fallbackIndex] : 'none';

    setState(() {
      _isSimulating = false;
      _lastSimulationResult = {
        'status': 'FAILOVER_SUCCESS',
        'attemptedProvider': primary,
        'simulatedScenario': _selectedScenario,
        'classification': _selectedScenario == 'TIMEOUT'
            ? 'TIMEOUT'
            : _selectedScenario == 'RATE_LIMIT'
                ? 'RATE_LIMITED'
                : _selectedScenario == 'AUTH_FAILURE'
                    ? 'AUTHENTICATION'
                    : 'NETWORK',
        'fallbackEngaged': true,
        'fallbackProvider': fallbackProvider,
        'totalLatencyMs': 142,
        'attempts': [
          {
            'attempt': 1,
            'provider': primary,
            'status': 'FAILED',
            'error': 'Simulated $_selectedScenario condition',
          },
          {
            'attempt': 2,
            'provider': fallbackProvider,
            'status': 'SUCCESS',
            'latency': '28ms',
          }
        ],
      };
    });
  }

  Color _getCircuitColor(String state) {
    switch (state) {
      case 'CLOSED':
        return const Color(0xFF10B981);
      case 'OPEN':
        return const Color(0xFFEF4444);
      case 'HALF_OPEN':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
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
          // Banner for degraded providers
          if (_circuitStates.values.contains('HALF_OPEN') || _circuitStates.values.contains('OPEN'))
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Degraded Providers / Incident Monitoring',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        const Gap(2),
                        Text(
                          'Provider gupshup_whatsapp circuit is in HALF_OPEN state with probe requests active. Failover routing is currently engaged to fallback channels.',
                          style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF78350F)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Section 1: Intelligent Fallback Chains Visualizer
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Provider Fallback & Dynamic Routing Pipeline',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Gap(4),
                          Text(
                            'Zero-code failover chains configured across tenants and branches.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.65),
                            ),
                          ),
                        ],
                      ),
                      DropdownButton<String>(
                        value: _selectedCategory,
                        items: _fallbackChains.keys
                            .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                    ],
                  ),
                  const Gap(20),
                  // Visual pipeline
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0; i < (_fallbackChains[_selectedCategory]?.length ?? 0); i++) ...[
                          _buildChainNode(
                            theme,
                            providerId: _fallbackChains[_selectedCategory]![i],
                            isPrimary: i == 0,
                            priority: i + 1,
                          ),
                          if (i < (_fallbackChains[_selectedCategory]!.length - 1))
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0),
                              child: Row(
                                children: [
                                  Container(
                                    height: 2,
                                    width: 32,
                                    color: theme.colorScheme.primary.withOpacity(0.5),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Gap(24),

          // Section 2: Live Circuit Breakers & Health Telemetry
          Text(
            'Provider Circuit Breakers & Rolling Telemetry',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.65,
            ),
            itemCount: _circuitStates.length,
            itemBuilder: (context, index) {
              final providerId = _circuitStates.keys.elementAt(index);
              final circuitState = _circuitStates[providerId]!;
              final metrics = _healthMetrics[providerId] ??
                  {'successRate': 100.0, 'p50': 150, 'p95': 320, 'p99': 600, 'streak': 0};

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _getCircuitColor(circuitState).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              providerId.replaceAll('_', ' ').toUpperCase(),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCircuitColor(circuitState).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _getCircuitColor(circuitState)),
                            ),
                            child: Text(
                              circuitState,
                              style: TextStyle(
                                color: _getCircuitColor(circuitState),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Success Rate',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                              ),
                              Text(
                                '${metrics['successRate']}%',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Latency (p50/p95)',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                              ),
                              Text(
                                '${metrics['p50']}ms / ${metrics['p95']}ms',
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (circuitState == 'OPEN' || circuitState == 'HALF_OPEN')
                            TextButton.icon(
                              icon: const Icon(Icons.restart_alt_rounded, size: 16),
                              label: const Text('Reset Circuit'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () => _resetCircuit(providerId),
                            )
                          else
                            TextButton.icon(
                              icon: const Icon(Icons.flash_off_rounded, size: 16),
                              label: const Text('Trip Circuit'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () => _tripCircuit(providerId),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const Gap(24),

          // Section 3: Sandbox Simulation Runner
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Provider Sandbox & Failover Simulation Runner',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Gap(4),
                  Text(
                    'Simulate upstream outages, timeouts, and rate limits to verify automated failover behavior.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.65),
                    ),
                  ),
                  const Gap(16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedProviderForSim,
                          decoration: const InputDecoration(
                            labelText: 'Target Provider',
                            border: OutlineInputBorder(),
                          ),
                          items: _circuitStates.keys
                              .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedProviderForSim = v);
                          },
                        ),
                      ),
                      const Gap(16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedScenario,
                          decoration: const InputDecoration(
                            labelText: 'Simulation Scenario',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'TIMEOUT', child: Text('504 Timeout Error')),
                            DropdownMenuItem(value: 'NETWORK_FAILURE', child: Text('Socket Disconnect / ECONNRESET')),
                            DropdownMenuItem(value: 'AUTH_FAILURE', child: Text('401 Invalid Credentials')),
                            DropdownMenuItem(value: 'RATE_LIMIT', child: Text('429 Rate Limit Exceeded')),
                            DropdownMenuItem(value: 'PROVIDER_DECLINED', child: Text('402 Bank Declined')),
                            DropdownMenuItem(value: 'SLOW_RESPONSE', child: Text('Latency Spike (>500ms)')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedScenario = v);
                          },
                        ),
                      ),
                      const Gap(16),
                      FilledButton.icon(
                        icon: _isSimulating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: const Text('Execute Simulation'),
                        onPressed: _isSimulating ? null : _runSimulation,
                      ),
                    ],
                  ),
                  if (_lastSimulationResult != null) ...[
                    const Gap(16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
                              const Gap(8),
                              Text(
                                'Failover Successfully Executed!',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF065F46),
                                ),
                              ),
                            ],
                          ),
                          const Gap(8),
                          Text(
                            'Provider ${_lastSimulationResult!['attemptedProvider']} failed with classification ${_lastSimulationResult!['classification']}. IntegrationRuntime automatically caught the failure and failed over to ${_lastSimulationResult!['fallbackProvider']} in ${_lastSimulationResult!['totalLatencyMs']}ms without business interruption.',
                            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF047857)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChainNode(
    ThemeData theme, {
    required String providerId,
    required bool isPrimary,
    required int priority,
  }) {
    final circuit = _circuitStates[providerId] ?? 'CLOSED';
    final isDegraded = circuit != 'CLOSED';

    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPrimary ? theme.colorScheme.primaryContainer.withOpacity(0.4) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary
              ? theme.colorScheme.primary
              : isDegraded
                  ? const Color(0xFFF59E0B)
                  : theme.colorScheme.outlineVariant,
          width: isPrimary ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPrimary ? theme.colorScheme.primary : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPrimary ? 'PRIMARY' : 'FALLBACK #$priority',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(
                circuit == 'CLOSED' ? Icons.check_circle : Icons.error,
                size: 14,
                color: _getCircuitColor(circuit),
              ),
            ],
          ),
          const Gap(10),
          Text(
            providerId.replaceAll('_', ' ').toUpperCase(),
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(4),
          Text(
            'Circuit: $circuit',
            style: TextStyle(fontSize: 10, color: _getCircuitColor(circuit), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/api_providers.dart';

class AdminOperationsCommandCenterPage extends ConsumerStatefulWidget {
  const AdminOperationsCommandCenterPage({super.key});

  @override
  ConsumerState<AdminOperationsCommandCenterPage> createState() =>
      _AdminOperationsCommandCenterPageState();
}

class _AdminOperationsCommandCenterPageState
    extends ConsumerState<AdminOperationsCommandCenterPage> {
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _commandData;

  @override
  void initState() {
    super.initState();
    _fetchCommandCenter();
  }

  Future<void> _fetchCommandCenter() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.get('/api/v1/operations/admin/command-center');
      if (mounted) {
        setState(() {
          _commandData = res.data is Map ? res.data as Map<String, dynamic> : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load command center: $e';
        });
      }
    }
  }

  Future<void> _triggerSlaEvaluation() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.post('/api/v1/operations/sla/evaluate');
      if (mounted) {
        final data = res.data is Map ? res.data as Map<String, dynamic> : {};
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SLA evaluation completed. Evaluated: ${data['totalEvaluated'] ?? 0}, Breaches flagged: ${data['incidentsCreated'] ?? 0}',
            ),
          ),
        );
        _fetchCommandCenter();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SLA evaluation failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resolveIncident(Map<String, dynamic> incident) async {
    final id = incident['id'].toString();
    final actionCtrl = TextEditingController(text: 'CONTACTED_HOST');
    final notesCtrl = TextEditingController();

    final resolved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Resolve SLA Incident #${incident['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${incident['breachType'] ?? incident['incidentType'] ?? 'SLA Breach'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Gap(8),
            TextField(
              controller: actionCtrl,
              decoration: const InputDecoration(
                labelText: 'Action Taken (e.g. CONTACTED_HOST, DISPATCHED_RELIEF)',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(8),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Resolution Notes', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resolve Incident'),
          ),
        ],
      ),
    );

    if (resolved != true) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final resolutionNotes = notesCtrl.text.trim().isNotEmpty
          ? '${actionCtrl.text.trim()}: ${notesCtrl.text.trim()}'
          : actionCtrl.text.trim();
      await apiClient.dio.post(
        '/api/v1/operations/sla/incidents/$id/resolve',
        data: {
          'resolutionNotes': resolutionNotes,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident resolved successfully.')),
        );
        _fetchCommandCenter();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve incident: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _commandData;
    final m = d != null && d['overview'] is Map ? (d['overview'] as Map<String, dynamic>) : (d ?? {});

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Operations Command Center & SLA Watch'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.timer_outlined, size: 16),
            label: const Text('Evaluate SLAs'),
            onPressed: _triggerSlaEvaluation,
          ),
          const Gap(8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCommandCenter,
            tooltip: 'Refresh',
          ),
          const Gap(16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : d == null
                  ? const Center(child: Text('No command center data available.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // High-Level Operational Metrics Grid
                        Row(
                          children: [
                            _buildStatCard('Active Rentals', '${m['activeRentals'] ?? d['activeRentals'] ?? 0}', Colors.blue),
                            const Gap(12),
                            _buildStatCard('Pickups Today', '${m['pickupsToday'] ?? d['pickupsToday'] ?? 0}', Colors.green),
                            const Gap(12),
                            _buildStatCard('Returns Today', '${m['returnsToday'] ?? d['returnsToday'] ?? 0}', Colors.teal),
                            const Gap(12),
                            _buildStatCard('Unallocated', '${m['unallocatedCount'] ?? d['unallocatedCount'] ?? 0}', Colors.orange),
                          ],
                        ),
                        const Gap(12),
                        Row(
                          children: [
                            _buildStatCard('SLA Breaches', '${m['slaBreachesCount'] ?? d['slaBreachesCount'] ?? 0}', Colors.red),
                            const Gap(12),
                            _buildStatCard('Maintenance', '${m['maintenanceVehicles'] ?? d['maintenanceVehicles'] ?? 0}', Colors.amber[800]!),
                            const Gap(12),
                            _buildStatCard(
                              'Active Fleet',
                              '${m['availableFleet'] ?? m['activeCars'] ?? d['activeCars'] ?? 0} / ${m['totalFleet'] ?? m['totalCars'] ?? d['totalCars'] ?? 0}',
                              Colors.indigo,
                            ),
                            const Gap(12),
                            _buildStatCard('Substitutions', '${m['substitutionsCount'] ?? d['substitutionsCount'] ?? 0}', Colors.purple),
                          ],
                        ),
                        const Gap(24),

                        // Active Incidents Section
                        const Text('Active SLA Breaches & Operational Incidents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Gap(8),
                        Builder(
                          builder: (ctx) {
                            final incidents = (d['recentIncidents'] as List<dynamic>?) ?? [];
                            if (incidents.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: const Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green),
                                      Gap(8),
                                      Text('All operations within SLA parameters. Zero open incidents.', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: incidents.length,
                              separatorBuilder: (_, __) => const Gap(8),
                              itemBuilder: (c, idx) {
                                final inc = incidents[idx] as Map<String, dynamic>;
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.red,
                                      child: Icon(Icons.warning_amber, color: Colors.white, size: 20),
                                    ),
                                    title: Text(
                                      '${inc['breachType'] ?? inc['title'] ?? 'SLA Incident'} • #${inc['id']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      'Booking: #${inc['bookingId'] ?? '-'} • Target: ${inc['targetRole'] ?? 'VENDOR'}\n'
                                      '${inc['description'] ?? '-'}\n'
                                      'Triggered: ${inc['createdAt'] != null ? DateFormat.yMMMd().add_jm().format(DateTime.parse(inc['createdAt'])) : '-'}',
                                    ),
                                    trailing: FilledButton.tonal(
                                      onPressed: () => _resolveIncident(inc),
                                      child: const Text('Resolve'),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const Gap(6),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

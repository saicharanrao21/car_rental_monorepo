import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';

final adminEmergencyRequestsProvider =
    FutureProvider.family.autoDispose<List<EmergencyRequestModel>, String?>((ref, statusFilter) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get(
    '/admin/emergency/requests',
    queryParameters: statusFilter != null && statusFilter != 'ALL' ? {'status': statusFilter} : null,
  );
  final raw = response.data;
  final List list = raw is Map ? (raw['requests'] as List? ?? []) : (raw is List ? raw : []);
  return list.map((e) => EmergencyRequestModel.fromJson(e as Map<String, dynamic>)).toList();
});

class AdminEmergencyDispatchPage extends ConsumerStatefulWidget {
  const AdminEmergencyDispatchPage({super.key});

  @override
  ConsumerState<AdminEmergencyDispatchPage> createState() => _AdminEmergencyDispatchPageState();
}

class _AdminEmergencyDispatchPageState extends ConsumerState<AdminEmergencyDispatchPage> {
  String _selectedStatus = 'ALL';

  void _openDispatchDialog(EmergencyRequestModel request) {
    showDialog(
      context: context,
      builder: (ctx) => _DispatchActionDialog(
        request: request,
        onUpdated: () => ref.invalidate(adminEmergencyRequestsProvider(_selectedStatus)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emergencyAsync = ref.watch(adminEmergencyRequestsProvider(_selectedStatus));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.emergency_outlined, color: Colors.red, size: 28),
                        Gap(10),
                        Text('Emergency Roadside Dispatch Control',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Gap(4),
                    Text('Rapid response dispatcher for roadside incidents, towing, tyre, battery and mechanical breakdowns.',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh SOS Feed'),
                  onPressed: () => ref.invalidate(adminEmergencyRequestsProvider(_selectedStatus)),
                ),
              ],
            ),
            const Gap(20),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('ALL', 'All Requests'),
                  _filterChip('REQUESTED', '🚨 New SOS'),
                  _filterChip('ACKNOWLEDGED', 'Acknowledged'),
                  _filterChip('ASSIGNED', 'Assigned'),
                  _filterChip('PROVIDER_EN_ROUTE', 'Provider En Route'),
                  _filterChip('ON_SITE', 'On Site'),
                  _filterChip('RESOLVED', 'Resolved'),
                ],
              ),
            ),
            const Gap(16),

            // Emergency Requests List
            Expanded(
              child: emergencyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error loading emergency requests: $err',
                      style: const TextStyle(color: Colors.red)),
                ),
                data: (requests) {
                  if (requests.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_outlined, size: 64, color: Colors.green.shade300),
                          const Gap(12),
                          const Text('No active emergency requests reported. All quiet on the road!',
                              style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      final isPending = req.status == EmergencyStatus.REQUESTED ||
                          req.status == EmergencyStatus.ACKNOWLEDGED;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isPending ? Colors.red.shade300 : Colors.grey.shade300,
                            width: isPending ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isPending
                                      ? Colors.red.withValues(alpha: 0.12)
                                      : Colors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.emergency,
                                  color: isPending ? Colors.red : Colors.blue,
                                  size: 24,
                                ),
                              ),
                              const Gap(16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('SOS #${req.requestNumber}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold, fontSize: 14)),
                                        const Gap(8),
                                        _buildStatusBadge(req.status),
                                        const Gap(8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(req.incidentType.label,
                                              style: const TextStyle(
                                                  fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const Gap(4),
                                    Text('Booking: ${req.bookingId}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.blueGrey)),
                                    if (req.customerNotes != null) ...[
                                      const Gap(4),
                                      Text('Notes: ${req.customerNotes}',
                                          style: const TextStyle(fontSize: 13)),
                                    ],
                                    if (req.locationAddress != null) ...[
                                      const Gap(2),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined,
                                              size: 14, color: Colors.grey),
                                          const Gap(4),
                                          Text(req.locationAddress!,
                                              style: const TextStyle(
                                                  fontSize: 12, color: Colors.black54)),
                                        ],
                                      ),
                                    ],
                                    if (req.assignedProviderName != null) ...[
                                      const Gap(4),
                                      Text(
                                        'Assigned Dispatcher: ${req.assignedProviderName} (${req.assignedProviderPhone ?? "N/A"}) - ETA ~${req.estimatedEtaMinutes ?? "?"} min',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.indigo),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPending ? Colors.red : Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _openDispatchDialog(req),
                                child: Text(isPending ? 'Dispatch Unit' : 'Update Status'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String statusKey, String label) {
    final isSelected = _selectedStatus == statusKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87, fontSize: 12)),
        selected: isSelected,
        selectedColor: statusKey == 'REQUESTED' ? Colors.red.shade700 : Colors.blue.shade700,
        checkmarkColor: Colors.white,
        onSelected: (selected) {
          if (selected) setState(() => _selectedStatus = statusKey);
        },
      ),
    );
  }

  Widget _buildStatusBadge(EmergencyStatus status) {
    Color color;
    switch (status) {
      case EmergencyStatus.REQUESTED:
        color = Colors.red;
        break;
      case EmergencyStatus.ACKNOWLEDGED:
        color = Colors.orange;
        break;
      case EmergencyStatus.ASSIGNED:
      case EmergencyStatus.PROVIDER_EN_ROUTE:
      case EmergencyStatus.CUSTOMER_CONTACTED:
      case EmergencyStatus.ON_SITE:
        color = Colors.blue;
        break;
      case EmergencyStatus.RESOLVED:
        color = Colors.green;
        break;
      case EmergencyStatus.CANCELLED:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(status.label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _DispatchActionDialog extends ConsumerStatefulWidget {
  final EmergencyRequestModel request;
  final VoidCallback onUpdated;

  const _DispatchActionDialog({required this.request, required this.onUpdated});

  @override
  ConsumerState<_DispatchActionDialog> createState() => _DispatchActionDialogState();
}

class _DispatchActionDialogState extends ConsumerState<_DispatchActionDialog> {
  late EmergencyStatus _status;
  final _providerNameCtrl = TextEditingController();
  final _providerPhoneCtrl = TextEditingController();
  final _etaCtrl = TextEditingController();
  final _resolutionNotesCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.request.status;
    _providerNameCtrl.text = widget.request.assignedProviderName ?? '';
    _providerPhoneCtrl.text = widget.request.assignedProviderPhone ?? '';
    _etaCtrl.text = widget.request.estimatedEtaMinutes?.toString() ?? '';
    _resolutionNotesCtrl.text = widget.request.resolutionNotes ?? '';
  }

  @override
  void dispose() {
    _providerNameCtrl.dispose();
    _providerPhoneCtrl.dispose();
    _etaCtrl.dispose();
    _resolutionNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final apiClient = ref.read(apiClientProvider);

      await apiClient.dio.patch(
        '/admin/emergency/requests/${widget.request.id}/status',
        data: {
          'status': _status.name,
          if (_providerNameCtrl.text.trim().isNotEmpty)
            'assignedProviderName': _providerNameCtrl.text.trim(),
          if (_providerPhoneCtrl.text.trim().isNotEmpty)
            'assignedProviderPhone': _providerPhoneCtrl.text.trim(),
          if (int.tryParse(_etaCtrl.text.trim()) != null)
            'estimatedEtaMinutes': int.parse(_etaCtrl.text.trim()),
          if (_resolutionNotesCtrl.text.trim().isNotEmpty)
            'resolutionNotes': _resolutionNotesCtrl.text.trim(),
        },
      );

      widget.onUpdated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating dispatch: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Emergency Dispatch: #${widget.request.requestNumber}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Gap(4),
              Text('Incident: ${widget.request.incidentType.label}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const Divider(height: 24),

              DropdownButtonFormField<EmergencyStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Dispatch Status',
                  border: OutlineInputBorder(),
                ),
                items: EmergencyStatus.values.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
              ),
              const Gap(16),

              TextField(
                controller: _providerNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Assigned Service Provider / Towing Company',
                  hintText: 'e.g. QuickTow Road Rescue Mumbai',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.car_crash_outlined),
                ),
              ),
              const Gap(16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _providerPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Driver / Dispatch Phone',
                        hintText: '+919876543210',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: TextField(
                      controller: _etaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ETA (Minutes)',
                        hintText: '25',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(16),

              TextField(
                controller: _resolutionNotesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Resolution Summary / Incident Log',
                  hintText: 'e.g. Spare tyre fitted on site, customer resumed journey.',
                  border: OutlineInputBorder(),
                ),
              ),
              const Gap(24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Gap(12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save & Update SOS'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

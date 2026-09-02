import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../providers/locations_providers.dart';

class LocationDetailDrawerContent extends ConsumerWidget {
  final VendorLocationModel location;
  final VoidCallback? onClose;

  const LocationDetailDrawerContent({
    super.key,
    required this.location,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _getStatusColor(location.status);
    final isPending = location.status == VendorLocationStatus.pendingApproval;
    final isActive = location.status == VendorLocationStatus.active;
    final isSuspended = location.status == VendorLocationStatus.suspended;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Status & Quick Action Banner ───
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: statusColor, size: 22),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS: ${location.status.toApiString()}',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      'Hub ID: ${location.id} • Type: ${location.type.displayName}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(20),

        // ─── Location & Address Details ───
        _buildSectionHeader('Location & Geocoordinates', Icons.pin_drop_outlined),
        const Gap(12),
        _buildInfoCard([
          _buildInfoRow('Hub Name', location.name),
          _buildInfoRow('Type', location.type.displayName),
          _buildInfoRow('City / State', '${location.city}, ${location.state ?? "N/A"}'),
          _buildInfoRow('Street Address', location.address),
          if (location.locality != null && location.locality!.isNotEmpty)
            _buildInfoRow('Locality', location.locality!),
          _buildInfoRow('Postal Code', location.pincode ?? 'N/A'),
          _buildInfoRow('Coordinates', '${location.latitude.toStringAsFixed(4)}° N, ${location.longitude.toStringAsFixed(4)}° E'),
          _buildInfoRow('Service Radius', '${location.serviceRadiusKm.toStringAsFixed(0)} km'),
        ]),
        const Gap(20),

        // ─── Contact & Operational Capacity ───
        _buildSectionHeader('Contact & Fleet Allocation', Icons.contact_phone_outlined),
        const Gap(12),
        _buildInfoCard([
          _buildInfoRow('Vendor Partner ID', location.vendorId),
          _buildInfoRow('Contact Person', location.contactPerson ?? 'N/A'),
          _buildInfoRow('Contact Phone', location.contactPhone ?? 'N/A'),
          _buildInfoRow('Assigned Vehicles', '${location.assignedCarCount} Vehicles Available'),
          _buildInfoRow('Pickup Allowed', location.allowsPickup ? 'Yes' : 'No'),
          _buildInfoRow('Return Allowed', location.allowsReturn ? 'Yes' : 'No'),
          _buildInfoRow('Delivery Supported', location.allowsDelivery ? 'Yes' : 'No'),
        ]),
        const Gap(20),

        // ─── Operating Schedule ───
        _buildSectionHeader('Operating Schedule', Icons.access_time_outlined),
        const Gap(12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(
                location.is24x7 ? Icons.all_inclusive : Icons.access_time,
                size: 20,
                color: Colors.blue,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.scheduleDisplay,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const Gap(2),
                    Text(
                      location.is24x7
                          ? 'Available for pickup and drop-off 24 hours daily'
                          : 'Operating daily from ${location.openingTime} to ${location.closingTime}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(24),

        // ─── Governance Actions ───
        _buildSectionHeader('Governance & Review Actions', Icons.admin_panel_settings_outlined),
        const Gap(12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (isPending || !isActive)
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Approve / Activate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await ref.read(locationGovernanceControllerProvider.notifier).updateStatus(location.id, 'ACTIVE');
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            if (isActive)
              OutlinedButton.icon(
                icon: const Icon(Icons.pause_circle_outline, size: 16, color: Colors.orange),
                label: const Text('Temporarily Pause', style: TextStyle(color: Colors.orange)),
                onPressed: () async {
                  await ref.read(locationGovernanceControllerProvider.notifier).updateStatus(location.id, 'TEMPORARILY_CLOSED');
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            if (!isSuspended)
              OutlinedButton.icon(
                icon: const Icon(Icons.block_outlined, size: 16, color: Colors.red),
                label: const Text('Suspend Location', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  await ref.read(locationGovernanceControllerProvider.notifier).updateStatus(location.id, 'SUSPENDED');
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          ],
        ),
        const Gap(20),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1E293B)),
        const Gap(8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(VendorLocationStatus status) {
    switch (status) {
      case VendorLocationStatus.active:
        return Colors.green;
      case VendorLocationStatus.pendingApproval:
        return Colors.orange;
      case VendorLocationStatus.temporarilyClosed:
        return Colors.amber;
      case VendorLocationStatus.suspended:
        return Colors.red;
      case VendorLocationStatus.inactive:
        return Colors.grey;
    }
  }
}

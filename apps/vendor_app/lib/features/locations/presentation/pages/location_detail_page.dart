import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../providers/locations_providers.dart';

class LocationDetailPage extends ConsumerWidget {
  final String locationId;

  const LocationDetailPage({super.key, required this.locationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(vendorLocationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Location Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B192C),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Location',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: locationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (locations) {
          final loc = locations.firstWhere(
            (l) => l.id == locationId,
            orElse: () => locations.isNotEmpty
                ? locations.first
                : VendorLocationModel(
                    id: locationId,
                    vendorId: 'v_1',
                    name: 'Location Overview',
                    address: 'Address not found',
                    city: 'Hyderabad',
                    latitude: 17.4483,
                    longitude: 78.3915,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
          );

          final isActive = loc.status == VendorLocationStatus.active;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0066FF).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              loc.type.displayName.toUpperCase(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0066FF)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF059669).withValues(alpha: 0.12)
                                  : Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isActive ? 'ACTIVE' : 'INACTIVE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive ? const Color(0xFF059669) : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(12),
                      Text(
                        loc.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
                      ),
                      const Gap(6),
                      Text(
                        loc.address,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
                          const Gap(6),
                          Text(loc.contactPhone ?? 'N/A', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                          const Gap(6),
                          Text(
                            loc.is24x7 ? 'Open 24x7 Continuous' : 'Hours: ${loc.openingTime} - ${loc.closingTime}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          const Icon(Icons.pin_drop_outlined, size: 16, color: Color(0xFF64748B)),
                          const Gap(6),
                          Text(
                            'GPS: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assigned Fleet (Stationed Vehicles)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
                      ),
                      const Gap(10),
                      Text(
                        '${loc.assignedCarCount} vehicles currently assigned to this location.',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      const Gap(12),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/fleet'),
                        icon: const Icon(Icons.directions_car, size: 16),
                        label: const Text('Manage Assigned Vehicles'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF0B192C),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable Location?'),
        content: const Text(
          'Are you sure you want to deactivate this location? Existing confirmed bookings will remain safe.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ref.read(vendorLocationsProvider.notifier).deleteLocation(locationId);
              Navigator.pop(ctx);
              context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

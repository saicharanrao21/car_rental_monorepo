import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
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
                // 1. Location Overview Card
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
                            loc.is24x7 ? 'Open 24x7 Continuous' : 'Standard Hours: ${loc.openingTime} - ${loc.closingTime}',
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

                // 2. Operating Hours & Location Exceptions Card
                _buildOperatingExceptionsCard(context, ref, loc),
                const Gap(16),

                // 3. Stationed Fleet Assignment Card
                _buildAssignedFleetCard(context, ref, loc),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOperatingExceptionsCard(BuildContext context, WidgetRef ref, VendorLocationModel loc) {
    final exceptionsAsync = ref.watch(locationExceptionsProvider(loc.id));

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.event_busy_outlined, color: Color(0xFF0066FF), size: 18),
                    Gap(8),
                    Expanded(
                      child: Text(
                        'Operating Hours & Exceptions',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                key: const Key('add_exception_button'),
                onPressed: () => _showAddExceptionDialog(context, ref, loc.id),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Exception', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Gap(4),
          const Text(
            'Schedule holiday closures, maintenance blackouts, or custom special hours.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Gap(12),
          exceptionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Unable to load exceptions: $err', style: const TextStyle(fontSize: 12, color: Colors.red)),
            ),
            data: (exceptions) {
              if (exceptions.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
                      Gap(8),
                      Expanded(
                        child: Text(
                          'No scheduled exceptions. Normal operating hours apply.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: exceptions.map((exc) {
                  final isClosed = exc.isClosed;
                  final dateFormatted = DateFormat('EEE, MMM d, yyyy').format(exc.date);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isClosed ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isClosed ? const Color(0xFFFECACA) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isClosed ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isClosed ? Icons.do_not_disturb_on_outlined : Icons.schedule_outlined,
                            size: 16,
                            color: isClosed ? Colors.red : Colors.orange.shade800,
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    dateFormatted,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isClosed ? Colors.red.shade100 : Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isClosed ? 'CLOSED' : 'SPECIAL HOURS',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: isClosed ? Colors.red.shade800 : Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(3),
                              Text(
                                exc.reason ?? (isClosed ? 'Closed for the day' : 'Custom operating hours'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isClosed ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                                ),
                              ),
                              if (!isClosed && (exc.customOpeningTime != null || exc.specialOpeningTime != null)) ...[
                                const Gap(2),
                                Text(
                                  'Custom Hours: ${exc.customOpeningTime ?? exc.specialOpeningTime} - ${exc.customClosingTime ?? exc.specialClosingTime}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          key: Key('delete_exception_${exc.id}'),
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          tooltip: 'Remove Exception',
                          onPressed: () async {
                            await ref.read(locationExceptionsProvider(loc.id).notifier).deleteException(exc.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Exception removed')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedFleetCard(BuildContext context, WidgetRef ref, VendorLocationModel loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_car_filled_outlined, color: Color(0xFF0066FF), size: 18),
              Gap(8),
              Expanded(
                child: Text(
                  'Assigned Fleet (Stationed Vehicles)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            '${loc.assignedCarCount} vehicles currently assigned to this location.',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          if (loc.assignedCarIds.isNotEmpty) ...[
            const Gap(10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: loc.assignedCarIds.map((cid) {
                return Chip(
                  label: Text(cid, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const Gap(14),
          ElevatedButton.icon(
            key: const Key('manage_stationed_vehicles_button'),
            onPressed: () => _showAssignVehiclesDialog(context, ref, loc),
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
    );
  }

  void _showAddExceptionDialog(BuildContext context, WidgetRef ref, String locationId) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    LocationExceptionType selectedType = LocationExceptionType.temporaryClosure;
    final reasonController = TextEditingController(text: 'Scheduled Maintenance / Holiday');
    final openTimeController = TextEditingController(text: '10:00');
    final closeTimeController = TextEditingController(text: '18:00');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isClosed = selectedType != LocationExceptionType.customHours;

            return AlertDialog(
              title: const Text('Add Location Exception', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const Gap(6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('EEE, MMM d, yyyy').format(selectedDate)),
                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    const Gap(14),
                    const Text('Exception Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const Gap(6),
                    DropdownButtonFormField<LocationExceptionType>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: LocationExceptionType.values.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t.displayName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedType = val;
                          });
                        }
                      },
                    ),
                    const Gap(14),
                    const Text('Reason / Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const Gap(6),
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Regional Holiday, Renovation, VIP Event',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (!isClosed) ...[
                      const Gap(14),
                      const Text('Custom Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const Gap(6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: openTimeController,
                              decoration: const InputDecoration(
                                labelText: 'Open',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: TextField(
                              controller: closeTimeController,
                              decoration: const InputDecoration(
                                labelText: 'Close',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('save_exception_button'),
                  onPressed: () async {
                    final exception = LocationExceptionModel(
                      id: 'exc_${DateTime.now().millisecondsSinceEpoch}',
                      locationId: locationId,
                      date: selectedDate,
                      exceptionType: selectedType,
                      isClosed: isClosed,
                      reason: reasonController.text.trim(),
                      specialOpeningTime: isClosed ? null : openTimeController.text.trim(),
                      specialClosingTime: isClosed ? null : closeTimeController.text.trim(),
                    );
                    await ref.read(locationExceptionsProvider(locationId).notifier).addException(exception);
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Exception scheduled successfully')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Schedule Exception'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAssignVehiclesDialog(BuildContext context, WidgetRef ref, VendorLocationModel loc) {
    final availableFleet = [
      (id: 'car_1', name: 'Hyundai Creta SX(O)', plate: 'MH 12 CD 5678', desc: 'SUV • Diesel'),
      (id: 'car_2', name: 'Mahindra Thar 4x4', plate: 'TS 09 EA 1001', desc: 'SUV • Diesel'),
      (id: 'car_3', name: 'Tata Nexon EV', plate: 'TS 09 EA 2002', desc: 'Compact SUV • Electric'),
      (id: 'car_4', name: 'Maruti Swift ZXi', plate: 'MH 02 EF 4321', desc: 'Hatchback • Petrol'),
    ];

    final selected = Set<String>.from(loc.assignedCarIds);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Assign Stationed Vehicles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select vehicles stationed primarily at this location:',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      const Gap(12),
                      ...availableFleet.map((car) {
                        final isChecked = selected.contains(car.id);
                        return CheckboxListTile(
                          key: Key('fleet_checkbox_${car.id}'),
                          value: isChecked,
                          title: Text(car.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('${car.plate} • ${car.desc}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          activeColor: const Color(0xFF0066FF),
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selected.add(car.id);
                              } else {
                                selected.remove(car.id);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('save_vehicle_assignment_button'),
                  onPressed: () async {
                    await ref.read(vendorLocationsProvider.notifier).assignVehiclesToLocation(loc.id, selected.toList());
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Assigned ${selected.length} vehicles to location')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Assignments'),
                ),
              ],
            );
          },
        );
      },
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

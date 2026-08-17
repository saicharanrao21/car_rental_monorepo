import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../providers/emergency_providers.dart';

class EmergencyBottomSheet extends ConsumerStatefulWidget {
  final String bookingId;
  final String carDetails;

  const EmergencyBottomSheet({
    super.key,
    required this.bookingId,
    required this.carDetails,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String bookingId,
    required String carDetails,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EmergencyBottomSheet(
        bookingId: bookingId,
        carDetails: carDetails,
      ),
    );
  }

  @override
  ConsumerState<EmergencyBottomSheet> createState() =>
      _EmergencyBottomSheetState();
}

class _EmergencyBottomSheetState extends ConsumerState<EmergencyBottomSheet> {
  IncidentType _selectedType = IncidentType.FLAT_TYRE;
  final _notesController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submitSos() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo = ref.read(emergencyRepositoryProvider);
      await repo.createEmergencyRequest(
        bookingId: widget.bookingId,
        incidentType: _selectedType,
        customerNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        locationAddress: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error dispatching SOS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning SOS Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emergency_outlined, color: Colors.red, size: 28),
                ),
                const Gap(12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Roadside Assistance',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      Text(
                        '24/7 Rapid Incident Dispatch',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(16),

            // Vehicle Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, size: 18, color: Colors.grey),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      'Vehicle: ${widget.carDetails}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),

            const Text(
              'Select Incident Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Gap(8),

            DropdownButtonFormField<IncidentType>(
              value: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning_amber_rounded, color: Colors.red),
              ),
              items: IncidentType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedType = val;
                  });
                }
              },
            ),
            const Gap(12),

            // Location
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Current Location / Landmark',
                hintText: 'e.g. Near Toll Gate, Highway NH-44',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(12),

            // Details
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Additional Notes / Symptoms',
                hintText: 'e.g. Front right tyre punctured, car parked safely on shoulder',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(20),

            // Warning text
            const Text(
              '⚠️ Roadside emergency assistance is intended for urgent operational breakdowns. Our team will contact you within minutes.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const Gap(16),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSubmitting ? null : _submitSos,
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('DISPATCH IMMEDIATE ASSISTANCE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

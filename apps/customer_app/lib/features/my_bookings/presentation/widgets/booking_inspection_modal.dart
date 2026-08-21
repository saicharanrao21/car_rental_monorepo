import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/my_bookings_providers.dart';

class BookingInspectionModal extends ConsumerWidget {
  final String bookingId;

  const BookingInspectionModal({
    super.key,
    required this.bookingId,
  });

  static Future<void> show(BuildContext context, {required String bookingId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingInspectionModal(bookingId: bookingId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionsAsync = ref.watch(bookingInspectionsProvider(bookingId));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.checklist_rounded, color: AppColors.primary, size: 24),
                  Gap(10),
                  Text(
                    'Vehicle Inspection Report',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Gap(16),

          Expanded(
            child: inspectionsAsync.when(
              loading: () => const Center(child: AppLoader()),
              error: (err, _) => Center(
                child: Text('Failed to load inspection report: $err'),
              ),
              data: (inspections) {
                if (inspections.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey[400]),
                        const Gap(12),
                        const Text(
                          'No Inspection Recorded Yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Gap(6),
                        Text(
                          'The fleet host will record vehicle odometer, fuel level, and condition photos during handover.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: inspections.length,
                  separatorBuilder: (_, __) => const Gap(16),
                  itemBuilder: (context, index) {
                    final insp = inspections[index];
                    final isPreTrip = insp.type == 'PRE_TRIP';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isPreTrip ? 'Pre-Trip Pickup Inspection' : 'Post-Trip Return Inspection',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPreTrip ? Colors.blue.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPreTrip ? 'HANDOVER' : 'RETURN',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isPreTrip ? Colors.blue[800] : Colors.green[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Gap(12),
                          Row(
                            children: [
                              Expanded(
                                child: _statTile(
                                  Icons.speed,
                                  'Odometer Reading',
                                  '${insp.odometer.toInt()} km',
                                ),
                              ),
                              const Gap(10),
                              Expanded(
                                child: _statTile(
                                  Icons.local_gas_station,
                                  'Fuel Level',
                                  '${insp.fuelPercent}% Tank',
                                ),
                              ),
                            ],
                          ),
                          if (insp.conditionNotes != null && insp.conditionNotes!.isNotEmpty) ...[
                            const Gap(10),
                            Text(
                              'Host Notes: ${insp.conditionNotes}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                            ),
                          ],
                          if (insp.damagePhotos.isNotEmpty) ...[
                            const Gap(12),
                            const Text(
                              'Condition Photos:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const Gap(8),
                            SizedBox(
                              height: 70,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: insp.damagePhotos.length,
                                separatorBuilder: (_, __) => const Gap(8),
                                itemBuilder: (context, pIndex) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: insp.damagePhotos[pIndex],
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Gap(16),
          AppButton(
            text: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const Gap(4),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
          const Gap(4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

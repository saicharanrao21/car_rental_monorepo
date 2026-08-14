import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';

class InspectionHistoryCard extends StatelessWidget {
  final InspectionModel inspection;

  const InspectionHistoryCard({super.key, required this.inspection});

  Color _getFuelColor(int percent) {
    if (percent < 25) return Colors.red;
    if (percent < 50) return Colors.amber.shade700;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final isPreTrip = inspection.type == 'PRE_TRIP';
    final title = isPreTrip ? 'Pre-Trip Handover' : 'Post-Trip Return';
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(inspection.createdAt);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and finalized badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isPreTrip ? Colors.blue[50] : Colors.purple[50],
                      child: Icon(
                        isPreTrip ? Icons.car_rental : Icons.fact_check_outlined,
                        size: 18,
                        color: isPreTrip ? Colors.blue[800] : Colors.purple[800],
                      ),
                    ),
                    const Gap(10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                      const Gap(4),
                      Text(
                        'Finalized',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Readings (Odometer & Fuel)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Odometer',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const Gap(4),
                        Text(
                          '${inspection.odometer.toStringAsFixed(1)} km',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fuel Level',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const Gap(4),
                        Text(
                          '${inspection.fuelPercent}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _getFuelColor(inspection.fuelPercent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Condition Notes if present
            if (inspection.conditionNotes != null && inspection.conditionNotes!.isNotEmpty) ...[
              const Gap(12),
              Text(
                'Notes: ${inspection.conditionNotes}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
              ),
            ],

            // Damage Photos if present
            if (inspection.damagePhotos.isNotEmpty) ...[
              const Gap(12),
              Text(
                'Inspection Photos (${inspection.damagePhotos.length}):',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const Gap(6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: inspection.damagePhotos.map((photo) {
                  return InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Inspection Photo'),
                          content: photo.startsWith('http')
                              ? Image.network(photo, fit: BoxFit.contain)
                              : Text('Storage Key: $photo'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_camera_back, size: 14, color: Colors.blue[800]),
                          const Gap(4),
                          Text(
                            photo.length > 20 ? '...${photo.substring(photo.length - 16)}' : photo,
                            style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

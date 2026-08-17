import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';

class EmergencyStatusCard extends StatelessWidget {
  final EmergencyRequestModel emergency;
  final VoidCallback onRefresh;

  const EmergencyStatusCard({
    super.key,
    required this.emergency,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isResolved = emergency.status == EmergencyStatus.RESOLVED;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isResolved
            ? Colors.green.withOpacity(0.08)
            : Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isResolved
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isResolved ? Icons.check_circle_outline : Icons.emergency,
                color: isResolved ? Colors.green : Colors.red,
                size: 24,
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Roadside Incident #${emergency.requestNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isResolved ? Colors.green.shade800 : Colors.red.shade900,
                      ),
                    ),
                    Text(
                      emergency.incidentType.label,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isResolved ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  emergency.status.label,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          if (emergency.assignedProviderName != null) ...[
            const Gap(12),
            const Divider(height: 1),
            const Gap(12),
            Row(
              children: [
                const Icon(Icons.person_pin, size: 18, color: Colors.blue),
                const Gap(8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned: ${emergency.assignedProviderName}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      if (emergency.assignedProviderPhone != null)
                        Text(
                          'Phone: ${emergency.assignedProviderPhone}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                if (emergency.estimatedEtaMinutes != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ETA: ~${emergency.estimatedEtaMinutes} min',
                      style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ],

          if (emergency.resolutionNotes != null) ...[
            const Gap(8),
            Text(
              'Resolution: ${emergency.resolutionNotes}',
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }
}

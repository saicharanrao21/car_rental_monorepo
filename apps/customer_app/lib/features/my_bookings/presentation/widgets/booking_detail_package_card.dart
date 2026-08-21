import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../../domain/repositories/my_bookings_repository.dart';

class BookingDetailPackageCard extends StatelessWidget {
  final CustomerBookingItem item;

  const BookingDetailPackageCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final booking = item.booking;
    final cs = Theme.of(context).colorScheme;

    final hasMileagePackage = item.mileagePackageName != null || item.includedKmTotal != null;
    final hasProtection = item.protectionCode != null || (item.protectionFee != null && item.protectionFee! > 0);

    if (!hasMileagePackage && !hasProtection) {
      return const SizedBox.shrink();
    }

    final isZeroDep = item.protectionCode == 'ZERO_DEP' || item.protectionCode == 'PREMIUM';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Package & Protection Details',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const Gap(14),

          // Mileage Package Row (only if present on booking)
          if (hasMileagePackage) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.speed_outlined, size: 20, color: AppColors.primary),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.mileagePackageName ?? 'Standard Mileage Plan',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Gap(2),
                        Text(
                          [
                            if (item.includedKmTotal != null) 'Included: ${item.includedKmTotal} km',
                            if (item.extraKmRate != null) 'Extra km rate: ₹${item.extraKmRate!.toInt()}/km',
                          ].join(' • '),
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(10),
          ],

          // Protection Plan Row (only if present on booking)
          if (hasProtection) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isZeroDep ? Colors.green.withValues(alpha: 0.08) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: isZeroDep ? Border.all(color: Colors.green.withValues(alpha: 0.3)) : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isZeroDep ? Colors.green.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: isZeroDep ? Colors.green[800] : Colors.blue[800],
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isZeroDep ? 'Zero-Deductible Peace of Mind' : 'Standard Protection',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isZeroDep ? Colors.green[900] : cs.onSurface,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          isZeroDep
                              ? '₹0 Maximum liability for accidental damage'
                              : 'Standard comprehensive insurance with limited deductible',
                          style: TextStyle(fontSize: 11, color: isZeroDep ? Colors.green[800] : cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(12),
          ],

          // Trip Type & Addons Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _specChip(context, Icons.directions_car_outlined, booking.tripType),
              if (item.deliveryFee != null && item.deliveryFee! > 0)
                _specChip(context, Icons.home_outlined, 'Doorstep Delivery'),
              _specChip(context, Icons.support_agent_outlined, '24/7 Roadside Assistance'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _specChip(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const Gap(5),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

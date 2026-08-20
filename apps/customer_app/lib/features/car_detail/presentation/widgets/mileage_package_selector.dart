import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

class MileagePackageSelector extends StatelessWidget {
  final List<dynamic> rawPackages;
  final String tripType;
  final String? selectedPackageId;
  final ValueChanged<MileagePackageModel> onPackageSelected;

  const MileagePackageSelector({
    super.key,
    required this.rawPackages,
    required this.tripType,
    required this.selectedPackageId,
    required this.onPackageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (rawPackages.isEmpty) {
      return const SizedBox.shrink();
    }

    final normalizedTripType = tripType.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');

    final parsedPackages = rawPackages
        .map((p) => MileagePackageModel.fromJson(Map<String, dynamic>.from(p as Map)))
        .where((pkg) => pkg.isActive)
        .toList();

    var matchingPackages = parsedPackages.where((p) => p.tripType.toUpperCase() == normalizedTripType).toList();
    if (matchingPackages.isEmpty) {
      matchingPackages = parsedPackages;
    }

    if (matchingPackages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Select Mileage Package',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(8),
            Text(
              '${matchingPackages.length} options',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Gap(12),
        ...matchingPackages.map((pkg) {
          final isSelected = selectedPackageId == pkg.id || (selectedPackageId == null && pkg.isDefault);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onPackageSelected(pkg),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : cs.outline.withValues(alpha: 0.18),
                    width: isSelected ? 1.8 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? AppColors.primary : cs.onSurfaceVariant.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    const Gap(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  pkg.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? AppColors.primary : cs.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (pkg.isDefault) ...[
                                const Gap(6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Recommended',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Gap(3),
                          Text(
                            pkg.includedKmPerDay != null
                                ? '${pkg.includedKmPerDay} km/day • Extra: ₹${pkg.extraKmRate.toStringAsFixed(0)}/km'
                                : 'Unlimited distance • No extra km charges',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${pkg.basePricePerDay.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '/ day',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

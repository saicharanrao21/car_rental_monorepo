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
    if (rawPackages.isEmpty) {
      return const SizedBox.shrink();
    }

    final normalizedTripType =
        tripType.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');

    final parsedPackages = rawPackages
        .map((p) =>
            MileagePackageModel.fromJson(Map<String, dynamic>.from(p as Map)))
        .where((pkg) => pkg.isActive)
        .toList();

    var matchingPackages = parsedPackages
        .where((p) => p.tripType.toUpperCase() == normalizedTripType)
        .toList();
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
            Flexible(
              child: Text(
                'Select Mileage Package',
                style: DDSTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: DDSColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(8),
            Text(
              '${matchingPackages.length} options',
              style: DDSTypography.labelSmall.copyWith(
                color: DDSColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Gap(12),
        ...matchingPackages.map((pkg) {
          final isSelected = selectedPackageId == pkg.id ||
              (selectedPackageId == null && pkg.isDefault);

          return Padding(
            padding: const EdgeInsets.only(bottom: DDSSpacing.xs),
            child: InkWell(
              borderRadius: BorderRadius.circular(DDSRadius.medium),
              onTap: () => onPackageSelected(pkg),
              child: Container(
                padding: const EdgeInsets.all(DDSSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DDSColors.infoBlueBg
                      : DDSColors.surfaceCard,
                  borderRadius: BorderRadius.circular(DDSRadius.medium),
                  border: Border.all(
                    color: isSelected
                        ? DDSColors.primaryBlue
                        : DDSColors.borderLight,
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? DDSColors.primaryBlue
                          : DDSColors.textMuted,
                      size: 20,
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  pkg.name,
                                  style: DDSTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? DDSColors.primaryBlue
                                        : DDSColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (pkg.isDefault) ...[
                                const Gap(6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: DDSSpacing.xs,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DDSColors.infoBlueBg,
                                    borderRadius: BorderRadius.circular(
                                        DDSRadius.small),
                                  ),
                                  child: Text(
                                    'Recommended',
                                    style: DDSTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: DDSColors.primaryBlue,
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
                            style: DDSTypography.labelSmall.copyWith(
                              color: DDSColors.textSecondary,
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
                          IndianCurrencyFormatter.format(pkg.basePricePerDay,
                              showDecimals: false),
                          style: DDSTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: DDSColors.textPrimary,
                          ),
                        ),
                        Text(
                          '/ day',
                          style: DDSTypography.labelSmall.copyWith(
                            color: DDSColors.textMuted,
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

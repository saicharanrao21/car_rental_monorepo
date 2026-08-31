import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';

class BookingMileagePackageSelector extends ConsumerStatefulWidget {
  final CarModel car;

  const BookingMileagePackageSelector({
    super.key,
    required this.car,
  });

  @override
  ConsumerState<BookingMileagePackageSelector> createState() =>
      _BookingMileagePackageSelectorState();
}

class _BookingMileagePackageSelectorState
    extends ConsumerState<BookingMileagePackageSelector> {
  late final TextEditingController _distanceCtrl;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider);
    _distanceCtrl =
        TextEditingController(text: draft.estimatedDistanceKm.toString());
    _distanceCtrl.addListener(_syncDistance);
  }

  void _syncDistance() {
    final n = int.tryParse(_distanceCtrl.text);
    if (n != null && n > 0) {
      ref
          .read(bookingDraftProvider.notifier)
          .update((d) => d.copyWith(estimatedDistanceKm: n));
    }
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    super.dispose();
  }

  List<MileagePackageModel> _getApplicablePackages(String tripType) {
    if (widget.car.rawMileagePackages.isEmpty) return [];
    return widget.car.rawMileagePackages
        .map((p) =>
            MileagePackageModel.fromJson(Map<String, dynamic>.from(p as Map)))
        .where((p) => p.isActive && p.tripType == tripType)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final applicablePackages = _getApplicablePackages(draft.tripType);
    final hasPackages = applicablePackages.isNotEmpty;

    if (!hasPackages) {
      if (draft.tripType == 'Airport' || draft.tripType == 'Airport Transfer') {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(DDSSpacing.md),
        decoration: BoxDecoration(
          color: DDSColors.surfaceCard,
          borderRadius: DDSRadius.largeBorderRadius,
          border: Border.all(
            color: DDSColors.borderLight,
          ),
          boxShadow: DDSElevation.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimated Distance (km)',
              style: DDSTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: DDSColors.textPrimary,
              ),
            ),
            const Gap(4),
            Text(
              draft.tripType == 'Self-Drive'
                  ? 'Used to compute estimated kilometer allowance and pricing.'
                  : 'Used to calculate your fare based on trip distance.',
              style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted, fontSize: 12),
            ),
            const Gap(DDSSpacing.md),
            AppTextField(
              label: '',
              hint: 'e.g. 50',
              controller: _distanceCtrl,
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.route_outlined, color: DDSColors.primaryBlue),
            ),
            const Gap(6),
            Text(
              'Current: ${draft.estimatedDistanceKm} km',
              style: DDSTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: DDSColors.primaryBlue,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Choose your mileage package',
                style: DDSTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DDSColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: DDSColors.infoBlueBg,
                borderRadius: DDSRadius.smallBorderRadius,
              ),
              child: Text(
                '${draft.rentalDays} Day${draft.rentalDays == 1 ? '' : 's'}',
                style: DDSTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DDSColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const Gap(4),
        Text(
          'Select the mileage allowance that matches your expected journey for ${draft.rentalDays} day${draft.rentalDays == 1 ? '' : 's'}.',
          style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted, fontSize: 12),
        ),
        const Gap(DDSSpacing.sm),
        ...applicablePackages.map((pkg) {
          final isSelected = draft.selectedMileagePackageId == pkg.id;
          final totalKm = pkg.totalIncludedKm(draft.rentalDays);

          return Padding(
            padding: const EdgeInsets.only(bottom: DDSSpacing.sm),
            child: InkWell(
              onTap: () {
                ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                      selectedMileagePackageId: pkg.id,
                      selectedMileagePackage: pkg,
                    ));
              },
              borderRadius: DDSRadius.mediumBorderRadius,
              child: AnimatedContainer(
                duration: DDSMotion.fast,
                padding: const EdgeInsets.all(DDSSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DDSColors.infoBlueBg
                      : DDSColors.surfaceCard,
                  borderRadius: DDSRadius.largeBorderRadius,
                  border: Border.all(
                    color: isSelected
                        ? DDSColors.primaryBlue
                        : DDSColors.borderLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? DDSElevation.cardShadow
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? DDSColors.primaryBlue : DDSColors.textMuted,
                      size: 20,
                    ),
                    const Gap(DDSSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  pkg.name,
                                  style: DDSTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? DDSColors.primaryBlue
                                        : DDSColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (pkg.isDefault) ...[
                                const Gap(6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: DDSColors.successGreenBg,
                                    borderRadius: DDSRadius.smallBorderRadius,
                                    border: Border.all(
                                      color: DDSColors.successGreen.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    'Popular',
                                    style: DDSTypography.labelSmall.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: DDSColors.successGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Gap(4),
                          Text(
                            pkg.isUnlimited
                                ? 'Unlimited km allowance • No per-km restriction'
                                : 'Total included: $totalKm km (${pkg.includedKmPerDay} km/day)',
                            style: DDSTypography.bodyMedium.copyWith(
                              color: DDSColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            pkg.isUnlimited
                                ? 'No extra km charges'
                                : 'Extra km: ₹${pkg.extraKmRate.toInt()}/km beyond $totalKm km',
                            style: DDSTypography.bodyMedium.copyWith(
                              fontSize: 11,
                              color: DDSColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(DDSSpacing.xs),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${pkg.basePricePerDay.toInt()}',
                          style: DDSTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            color: DDSColors.primaryBlue,
                          ),
                        ),
                        Text(
                          '/day',
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

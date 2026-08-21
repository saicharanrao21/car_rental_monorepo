import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
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
    final cs = Theme.of(context).colorScheme;
    final applicablePackages = _getApplicablePackages(draft.tripType);
    final hasPackages = applicablePackages.isNotEmpty;

    if (!hasPackages) {
      if (draft.tripType == 'Airport' || draft.tripType == 'Airport Transfer') {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimated Distance (km)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: cs.onSurface,
              ),
            ),
            const Gap(4),
            Text(
              draft.tripType == 'Self-Drive'
                  ? 'Used to compute estimated kilometer allowance and pricing.'
                  : 'Used to calculate your fare based on trip distance.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const Gap(12),
            AppTextField(
              label: '',
              hint: 'e.g. 50',
              controller: _distanceCtrl,
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.route_outlined, color: AppColors.primary),
            ),
            const Gap(6),
            Text(
              'Current: ${draft.estimatedDistanceKm} km',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
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
            Text(
              'Choose your mileage package',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: cs.onSurface,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${draft.rentalDays} Day${draft.rentalDays == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const Gap(4),
        Text(
          'Select the mileage allowance that matches your expected journey for ${draft.rentalDays} day${draft.rentalDays == 1 ? '' : 's'}.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const Gap(12),
        ...applicablePackages.map((pkg) {
          final isSelected = draft.selectedMileagePackageId == pkg.id;
          final totalKm = pkg.totalIncludedKm(draft.rentalDays);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () {
                ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                      selectedMileagePackageId: pkg.id,
                      selectedMileagePackage: pkg,
                    ));
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : cs.outlineVariant.withValues(alpha: 0.4),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? AppColors.primary : cs.outline,
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
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.primary
                                        : cs.onSurface,
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
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.green.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Text(
                                    'Popular',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green,
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
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            pkg.isUnlimited
                                ? 'No extra km charges'
                                : 'Extra km: ₹${pkg.extraKmRate.toInt()}/km beyond $totalKm km',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${pkg.basePricePerDay.toInt()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '/day',
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

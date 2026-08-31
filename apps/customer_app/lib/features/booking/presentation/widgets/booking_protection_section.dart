import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';
import '../providers/protection_providers.dart';

class BookingProtectionSection extends ConsumerWidget {
  final String? city;

  const BookingProtectionSection({super.key, this.city});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftProvider);
    final packagesAsync = ref.watch(protectionPackagesProvider(city));

    return Container(
      padding: const EdgeInsets.all(DDSSpacing.md),
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.largeBorderRadius,
        border: const Border.fromBorderSide(
          BorderSide(color: DDSColors.borderLight),
        ),
        boxShadow: DDSElevation.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: DDSColors.primaryBlue,
                  size: 18,
                ),
              ),
              const Gap(DDSSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DriveGo Protection Package',
                      style: DDSTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Coverage against road accidents & body damage liabilities',
                      style: DDSTypography.bodyMedium.copyWith(
                        color: DDSColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: DDSColors.successGreenBg,
                  borderRadius: DDSRadius.smallBorderRadius,
                ),
                child: Text(
                  'Recommended',
                  style: DDSTypography.labelSmall.copyWith(
                    fontSize: 10,
                    color: DDSColors.successGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Gap(DDSSpacing.md),

          // Dynamically loaded or fallback tiers
          packagesAsync.when(
            loading: () => Column(
              children: [
                _buildDefaultTiers(context, ref, draft),
              ],
            ),
            error: (_, __) => _buildDefaultTiers(context, ref, draft),
            data: (packages) {
              if (packages.isEmpty) {
                return _buildDefaultTiers(context, ref, draft);
              }
              return Column(
                children: [
                  // Basic included tier
                  _buildOption(
                    context,
                    ref: ref,
                    draft: draft,
                    name: 'Basic Protection',
                    code: 'BASIC',
                    priceText: 'Included',
                    deductibleText: 'Deductible: ₹10,000 max',
                    description: 'Standard third-party liability coverage.',
                    packageId: null,
                    dailyRate: 0.0,
                  ),
                  const Gap(DDSSpacing.sm),
                  // Backend packages
                  ...packages.map((pkg) {
                    final codeStr = pkg.code.name.toUpperCase();
                    final isRecommended = codeStr == 'STANDARD' || codeStr == 'ZERO_DEP';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: DDSSpacing.sm),
                      child: _buildOption(
                        context,
                        ref: ref,
                        draft: draft,
                        name: pkg.name,
                        code: pkg.code.name,
                        priceText: '+₹${pkg.dailyRate.toInt()} / day',
                        deductibleText: 'Deductible: ₹${pkg.deductibleAmount.toInt()} max',
                        description: pkg.description.isNotEmpty ? pkg.description : 'Comprehensive damage and scratch protection.',
                        packageId: pkg.id,
                        dailyRate: pkg.dailyRate,
                        isRecommended: isRecommended,
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultTiers(BuildContext context, WidgetRef ref, BookingDraft draft) {
    return Column(
      children: [
        // Tier 1: Basic (₹0)
        _buildOption(
          context,
          ref: ref,
          draft: draft,
          name: 'Basic Protection',
          code: 'BASIC',
          priceText: 'Included',
          deductibleText: 'Deductible: ₹10,000 max',
          description: 'Standard third-party liability coverage.',
          packageId: null,
          dailyRate: 0.0,
        ),
        const Gap(DDSSpacing.sm),

        // Tier 2: Standard (+₹250/day)
        _buildOption(
          context,
          ref: ref,
          draft: draft,
          name: 'Standard Peace-of-Mind',
          code: 'STANDARD',
          priceText: '+₹250 / day',
          deductibleText: 'Deductible capped at ₹5,000',
          description: 'Glass, mirror & scratch protection with lower deductible.',
          packageId: 'standard_tier',
          dailyRate: 250.0,
          isRecommended: true,
        ),
        const Gap(DDSSpacing.sm),

        // Tier 3: Premium Zero-Dep (+₹500/day)
        _buildOption(
          context,
          ref: ref,
          draft: draft,
          name: 'Premium Zero-Depreciation',
          code: 'ZERO_DEP',
          priceText: '+₹500 / day',
          deductibleText: '₹0 Deductible (100% Covered)',
          description: 'Bumper-to-bumper collision coverage with zero deposit deductions.',
          packageId: 'zero_dep_tier',
          dailyRate: 500.0,
        ),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required WidgetRef ref,
    required BookingDraft draft,
    required String name,
    required String code,
    required String priceText,
    required String deductibleText,
    required String description,
    required String? packageId,
    required double dailyRate,
    bool isRecommended = false,
  }) {
    final isSelected = (draft.selectedProtectionPackageId == null && packageId == null) ||
        (draft.selectedProtectionPackageId == packageId);

    return InkWell(
      onTap: () {
        final totalFee = dailyRate * draft.rentalDays;
        ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
              selectedProtectionPackageId: packageId,
              protectionFee: totalFee,
            ));
      },
      borderRadius: DDSRadius.mediumBorderRadius,
      child: AnimatedContainer(
        duration: DDSMotion.fast,
        padding: const EdgeInsets.all(DDSSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? DDSColors.infoBlueBg
              : DDSColors.surfaceSubtle,
          borderRadius: DDSRadius.mediumBorderRadius,
          border: Border.all(
            color: isSelected
                ? DDSColors.primaryBlue
                : DDSColors.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
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
            const Gap(DDSSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: DDSTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isSelected ? DDSColors.primaryBlue : DDSColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Gap(DDSSpacing.xs),
                      Text(
                        priceText,
                        style: DDSTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: isSelected ? DDSColors.primaryBlue : DDSColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Gap(2),
                  Text(
                    deductibleText,
                    style: DDSTypography.bodyMedium.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: DDSColors.successGreen,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    description,
                    style: DDSTypography.bodyMedium.copyWith(
                      fontSize: 11,
                      color: DDSColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

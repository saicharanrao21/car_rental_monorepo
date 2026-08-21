import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';

class BookingProtectionSection extends ConsumerWidget {
  const BookingProtectionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftProvider);
    final cs = Theme.of(context).colorScheme;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DriveGo Protection Package',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'Coverage against road accidents & body damage liabilities',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Recommended',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Gap(14),

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
          const Gap(10),

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
          ),
          const Gap(10),

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
      ),
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
  }) {
    final cs = Theme.of(context).colorScheme;
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
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : cs.surfaceContainerHighest.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : cs.outlineVariant.withValues(alpha: 0.35),
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
              color: isSelected ? AppColors.primary : cs.outline,
              size: 20,
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isSelected ? AppColors.primary : cs.onSurface,
                        ),
                      ),
                      Text(
                        priceText,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: isSelected ? AppColors.primary : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const Gap(2),
                  Text(
                    deductibleText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
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

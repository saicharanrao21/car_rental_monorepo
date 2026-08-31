import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'booking_protection_section.dart';
import 'booking_addons_section.dart';

class AddonsStep extends ConsumerWidget {
  final CarModel car;
  final VendorModel vendor;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const AddonsStep({
    super.key,
    required this.car,
    required this.vendor,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(DDSSpacing.md, DDSSpacing.md, DDSSpacing.md, DDSSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your protection coverage tier and optional trip amenities.',
            style: DDSTypography.bodyMedium.copyWith(
              color: DDSColors.textSecondary,
              height: 1.4,
              fontSize: 12,
            ),
          ),
          const Gap(DDSSpacing.md),

          // ── Section 1: Protection Packages ─────────────────────────
          BookingProtectionSection(city: vendor.city),
          const Gap(DDSSpacing.md),

          // ── Section 2: Add-ons & Services ──────────────────────────
          const BookingAddonsSection(),
          const Gap(DDSSpacing.md),

          // ── Security & Policy Note ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(DDSSpacing.sm),
            decoration: BoxDecoration(
              color: DDSColors.infoBlueBg,
              borderRadius: DDSRadius.mediumBorderRadius,
              border: Border.all(color: DDSColors.primaryBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_outlined,
                  color: DDSColors.primaryBlue,
                  size: 18,
                ),
                const Gap(DDSSpacing.xs),
                Expanded(
                  child: Text(
                    'All add-ons and protection tiers are authorized server-side and protected by DriveGo escrow policy.',
                    style: DDSTypography.bodyMedium.copyWith(
                      fontSize: 11,
                      color: DDSColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

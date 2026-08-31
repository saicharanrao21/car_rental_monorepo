import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import '../../home_providers.dart';

/// DriveGo Design System (DDS) — Top Rated Fleet Partners Widget
class HomeTopVendorsWidget extends ConsumerWidget {
  const HomeTopVendorsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCity = ref.watch(selectedCityProvider);
    final vendorsVal = ref.watch(topVendorsProvider);

    return vendorsVal.when(
      data: (vendors) {
        if (vendors.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DriveGoSectionHeader(title: 'Top Fleet Partners in $selectedCity'),
            const Gap(12),
            SizedBox(
              height: 125,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: vendors.length,
                itemBuilder: (context, index) {
                  final vendor = vendors[index];
                  return _VendorCard(vendor: vendor);
                },
              ),
            ),
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DriveGoSectionHeader(title: 'Top Fleet Partners in $selectedCity'),
          const Gap(12),
          const DriveGoLoadingState(variant: DriveGoLoadingVariant.card, itemCount: 1),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final VendorModel vendor;

  const _VendorCard({required this.vendor});

  @override
  Widget build(BuildContext context) {
    final displayName = vendor.displayName ?? vendor.businessName;

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.mediumBorderRadius,
        border: Border.all(color: DDSColors.borderLight),
        boxShadow: DDSElevation.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: DDSTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DDSColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (vendor.verificationStatus.toLowerCase() == 'verified') ...[
                const Gap(4),
                const Icon(
                  Icons.verified_rounded,
                  color: DDSColors.primaryBlue,
                  size: 16,
                ),
              ],
            ],
          ),
          const Gap(4),
          Text(
            vendor.locality != null ? '${vendor.locality}, ${vendor.city}' : vendor.city,
            style: DDSTypography.labelSmall.copyWith(
              color: DDSColors.textMuted,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(8),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: DDSColors.accentAmber),
              const Gap(4),
              Text(
                vendor.rating > 0 ? vendor.rating.toStringAsFixed(1) : 'New Partner',
                style: DDSTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: vendor.rating > 0 ? DDSColors.accentAmber : DDSColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

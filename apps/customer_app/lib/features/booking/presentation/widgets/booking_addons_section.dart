import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';
import '../providers/booking_providers.dart';

class BookingAddonsSection extends ConsumerWidget {
  const BookingAddonsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftProvider);
    final isSelfDrive = draft.tripType == 'Self-Drive';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Trip Add-ons & Convenience',
          style: DDSTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: DDSColors.textPrimary,
          ),
        ),
        const Gap(4),
        Text(
          'Enhance your trip with verified delivery, extra drivers, and gear.',
          style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted, fontSize: 12),
        ),
        const Gap(DDSSpacing.sm),

        // ── Driver Included ──────────────────────────────────────────
        _addonCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Professional Chauffeur',
              style: DDSTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: DDSColors.textPrimary,
              ),
            ),
            subtitle: Text(
              isSelfDrive
                  ? 'Disabled for Self-Drive rentals'
                  : 'Included in your ${draft.tripType} service package',
              style: DDSTypography.bodyMedium.copyWith(fontSize: 11, color: DDSColors.textMuted),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelfDrive
                    ? DDSColors.surfaceSubtle
                    : DDSColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 18,
                color: isSelfDrive ? DDSColors.textMuted : DDSColors.primaryBlue,
              ),
            ),
            value: draft.driverIncluded,
            activeThumbColor: DDSColors.primaryBlue,
            onChanged: isSelfDrive
                ? null
                : (val) => ref
                    .read(bookingDraftProvider.notifier)
                    .update((d) => d.copyWith(driverIncluded: val)),
          ),
        ),
        const Gap(DDSSpacing.sm),

        // ── Doorstep Delivery ─────────────────────────────────────────
        _addonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Doorstep Delivery',
                        style: DDSTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: DDSColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DDSColors.infoBlueBg,
                        borderRadius: DDSRadius.smallBorderRadius,
                      ),
                      child: Text(
                        '+₹400 flat',
                        style: DDSTypography.labelSmall.copyWith(
                          fontSize: 10,
                          color: DDSColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Vehicle delivered directly to your door before trip start',
                  style: DDSTypography.bodyMedium.copyWith(fontSize: 11, color: DDSColors.textMuted),
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: DDSColors.primaryBlue,
                  ),
                ),
                value: draft.hasDoorstepDelivery,
                activeThumbColor: DDSColors.primaryBlue,
                onChanged: (val) async {
                  ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                        hasDoorstepDelivery: val,
                        deliveryFee: val ? (d.deliveryFee > 0 ? d.deliveryFee : 300.0) : 0.0,
                      ));
                  if (val && draft.vendorId.isNotEmpty) {
                    try {
                      final repo = ref.read(bookingRepositoryProvider);
                      final quote = await repo.calculateLocationQuote(
                        vendorId: draft.vendorId,
                        pickupLocationId: draft.pickupHubId,
                        returnLocationId: draft.returnHubId,
                        deliveryAddress: draft.deliveryAddress,
                      );
                      if (quote['deliveryFee'] != null) {
                        final fee = (quote['deliveryFee'] as num).toDouble();
                        ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(deliveryFee: fee));
                      }
                    } catch (_) {}
                  }
                },
              ),
              if (draft.hasDoorstepDelivery) ...[
                const Gap(DDSSpacing.xs),
                TextFormField(
                  initialValue: draft.deliveryAddress,
                  style: DDSTypography.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Delivery Address',
                    hintText: 'Flat / Building, Landmark, Area',
                    prefixIcon:
                        const Icon(Icons.location_on_outlined, size: 18, color: DDSColors.primaryBlue),
                    border: OutlineInputBorder(
                      borderRadius: DDSRadius.mediumBorderRadius,
                      borderSide: const BorderSide(color: DDSColors.borderMedium),
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) async {
                    ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(deliveryAddress: val));
                    if (draft.hasDoorstepDelivery && draft.vendorId.isNotEmpty && val.length > 5) {
                      try {
                        final repo = ref.read(bookingRepositoryProvider);
                        final quote = await repo.calculateLocationQuote(
                          vendorId: draft.vendorId,
                          pickupLocationId: draft.pickupHubId,
                          returnLocationId: draft.returnHubId,
                          deliveryAddress: val,
                        );
                        if (quote['deliveryFee'] != null) {
                          final fee = (quote['deliveryFee'] as num).toDouble();
                          ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(deliveryFee: fee));
                        }
                      } catch (_) {}
                    }
                  },
                ),
              ],
            ],
          ),
        ),
        const Gap(DDSSpacing.sm),

        // ── Additional Driver ─────────────────────────────────────────
        _addonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Additional Driver',
                        style: DDSTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: DDSColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DDSColors.successGreenBg,
                        borderRadius: DDSRadius.smallBorderRadius,
                      ),
                      child: Text(
                        '+₹350 flat',
                        style: DDSTypography.labelSmall.copyWith(
                          fontSize: 10,
                          color: DDSColors.successGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Authorize a secondary driver with verified driving licence',
                  style: DDSTypography.bodyMedium.copyWith(fontSize: 11, color: DDSColors.textMuted),
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: DDSColors.successGreenBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.group_add_outlined,
                    size: 18,
                    color: DDSColors.successGreen,
                  ),
                ),
                value: draft.hasAdditionalDriver,
                activeThumbColor: DDSColors.successGreen,
                onChanged: (val) => ref
                    .read(bookingDraftProvider.notifier)
                    .update((d) => d.copyWith(
                          hasAdditionalDriver: val,
                          additionalDriverFee: val ? 350.0 : 0.0,
                        )),
              ),
              if (draft.hasAdditionalDriver) ...[
                const Gap(DDSSpacing.xs),
                TextFormField(
                  initialValue: draft.additionalDriverName,
                  style: DDSTypography.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Secondary Driver Full Name',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: DDSColors.successGreen),
                    border: OutlineInputBorder(
                      borderRadius: DDSRadius.mediumBorderRadius,
                      borderSide: const BorderSide(color: DDSColors.borderMedium),
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) => ref
                      .read(bookingDraftProvider.notifier)
                      .update((d) => d.copyWith(additionalDriverName: val)),
                ),
                const Gap(DDSSpacing.xs),
                TextFormField(
                  initialValue: draft.additionalDriverLicence,
                  style: DDSTypography.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Driving Licence Number',
                    hintText: 'e.g. MH0220201234567',
                    prefixIcon:
                        const Icon(Icons.credit_card_outlined, size: 18, color: DDSColors.successGreen),
                    border: OutlineInputBorder(
                      borderRadius: DDSRadius.mediumBorderRadius,
                      borderSide: const BorderSide(color: DDSColors.borderMedium),
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) => ref
                      .read(bookingDraftProvider.notifier)
                      .update((d) => d.copyWith(additionalDriverLicence: val)),
                ),
              ],
            ],
          ),
        ),
        const Gap(DDSSpacing.sm),

        // ── Child Seat ────────────────────────────────────────────────
        _addonCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Child Safety Seat',
              style: DDSTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: DDSColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Certified child safety seat for infants and young children',
              style: DDSTypography.bodyMedium.copyWith(fontSize: 11, color: DDSColors.textMuted),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: DDSColors.accentAmber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.child_care,
                size: 18,
                color: DDSColors.accentAmber,
              ),
            ),
            value: draft.childSeat,
            activeThumbColor: DDSColors.primaryBlue,
            onChanged: (val) => ref
                .read(bookingDraftProvider.notifier)
                .update((d) => d.copyWith(childSeat: val)),
          ),
        ),
        const Gap(DDSSpacing.sm),

        // ── Extra Luggage Space ───────────────────────────────────────
        _addonCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Extra Luggage Space',
              style: DDSTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: DDSColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Roof carrier / extra boot space for oversized baggage',
              style: DDSTypography.bodyMedium.copyWith(fontSize: 11, color: DDSColors.textMuted),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.luggage_outlined,
                size: 18,
                color: DDSColors.primaryBlue,
              ),
            ),
            value: draft.extraLuggage,
            activeThumbColor: DDSColors.primaryBlue,
            onChanged: (val) => ref
                .read(bookingDraftProvider.notifier)
                .update((d) => d.copyWith(extraLuggage: val)),
          ),
        ),
      ],
    );
  }

  Widget _addonCard({required Widget child}) {
    return Material(
      color: DDSColors.surfaceCard,
      borderRadius: DDSRadius.largeBorderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DDSSpacing.md, vertical: DDSSpacing.xs),
        decoration: BoxDecoration(
          borderRadius: DDSRadius.largeBorderRadius,
          border: const Border.fromBorderSide(
            BorderSide(color: DDSColors.borderLight),
          ),
          boxShadow: DDSElevation.cardShadow,
        ),
        child: child,
      ),
    );
  }
}

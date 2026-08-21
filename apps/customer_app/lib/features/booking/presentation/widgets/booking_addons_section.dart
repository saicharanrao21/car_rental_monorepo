import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';

class BookingAddonsSection extends ConsumerWidget {
  const BookingAddonsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftProvider);
    final cs = Theme.of(context).colorScheme;
    final isSelfDrive = draft.tripType == 'Self-Drive';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Trip Add-ons & Convenience',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: cs.onSurface,
          ),
        ),
        const Gap(4),
        Text(
          'Enhance your trip with verified delivery, extra drivers, and gear.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const Gap(12),

        // ── Driver Included ──────────────────────────────────────────
        _addonCard(
          cs,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Professional Chauffeur',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: cs.onSurface,
              ),
            ),
            subtitle: Text(
              isSelfDrive
                  ? 'Disabled for Self-Drive rentals'
                  : 'Included in your ${draft.tripType} service package',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelfDrive
                    ? cs.surfaceContainerHighest
                    : AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 18,
                color: isSelfDrive ? cs.outline : AppColors.primary,
              ),
            ),
            value: draft.driverIncluded,
            activeThumbColor: AppColors.primary,
            onChanged: isSelfDrive
                ? null
                : (val) => ref
                    .read(bookingDraftProvider.notifier)
                    .update((d) => d.copyWith(driverIncluded: val)),
          ),
        ),
        const Gap(10),

        // ── Doorstep Delivery ─────────────────────────────────────────
        _addonCard(
          cs,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Text(
                      'Doorstep Delivery',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: cs.onSurface,
                      ),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '+₹400',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Car delivered directly to your home, office, or hotel',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                value: draft.hasDoorstepDelivery,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => ref
                    .read(bookingDraftProvider.notifier)
                    .update((d) => d.copyWith(
                          hasDoorstepDelivery: val,
                          deliveryFee: val ? 400.0 : 0.0,
                        )),
              ),
              if (draft.hasDoorstepDelivery) ...[
                const Gap(8),
                TextFormField(
                  initialValue: draft.deliveryAddress,
                  decoration: InputDecoration(
                    labelText: 'Delivery Address',
                    hintText: 'Flat / Building, Landmark, Area',
                    prefixIcon:
                        const Icon(Icons.location_on_outlined, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) => ref
                      .read(bookingDraftProvider.notifier)
                      .update((d) => d.copyWith(deliveryAddress: val)),
                ),
              ],
            ],
          ),
        ),
        const Gap(10),

        // ── Additional Driver ─────────────────────────────────────────
        _addonCard(
          cs,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Text(
                      'Additional Driver',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: cs.onSurface,
                      ),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '+₹350',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Authorize a secondary driver with verified driving licence',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.group_add_outlined,
                    size: 18,
                    color: Colors.teal,
                  ),
                ),
                value: draft.hasAdditionalDriver,
                activeThumbColor: Colors.teal,
                onChanged: (val) => ref
                    .read(bookingDraftProvider.notifier)
                    .update((d) => d.copyWith(
                          hasAdditionalDriver: val,
                          additionalDriverFee: val ? 350.0 : 0.0,
                        )),
              ),
              if (draft.hasAdditionalDriver) ...[
                const Gap(8),
                TextFormField(
                  initialValue: draft.additionalDriverName,
                  decoration: InputDecoration(
                    labelText: 'Driver Full Name',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) => ref
                      .read(bookingDraftProvider.notifier)
                      .update((d) => d.copyWith(additionalDriverName: val)),
                ),
                const Gap(8),
                TextFormField(
                  initialValue: draft.additionalDriverLicence,
                  decoration: InputDecoration(
                    labelText: 'Driving Licence Number',
                    hintText: 'e.g. MH0220201234567',
                    prefixIcon:
                        const Icon(Icons.credit_card_outlined, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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
        const Gap(10),

        // ── Child Seat ────────────────────────────────────────────────
        _addonCard(
          cs,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Child Safety Seat',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: cs.onSurface,
              ),
            ),
            subtitle: Text(
              'Certified child safety seat for infants and young children',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.child_care,
                size: 18,
                color: AppColors.accent,
              ),
            ),
            value: draft.childSeat,
            activeThumbColor: AppColors.primary,
            onChanged: (val) => ref
                .read(bookingDraftProvider.notifier)
                .update((d) => d.copyWith(childSeat: val)),
          ),
        ),
        const Gap(10),

        // ── Extra Luggage Space ───────────────────────────────────────
        _addonCard(
          cs,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Extra Luggage Space',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: cs.onSurface,
              ),
            ),
            subtitle: Text(
              'Roof carrier / extra boot space for oversized baggage',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.luggage_outlined,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            value: draft.extraLuggage,
            activeThumbColor: AppColors.primary,
            onChanged: (val) => ref
                .read(bookingDraftProvider.notifier)
                .update((d) => d.copyWith(extraLuggage: val)),
          ),
        ),
      ],
    );
  }

  Widget _addonCard(ColorScheme cs, {required Widget child}) {
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: child,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';

class AddonsStep extends ConsumerWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;

  const AddonsStep({super.key, required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftProvider);
    final isSelfDrive = draft.tripType == 'Self-Drive';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column( 
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Customise your trip with add-ons',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const Gap(16),

          // ── Driver ──────────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Driver Included',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                isSelfDrive
                    ? 'Disabled for Self-Drive trips'
                    : 'A professional driver will accompany you',
                style: const TextStyle(fontSize: 12),
              ),
              secondary: Icon(Icons.person,
                  color: isSelfDrive ? Colors.grey : AppColors.primary),
              value: draft.driverIncluded,
              activeThumbColor: AppColors.primary,
              onChanged: isSelfDrive
                  ? null
                  : (val) => ref
                      .read(bookingDraftProvider.notifier)
                      .update((d) => d.copyWith(driverIncluded: val)),
            ),
          ),
          const Gap(12),

          // ── Child Seat ───────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Child Seat',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Safety seat for children under 12',
                  style: TextStyle(fontSize: 12)),
              secondary: const Icon(Icons.child_care, color: AppColors.accent),
              value: draft.childSeat,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => ref
                  .read(bookingDraftProvider.notifier)
                  .update((d) => d.copyWith(childSeat: val)),
            ),
          ),
          const Gap(12),

          // ── Extra Luggage ────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Extra Luggage Space',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Roof carrier / cargo space for bulky items',
                  style: TextStyle(fontSize: 12)),
              secondary: const Icon(Icons.luggage_outlined, color: AppColors.primary),
              value: draft.extraLuggage,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => ref
                  .read(bookingDraftProvider.notifier)
                  .update((d) => d.copyWith(extraLuggage: val)),
            ),
          ),
          const Gap(12),

          // ── Info note ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
                Gap(8),
                Expanded(
                  child: Text(
                    'Add-ons are illustrative for this UI preview. '
                    'Vendor will confirm availability on contact.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Gap(24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    print('ADDONS_STEP: Back pressed');
                    onBack();
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text('Back',
                      style: TextStyle(color: AppColors.primary)),
                ),
              ),
              const Gap(12),
              Expanded(
                child: AppButton(
                  text: 'Next: Fare',
                  onPressed: () {
                    print('ADDONS_STEP: Next: Fare pressed');
                    onNext();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

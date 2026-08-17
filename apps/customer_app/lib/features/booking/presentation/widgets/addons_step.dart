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

          // ── Doorstep Delivery (Phase 4 Feature 26) ───────────────────
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      const Text('Doorstep Delivery',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Gap(8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('+₹400',
                            style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  subtitle: const Text('Car delivered to your home or hotel',
                      style: TextStyle(fontSize: 12)),
                  secondary: const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
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
                    decoration: const InputDecoration(
                      labelText: 'Delivery Address',
                      hintText: 'Flat / Building, Landmark, Area',
                      prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                      border: OutlineInputBorder(),
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
          const Gap(12),

          // ── Additional Driver (Phase 4 Feature 29) ────────────────────
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      const Text('Additional Driver',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Gap(8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('+₹350',
                            style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  subtitle: const Text('Authorize a secondary driver with verified licence',
                      style: TextStyle(fontSize: 12)),
                  secondary: const Icon(Icons.group_add_outlined, color: Colors.teal),
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
                    decoration: const InputDecoration(
                      labelText: 'Driver Full Name',
                      prefixIcon: Icon(Icons.badge_outlined, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) => ref
                        .read(bookingDraftProvider.notifier)
                        .update((d) => d.copyWith(additionalDriverName: val)),
                  ),
                  const Gap(8),
                  TextFormField(
                    initialValue: draft.additionalDriverLicence,
                    decoration: const InputDecoration(
                      labelText: 'Driving Licence Number',
                      hintText: 'e.g. MH0220201234567',
                      prefixIcon: Icon(Icons.credit_card_outlined, size: 18),
                      border: OutlineInputBorder(),
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
          const Gap(12),

          // ── Protection Packages (Feature 17) ──────────────────────────
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
                    const Gap(8),
                    const Text('DriveGo Protection Package',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Recommended',
                          style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Gap(4),
                const Text(
                  'Choose your coverage level to protect against road accidents & body damage liabilities.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Gap(14),

                // Package Tier 1: Basic (₹0)
                _buildProtectionOption(
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

                // Package Tier 2: Standard (+₹250/day)
                _buildProtectionOption(
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

                // Package Tier 3: Premium Zero-Dep (+₹500/day)
                _buildProtectionOption(
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
          ),
          const Gap(16),

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
                    'All add-ons are authorized server-side and protected by DriveGo insurance & escrow policy.',
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

  Widget _buildProtectionOption(
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : Colors.grey,
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
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        priceText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isSelected ? AppColors.primary : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const Gap(2),
                  Text(
                    deductibleText,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal),
                  ),
                  const Gap(2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
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

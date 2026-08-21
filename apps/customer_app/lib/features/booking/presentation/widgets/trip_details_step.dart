import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';
import 'booking_trip_schedule_card.dart';
import 'booking_mileage_package_selector.dart';

class TripDetailsStep extends ConsumerStatefulWidget {
  final CarModel car;
  final VendorModel vendor;
  final VoidCallback onNext;

  const TripDetailsStep({
    super.key,
    required this.car,
    required this.vendor,
    required this.onNext,
  });

  @override
  ConsumerState<TripDetailsStep> createState() => _TripDetailsStepState();
}

class _TripDetailsStepState extends ConsumerState<TripDetailsStep> {
  @override
  void initState() {
    super.initState();

    // If mileage packages exist and none is selected, auto-select default or first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final currentDraft = ref.read(bookingDraftProvider);
        if (currentDraft.selectedMileagePackageId == null &&
            widget.car.rawMileagePackages.isNotEmpty) {
          final packages = widget.car.rawMileagePackages
              .map((p) => MileagePackageModel.fromJson(
                  Map<String, dynamic>.from(p as Map)))
              .where((p) => p.isActive && p.tripType == currentDraft.tripType)
              .toList();
          if (packages.isNotEmpty) {
            final defaultPkg = packages.firstWhere((p) => p.isDefault,
                orElse: () => packages.first);
            ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                  selectedMileagePackageId: defaultPkg.id,
                  selectedMileagePackage: defaultPkg,
                ));
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Confirm your trip schedule and locations. Your search preferences have been pre-filled below.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const Gap(14),

          // ── Trip Schedule & Location Card ─────────────────────────
          BookingTripScheduleCard(
            car: widget.car,
            vendor: widget.vendor,
          ),
          const Gap(16),

          // ── Mileage Package Selector (or Distance fallback) ─────────
          BookingMileagePackageSelector(
            car: widget.car,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import '../../home_providers.dart';
import '../../../location/presentation/widgets/location_selection_sheet.dart';

/// DriveGo Design System (DDS) — Hero Search & Trip Configuration Card
class HomeTripConfigCard extends ConsumerWidget {
  final VoidCallback onSearchPressed;

  const HomeTripConfigCard({
    super.key,
    required this.onSearchPressed,
  });

  Future<void> _pickDateRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentRange = ref.read(selectedDateRangeProvider);

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: currentRange,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      locale: const Locale('en', 'IN'),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: DDSColors.primaryBlue,
              onPrimary: Colors.white,
              surface: DDSColors.surfaceCard,
              onSurface: DDSColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(selectedDateRangeProvider.notifier).state = picked;
    }
  }

  void _applyQuickDate(WidgetRef ref, String option) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTimeRange range;
    switch (option) {
      case 'Today':
        range = DateTimeRange(start: today, end: today.add(const Duration(days: 1)));
        break;
      case 'Tomorrow':
        final tomorrow = today.add(const Duration(days: 1));
        range = DateTimeRange(start: tomorrow, end: tomorrow.add(const Duration(days: 1)));
        break;
      case 'This Weekend':
        // Calculate upcoming Saturday
        final daysUntilSat = (DateTime.saturday - today.weekday + 7) % 7;
        final sat = today.add(Duration(days: daysUntilSat == 0 ? 7 : daysUntilSat));
        final mon = sat.add(const Duration(days: 2));
        range = DateTimeRange(start: sat, end: mon);
        break;
      case '7 Days':
        range = DateTimeRange(start: today.add(const Duration(days: 1)), end: today.add(const Duration(days: 8)));
        break;
      default:
        return;
    }
    ref.read(selectedDateRangeProvider.notifier).state = range;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCity = ref.watch(selectedCityProvider);
    final tripType = ref.watch(selectedTripTypeProvider);
    final pickupLocation = ref.watch(pickupLocationProvider);
    final dropLocation = ref.watch(dropLocationProvider);
    final dateRange = ref.watch(selectedDateRangeProvider);

    final isOutstationOrAirport = tripType == 'Outstation' || tripType == 'Airport Transfer';

    return Container(
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.largeBorderRadius,
        border: Border.all(color: DDSColors.borderLight),
        boxShadow: DDSElevation.subtleShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Pickup Location Tile ───────────────────────────────────────
          _buildActionTile(
            context: context,
            icon: Icons.location_on_rounded,
            iconColor: DDSColors.accentAmber,
            label: tripType == 'Airport Transfer' ? 'AIRPORT / TERMINAL' : 'PICKUP LOCATION / AREA',
            title: pickupLocation?.isNotEmpty == true
                ? pickupLocation!
                : 'Choose pickup area in $selectedCity',
            isPlaceholder: pickupLocation?.isNotEmpty != true,
            onTap: () {
              LocationSelectionSheet.show(
                context: context,
                title: tripType == 'Airport Transfer' ? 'Select Airport / Terminal' : 'Select Pickup Location',
                initialValue: pickupLocation,
                city: selectedCity,
                onLocationSelected: (loc, {lat, lng}) {
                  ref.read(pickupLocationProvider.notifier).state = loc;
                },
                onStructuredLocationSelected: ({
                  required name,
                  id,
                  address,
                  type,
                  lat,
                  lng,
                  fee,
                  operatingHours,
                }) {
                  ref.read(structuredPickupLocationProvider.notifier).state =
                      StructuredLocationData(
                    name: name,
                    id: id,
                    address: address,
                    type: type,
                    lat: lat,
                    lng: lng,
                    fee: fee,
                    operatingHours: operatingHours,
                  );
                },
              );
            },
          ),

          // ── 2. Optional Drop Location Tile ────────────────────────────────
          if (isOutstationOrAirport) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Divider(height: 1, color: DDSColors.borderLight),
            ),
            _buildActionTile(
              context: context,
              icon: Icons.flag_rounded,
              iconColor: DDSColors.warningOrange,
              label: tripType == 'Outstation' ? 'DESTINATION CITY / ADDRESS' : 'DROP-OFF DESTINATION',
              title: dropLocation?.isNotEmpty == true
                  ? dropLocation!
                  : (tripType == 'Outstation' ? 'e.g. Pune / Lonavala' : 'Enter drop-off destination'),
              isPlaceholder: dropLocation?.isNotEmpty != true,
              onTap: () {
                LocationSelectionSheet.show(
                  context: context,
                  title: tripType == 'Outstation' ? 'Select Destination City / Area' : 'Select Drop Destination',
                  initialValue: dropLocation,
                  city: selectedCity,
                  isDropLocation: true,
                  onLocationSelected: (loc, {lat, lng}) {
                    ref.read(dropLocationProvider.notifier).state = loc;
                  },
                  onStructuredLocationSelected: ({
                    required name,
                    id,
                    address,
                    type,
                    lat,
                    lng,
                    fee,
                    operatingHours,
                  }) {
                    ref.read(structuredDropLocationProvider.notifier).state =
                        StructuredLocationData(
                      name: name,
                      id: id,
                      address: address,
                      type: type,
                      lat: lat,
                      lng: lng,
                      fee: fee,
                      operatingHours: operatingHours,
                    );
                  },
                );
              },
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1, color: DDSColors.borderLight),
          ),

          // ── 3. Rental Schedule Tile ───────────────────────────────────────
          _buildActionTile(
            context: context,
            icon: Icons.calendar_today_rounded,
            iconColor: DDSColors.primaryBlue,
            label: 'RENTAL SCHEDULE',
            title: dateRange != null
                ? '${dateRange.start.toDDMMYYYY()} → ${dateRange.end.toDDMMYYYY()}'
                : 'Select pickup & return dates',
            badgeText: dateRange != null
                ? '${dateRange.duration.inDays} ${dateRange.duration.inDays == 1 ? 'day' : 'days'}'
                : null,
            isPlaceholder: dateRange == null,
            onTap: () => _pickDateRange(context, ref),
          ),

          const Gap(12),

          // ── Quick Date Filter Chips ───────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: [
                _buildQuickDateChip(ref, 'Today'),
                const Gap(8),
                _buildQuickDateChip(ref, 'Tomorrow'),
                const Gap(8),
                _buildQuickDateChip(ref, 'This Weekend'),
                const Gap(8),
                _buildQuickDateChip(ref, '7 Days'),
              ],
            ),
          ),

          const Gap(18),

          // ── 4. Primary Search CTA ─────────────────────────────────────────
          DriveGoButton(
            text: 'Search Available Cars',
            size: DriveGoButtonSize.large,
            icon: const Icon(Icons.search_rounded, size: 20, color: Colors.white),
            onPressed: onSearchPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDateChip(WidgetRef ref, String label) {
    return InkWell(
      onTap: () => _applyQuickDate(ref, label),
      borderRadius: DDSRadius.pillBorderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: DDSColors.surfaceSubtle,
          borderRadius: DDSRadius.pillBorderRadius,
          border: Border.all(color: DDSColors.borderLight),
        ),
        child: Text(
          label,
          style: DDSTypography.labelSmall.copyWith(
            fontSize: 11,
            color: DDSColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String title,
    required bool isPlaceholder,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: DDSRadius.mediumBorderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: DDSRadius.smallBorderRadius,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: DDSTypography.labelSmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: DDSColors.textMuted,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    title,
                    style: DDSTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.w600,
                      color: isPlaceholder ? DDSColors.textMuted : DDSColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (badgeText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: DDSRadius.pillBorderRadius,
                ),
                child: Text(
                  badgeText,
                  style: DDSTypography.labelSmall.copyWith(
                    color: DDSColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Gap(8),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: DDSColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

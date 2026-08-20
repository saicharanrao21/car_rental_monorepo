import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../home_providers.dart';
import '../../../location/presentation/widgets/location_selection_sheet.dart';

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
      firstDate: today.subtract(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 365)),
      locale: const Locale('en', 'IN'),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final selectedCity = ref.watch(selectedCityProvider);
    final tripType = ref.watch(selectedTripTypeProvider);
    final pickupLocation = ref.watch(pickupLocationProvider);
    final dropLocation = ref.watch(dropLocationProvider);
    final dateRange = ref.watch(selectedDateRangeProvider);

    final isOutstationOrAirport = tripType == 'Outstation' || tripType == 'Airport Transfer';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Pickup Location Tile ───────────────────────────────────────
          _buildActionTile(
            context: context,
            icon: Icons.my_location,
            iconColor: AppColors.primary,
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
              );
            },
          ),

          // ── 2. Optional Drop Location Tile ────────────────────────────────
          if (isOutstationOrAirport) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Divider(height: 1),
            ),
            _buildActionTile(
              context: context,
              icon: Icons.flag_outlined,
              iconColor: Colors.orange[800]!,
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
                );
              },
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1),
          ),

          // ── 3. Rental Schedule Tile ───────────────────────────────────────
          _buildActionTile(
            context: context,
            icon: Icons.calendar_today_outlined,
            iconColor: AppColors.primary,
            label: 'RENTAL SCHEDULE',
            title: dateRange != null
                ? '${dateRange.start.toDDMMYYYY()} → ${dateRange.end.toDDMMYYYY()} (${dateRange.duration.inDays} ${dateRange.duration.inDays == 1 ? 'day' : 'days'})'
                : 'Select pickup & return dates',
            isPlaceholder: dateRange == null,
            onTap: () => _pickDateRange(context, ref),
          ),

          const Gap(18),

          // ── 4. Primary CTA ────────────────────────────────────────────────
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: AppColors.primary.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onSearchPressed,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, size: 20, color: Colors.white),
                Gap(8),
                Flexible(
                  child: Text(
                    'Search Available Cars',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  }) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
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
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  const Gap(2),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.w600,
                      color: isPlaceholder ? cs.onSurfaceVariant.withValues(alpha: 0.6) : cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

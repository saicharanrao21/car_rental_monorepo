import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/search_providers.dart';
import '../../../home/home_providers.dart';

class ChooseTripTypeView extends ConsumerWidget {
  const ChooseTripTypeView({super.key});

  bool _isTripTypeEnabled(String type, List<String> enabledTypes) {
    final norm = type.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (norm == 'AIRPORT' || norm == 'AIRPORT_TRANSFER') {
      return enabledTypes.contains('AIRPORT_TRANSFER');
    }
    return enabledTypes.contains(norm);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicSettingsVal = ref.watch(publicSettingsProvider);
    final enabledTripTypes = publicSettingsVal.valueOrNull?.enabledTripTypes ?? const ['SELF_DRIVE', 'OUTSTATION'];

    final tripOptions = [
      (
        type: 'Self-Drive',
        title: 'Self-Drive Cars',
        subtitle: 'Drive yourself with flexible daily & mileage packages',
        icon: Icons.directions_car_rounded,
        badge: 'POPULAR',
      ),
      (
        type: 'Outstation',
        title: 'Outstation Travel',
        subtitle: 'Comfortable long distance rides across cities',
        icon: Icons.alt_route_rounded,
        badge: 'INTERCITY',
      ),
      (
        type: 'Local',
        title: 'Local City Rentals',
        subtitle: 'Hourly and daily rentals within city limits',
        icon: Icons.location_city_rounded,
        badge: null,
      ),
      (
        type: 'Airport Transfer',
        title: 'Airport Transfer',
        subtitle: 'Reliable pickup & drop to and from airports',
        icon: Icons.flight_takeoff_rounded,
        badge: null,
      ),
    ];

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select your trip type to find the best available cars',
            style: DDSTypography.bodyMedium.copyWith(
              color: DDSColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Gap(16),
          ...tripOptions.map((opt) {
            final isEnabled = _isTripTypeEnabled(opt.type, enabledTripTypes);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isEnabled ? DDSColors.surfaceCard : DDSColors.surfaceSubtle,
                  borderRadius: DDSRadius.mediumBorderRadius,
                  border: Border.all(
                    color: isEnabled ? DDSColors.borderLight : DDSColors.borderMedium.withValues(alpha: 0.5),
                  ),
                  boxShadow: isEnabled ? DDSElevation.subtleShadow : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: DDSRadius.mediumBorderRadius,
                    onTap: isEnabled
                        ? () {
                            ref.read(searchTripTypeProvider.notifier).state = opt.type;
                            ref.read(selectedTripTypeProvider.notifier).state = opt.type;
                          }
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${opt.type} service is launching soon in your city!'),
                              ),
                            );
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isEnabled
                                  ? DDSColors.primaryBlue.withValues(alpha: 0.1)
                                  : DDSColors.borderMedium.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              opt.icon,
                              color: isEnabled ? DDSColors.primaryBlue : DDSColors.textMuted,
                              size: 26,
                            ),
                          ),
                          const Gap(16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        opt.title,
                                        style: DDSTypography.titleMedium.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isEnabled ? DDSColors.textPrimary : DDSColors.textMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (opt.badge != null && isEnabled) ...[
                                      const Gap(8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                                          borderRadius: DDSRadius.smallBorderRadius,
                                        ),
                                        child: Text(
                                          opt.badge!,
                                          style: DDSTypography.labelSmall.copyWith(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: DDSColors.primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (!isEnabled) ...[
                                      const Gap(8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: DDSColors.borderMedium.withValues(alpha: 0.3),
                                          borderRadius: DDSRadius.smallBorderRadius,
                                        ),
                                        child: Text(
                                          'COMING SOON',
                                          style: DDSTypography.labelSmall.copyWith(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: DDSColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const Gap(4),
                                Text(
                                  opt.subtitle,
                                  style: DDSTypography.bodyMedium.copyWith(
                                    fontSize: 12,
                                    color: isEnabled ? DDSColors.textSecondary : DDSColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: isEnabled ? DDSColors.primaryBlue : DDSColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

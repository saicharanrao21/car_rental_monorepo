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
    final cs = Theme.of(context).colorScheme;
    final publicSettingsVal = ref.watch(publicSettingsProvider);
    final enabledTripTypes = publicSettingsVal.valueOrNull?.enabledTripTypes ?? const ['SELF_DRIVE', 'OUTSTATION'];

    final tripOptions = [
      (
        type: 'Self-Drive',
        title: 'Self-Drive Cars',
        subtitle: 'Drive yourself with flexible daily & mileage packages',
        icon: Icons.directions_car_outlined,
        badge: 'Popular',
      ),
      (
        type: 'Outstation',
        title: 'Outstation Travel',
        subtitle: 'Comfortable long distance rides across cities',
        icon: Icons.alt_route_outlined,
        badge: 'Intercity',
      ),
      (
        type: 'Local',
        title: 'Local City Rentals',
        subtitle: 'Hourly and daily rentals within city limits',
        icon: Icons.location_city_outlined,
        badge: null,
      ),
      (
        type: 'Airport Transfer',
        title: 'Airport Transfer',
        subtitle: 'Reliable pickup & drop to and from airports',
        icon: Icons.flight_takeoff_outlined,
        badge: null,
      ),
    ];

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select your trip type to find the best available cars',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const Gap(16),
          ...tripOptions.map((opt) {
            final isEnabled = _isTripTypeEnabled(opt.type, enabledTripTypes);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isEnabled ? cs.outline.withValues(alpha: 0.18) : cs.outline.withValues(alpha: 0.1),
                  ),
                  boxShadow: isEnabled
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
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
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              opt.icon,
                              color: isEnabled ? AppColors.primary : cs.onSurfaceVariant.withValues(alpha: 0.4),
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
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isEnabled ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (opt.badge != null && isEnabled) ...[
                                      const Gap(8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          opt.badge!,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (!isEnabled) ...[
                                      const Gap(8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Coming Soon',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const Gap(4),
                                Text(
                                  opt.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isEnabled ? cs.onSurfaceVariant : cs.onSurfaceVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: isEnabled ? AppColors.primary : cs.onSurfaceVariant.withValues(alpha: 0.25),
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

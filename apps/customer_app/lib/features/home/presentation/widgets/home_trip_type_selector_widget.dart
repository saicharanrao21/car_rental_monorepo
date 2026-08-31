import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../home_providers.dart';

/// DriveGo Design System (DDS) — Trip Type Selector for Customer Home
class HomeTripTypeSelectorWidget extends ConsumerWidget {
  const HomeTripTypeSelectorWidget({super.key});

  bool _isTripTypeEnabled(String type, List<String> enabledTypes) {
    final norm = type.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (norm == 'AIRPORT' || norm == 'AIRPORT_TRANSFER') {
      return enabledTypes.contains('AIRPORT_TRANSFER');
    }
    return enabledTypes.contains(norm);
  }

  IconData _getTripTypeIcon(String type) {
    switch (type) {
      case 'Self-Drive':
        return Icons.directions_car_rounded;
      case 'Outstation':
        return Icons.alt_route_rounded;
      case 'Local':
        return Icons.location_city_rounded;
      case 'Airport Transfer':
      case 'Airport':
        return Icons.flight_takeoff_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTripType = ref.watch(selectedTripTypeProvider);
    final publicSettingsVal = ref.watch(publicSettingsProvider);
    final enabledTripTypes = publicSettingsVal.valueOrNull?.enabledTripTypes ?? const ['SELF_DRIVE', 'OUTSTATION'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DDSColors.surfaceSubtle,
        borderRadius: DDSRadius.largeBorderRadius,
        border: Border.all(color: DDSColors.borderLight),
      ),
      child: Row(
        children: AppConstants.tripTypes.map((type) {
          final isEnabled = _isTripTypeEnabled(type, enabledTripTypes);
          final isSelected = isEnabled && type == currentTripType;

          return Expanded(
            child: Semantics(
              button: true,
              label: '$type Trip Option${isEnabled ? (isSelected ? ", Selected" : "") : ", Coming Soon"}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isEnabled
                    ? () => ref.read(selectedTripTypeProvider.notifier).state = type
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$type service is launching soon in your city!'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: DDSRadius.smallBorderRadius),
                          ),
                        );
                      },
                child: AnimatedContainer(
                  duration: DDSMotion.fast,
                  curve: DDSMotion.standardCurve,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? DDSColors.primaryBlue : Colors.transparent,
                    borderRadius: DDSRadius.mediumBorderRadius,
                    boxShadow: isSelected ? DDSElevation.subtleShadow : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTripTypeIcon(type),
                        size: 20,
                        color: isEnabled
                            ? (isSelected ? Colors.white : DDSColors.textSecondary)
                            : DDSColors.textMuted,
                      ),
                      const Gap(4),
                      Text(
                        type,
                        style: DDSTypography.labelSmall.copyWith(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isEnabled
                              ? (isSelected ? Colors.white : DDSColors.textPrimary)
                              : DDSColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isEnabled) ...[
                        const Gap(2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: DDSColors.accentAmber,
                            borderRadius: DDSRadius.smallBorderRadius,
                          ),
                          child: const Text(
                            'Soon',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

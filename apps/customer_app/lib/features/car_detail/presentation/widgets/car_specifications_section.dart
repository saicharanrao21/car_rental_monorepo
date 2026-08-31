import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

class CarSpecificationsSection extends StatelessWidget {
  final CarModel car;

  const CarSpecificationsSection({
    super.key,
    required this.car,
  });

  @override
  Widget build(BuildContext context) {
    final specs = [
      (
        icon: Icons.people_outline,
        title: 'Seating',
        value: '${car.seating} Seats',
      ),
      (
        icon: Icons.local_gas_station_outlined,
        title: 'Fuel Type',
        value: car.fuelType.isNotEmpty ? car.fuelType : 'Petrol',
      ),
      (
        icon: Icons.ac_unit,
        title: 'Air Conditioning',
        value: car.isAC ? 'Climate Control AC' : 'Non-AC',
      ),
      (
        icon: Icons.directions_car_outlined,
        title: 'Body Style',
        value: car.type,
      ),
      (
        icon: Icons.calendar_month_outlined,
        title: 'Model Year',
        value: car.year.toString(),
      ),
      if (car.distanceKm != null)
        (
          icon: Icons.near_me_outlined,
          title: 'Distance',
          value: '${car.distanceKm!.toStringAsFixed(1)} km away',
        )
      else
        (
          icon: Icons.speed_outlined,
          title: 'Transmission',
          value: 'Manual / Automatic',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle Specifications',
          style: DDSTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: DDSColors.textPrimary,
          ),
        ),
        const Gap(12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.4,
            crossAxisSpacing: DDSSpacing.xs,
            mainAxisSpacing: DDSSpacing.xs,
          ),
          itemCount: specs.length,
          itemBuilder: (context, index) {
            final spec = specs[index];
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DDSSpacing.sm,
                vertical: DDSSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: DDSColors.surfaceCard,
                borderRadius: BorderRadius.circular(DDSRadius.medium),
                border: Border.all(color: DDSColors.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DDSSpacing.xs - 1),
                    decoration: const BoxDecoration(
                      color: DDSColors.infoBlueBg,
                      borderRadius: BorderRadius.all(Radius.circular(DDSRadius.small)),
                    ),
                    child: Icon(
                      spec.icon,
                      size: 18,
                      color: DDSColors.primaryBlue,
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          spec.title,
                          style: DDSTypography.labelSmall.copyWith(
                            color: DDSColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Gap(2),
                        Text(
                          spec.value,
                          style: DDSTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: DDSColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

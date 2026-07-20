import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../providers/fleet_providers.dart';

class FleetListPage extends ConsumerWidget {
  const FleetListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(fleetControllerProvider);
    final isGrid = ref.watch(fleetViewGridModeProvider);
    final carsAsync = ref.watch(fleetCarsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Fleet'),
        actions: [
          IconButton(
            icon: Icon(isGrid ? Icons.list : Icons.grid_view),
            tooltip: isGrid ? 'Show List' : 'Show Grid',
            onPressed: () {
              ref.read(fleetViewGridModeProvider.notifier).state = !isGrid;
            },
          ),
        ],
      ),
      body: carsAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, stack) => Center(
          child: ErrorStateWidget(
            message: 'Failed to load fleet cars',
            onRetry: () => ref.invalidate(fleetCarsProvider),
          ),
        ),
        data: (cars) {
          if (cars.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: EmptyStateWidget(
                  icon: Icons.directions_car,
                  title: 'No cars yet',
                  subtitle: 'Add your first car to start earning!',
                  actionText: 'Add Car',
                  onActionPressed: () => context.push('/fleet/add'),
                ),
              ),
            );
          }

          if (isGrid) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.70,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: cars.length,
              itemBuilder: (context, index) {
                final car = cars[index];
                return _buildGridCarCard(context, ref, car);
              },
            );
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cars.length,
              itemBuilder: (context, index) {
                final car = cars[index];
                return _buildListCarCard(context, ref, car);
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/fleet/add'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Grid layout card
  Widget _buildGridCarCard(BuildContext context, WidgetRef ref, CarModel car) {
    return AppCard(
      onTap: () => context.push('/fleet/${car.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image / Placeholder
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: const Icon(Icons.directions_car, size: 48, color: Colors.grey),
            ),
          ),
          // Info details
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${car.make} ${car.model}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Gap(2),
                      Text(
                        car.type,
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${car.pricePerDay.toStringAsFixed(0)}/d',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.accent),
                      ),
                      // Availability toggle
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: car.isAvailable,
                            activeThumbColor: Colors.white,
                            activeTrackColor: Colors.green,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Colors.red[200],
                            onChanged: (val) {
                              ref.read(fleetControllerProvider.notifier).toggleAvailability(car.id, val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // List layout card (wrapping and adding switch to resemble ui_kit CarCard)
  Widget _buildListCarCard(BuildContext context, WidgetRef ref, CarModel car) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/fleet/${car.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Icon(Icons.directions_car, size: 70, color: Colors.grey),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${car.make} ${car.model}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          car.type,
                          style: const TextStyle(color: AppColors.primary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const Gap(8),
                  Row(
                    children: [
                      const Icon(Icons.event_seat, size: 16, color: Colors.grey),
                      const Gap(4),
                      Text('${car.seating} Seats'),
                      const Gap(16),
                      const Icon(Icons.ac_unit, size: 16, color: Colors.grey),
                      const Gap(4),
                      Text(car.isAC ? 'AC' : 'Non-AC'),
                    ],
                  ),
                  const Gap(16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Starts from', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            '₹${car.pricePerDay.toStringAsFixed(0)}/day',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                          ),
                        ],
                      ),
                      // Availability block
                      Row(
                        children: [
                          Text(
                            car.isAvailable ? 'Available' : 'Unavailable',
                            style: TextStyle(
                              color: car.isAvailable ? Colors.green[700] : Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Gap(8),
                          Switch(
                            value: car.isAvailable,
                            activeThumbColor: Colors.white,
                            activeTrackColor: Colors.green,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Colors.red[200],
                            onChanged: (val) {
                              ref.read(fleetControllerProvider.notifier).toggleAvailability(car.id, val);
                            },
                          ),
                        ],
                      ),
                    ],
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

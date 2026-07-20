import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/fleet_providers.dart';

class FleetCarDetailPage extends ConsumerStatefulWidget {
  final String carId;

  const FleetCarDetailPage({super.key, required this.carId});

  @override
  ConsumerState<FleetCarDetailPage> createState() => _FleetCarDetailPageState();
}

class _FleetCarDetailPageState extends ConsumerState<FleetCarDetailPage> {
  DateTime _focusedDay = DateTime.now();
  bool _isToggling = false;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(fleetCarsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Details'),
      ),
      body: carsAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, stack) => Center(
          child: ErrorStateWidget(
            message: 'Failed to load car details',
            onRetry: () => ref.invalidate(fleetCarsProvider),
          ),
        ),
        data: (cars) {
          final index = cars.indexWhere((c) => c.id == widget.carId);
          if (index == -1) {
            return const Center(child: Text('Car not found'));
          }
          final car = cars[index];

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Car header/image area
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.directions_car, size: 100, color: Colors.grey),
                      ),
                    ),
                    const Gap(24),

                    // Make & Model
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${car.make} ${car.model}',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const Gap(4),
                              Text(
                                'Year ${car.year} | ${car.fuelType} | ${car.type}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (car.isAvailable ? Colors.green : Colors.red).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: (car.isAvailable ? Colors.green : Colors.red).withValues(alpha: 0.24), width: 1),
                          ),
                          child: Text(
                            car.isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                            style: TextStyle(
                              color: car.isAvailable ? Colors.green : Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(24),

                    // Specifications
                    const Text('Specifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Gap(12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpecTile(Icons.event_seat, '${car.seating} Seats'),
                        ),
                        const Gap(12),
                        Expanded(
                          child: _buildSpecTile(Icons.ac_unit, car.isAC ? 'Air Conditioning' : 'No AC'),
                        ),
                      ],
                    ),
                    const Gap(24),

                    // Pricing
                    const Text('Pricing Rates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Gap(12),
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildPriceRow('Per Hour Rate', car.pricePerHour),
                            const Divider(height: 24),
                            _buildPriceRow('Per Day Rate', car.pricePerDay),
                            const Divider(height: 24),
                            _buildPriceRow('Per KM Rate', car.pricePerKm),
                          ],
                        ),
                      ),
                    ),
                    const Gap(24),

                    // Trip Types
                    const Text('Available Trip Types', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Gap(12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: car.availableTripTypes.map((type) {
                        return Chip(
                          label: Text(type),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                        );
                      }).toList(),
                    ),
                    const Gap(24),

                    // Availability Calendar Section
                    const Text('Availability Calendar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Gap(4),
                    Text(
                      'Tap a date to block or unblock it. Blocked dates are highlighted in red.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const Gap(12),
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TableCalendar(
                          firstDay: DateTime.now().subtract(const Duration(days: 365)),
                          lastDay: DateTime.now().add(const Duration(days: 365)),
                          focusedDay: _focusedDay,
                          currentDay: DateTime.now(),
                          calendarFormat: CalendarFormat.month,
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                          selectedDayPredicate: (day) {
                            return car.blockedDates.any((d) => _isSameDay(d, day));
                          },
                           onDaySelected: (selectedDay, focusedDay) async {
                            final isAlreadyBlocked = car.blockedDates.any((d) => _isSameDay(d, selectedDay));
                            final updatedBlocked = List<DateTime>.from(car.blockedDates);
                            if (isAlreadyBlocked) {
                              updatedBlocked.removeWhere((d) => _isSameDay(d, selectedDay));
                            } else {
                              updatedBlocked.add(selectedDay);
                            }

                            final messenger = ScaffoldMessenger.of(context);

                            setState(() {
                              _isToggling = true;
                              _focusedDay = focusedDay;
                            });

                            final success = await ref
                                .read(fleetControllerProvider.notifier)
                                .updateBlockedDates(car.id, updatedBlocked);

                            if (mounted) {
                              setState(() {
                                _isToggling = false;
                              });
                              if (success) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isAlreadyBlocked ? 'Date unblocked' : 'Date blocked successfully',
                                    ),
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to update availability'),
                                  ),
                                );
                              }
                            }
                          },
                          calendarStyle: const CalendarStyle(
                            selectedDecoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            todayDecoration: BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Gap(40),

                    // Edit Button
                    AppButton(
                      text: 'Edit Car Details',
                      onPressed: () => context.push('/fleet/edit/${car.id}'),
                    ),
                    const Gap(20),
                  ],
                ),
              ),
              if (_isToggling)
                Container(
                  color: Colors.black12,
                  child: const Center(
                    child: AppLoader(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpecTile(IconData icon, String text) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const Gap(8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        PriceTag(
          amount: price,
          amountStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

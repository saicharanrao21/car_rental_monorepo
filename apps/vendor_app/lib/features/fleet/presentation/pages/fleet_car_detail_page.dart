import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:models/models.dart';
import '../providers/fleet_providers.dart';

class FleetCarDetailPage extends ConsumerStatefulWidget {
  final String carId;

  const FleetCarDetailPage({super.key, required this.carId});

  @override
  ConsumerState<FleetCarDetailPage> createState() => _FleetCarDetailPageState();
}

class _FleetCarDetailPageState extends ConsumerState<FleetCarDetailPage> {
  DateTime _focusedDay = DateTime.now();
  int _selectedPhotoIndex = 0;
  bool _isToggling = false;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showAvailabilityConfirmDialog(BuildContext context, CarModel car, bool targetState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          targetState ? 'Make Vehicle Available?' : 'Take Vehicle Offline?',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          targetState
              ? 'This vehicle will immediately become visible to customers in search results and available for new bookings.'
              : 'Taking this vehicle offline prevents future customer bookings. Any ongoing or confirmed trips must still be honored.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              setState(() => _isToggling = true);
              final success = await ref
                  .read(fleetControllerProvider.notifier)
                  .toggleAvailability(car.id, targetState);
              if (mounted) {
                setState(() => _isToggling = false);
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? (targetState ? 'Vehicle is now AVAILABLE' : 'Vehicle is now OFFLINE')
                          : 'Failed to update vehicle availability',
                    ),
                    backgroundColor: targetState ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: targetState ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(targetState ? 'Confirm Available' : 'Confirm Offline'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(fleetCarsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Vehicle Details', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Vehicle',
            onPressed: () => context.push('/fleet/edit/${widget.carId}'),
          ),
        ],
      ),
      body: carsAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, stack) => Center(
          child: ErrorStateWidget(
            message: 'Failed to load vehicle details',
            onRetry: () => ref.invalidate(fleetCarsProvider),
          ),
        ),
        data: (cars) {
          final index = cars.indexWhere((c) => c.id == widget.carId);
          if (index == -1) {
            return const Center(child: Text('Vehicle not found in fleet'));
          }
          final car = cars[index];
          final photos = car.photos.isNotEmpty
              ? car.photos
              : ['https://images.unsplash.com/photo-1549399542-7e3f8b79c341'];

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Hero Image / Gallery Section
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              photos[_selectedPhotoIndex.clamp(0, photos.length - 1)],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.directions_car_rounded, size: 80, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                          // Status Badge overlay
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: (car.isAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    car.isAvailable ? Icons.check_circle : Icons.pause_circle_filled,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const Gap(4),
                                  Text(
                                    car.isAvailable ? 'AVAILABLE FOR RENT' : 'OFFLINE',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Gallery thumbnails if multiple
                    if (photos.length > 1) ...[
                      const Gap(10),
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: photos.length,
                          itemBuilder: (ctx, i) {
                            final isSelected = i == _selectedPhotoIndex;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedPhotoIndex = i),
                              child: Container(
                                width: 60,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(photos[i], fit: BoxFit.cover),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const Gap(16),

                    // 2. Identity Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${car.make} ${car.model}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const Gap(4),
                                    Text(
                                      'Year ${car.year} • ${car.type} • ${car.fuelType}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Registration badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                                ),
                                child: Text(
                                  car.registrationNumber.isNotEmpty ? car.registrationNumber : 'MH 12 AB 1234',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          // Availability Switch row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Operational Availability',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  Text(
                                    car.isAvailable
                                        ? 'Active on platform — accepting trip bookings'
                                        : 'Paused — invisible to customer search',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: car.isAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: car.isAvailable,
                                activeThumbColor: const Color(0xFF10B981),
                                onChanged: (val) => _showAvailabilityConfirmDialog(context, car, val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),

                    // 3. Specifications Grid
                    const Text(
                      'Vehicle Specifications',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const Gap(10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpecTile(
                            icon: Icons.event_seat_rounded,
                            title: 'Seating',
                            value: '${car.seating} Passengers',
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: _buildSpecTile(
                            icon: Icons.ac_unit_rounded,
                            title: 'Climate',
                            value: car.isAC ? 'Air Conditioned' : 'Non-AC',
                          ),
                        ),
                      ],
                    ),
                    const Gap(10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpecTile(
                            icon: Icons.local_gas_station_rounded,
                            title: 'Fuel Type',
                            value: car.fuelType,
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: _buildSpecTile(
                            icon: Icons.location_on_rounded,
                            title: 'Hub Location',
                            value: car.pickupLocationName ?? 'Main Service Hub',
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),

                    // 4. Commercial & Pricing Breakdown
                    const Text(
                      'Commercial Rates & Pricing',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const Gap(10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildPriceItem('Daily Rental Rate', car.pricePerDay, '/day'),
                          const Divider(height: 20),
                          _buildPriceItem('Hourly Rate', car.pricePerHour, '/hr'),
                          const Divider(height: 20),
                          _buildPriceItem('Excess Mileage Rate', car.pricePerKm, '/km'),
                        ],
                      ),
                    ),
                    const Gap(16),

                    // 5. Supported Trip Types
                    const Text(
                      'Enabled Trip Types',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const Gap(10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: car.availableTripTypes.map((type) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Text(
                            type,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Gap(20),

                    // 6. Availability & Blocked Dates Calendar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Blocked Dates Management',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Tap any date to block/unblock maintenance or rest days',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        if (car.blockedDates.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              setState(() => _isToggling = true);
                              await ref
                                  .read(fleetControllerProvider.notifier)
                                  .updateBlockedDates(car.id, []);
                              if (mounted) {
                                setState(() => _isToggling = false);
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(content: Text('All blocked dates cleared')),
                                );
                              }
                            },
                            child: const Text('Clear All', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                          ),
                      ],
                    ),
                    const Gap(10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TableCalendar(
                        firstDay: DateTime.now().subtract(const Duration(days: 90)),
                        lastDay: DateTime.now().add(const Duration(days: 365)),
                        focusedDay: _focusedDay,
                        currentDay: DateTime.now(),
                        calendarFormat: CalendarFormat.month,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        selectedDayPredicate: (day) {
                          return car.blockedDates.any((d) => _isSameDay(d, day));
                        },
                        onDaySelected: (selectedDay, focusedDay) async {
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final isAlreadyBlocked = car.blockedDates.any((d) => _isSameDay(d, selectedDay));
                          final updatedBlocked = List<DateTime>.from(car.blockedDates);
                          if (isAlreadyBlocked) {
                            updatedBlocked.removeWhere((d) => _isSameDay(d, selectedDay));
                          } else {
                            updatedBlocked.add(selectedDay);
                          }

                          setState(() {
                            _isToggling = true;
                            _focusedDay = focusedDay;
                          });

                          await ref
                              .read(fleetControllerProvider.notifier)
                              .updateBlockedDates(car.id, updatedBlocked);

                          if (mounted) {
                            setState(() => _isToggling = false);
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  isAlreadyBlocked ? 'Date unblocked' : 'Date successfully marked as BLOCKED',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        calendarStyle: CalendarStyle(
                          selectedDecoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          todayDecoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const Gap(28),

                    // 7. Edit Action Button
                    ElevatedButton.icon(
                      onPressed: () => context.push('/fleet/edit/${car.id}'),
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      label: const Text('Edit Vehicle Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isToggling)
                Container(
                  color: Colors.black26,
                  child: const Center(child: AppLoader()),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpecTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const Gap(2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceItem(String label, double price, String suffix) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF334155)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '₹${price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              suffix,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    );
  }
}

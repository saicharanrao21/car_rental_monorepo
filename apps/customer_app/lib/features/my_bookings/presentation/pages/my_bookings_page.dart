import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import '../providers/my_bookings_providers.dart';

class MyBookingsPage extends ConsumerStatefulWidget {
  const MyBookingsPage({super.key});

  @override
  ConsumerState<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends ConsumerState<MyBookingsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 4 Tabs: Upcoming, Ongoing, Completed, Cancelled
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(myBookingsTabProvider.notifier).state = _tabController.index;
      }
    });

    // Sync provider state back to TabController if initialized differently
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tabController.index = ref.read(myBookingsTabProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(myBookingsTabProvider, (_, nextIndex) {
      if (_tabController.index != nextIndex) {
        _tabController.animateTo(nextIndex);
      }
    });

    final bookingsVal = ref.watch(myBookingsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
          indicatorColor: Colors.white,
          indicatorWeight: 3.0,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: bookingsVal.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 3,
          itemBuilder: (_, __) => const ShimmerCard(),
        ),
        error: (e, st) => ErrorStateWidget(
          message: 'Failed to load bookings: $e',
          onRetry: () => ref.read(myBookingsListProvider.notifier).refresh(),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_car_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap(24),
                    const Text(
                      'No Bookings Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      'Explore our wide selection of cars and book your perfect trip today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap(24),
                    SizedBox(
                      width: 200,
                      child: AppButton(
                        text: 'Browse Cars',
                        onPressed: () {
                          // Navigate to /home
                          context.go('/home');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(myBookingsListProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: BookingCard(
                    booking: booking,
                    carMake: 'Trip',
                    carModel: booking.tripType,
                    partnerName: 'Booking #${booking.id.length > 8 ? booking.id.substring(0, 8) : booking.id}',
                    onTap: () {
                      context.push('/bookings/${booking.id}');
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

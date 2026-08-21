import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import '../providers/my_bookings_providers.dart';
import '../widgets/booking_list_item_card.dart';
import '../widgets/active_trip_hero_card.dart';

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
      if (ref.read(myBookingsTabProvider) != _tabController.index) {
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

  (String, String, IconData) _getEmptyStateContent(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return (
          'No Upcoming Trips',
          'You don\'t have any scheduled trips. Explore cars and plan your next journey.',
          Icons.calendar_month_outlined,
        );
      case 1:
        return (
          'No Active Trips',
          'You don\'t have any trip currently active or ready for handover.',
          Icons.directions_car_outlined,
        );
      case 2:
        return (
          'No Completed Trips',
          'Trips you complete will appear here along with invoices and ratings.',
          Icons.task_alt_outlined,
        );
      case 3:
        return (
          'No Cancelled Bookings',
          'No bookings have been cancelled or refunded.',
          Icons.cancel_outlined,
        );
      default:
        return (
          'No Bookings',
          'You haven\'t made any bookings yet.',
          Icons.directions_car_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep tab controller synchronized with Riverpod state
    ref.listen<int>(myBookingsTabProvider, (_, nextIndex) {
      if (_tabController.index != nextIndex) {
        _tabController.animateTo(nextIndex);
      }
    });

    final currentTab = ref.watch(myBookingsTabProvider);
    final bookingsVal = ref.watch(myBookingsListProvider);
    final activeTrip = ref.watch(activeOngoingTripProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Bookings',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
        ),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => ref.read(myBookingsTabProvider.notifier).state = index,
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
          final (emptyTitle, emptyDesc, emptyIcon) = _getEmptyStateContent(currentTab);

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
                        emptyIcon,
                        size: 56,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap(20),
                    Text(
                      emptyTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      emptyDesc,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap(24),
                    SizedBox(
                      width: 200,
                      child: AppButton(
                        text: 'Explore Cars',
                        onPressed: () => context.go('/home'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final showActiveHero = currentTab == 1 && activeTrip != null;

          return RefreshIndicator(
            onRefresh: () => ref.read(myBookingsListProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length + (showActiveHero ? 1 : 0),
              itemBuilder: (context, index) {
                // If on Ongoing tab and activeTrip is present, show ActiveTripHeroCard as first item
                if (showActiveHero) {
                  if (index == 0) {
                    return ActiveTripHeroCard(
                      item: activeTrip,
                      onRefresh: () => ref.read(myBookingsListProvider.notifier).refresh(),
                    );
                  }
                  final item = bookings[index - 1];
                  return BookingListItemCard(item: item);
                }

                final item = bookings[index];
                return BookingListItemCard(item: item);
              },
            ),
          );
        },
      ),
    );
  }
}

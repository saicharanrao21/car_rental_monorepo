import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:customer_app/features/my_bookings/presentation/pages/my_bookings_page.dart';
import 'package:customer_app/features/my_bookings/presentation/providers/my_bookings_providers.dart';

class MockBookingsNotifier extends MyBookingsListNotifier {
  final List<BookingModel> _initialBookings;
  MockBookingsNotifier(this._initialBookings);

  @override
  Future<List<BookingModel>> build() async {
    final tabIndex = ref.watch(myBookingsTabProvider);
    switch (tabIndex) {
      case 0:
        return _initialBookings.where((b) => b.id == 'bk_upcoming_1').toList();
      case 1:
        return _initialBookings.where((b) => b.id == 'bk_ongoing_1').toList();
      case 2:
        return _initialBookings.where((b) => b.id == 'bk_completed_1').toList();
      case 3:
        return _initialBookings.where((b) => b.id == 'bk_cancelled_1').toList();
      default:
        return [];
    }
  }
}

void main() {
  final sampleBookings = <BookingModel>[
    BookingModel(
      id: 'bk_upcoming_1',
      customerId: 'cust_1',
      carId: 'car_1',
      vendorId: 'vendor_1',
      status: 'confirmed',
      startDate: DateTime.now().add(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      totalFare: 6000,
      platformFee: 600,
      gstAmount: 1080,
      netToVendor: 4320,
      tripType: 'Self-Drive',
      pickupLocation: 'Mumbai Airport',
      dropLocation: 'Mumbai Airport',
      createdAt: DateTime.now(),
    ),
    BookingModel(
      id: 'bk_ongoing_1',
      customerId: 'cust_1',
      carId: 'car_1',
      vendorId: 'vendor_1',
      status: 'ongoing',
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 2)),
      totalFare: 5000,
      platformFee: 500,
      gstAmount: 900,
      netToVendor: 3600,
      tripType: 'Outstation',
      pickupLocation: 'Bandra',
      dropLocation: 'Pune',
      createdAt: DateTime.now(),
    ),
    BookingModel(
      id: 'bk_completed_1',
      customerId: 'cust_1',
      carId: 'car_1',
      vendorId: 'vendor_1',
      status: 'completed',
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      endDate: DateTime.now().subtract(const Duration(days: 2)),
      totalFare: 8000,
      platformFee: 800,
      gstAmount: 1440,
      netToVendor: 5760,
      tripType: 'Self-Drive',
      pickupLocation: 'Mumbai',
      dropLocation: 'Mumbai',
      createdAt: DateTime.now(),
    ),
    BookingModel(
      id: 'bk_cancelled_1',
      customerId: 'cust_1',
      carId: 'car_1',
      vendorId: 'vendor_1',
      status: 'cancelled',
      startDate: DateTime.now().add(const Duration(days: 7)),
      endDate: DateTime.now().add(const Duration(days: 10)),
      totalFare: 4000,
      platformFee: 400,
      gstAmount: 720,
      netToVendor: 2880,
      tripType: 'Local',
      pickupLocation: 'Andheri',
      dropLocation: 'Andheri',
      createdAt: DateTime.now(),
    ),
  ];

  group('My Bookings Active Tab Visual & Functional Tests', () {
    testWidgets('1. Renders all 4 tabs with high-contrast active styling', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          myBookingsListProvider.overrideWith(() => MockBookingsNotifier(sampleBookings)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MyBookingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check all 4 tab labels are present
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Ongoing'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);

      // Verify TabBar configuration
      final tabBarFinder = find.byType(TabBar);
      expect(tabBarFinder, findsOneWidget);
      final tabBar = tester.widget<TabBar>(tabBarFinder);

      expect(tabBar.labelColor, Colors.white);
      expect(tabBar.indicatorColor, Colors.white);
      expect(tabBar.labelStyle?.fontWeight, FontWeight.bold);
      expect(tabBar.unselectedLabelStyle?.fontWeight, FontWeight.normal);
      expect(tabBar.indicatorWeight, 3.0);
      expect(tabBar.indicatorSize, TabBarIndicatorSize.tab);

      // Initial tab is Upcoming (index 0)
      expect(container.read(myBookingsTabProvider), 0);
      expect(find.byType(BookingCard), findsOneWidget);
      expect(find.text('Trip Self-Drive'), findsOneWidget);
    });

    testWidgets('2. Switching through all tabs updates active state and filters bookings cleanly',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          myBookingsListProvider.overrideWith(() => MockBookingsNotifier(sampleBookings)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MyBookingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tab 1: Ongoing
      await tester.tap(find.text('Ongoing'));
      await tester.pumpAndSettle();
      expect(container.read(myBookingsTabProvider), 1);
      expect(find.text('Trip Outstation'), findsOneWidget);

      // Tab 2: Completed
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(container.read(myBookingsTabProvider), 2);
      expect(find.text('Trip Self-Drive'), findsOneWidget);

      // Tab 3: Cancelled
      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();
      expect(container.read(myBookingsTabProvider), 3);
      expect(find.text('Trip Local'), findsOneWidget);

      // Back to Tab 0: Upcoming
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();
      expect(container.read(myBookingsTabProvider), 0);
    });
  });
}

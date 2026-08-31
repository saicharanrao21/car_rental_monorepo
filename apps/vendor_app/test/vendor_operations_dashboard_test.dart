import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:vendor_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:vendor_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:vendor_app/features/dashboard/domain/models/operations_models.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';
import 'package:vendor_app/features/profile/presentation/providers/documents_provider.dart';
import 'package:core/core.dart';

class MockOperationsDashboardRepository implements DashboardRepository {
  List<TriageItem> triageItems = [];
  List<TodayTimelineItem> timelineItems = [];
  bool respondCalled = false;

  @override
  Future<DashboardStats> getStats(String vendorId) async {
    return const DashboardStats(
      todaysBookings: 3,
      pendingRequests: 1,
      thisMonthEarnings: 45000.0,
      activeCars: 8,
      inactiveCars: 2,
    );
  }

  @override
  Future<List<BookingModel>> getLatestBookingRequests(String vendorId, {int limit = 3}) async {
    return [];
  }

  @override
  Future<void> respondToBooking(String bookingId, bool accept) async {
    respondCalled = true;
  }

  @override
  Future<List<TriageItem>> getOperationsTriage(String vendorId) async {
    return triageItems;
  }

  @override
  Future<List<TodayTimelineItem>> getTodayOperations(String vendorId) async {
    return timelineItems;
  }

  @override
  Future<BookingMatrix> getBookingMatrix(String vendorId) async {
    return const BookingMatrix(
      todayCount: 3,
      pendingCount: 1,
      upcomingCount: 4,
      completedCount: 18,
      activeCount: 2,
    );
  }

  @override
  Future<FleetSummary> getFleetSummary(String vendorId) async {
    return const FleetSummary(
      totalCars: 10,
      availableCars: 6,
      onTripCars: 2,
      unavailableCars: 2,
    );
  }

  @override
  Future<EarningsSnapshot> getEarningsSnapshot(String vendorId) async {
    return const EarningsSnapshot(
      thisMonthEarnings: 45000.0,
      availableBalance: 32000.0,
      heldEarnings: 8500.0,
      totalEarnings: 185000.0,
      totalPaidOut: 144500.0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DDSTypography.useSystemFallbackInTests = true;

  group('Vendor Operations Dashboard & Actionable Triage Tests', () {
    late MockOperationsDashboardRepository mockRepo;

    setUp(() {
      mockRepo = MockOperationsDashboardRepository();
    });

    Widget buildTestApp() {
      const testVendor = VendorModel(
        id: 'v-999',
        businessName: 'Apex Premium Fleet',
        ownerName: 'Vikram Mehta',
        city: 'Hyderabad',
        phone: '9876543002',
        verificationStatus: 'verified',
        subscriptionTier: 'PRO',
      );

      return ProviderScope(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(mockRepo),
          vendorSessionProvider.overrideWith(() => MockSessionNotifier(testVendor)),
          vendorDocumentsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          home: DashboardPage(),
        ),
      );
    }

    testWidgets('1. Renders Partner OS Header and Verification Status', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('DriveGo Partner OS'), findsOneWidget);
      expect(find.text('Apex Premium Fleet'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('Hyderabad Hub Operations'), findsOneWidget);
      expect(find.text('Fleet Active'), findsOneWidget);
    });

    testWidgets('2. Displays Action Required items when triage has pending actions', (tester) async {
      mockRepo.triageItems = [
        const TriageItem(
          id: 'pending_101',
          title: 'Booking confirmation required',
          subtitle: '₹4,500 • Mahindra Thar requested',
          priority: TriagePriority.urgent,
          badgeText: 'PENDING ACTION',
          actionLabel: 'Review Request',
          routePath: '/bookings/101',
          vehicleName: 'Mahindra Thar',
          bookingId: '101',
          isBookingAction: true,
        ),
        TriageItem(
          id: 'pickup_102',
          title: 'Pickup scheduled today at 11:30 AM',
          subtitle: 'Tata Nexon • Banjara Hills Hub',
          priority: TriagePriority.high,
          badgeText: 'TODAY PICKUP',
          actionLabel: 'Prepare Handover',
          routePath: '/bookings/102',
          vehicleName: 'Tata Nexon',
          bookingId: '102',
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('ACTION REQUIRED'), findsOneWidget);
      expect(find.text('2 PENDING'), findsOneWidget);
      expect(find.text('Booking confirmation required'), findsOneWidget);
      expect(find.text('₹4,500 • Mahindra Thar requested'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      expect(find.text('Pickup scheduled today at 11:30 AM'), findsOneWidget);
      expect(find.text('Prepare Handover'), findsOneWidget);
    });

    testWidgets('3. Displays Zero-Action State ("You\'re All Caught Up") when no pending actions', (tester) async {
      mockRepo.triageItems = [];

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('ACTION REQUIRED'), findsOneWidget);
      expect(find.text("You're All Caught Up!"), findsOneWidget);
      expect(find.text('No urgent actions required. All operations are running smoothly.'), findsOneWidget);
    });

    testWidgets('4. Renders Booking Operations Matrix and counts', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Booking Operations Matrix'), findsOneWidget);
      expect(find.text('Today\'s Drives'), findsOneWidget);
      expect(find.text('Pending Action'), findsOneWidget);
      expect(find.text('Upcoming Handovers'), findsOneWidget);
      expect(find.text('Completed Trips'), findsOneWidget);
    });

    testWidgets('5. Renders Today\'s Operations Timeline and empty state', (tester) async {
      mockRepo.timelineItems = [
        TodayTimelineItem(
          id: 'time_1',
          bookingId: 'b-101',
          type: TimelineEventType.pickup,
          time: DateTime(2026, 8, 31, 10, 30),
          vehicleName: 'Hyundai Creta SX',
          customerSafeName: 'Ramesh K.',
          hubLocation: 'Hitec City Hub',
          status: 'CONFIRMED',
          tripType: 'Self-Drive',
        ),
      ];

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Today\'s Operations Timeline'), findsOneWidget);
      expect(find.text('LIVE SCHEDULE'), findsOneWidget);
      expect(find.text('Hyundai Creta SX'), findsOneWidget);
      expect(find.text('Customer: Ramesh K. • Hitec City Hub'), findsOneWidget);
    });

    testWidgets('6. Renders Fleet Status & Availability breakdown', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Fleet Status & Availability'), findsOneWidget);
      expect(find.text('10 Total Vehicles'), findsOneWidget);
      expect(find.text('6 Ready for Booking'), findsOneWidget);
      expect(find.text('Ready (6)'), findsOneWidget);
      expect(find.text('On Trip (2)'), findsOneWidget);
      expect(find.text('Offline (2)'), findsOneWidget);
    });

    testWidgets('7. Renders Financial Overview & Earnings Breakdown', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Financial Overview'), findsOneWidget);
      expect(find.text('This Month Net Earnings'), findsOneWidget);
      expect(find.text('Available Balance'), findsOneWidget);
      expect(find.text('₹32000'), findsOneWidget);
      expect(find.text('Pending Settlement'), findsOneWidget);
      expect(find.text('₹8500'), findsOneWidget);
    });

    testWidgets('8. Renders Operational Quick Actions and 24x7 Support', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Operational Quick Actions'), findsOneWidget);
      expect(find.text('+ Add Vehicle'), findsOneWidget);
      expect(find.text('Fleet Manager'), findsOneWidget);
      expect(find.text('Earnings'), findsOneWidget);
      expect(find.text('Branch Hubs'), findsOneWidget);
      expect(find.text('24x7 Partner Operations Support'), findsOneWidget);
    });
  });
}

class MockSessionNotifier extends VendorSessionNotifier {
  final VendorModel _vendor;
  MockSessionNotifier(this._vendor);

  @override
  VendorAuthState build() {
    return VendorAuthState.authenticated(_vendor);
  }
}

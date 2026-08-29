import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:vendor_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:vendor_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';
import 'package:vendor_app/features/profile/presentation/providers/documents_provider.dart';
import 'package:ui_kit/ui_kit.dart';

class FakeDashboardRepository implements DashboardRepository {
  Future<DashboardStats>? getStatsFuture;
  bool shouldFail = false;

  @override
  Future<DashboardStats> getStats(String vendorId) async {
    if (getStatsFuture != null) {
      return getStatsFuture!;
    }
    if (shouldFail) {
      throw Exception('API Failure');
    }
    return const DashboardStats(
      todaysBookings: 5,
      pendingRequests: 2,
      thisMonthEarnings: 15000.0,
      activeCars: 10,
      inactiveCars: 1,
    );
  }

  @override
  Future<List<BookingModel>> getLatestBookingRequests(String vendorId, {int limit = 3}) async {
    return [];
  }

  @override
  Future<void> respondToBooking(String bookingId, bool accept) async {}
}

void main() {
  group('Dashboard Resilience Tests', () {
    late FakeDashboardRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeDashboardRepository();
    });

    Widget createTestWidget() {
      const testVendor = VendorModel(
        id: 'v-123',
        businessName: 'DriveGo Staging Rentals',
        ownerName: 'Amit Shah',
        city: 'Mumbai',
        phone: '9876543001',
        verificationStatus: 'verified',
        subscriptionTier: 'BASIC',
      );

      return ProviderScope(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(fakeRepo),
          vendorSessionProvider.overrideWith(() => MockSessionNotifier(testVendor)),
          vendorDocumentsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          home: DashboardPage(),
        ),
      );
    }

    testWidgets('1. Dashboard shows greeting even when stats are loading (Resilience)', (tester) async {
      final completer = Completer<DashboardStats>();
      fakeRepo.getStatsFuture = completer.future;

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Verify Header is visible (Resilience: greeting is always shown)
      expect(find.text('Hello,'), findsOneWidget);
      expect(find.text('DriveGo Staging Rentals'), findsOneWidget);

      // Verify Stats Row shows loading (Shimmer)
      expect(find.byType(ShimmerCard), findsWidgets);

      // Verify Quick Actions are visible even during stats load
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Add Car'), findsOneWidget);

      // Cleanup
      completer.complete(const DashboardStats(
        todaysBookings: 0, pendingRequests: 0, thisMonthEarnings: 0, activeCars: 0, inactiveCars: 0));
      await tester.pumpAndSettle();
    });

    testWidgets('2. Dashboard shows error in stats row but keeps other parts functional', (tester) async {
      fakeRepo.shouldFail = true;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify Header is still visible
      expect(find.text('Hello,'), findsOneWidget);

      // Verify Stats Row shows error state instead of breaking the whole page
      expect(find.text('Could not load summary stats'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Verify Quick Actions are still visible
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Add Car'), findsOneWidget);
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

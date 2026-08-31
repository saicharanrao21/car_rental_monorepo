import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:vendor_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:vendor_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:vendor_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:vendor_app/features/dashboard/domain/models/operations_models.dart';
import 'package:vendor_app/core/providers/vendor_session_provider.dart';
import 'package:vendor_app/features/profile/presentation/providers/documents_provider.dart';
import 'package:vendor_app/features/bookings/presentation/pages/vendor_bookings_page.dart';
import 'package:vendor_app/features/bookings/presentation/providers/vendor_bookings_providers.dart';
import 'package:vendor_app/features/bookings/domain/repositories/vendor_bookings_repository.dart';
import 'package:vendor_app/features/fleet/presentation/pages/fleet_list_page.dart';
import 'package:vendor_app/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:vendor_app/features/fleet/domain/repositories/fleet_repository.dart';

class FastEvidenceDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardStats> getStats(String vendorId) async {
    return const DashboardStats(
      todaysBookings: 3,
      pendingRequests: 2,
      thisMonthEarnings: 45800.0,
      activeCars: 8,
      inactiveCars: 2,
    );
  }

  @override
  Future<List<BookingModel>> getLatestBookingRequests(String vendorId, {int limit = 3}) async => [];

  @override
  Future<void> respondToBooking(String bookingId, bool accept) async {}

  @override
  Future<List<TriageItem>> getOperationsTriage(String vendorId) async {
    return [
      const TriageItem(
        id: 'triage_urgent_1',
        title: 'Booking confirmation required',
        subtitle: '₹4,500 • Mahindra Thar 4x4 requested for 3 days',
        priority: TriagePriority.urgent,
        badgeText: 'PENDING ACTION',
        actionLabel: 'Review Request',
        routePath: '/bookings/b-101',
        vehicleName: 'Mahindra Thar 4x4',
        bookingId: 'b-101',
        isBookingAction: true,
      ),
      TriageItem(
        id: 'triage_pickup_2',
        title: 'Pickup scheduled today at 11:30 AM',
        subtitle: 'Tata Nexon EV • Banjara Hills Hub',
        priority: TriagePriority.high,
        badgeText: 'TODAY PICKUP',
        actionLabel: 'Prepare Handover',
        routePath: '/bookings/b-102',
        vehicleName: 'Tata Nexon EV',
        timestamp: DateTime(2026, 8, 31, 11, 30),
        bookingId: 'b-102',
      ),
      TriageItem(
        id: 'triage_return_3',
        title: 'Vehicle return due today at 04:30 PM',
        subtitle: 'Hyundai Creta SX • Complete return check',
        priority: TriagePriority.high,
        badgeText: 'RETURN DUE',
        actionLabel: 'Inspect Return',
        routePath: '/bookings/b-103',
        vehicleName: 'Hyundai Creta SX',
        timestamp: DateTime(2026, 8, 31, 16, 30),
        bookingId: 'b-103',
      ),
      const TriageItem(
        id: 'triage_doc_4',
        title: 'Trade License expiring in 6 days',
        subtitle: 'Renew compliance document to avoid listing freeze',
        priority: TriagePriority.today,
        badgeText: 'COMPLIANCE',
        actionLabel: 'Update Document',
        routePath: '/profile',
      ),
    ];
  }

  @override
  Future<List<TodayTimelineItem>> getTodayOperations(String vendorId) async {
    return [
      TodayTimelineItem(
        id: 'timeline_1',
        bookingId: 'b-101',
        type: TimelineEventType.pickup,
        time: DateTime(2026, 8, 31, 10, 30),
        vehicleName: 'Mahindra Thar 4x4',
        registrationNumber: 'TS09EA1001',
        customerSafeName: 'Rahul S.',
        hubLocation: 'Hitec City Hub',
        status: 'CONFIRMED',
        tripType: 'Self-Drive',
      ),
      TodayTimelineItem(
        id: 'timeline_2',
        bookingId: 'b-102',
        type: TimelineEventType.pickup,
        time: DateTime(2026, 8, 31, 11, 30),
        vehicleName: 'Tata Nexon EV',
        registrationNumber: 'TS09EA2002',
        customerSafeName: 'Vikram M.',
        hubLocation: 'Banjara Hills Hub',
        status: 'HANDOVER READY',
        tripType: 'Self-Drive',
      ),
      TodayTimelineItem(
        id: 'timeline_3',
        bookingId: 'b-103',
        type: TimelineEventType.vehicleReturn,
        time: DateTime(2026, 8, 31, 16, 30),
        vehicleName: 'Hyundai Creta SX',
        registrationNumber: 'TS09EA3003',
        customerSafeName: 'Sneha P.',
        hubLocation: 'Jubilee Hills Hub',
        status: 'RETURN PENDING',
        tripType: 'Outstation',
      ),
    ];
  }

  @override
  Future<BookingMatrix> getBookingMatrix(String vendorId) async {
    return const BookingMatrix(
      todayCount: 3,
      pendingCount: 2,
      upcomingCount: 5,
      completedCount: 24,
      activeCount: 4,
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
      thisMonthEarnings: 45800.0,
      availableBalance: 34200.0,
      heldEarnings: 11600.0,
      totalEarnings: 184500.0,
      totalPaidOut: 138700.0,
    );
  }
}

class FastEvidenceBookingsRepository implements VendorBookingsRepository {
  @override
  Future<List<BookingModel>> getBookingsForVendor(String vendorId, {String? statusFilter}) async {
    return [
      BookingModel(
        id: 'b-101',
        customerId: 'c-1',
        vendorId: 'v-999',
        carId: 'car-1',
        tripType: 'Self-Drive',
        pickupLocation: 'Hitec City Hub',
        dropLocation: 'Hitec City Hub',
        startDate: DateTime.now().add(const Duration(hours: 2)),
        endDate: DateTime.now().add(const Duration(days: 3)),
        totalFare: 4500.0,
        platformFee: 450.0,
        gstAmount: 225.0,
        netToVendor: 3825.0,
        status: 'pending',
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      BookingModel(
        id: 'b-102',
        customerId: 'c-2',
        vendorId: 'v-999',
        carId: 'car-2',
        tripType: 'Self-Drive',
        pickupLocation: 'Banjara Hills Hub',
        dropLocation: 'Banjara Hills Hub',
        startDate: DateTime.now().add(const Duration(hours: 1)),
        endDate: DateTime.now().add(const Duration(days: 2)),
        totalFare: 3200.0,
        platformFee: 320.0,
        gstAmount: 160.0,
        netToVendor: 2720.0,
        status: 'confirmed',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }

  @override
  Future<void> updateBookingStatus(String bookingId, String newStatus, {String? handoverOtp, String? reason}) async {}

  @override
  Future<void> rejectBooking(String bookingId, String reason) async {}

  @override
  Future<List<InspectionModel>> getInspections(String bookingId) async => [];

  @override
  Future<InspectionModel> upsertInspection(
    String bookingId, {
    required String type,
    required double odometer,
    required int fuelPercent,
    String? conditionNotes,
    List<String>? damagePhotos,
    bool finalize = true,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> sendHandoverOtp(String bookingId, String otpType) async {}

  @override
  Future<List<DamageClaimModel>> getDamageClaims(String bookingId) async => [];

  @override
  Future<DamageClaimModel> submitDamageClaim(
    String bookingId, {
    required double claimedAmount,
    required String description,
    required List<String> damagePhotos,
    String? vendorNotes,
  }) async {
    throw UnimplementedError();
  }
}

class FastEvidenceFleetRepository implements FleetRepository {
  @override
  Future<List<CarModel>> getCarsForVendor(String vendorId) async {
    return [
      const CarModel(
        id: 'car-1',
        vendorId: 'v-999',
        make: 'Mahindra',
        model: 'Thar 4x4',
        year: 2024,
        type: 'SUV',
        fuelType: 'Diesel',
        seating: 4,
        isAC: true,
        registrationNumber: 'TS09EA1001',
        photos: ['https://images.unsplash.com/photo-1533473359331-0135ef1b58bf'],
        pricePerKm: 16.0,
        pricePerDay: 4500.0,
        pricePerHour: 350.0,
        isAvailable: true,
        availableTripTypes: ['Self-Drive', 'Outstation'],
      ),
      const CarModel(
        id: 'car-2',
        vendorId: 'v-999',
        make: 'Tata',
        model: 'Nexon EV',
        year: 2024,
        type: 'SUV',
        fuelType: 'Electric',
        seating: 5,
        isAC: true,
        registrationNumber: 'TS09EA2002',
        photos: ['https://images.unsplash.com/photo-1549399542-7e3f8b79c341'],
        pricePerKm: 12.0,
        pricePerDay: 3200.0,
        pricePerHour: 250.0,
        isAvailable: true,
        availableTripTypes: ['Self-Drive', 'Local'],
      ),
      const CarModel(
        id: 'car-3',
        vendorId: 'v-999',
        make: 'Toyota',
        model: 'Innova Crysta',
        year: 2023,
        type: 'MUV',
        fuelType: 'Diesel',
        seating: 7,
        isAC: true,
        registrationNumber: 'TS09EA3003',
        photos: ['https://images.unsplash.com/photo-1542282088-72c9c27ed0cd'],
        pricePerKm: 18.0,
        pricePerDay: 5200.0,
        pricePerHour: 400.0,
        isAvailable: false,
        availableTripTypes: ['Outstation', 'Airport Transfer'],
      ),
    ];
  }

  @override
  Future<void> toggleCarAvailability(String carId, bool isAvailable) async {}

  @override
  Future<CarModel> addCar(CarModel car) async => car;

  @override
  Future<CarModel> updateCar(CarModel car) async => car;

  @override
  Future<void> updateBlockedDates(String carId, List<DateTime> blockedDates) async {}

  @override
  Future<void> uploadCarDocument({
    required String carId,
    required String type,
    required String fileUrl,
    DateTime? expiresAt,
  }) async {}

  @override
  Future<List<MileagePackageModel>> getMileagePackages(String carId) async => [];

  @override
  Future<MileagePackageModel> createMileagePackage(String carId, MileagePackageModel package) async => package;

  @override
  Future<MileagePackageModel> updateMileagePackage(String carId, MileagePackageModel package) async => package;

  @override
  Future<void> deleteMileagePackage(String carId, String packageId) async {}
}

class FastSessionNotifier extends VendorSessionNotifier {
  final VendorModel _vendor;
  FastSessionNotifier(this._vendor);

  @override
  VendorAuthState build() {
    return VendorAuthState.authenticated(_vendor);
  }
}

final evidenceDir = Directory(r'd:\Flutter\car_rental_monorepo\docs\evidence\phase29-8-vendor-operations-dashboard\test-harness');

Future<void> saveScreenshot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    // ignore: avoid_print
    print('[EVIDENCE_CAPTURED] ${file.path} (${file.lengthSync()} bytes)');
  });
}

Widget createFramedSubject({
  required Widget child,
  required GlobalKey key,
}) {
  const testVendor = VendorModel(
    id: 'v-999',
    businessName: 'DriveGo Apex Fleet Hub',
    ownerName: 'Vikram Mehta',
    city: 'Hyderabad',
    phone: '9876543002',
    verificationStatus: 'verified',
    subscriptionTier: 'PRO',
  );

  return ProviderScope(
    overrides: [
      dashboardRepositoryProvider.overrideWithValue(FastEvidenceDashboardRepository()),
      vendorBookingsRepositoryProvider.overrideWithValue(FastEvidenceBookingsRepository()),
      fleetRepositoryProvider.overrideWithValue(FastEvidenceFleetRepository()),
      vendorSessionProvider.overrideWith(() => FastSessionNotifier(testVendor)),
      vendorDocumentsProvider.overrideWith((ref) async => []),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: DDSColors.bgCanvas,
      ),
      home: RepaintBoundary(
        key: key,
        child: SizedBox(
          width: 390,
          height: 844,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DDSTypography.useSystemFallbackInTests = true;

  group('DriveGo Phase 29.8 Visual Evidence Capture (10 Screens)', () {
    testWidgets('01_vendor_dashboard.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const DashboardPage()));
      await saveScreenshot(tester, key, '${evidenceDir.path}/01_vendor_dashboard.png');
    });

    testWidgets('02_action_required.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const DashboardPage()));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -120));
      await saveScreenshot(tester, key, '${evidenceDir.path}/02_action_required.png');
    });

    testWidgets('03_booking_attention.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const DashboardPage()));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await saveScreenshot(tester, key, '${evidenceDir.path}/03_booking_attention.png');
    });

    testWidgets('04_todays_operations.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const DashboardPage()));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -480));
      await saveScreenshot(tester, key, '${evidenceDir.path}/04_todays_operations.png');
    });

    testWidgets('05_fleet_snapshot.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const DashboardPage()));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -750));
      await saveScreenshot(tester, key, '${evidenceDir.path}/05_fleet_snapshot.png');
    });

    testWidgets('06_earnings_snapshot.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const DashboardPage()));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1020));
      await saveScreenshot(tester, key, '${evidenceDir.path}/06_earnings_snapshot.png');
    });

    testWidgets('07_notifications.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 390,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Operational Alerts & Dispatch',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: DDSColors.errorRed, borderRadius: BorderRadius.circular(10)),
                            child: const Text('3 NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const Divider(),
                      _buildMockNotification('New booking request received for Mahindra Thar 4x4 (TS09EA1001)', '2 mins ago', Icons.book_online, DDSColors.primaryBlue),
                      _buildMockNotification('Settlement payout of ₹34,200 deposited to HDFC Bank ****5678', '2 hours ago', Icons.payments, DDSColors.successGreen),
                      _buildMockNotification('Trade License expiry warning: 6 days remaining before audit freeze', '1 day ago', Icons.warning_amber, DDSColors.warningOrange),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await saveScreenshot(tester, key, '${evidenceDir.path}/07_notifications.png');
    });

    testWidgets('08_support_entry.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const DashboardPage()));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1350));
      await saveScreenshot(tester, key, '${evidenceDir.path}/08_support_entry.png');
    });

    testWidgets('09_booking_destination.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const VendorBookingsPage()));
      await saveScreenshot(tester, key, '${evidenceDir.path}/09_booking_destination.png');
    });

    testWidgets('10_fleet_destination.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const FleetListPage()));
      await saveScreenshot(tester, key, '${evidenceDir.path}/10_fleet_destination.png');
    });
  });
}

Widget _buildMockNotification(String title, String time, IconData icon, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      ],
    ),
  );
}

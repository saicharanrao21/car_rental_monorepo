import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import 'package:admin_panel/core/widgets/admin_shell.dart';
import 'package:admin_panel/features/coupons/presentation/pages/admin_coupons_page.dart';
import 'package:admin_panel/features/coupons/presentation/providers/admin_coupons_providers.dart';

void main() {
  final sampleCoupons = [
    const CouponModel(
      id: 'cpn_1001',
      code: 'DRIVEGO20',
      description: 'Flat 20% discount on all rentals',
      discountType: 'PERCENTAGE',
      discountValue: 20.0,
      maxDiscountAmount: 1000.0,
      minBookingAmount: 1500.0,
      city: 'Hyderabad',
      tripType: 'RoundTrip',
      carCategory: 'SUV',
      firstBookingOnly: false,
      isActive: true,
      usageCount: 42,
    ),
    const CouponModel(
      id: 'cpn_1002',
      code: 'FIRST500',
      description: 'First booking ₹500 off',
      discountType: 'FIXED',
      discountValue: 500.0,
      minBookingAmount: 2000.0,
      firstBookingOnly: true,
      isActive: false,
      usageCount: 15,
    ),
  ];

  testWidgets('Coupons & Promo Codes Navigation & Page Load via AdminShell', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: '/coupons',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AdminShell(child: child),
          routes: [
            GoRoute(
              path: '/coupons',
              builder: (context, state) => const AdminCouponsPage(),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminCouponsProvider.overrideWith(() => MockCouponsNotifier(sampleCoupons)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify brand and breadcrumbs
    expect(find.text('DRIVEGO CONTROL'), findsOneWidget);
    expect(find.text('Growth & Marketing'), findsWidgets);
    expect(find.text('Coupons & Promo Codes'), findsWidgets);

    // Verify page title and subtitle
    expect(find.text('Coupon & Promo Code Management'), findsOneWidget);
    expect(find.text('Configure discount codes, usage caps, minimum booking thresholds, and promotional restrictions.'), findsOneWidget);

    // Verify Coupon Codes rendered in DataGrid
    expect(find.text('DRIVEGO20'), findsOneWidget);
    expect(find.text('FIRST500'), findsOneWidget);
    expect(find.text('20% OFF'), findsOneWidget);
    expect(find.text('₹500 OFF'), findsOneWidget);

    // Verify Status chips
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('INACTIVE'), findsOneWidget);

    // Verify Create Coupon button exists
    expect(find.widgetWithText(AppButton, 'Create Coupon'), findsOneWidget);

    // Verify Search Bar and Status Filter exist
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('AdminCouponsPage Create Coupon modal renders all DTO input fields', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminCouponsProvider.overrideWith(() => MockCouponsNotifier(sampleCoupons)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AdminCouponsPage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Create Coupon button
    await tester.tap(find.widgetWithText(AppButton, 'Create Coupon'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify Drawer / Modal opens with title
    expect(find.text('Configure promotional discount codes'), findsOneWidget);
    expect(find.text('Coupon Code'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Discount (%)'), findsOneWidget);
    expect(find.text('Max Discount (₹)'), findsOneWidget);
    expect(find.text('Min Booking (₹)'), findsOneWidget);
    expect(find.text('First Booking Only'), findsOneWidget);
    expect(find.text('Active Status'), findsOneWidget);
  });
}

class MockCouponsNotifier extends AdminCouponsNotifier {
  final List<CouponModel> _initial;
  MockCouponsNotifier(this._initial);

  @override
  Future<List<CouponModel>> build() async {
    return _initial;
  }

  @override
  Future<void> createCoupon(Map<String, dynamic> couponData) async {}

  @override
  Future<void> updateCoupon(String id, Map<String, dynamic> couponData) async {}

  @override
  Future<void> deleteCoupon(String id) async {}

  @override
  Future<void> toggleStatus(String id, bool isActive) async {}

  @override
  Future<void> archiveCoupon(String id) async {}

  @override
  Future<Map<String, dynamic>> fetchCouponUsages(String id, {int skip = 0, int take = 50}) async {
    return {
      'coupon': {'id': id, 'code': 'DRIVEGO20', 'usageCount': 1},
      'total': 1,
      'usages': [
        {
          'id': 'usg_1',
          'discountAmount': 400.0,
          'usedAt': '2026-09-19T10:00:00.000Z',
          'customerName': 'Test Customer',
          'bookingTotalFare': 2000.0,
          'carName': 'Hyundai Creta',
        }
      ],
    };
  }
}

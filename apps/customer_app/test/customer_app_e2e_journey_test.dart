import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:customer_app/core/providers/session_provider.dart';
import 'package:customer_app/features/home/home_providers.dart';
import 'package:customer_app/features/home/domain/repositories/home_repository.dart';
import 'package:customer_app/features/home/presentation/widgets/home_header_widget.dart';
import 'package:customer_app/features/home/presentation/widgets/home_trip_type_selector_widget.dart';
import 'package:customer_app/features/home/presentation/widgets/home_banners_carousel_widget.dart';
import 'package:customer_app/features/home/presentation/widgets/home_quick_categories_widget.dart';
import 'package:customer_app/features/home/presentation/widgets/home_top_vendors_widget.dart';
import 'package:customer_app/features/search/presentation/providers/search_providers.dart';
import 'package:customer_app/features/search/domain/repositories/search_repository.dart';
import 'package:customer_app/features/search/presentation/pages/search_results_page.dart';
import 'package:customer_app/features/car_detail/presentation/providers/car_detail_providers.dart';
import 'package:customer_app/features/car_detail/domain/repositories/car_detail_repository.dart';
import 'package:customer_app/features/car_detail/presentation/pages/car_detail_page.dart';
import 'package:customer_app/features/car_detail/presentation/widgets/selected_trip_summary_card.dart';
import 'package:customer_app/features/booking/presentation/providers/booking_providers.dart';
import 'package:customer_app/features/booking/domain/repositories/booking_repository.dart';
import 'package:customer_app/features/booking/presentation/widgets/fulfillment_selection_card.dart';
import 'package:customer_app/features/booking/presentation/widgets/booking_price_breakdown_card.dart';
import 'package:customer_app/features/booking/presentation/pages/booking_confirmation_page.dart';
import 'package:customer_app/features/my_bookings/domain/repositories/my_bookings_repository.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_header_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_actions_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_pricing_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_refund_tracker_card.dart';
import 'package:customer_app/features/wallet/data/wallet_repository.dart';
import 'package:customer_app/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:customer_app/features/wallet/presentation/pages/wallet_page.dart';
import 'package:customer_app/features/profile/presentation/pages/profile_page.dart';
import 'package:customer_app/features/profile/presentation/pages/kyc_upload_page.dart';
import 'package:customer_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:customer_app/features/referral/presentation/providers/referral_providers.dart';
import 'package:customer_app/features/wishlist/wishlist_providers.dart';

// ============================================================================
// E2E TEST FIXTURES & MOCK SERVICES
// ============================================================================

const kE2EUser = UserModel(
  id: 'cust_priya_e2e',
  name: 'Priya Sharma',
  phone: '+919876543210',
  email: 'priya.sharma@example.com',
  role: 'customer',
  profilePhoto: null,
);

const kE2EVendor = VendorModel(
  id: 'vendor_royal_e2e',
  businessName: 'Royal Fleet Rentals',
  ownerName: 'Vikram Patel',
  city: 'Bengaluru',
  phone: '+919123456780',
  verificationStatus: 'verified',
  rating: 4.9,
  totalTrips: 182,
);

const kE2ECar = CarModel(
  id: 'car_e2e_creta',
  vendorId: 'vendor_royal_e2e',
  make: 'Hyundai',
  model: 'Creta SX',
  year: 2024,
  type: 'SUV',
  fuelType: 'Diesel',
  seating: 5,
  isAC: true,
  photos: ['https://example.com/creta.jpg'],
  pricePerKm: 14.0,
  pricePerDay: 3000.0,
  pricePerHour: 220.0,
  registrationNumber: 'KA-01-MJ-9988',
  isAvailable: true,
  availableTripTypes: ['SELF_DRIVE', 'LOCAL', 'OUTSTATION'],
  blockedDates: [],
);

final kE2EReview = ReviewModel(
  id: 'rev_1',
  bookingId: 'bk_rev_1',
  customerId: 'cust_rev_1',
  vendorId: 'vendor_royal_e2e',
  rating: 5.0,
  comment: 'Immaculately maintained vehicle, smooth handover!',
  createdAt: DateTime(2026, 8, 15),
);

class E2EHomeRepo implements HomeRepository {
  @override
  Future<List<CarModel>> getCarsByCity(String city, {double? lat, double? lng, String sortBy = 'RECOMMENDED'}) async => [kE2ECar];

  @override
  Future<List<VendorModel>> getTopVendorsByCity(String city) async => [kE2EVendor];

  @override
  Future<List<BannerModel>> getBanners() async => [
        const BannerModel(
          id: 'banner_e2e_1',
          imageUrl: 'https://example.com/banner1.jpg',
          title: 'Special Weekend Deal',
          ctaLink: '/search?tripType=Self-Drive',
          displayOrder: 1,
        ),
      ];

  @override
  Future<List<SupportedCityModel>> getSupportedCities() async => [
        const SupportedCityModel(id: 'c_blr', name: 'Bengaluru', state: 'Karnataka', latitude: 12.9716, longitude: 77.5946),
        const SupportedCityModel(id: 'c_mum', name: 'Mumbai', state: 'Maharashtra', latitude: 19.0760, longitude: 72.8777),
      ];

  @override
  Future<SupportedCityModel> getNearestCity(double lat, double lng) async => const SupportedCityModel(
        id: 'c_blr',
        name: 'Bengaluru',
        state: 'Karnataka',
        latitude: 12.9716,
        longitude: 77.5946,
      );

  @override
  Future<PublicSettingsModel> getPublicSettings() async => const PublicSettingsModel(
        platformName: 'DriveGo',
        supportEmail: 'support@drivego.in',
        supportPhone: '+91 9876543210',
        enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
      );
}

class E2ESearchRepo implements SearchRepository {
  @override
  Future<List<CarModel>> searchCars({
    required String city,
    double? lat,
    double? lng,
    String? tripType,
    DateTime? startDate,
    DateTime? endDate,
    String? carType,
    bool? isAC,
    String? fuelType,
    int? seating,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    required String sortBy,
  }) async => [kE2ECar];
}

class E2ECarDetailRepo implements CarDetailRepository {
  @override
  Future<CarModel> getCarById(String id) async => kE2ECar;

  @override
  Future<VendorModel> getVendorById(String vendorId) async => kE2EVendor;

  @override
  Future<List<ReviewModel>> getReviewsForVendor(String vendorId) async => [kE2EReview];
}

class E2EBookingRepo implements BookingRepository {
  BookingModel? lastCreatedBooking;

  @override
  Future<BookingModel> createBooking(BookingModel draft) async {
    lastCreatedBooking = draft.copyWith(id: 'BK_CONFIRMED_E2E_001');
    return lastCreatedBooking!;
  }

  @override
  Future<BookingModel?> getBookingById(String id) async {
    return BookingModel(
      id: id,
      customerId: kE2EUser.id,
      vendorId: kE2EVendor.id,
      carId: kE2ECar.id,
      tripType: 'Self-Drive',
      pickupLocation: 'Indiranagar Hub, Bengaluru',
      dropLocation: 'Indiranagar Hub, Bengaluru',
      startDate: DateTime(2026, 9, 15, 10, 0),
      endDate: DateTime(2026, 9, 17, 10, 0),
      totalFare: 7499.0,
      platformFee: 300.0,
      gstAmount: 1199.0,
      netToVendor: 6000.0,
      status: 'confirmed',
      createdAt: DateTime.now(),
      pickupHubId: 'hub_indiranagar',
      returnHubId: 'hub_indiranagar',
      pickupName: 'Indiranagar Delivery Hub',
      dropName: 'Indiranagar Delivery Hub',
      pickupAddress: 'Plot 104, Indiranagar 100ft Rd, Bengaluru',
      deliveryAddress: 'Plot 104, Indiranagar 100ft Rd, Bengaluru',
      deliveryFee: 350.0,
      pickupFee: 0.0,
      returnFee: 0.0,
      oneWayFee: 0.0,
      deliveryType: 'DOORSTEP_DELIVERY',
    );
  }

  @override
  Future<List<BookingModel>> getBookingsForCustomer(String customerId) async => [
        await getBookingById('BK_CONFIRMED_E2E_001') as BookingModel,
      ];

  @override
  Future<BookingModel> cancelBooking(String bookingId) async =>
      (await getBookingById(bookingId))!.copyWith(status: 'cancelled');

  @override
  Future<CouponValidationResultModel> validateCoupon({
    required String code,
    String? carId,
    double? subtotal,
    String? city,
    String? tripType,
    String? carCategory,
  }) async {
    if (code == 'DRIVEGO500') {
      return CouponValidationResultModel(
        valid: true,
        couponId: 'coup_500',
        code: 'DRIVEGO500',
        description: 'Flat ₹500 off on first ride',
        discountType: 'FLAT',
        discountValue: 500,
        discountAmount: 500,
        finalPayableAmount: (subtotal ?? 6000) - 500,
      );
    }
    return CouponValidationResultModel(
      valid: false,
      couponId: '',
      code: code,
      description: 'Invalid or expired coupon',
      discountType: 'FLAT',
      discountValue: 0,
      discountAmount: 0,
      finalPayableAmount: subtotal ?? 0,
    );
  }

  @override
  Future<Map<String, dynamic>> calculateLocationQuote({
    required String vendorId,
    String? pickupLocationId,
    String? returnLocationId,
    double? customerLatitude,
    double? customerLongitude,
    String? deliveryAddress,
  }) async {
    if (deliveryAddress != null && deliveryAddress.contains('Far Away Out Of Radius')) {
      return {
        'isAvailable': false,
        'distanceKm': 65.0,
        'deliveryFee': 0.0,
        'pickupFee': 0.0,
        'returnFee': 0.0,
        'oneWayFee': 0.0,
        'totalFulfillmentFee': 0.0,
        'reason': 'Delivery location (65 km) exceeds vendor service radius of 30 km.',
      };
    }
    return {
      'isAvailable': true,
      'distanceKm': 8.5,
      'deliveryFee': 350.0,
      'pickupFee': 0.0,
      'returnFee': 0.0,
      'oneWayFee': 0.0,
      'totalFulfillmentFee': 350.0,
    };
  }

  @override
  CommissionConfigModel getCommissionConfig({
    required String city,
    required String carCategory,
    required String tripType,
  }) =>
      CommissionConfigModel(
        id: 'cfg_1',
        tripType: 'All',
        city: 'All',
        carCategory: 'All',
        percentage: 10.0,
        effectiveFrom: DateTime(2026, 1, 1),
      );

  @override
  Future<VehicleAvailabilityResult> checkVehicleAvailability({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    String? hubId,
  }) async =>
      VehicleAvailabilityResult(
        available: true,
        carId: carId,
        startDate: startDate.toIso8601String(),
        endDate: endDate.toIso8601String(),
      );

  @override
  Future<VehicleHoldModel> createVehicleHold({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    int ttlSeconds = 900,
    String? idempotencyKey,
  }) async =>
      VehicleHoldModel(
        id: 'hold_e2e_1',
        carId: carId,
        customerId: kE2EUser.id,
        vendorId: kE2EVendor.id,
        startDate: startDate,
        endDate: endDate,
        expiresAt: DateTime.now().add(Duration(seconds: ttlSeconds)),
        status: 'ACTIVE',
      );

  @override
  Future<bool> releaseVehicleHold(String holdId) async => true;

  @override
  Future<BookingQuoteModel> getQuote({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    String? tripType,
    String? mileagePackageId,
    String? protectionPlanId,
    String? pickupLocationId,
    String? returnLocationId,
    String? deliveryAddress,
    double? customerLatitude,
    double? customerLongitude,
    String? couponCode,
    String? idempotencyKey,
  }) async =>
      BookingQuoteModel(
        quoteId: 'quote_e2e_99',
        tenantId: 'tenant_e2e',
        carId: carId,
        vehicleName: 'Hyundai Creta SX',
        registrationNumber: 'KA-01-MJ-9988',
        tripType: tripType ?? 'Self-Drive',
        startDate: startDate,
        endDate: endDate,
        durationDays: 2,
        durationHours: 48,
        currency: 'INR',
        pricingVersion: 'v2.0',
        subtotal: 6000.0,
        discountTotal: couponCode == 'DRIVEGO500' ? 500.0 : 0.0,
        feesTotal: 350.0,
        taxTotal: 1199.0,
        depositTotal: 3000.0,
        tripFare: 7049.0,
        totalPayable: 10049.0,
        netToVendor: 5400.0,
        status: 'ACTIVE',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

  @override
  Future<BookingQuoteModel> refreshQuote(String quoteId) async => getQuote(
        carId: kE2ECar.id,
        startDate: DateTime(2026, 9, 15, 10),
        endDate: DateTime(2026, 9, 17, 10),
      );

  @override
  Future<BookingQuoteModel?> getQuoteById(String quoteId) async => refreshQuote(quoteId);
}

class E2EWalletRepo implements WalletRepository {
  WalletModel wallet = WalletModel(
    id: 'wlt_priya_e2e',
    userId: kE2EUser.id,
    currency: 'INR',
    availableBalance: 4500.0,
    lockedBalance: 0.0,
    realBalance: 3500.0,
    promoBalance: 1000.0,
    status: WalletStatus.ACTIVE,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 9, 11),
  );

  final List<WalletLedgerEntryModel> transactions = [
    WalletLedgerEntryModel(
      id: 'tx_e2e_refund_1',
      walletId: 'wlt_priya_e2e',
      type: LedgerEntryType.CUSTOMER_DEPOSIT,
      direction: LedgerDirection.CREDIT,
      bucket: WalletBucketType.REAL_MONEY,
      amount: 3000.0,
      balanceBefore: 500.0,
      balanceAfter: 3500.0,
      referenceType: 'REFUND',
      referenceId: 'ref_sec_dep_9912',
      idempotencyKey: 'wallet_refund_dep_9912',
      description: 'Security Deposit Refund for BK_CONFIRMED_E2E_001',
      createdAt: DateTime(2026, 9, 11, 14, 30),
    ),
  ];

  @override
  Future<WalletModel> getWallet() async => wallet;

  @override
  Future<List<WalletLedgerEntryModel>> getTransactions({int page = 1, int limit = 20}) async => transactions;

  @override
  Future<Map<String, dynamic>> createDepositOrder(double amount) async => {
        'orderId': 'order_e2e_dep_1',
        'amount': amount,
        'currency': 'INR',
        'keyId': 'rzp_test_e2eKey',
        'isMock': false,
      };

  @override
  Future<Map<String, dynamic>> verifyDeposit({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async => {
        'success': true,
        'balance': 4500.0,
      };
}

class E2ESessionNotifier extends SessionNotifier {
  final UserModel _user;
  E2ESessionNotifier(this._user);

  @override
  AuthState build() => AuthState.authenticated(_user);

  @override
  Future<void> checkSession() async {}
}

// ============================================================================
// MAIN END-TO-END CUSTOMER JOURNEY TEST SUITE
// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DDSTypography.useSystemFallbackInTests = true;

  Widget wrapWithTheme(
    Widget child, {
    bool isFullPage = false,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => E2ESessionNotifier(kE2EUser)),
        homeRepositoryProvider.overrideWithValue(E2EHomeRepo()),
        searchRepositoryProvider.overrideWithValue(E2ESearchRepo()),
        carDetailRepositoryProvider.overrideWithValue(E2ECarDetailRepo()),
        bookingRepositoryProvider.overrideWithValue(E2EBookingRepo()),
        walletRepositoryProvider.overrideWithValue(E2EWalletRepo()),
        customerWalletProvider.overrideWith((ref) async => E2EWalletRepo().wallet),
        customerWalletTransactionsProvider.overrideWith((ref) async => E2EWalletRepo().transactions),
        kycStatusProvider.overrideWith((ref) async => {'status': 'VERIFIED'}),
        myReferralCodeProvider.overrideWith((ref) async => {'code': 'DGPRIYA1'}),
        wishlistIdsProvider.overrideWith((ref) {
          final notifier = WishlistIdsNotifier(ref);
          notifier.setInitial({'car_e2e_creta'});
          return notifier;
        }),
        selectedCityProvider.overrideWith((ref) => 'Bengaluru'),
        unreadNotificationsCountProvider.overrideWith((ref) => 2),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: isFullPage
            ? child
            : Scaffold(
                body: SingleChildScrollView(child: child),
              ),
      ),
    );
  }

  group('DriveGo Customer App — Autonomous End-to-End (E2E) Journey Suite', () {
    // ------------------------------------------------------------------------
    // SCENARIO 1: HOME DISCOVERY & CITY/CATEGORY SELECTION
    // ------------------------------------------------------------------------
    testWidgets('E2E Step 1: Home Screen renders brand header, category chips, and verified partners', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithTheme(
        Column(
          children: [
            HomeHeaderWidget(onCityTap: () {}),
            const HomeTripTypeSelectorWidget(),
            const HomeBannersCarouselWidget(),
            const HomeQuickCategoriesWidget(),
            const HomeTopVendorsWidget(),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      // Brand Header & City
      expect(find.text('Bengaluru'), findsWidgets);
      expect(find.text('2'), findsOneWidget); // Unread notification badge

      // Trip Type Selector
      expect(find.text('Self-Drive'), findsOneWidget);
      expect(find.text('Outstation'), findsOneWidget);

      // Quick Categories
      expect(find.text('SUV'), findsOneWidget);
      expect(find.text('Luxury'), findsOneWidget);
      expect(find.text('Hatchback'), findsOneWidget);

      // Top Host Partners
      expect(find.text('Royal Fleet Rentals'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 2: SEARCH RESULTS & CAR DISCOVERY
    // ------------------------------------------------------------------------
    testWidgets('E2E Step 2: Search Results displays vehicle listings with specifications and pricing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithTheme(
        const SearchResultsPage(
          city: 'Bengaluru',
          tripType: 'Self-Drive',
          start: '2026-09-15',
          end: '2026-09-17',
          pickup: 'Indiranagar Hub',
          drop: 'Indiranagar Hub',
          category: 'SUV',
        ),
        isFullPage: true,
      ));
      await tester.pumpAndSettle();

      // Search filters and results summary
      expect(find.text('Indiranagar Hub, Bengaluru'), findsOneWidget);
      expect(find.textContaining('Filters'), findsOneWidget);
      expect(find.text('Hyundai Creta SX'), findsWidgets);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 3: VEHICLE DETAILS & SPECIFICATIONS INSPECTION
    // ------------------------------------------------------------------------
    testWidgets('E2E Step 3: Vehicle Details renders specs, verified host badge, and booking bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testRange = DateTimeRange(
        start: DateTime(2026, 9, 15, 10, 0),
        end: DateTime(2026, 9, 17, 10, 0),
      );

      await tester.pumpWidget(wrapWithTheme(
        const CarDetailPage(carId: 'car_e2e_creta'),
        isFullPage: true,
        overrides: [
          searchDatesProvider.overrideWith((ref) => testRange),
          searchTripTypeProvider.overrideWith((ref) => 'Self-Drive'),
        ],
      ));
      await tester.pumpAndSettle();

      // Compact availability and car identity
      expect(find.byType(SelectedTripSummaryCard), findsOneWidget);
      expect(find.text('Available for your schedule'), findsOneWidget);
      expect(find.text('Hyundai Creta SX'), findsWidgets);
      expect(find.text('Royal Fleet Rentals'), findsWidgets);
      expect(find.text('Book Now'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 4: MULTI-STEP BOOKING, FULFILLMENT & PRICING ENGINE
    // ------------------------------------------------------------------------
    testWidgets('E2E Step 4: Fulfillment selection, doorstep quote, coupon discount, and price breakdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const fareResult = FareCalculatorResult(
        baseFare: 6000.0,
        platformFee: 300.0,
        gst: 1080.0,
        total: 7380.0,
        netToVendor: 5400.0,
      );

      final config = CommissionConfigModel(
        id: 'default',
        tripType: 'All',
        city: 'All',
        carCategory: 'All',
        percentage: 10.0,
        effectiveFrom: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(wrapWithTheme(
        Column(
          children: [
            const FulfillmentSelectionCard(
              car: kE2ECar,
              vendor: kE2EVendor,
            ),
            BookingPriceBreakdownCard(
              car: kE2ECar,
              vendor: kE2EVendor,
              originalRentalFare: 6000.0,
              discountPercent: 0.0,
              discountLabel: 'DRIVEGO500',
              discountAmount: 500.0,
              result: fareResult,
              finalPayable: 6880.0,
              config: config,
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      // Fulfillment Card
      expect(find.text('Vehicle Handover & Fulfillment'), findsOneWidget);
      expect(find.text('1. PICKUP METHOD'), findsOneWidget);
      expect(find.text('Doorstep'), findsOneWidget);

      // Price breakdown
      expect(find.text('Price Breakdown'), findsOneWidget);
      expect(find.text('Base Trip Fare'), findsOneWidget);
      expect(find.text('Total Payable Amount'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 5: BOOKING CONFIRMATION & REFERENCE
    // ------------------------------------------------------------------------
    testWidgets('E2E Step 5: Booking Confirmation screen displays reference ID, itinerary and CTAs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithTheme(
        const BookingConfirmationPage(bookingId: 'BK_CONFIRMED_E2E_001'),
        isFullPage: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Payment Successful!'), findsOneWidget);
      expect(find.textContaining('Booking #'), findsOneWidget);
      expect(find.text('Hyundai Creta SX'), findsOneWidget);
      expect(find.text('View My Bookings'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 6: MY BOOKINGS LIFECYCLE — CONFIRMED & HANDOVER PIN
    // ------------------------------------------------------------------------
    testWidgets('E2E Step 6: Confirmed booking renders pickup PIN, inspection checklist and host contact', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final confirmedItem = CustomerBookingItem(
        booking: BookingModel(
          id: 'BK_CONFIRMED_E2E_001',
          customerId: kE2EUser.id,
          vendorId: kE2EVendor.id,
          carId: kE2ECar.id,
          tripType: 'Self-Drive',
          pickupLocation: 'Indiranagar Hub, Bengaluru',
          dropLocation: 'Indiranagar Hub, Bengaluru',
          startDate: DateTime(2026, 9, 15, 10, 0),
          endDate: DateTime(2026, 9, 17, 10, 0),
          totalFare: 7499.0,
          platformFee: 300.0,
          gstAmount: 1199.0,
          netToVendor: 6000.0,
          status: 'confirmed',
          createdAt: DateTime.now(),
        ),
        car: kE2ECar,
        vendor: kE2EVendor,
        paymentStatus: 'CAPTURED',
        razorpayPaymentId: 'pay_rzp_e2e_verified_99',
      );

      await tester.pumpWidget(wrapWithTheme(
        Column(
          children: [
            BookingDetailHeaderCard(item: confirmedItem),
            BookingDetailActionsCard(item: confirmedItem),
            BookingDetailPricingCard(item: confirmedItem),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Hyundai Creta SX'), findsOneWidget);
      expect(find.text('View Pickup Handover PIN'), findsOneWidget);
      expect(find.text('Cancel Booking'), findsOneWidget);
      expect(find.text('PAID & CAPTURED'), findsOneWidget);
      expect(find.textContaining('pay_rzp_e2e_verified_99'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 7: ACTIVE TRIP LIFECYCLE — ONGOING, SOS & RETURN PIN
    // ------------------------------------------------------------------------
    testWidgets('E2E Step 7: Ongoing trip renders extension, return PIN and SOS emergency buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ongoingItem = CustomerBookingItem(
        booking: BookingModel(
          id: 'BK_CONFIRMED_E2E_001',
          customerId: kE2EUser.id,
          vendorId: kE2EVendor.id,
          carId: kE2ECar.id,
          tripType: 'Self-Drive',
          pickupLocation: 'Indiranagar Hub, Bengaluru',
          dropLocation: 'Indiranagar Hub, Bengaluru',
          startDate: DateTime(2026, 9, 15, 10, 0),
          endDate: DateTime(2026, 9, 17, 10, 0),
          totalFare: 7499.0,
          platformFee: 300.0,
          gstAmount: 1199.0,
          netToVendor: 6000.0,
          status: 'ongoing',
          createdAt: DateTime.now(),
        ),
        car: kE2ECar,
        vendor: kE2EVendor,
        paymentStatus: 'CAPTURED',
      );

      await tester.pumpWidget(wrapWithTheme(
        Column(
          children: [
            BookingDetailHeaderCard(item: ongoingItem),
            BookingDetailActionsCard(item: ongoingItem),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Extend Trip Duration'), findsOneWidget);
      expect(find.text('Return PIN'), findsOneWidget);
      expect(find.text('Inspection'), findsOneWidget);
      expect(find.text('Emergency Assistance (SOS)'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 8: TRIP COMPLETION & DEPOSIT REFUND TRACKING
    // ------------------------------------------------------------------------
    testWidgets('E2E Step 8: Completed trip locks mutable actions and displays deposit refund tracker', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final completedItem = CustomerBookingItem(
        booking: BookingModel(
          id: 'BK_CONFIRMED_E2E_001',
          customerId: kE2EUser.id,
          vendorId: kE2EVendor.id,
          carId: kE2ECar.id,
          tripType: 'Self-Drive',
          pickupLocation: 'Indiranagar Hub, Bengaluru',
          dropLocation: 'Indiranagar Hub, Bengaluru',
          startDate: DateTime(2026, 9, 15, 10, 0),
          endDate: DateTime(2026, 9, 17, 10, 0),
          totalFare: 7499.0,
          platformFee: 300.0,
          gstAmount: 1199.0,
          netToVendor: 6000.0,
          status: 'refunded',
          createdAt: DateTime.now(),
        ),
        car: kE2ECar,
        vendor: kE2EVendor,
        paymentStatus: 'REFUNDED',
        cancellationReason: 'Completed trip inspection with zero deductions',
        cancellationFee: 0.0,
        refundAmount: 3000.0,
      );

      await tester.pumpWidget(wrapWithTheme(
        Column(
          children: [
            BookingDetailHeaderCard(item: completedItem),
            BookingDetailActionsCard(item: completedItem),
            BookingRefundTrackerCard(item: completedItem),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      // No mutable transition buttons
      expect(find.text('Extend Trip Duration'), findsNothing);
      expect(find.text('View Pickup Handover PIN'), findsNothing);

      // Refund Tracker
      expect(find.text('Cancellation & Refund Details'), findsOneWidget);
      expect(find.text('REFUND CREDITED'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 9: WALLET & PROFILE INTEGRATION
    // ------------------------------------------------------------------------
    testWidgets('E2E Step 9: Customer Wallet & Profile reflects verified balance and customer data', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Test 9A: Wallet
      await tester.pumpWidget(wrapWithTheme(
        const WalletPage(),
        isFullPage: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('DriveGo Wallet'), findsOneWidget);
      expect(find.text('Available Balance'), findsOneWidget);
      expect(find.text('₹4500.00'), findsOneWidget);
      expect(find.text('Real Cash'), findsOneWidget);

      // Test 9B: Profile
      await tester.pumpWidget(wrapWithTheme(
        const ProfilePage(),
        isFullPage: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('+919876543210'), findsOneWidget);
      expect(find.text('Verified Driver'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 10: EDGE CASE — OUT-OF-RADIUS DELIVERY VALIDATION GUARD
    // ------------------------------------------------------------------------
    testWidgets('E2E Step 10: Fulfillment selection displays authoritative warning when out-of-radius', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockBookingRepo = E2EBookingRepo();

      await tester.pumpWidget(wrapWithTheme(
        const FulfillmentSelectionCard(
          car: kE2ECar,
          vendor: kE2EVendor,
        ),
        overrides: [
          bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
        ],
      ));
      await tester.pumpAndSettle();

      // Tap Doorstep chip
      await tester.tap(find.text('Doorstep'));
      await tester.pumpAndSettle();

      // Enter out-of-radius delivery address
      await tester.enterText(find.byType(TextField), 'Far Away Out Of Radius Hill Station');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      // Assert error message appears
      expect(find.textContaining('exceeds vendor service radius'), findsOneWidget);
    });
  });
}

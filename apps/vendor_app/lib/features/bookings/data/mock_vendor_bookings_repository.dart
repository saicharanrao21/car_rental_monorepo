import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/vendor_bookings_repository.dart';

class MockVendorBookingsRepository with LatencySimulator implements VendorBookingsRepository {
  static List<BookingModel> _fulfillmentMockBookings(String vendorId) {
    final now = DateTime.now();
    return [
      // 1. Host Yard
      BookingModel(
        id: 'bk_mock_host_yard',
        customerId: 'cust_hy_01',
        vendorId: vendorId,
        carId: 'car_hy_01',
        tripType: 'Self-Drive',
        pickupLocation: 'Main Operating Yard, Andheri East',
        dropLocation: 'Main Operating Yard, Andheri East',
        pickupName: 'Main Operating Yard, Andheri East',
        dropName: 'Main Operating Yard, Andheri East',
        pickupAddress: 'Sector 4, Andheri East, Mumbai, Maharashtra 400069',
        pickupLatitude: 19.1136,
        pickupLongitude: 72.8697,
        startDate: now.add(const Duration(hours: 2)),
        endDate: now.add(const Duration(days: 2)),
        totalFare: 4200.0,
        platformFee: 420.0,
        gstAmount: 756.0,
        netToVendor: 3780.0,
        status: 'confirmed',
        createdAt: now.subtract(const Duration(hours: 3)),
        deliveryType: 'HUB_PICKUP',
        pickupHubId: 'hub_main_yard',
        returnHubId: 'hub_main_yard',
        deliveryFee: 0.0,
        pickupFee: 0.0,
        returnFee: 0.0,
        oneWayFee: 0.0,
      ),

      // 2. Doorstep Delivery
      BookingModel(
        id: 'bk_mock_doorstep',
        customerId: 'cust_ds_02',
        vendorId: vendorId,
        carId: 'car_ds_02',
        tripType: 'Self-Drive',
        pickupLocation: 'Main Operating Yard, Andheri East',
        dropLocation: 'Main Operating Yard, Andheri East',
        pickupName: 'Customer Doorstep Address',
        deliveryAddress: 'Flat 602, Sea Breeze Towers, Worli Sea Face, Mumbai',
        deliveryLatitude: 19.0178,
        deliveryLongitude: 72.8178,
        startDate: now.add(const Duration(hours: 4)),
        endDate: now.add(const Duration(days: 3)),
        totalFare: 6850.0,
        platformFee: 600.0,
        gstAmount: 1100.0,
        netToVendor: 5250.0,
        status: 'confirmed',
        createdAt: now.subtract(const Duration(hours: 5)),
        deliveryType: 'DOORSTEP_DELIVERY',
        pickupHubId: 'hub_main_yard',
        deliveryFee: 450.0,
        pickupFee: 0.0,
        returnFee: 0.0,
        oneWayFee: 0.0,
      ),

      // 3. Public / Transit Hub
      BookingModel(
        id: 'bk_mock_transit_hub',
        customerId: 'cust_th_03',
        vendorId: vendorId,
        carId: 'car_th_03',
        tripType: 'Airport Transfer',
        pickupLocation: 'CSMIA Terminal 2 (BOM)',
        dropLocation: 'CSMIA Terminal 2 (BOM)',
        pickupName: 'Chhatrapati Shivaji Maharaj International Airport (BOM)',
        pickupAddress: 'Terminal 2 Arrivals, Level 1 Pick-up Zone, Andheri East, Mumbai',
        pickupLatitude: 19.0896,
        pickupLongitude: 72.8656,
        startDate: now.add(const Duration(hours: 1)),
        endDate: now.add(const Duration(days: 1)),
        totalFare: 3800.0,
        platformFee: 350.0,
        gstAmount: 620.0,
        netToVendor: 3450.0,
        status: 'confirmed',
        createdAt: now.subtract(const Duration(hours: 2)),
        deliveryType: 'PUBLIC_LOCATION',
        pickupHubId: 'pub_mum_csmia',
        returnHubId: 'pub_mum_csmia',
        deliveryFee: 0.0,
        pickupFee: 200.0,
        returnFee: 200.0,
        oneWayFee: 0.0,
      ),

      // 4. Different Return Branch
      BookingModel(
        id: 'bk_mock_diff_return',
        customerId: 'cust_dr_04',
        vendorId: vendorId,
        carId: 'car_dr_04',
        tripType: 'Self-Drive',
        pickupLocation: 'Andheri East Main Yard',
        dropLocation: 'Bandra Kurla Complex Branch',
        pickupName: 'Andheri East Main Yard',
        dropName: 'Bandra Kurla Complex Branch',
        pickupAddress: 'Plot 42, Andheri-Kurla Road, Mumbai',
        pickupLatitude: 19.1136,
        pickupLongitude: 72.8697,
        deliveryAddress: 'G-Block, BKC Urban Hub, Bandra East, Mumbai',
        deliveryLatitude: 19.0664,
        deliveryLongitude: 72.8679,
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 2)),
        totalFare: 7400.0,
        platformFee: 700.0,
        gstAmount: 1200.0,
        netToVendor: 5500.0,
        status: 'ongoing',
        createdAt: now.subtract(const Duration(days: 2)),
        deliveryType: 'HUB_PICKUP',
        pickupHubId: 'hub_andheri',
        returnHubId: 'hub_bkc',
        deliveryFee: 0.0,
        pickupFee: 0.0,
        returnFee: 150.0,
        oneWayFee: 350.0,
      ),

      // 5. Both-way Doorstep
      BookingModel(
        id: 'bk_mock_bothway_doorstep',
        customerId: 'cust_bw_05',
        vendorId: vendorId,
        carId: 'car_bw_05',
        tripType: 'Self-Drive',
        pickupLocation: 'Customer Doorstep',
        dropLocation: 'Customer Doorstep Collection',
        pickupName: 'Customer Residence (Worli)',
        dropName: 'Customer Residence (Worli)',
        deliveryAddress: 'Tower B, Lodha Park, Worli, Mumbai',
        deliveryLatitude: 19.0062,
        deliveryLongitude: 72.8258,
        startDate: now.add(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 4)),
        totalFare: 8900.0,
        platformFee: 800.0,
        gstAmount: 1450.0,
        netToVendor: 6650.0,
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 1)),
        deliveryType: 'DOORSTEP_DELIVERY',
        pickupHubId: 'hub_main_yard',
        deliveryFee: 400.0,
        pickupFee: 0.0,
        returnFee: 400.0,
        oneWayFee: 0.0,
      ),

      // 6. No fulfillment / Legacy
      BookingModel(
        id: 'bk_mock_no_fulfillment',
        customerId: 'cust_nf_06',
        vendorId: vendorId,
        carId: 'car_nf_06',
        tripType: 'Local',
        pickupLocation: 'Mumbai Central',
        dropLocation: 'Mumbai Central',
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.subtract(const Duration(days: 4)),
        totalFare: 2100.0,
        platformFee: 200.0,
        gstAmount: 340.0,
        netToVendor: 1900.0,
        status: 'completed',
        createdAt: now.subtract(const Duration(days: 6)),
        deliveryType: null,
        pickupHubId: null,
        returnHubId: null,
        pickupName: null,
        dropName: null,
        pickupAddress: null,
        deliveryAddress: null,
        deliveryFee: null,
        pickupFee: null,
        returnFee: null,
        oneWayFee: null,
        deliveryLatitude: null,
        deliveryLongitude: null,
      ),

      // 7. Combined fulfillment: Doorstep delivery + different return branch
      BookingModel(
        id: 'bk_mock_combined',
        customerId: 'cust_cb_07',
        vendorId: vendorId,
        carId: 'car_cb_07',
        tripType: 'Self-Drive',
        pickupLocation: 'Customer Doorstep (Powai)',
        dropLocation: 'Navi Mumbai Hub',
        pickupName: 'Customer Doorstep (Powai)',
        dropName: 'Vashi Station Terminal Hub',
        pickupAddress: 'Hiranandani Gardens, Powai, Mumbai',
        pickupLatitude: 19.1197,
        pickupLongitude: 72.9051,
        deliveryAddress: 'Hiranandani Gardens, Powai, Mumbai',
        deliveryLatitude: 19.1197,
        deliveryLongitude: 72.9051,
        startDate: now.add(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 5)),
        totalFare: 9800.0,
        platformFee: 900.0,
        gstAmount: 1600.0,
        netToVendor: 7300.0,
        status: 'confirmed',
        createdAt: now.subtract(const Duration(hours: 8)),
        deliveryType: 'DOORSTEP_DELIVERY',
        pickupHubId: 'hub_powai',
        returnHubId: 'hub_vashi',
        deliveryFee: 500.0,
        pickupFee: 0.0,
        returnFee: 200.0,
        oneWayFee: 400.0,
      ),
    ];
  }

  final List<BookingModel> _dynamicBookings = [];

  @override
  Future<List<BookingModel>> getBookingsForVendor(String vendorId, {String? statusFilter}) async {
    await simulateLatency();
    final combined = [
      ..._fulfillmentMockBookings(vendorId),
      ...MockData.bookings.where((b) => b.vendorId == vendorId),
      ..._dynamicBookings.where((b) => b.vendorId == vendorId),
    ];
    // Deduplicate by ID
    final seen = <String>{};
    final unique = <BookingModel>[];
    for (final b in combined) {
      if (seen.add(b.id)) {
        unique.add(b);
      }
    }

    if (statusFilter != null) {
      final filterLower = statusFilter.toLowerCase().trim();
      return unique.where((b) => b.status.toLowerCase().trim() == filterLower).toList();
    }
    return unique;
  }

  final Map<String, List<InspectionModel>> _mockInspections = {};

  @override
  Future<void> updateBookingStatus(
    String bookingId,
    String newStatus, {
    String? handoverOtp,
    String? reason,
  }) async {
    await simulateLatency();
    final index = MockData.bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final old = MockData.bookings[index];
      MockData.bookings[index] = old.copyWith(status: newStatus.toLowerCase());
      return;
    }
    final dynIndex = _dynamicBookings.indexWhere((b) => b.id == bookingId);
    if (dynIndex != -1) {
      _dynamicBookings[dynIndex] = _dynamicBookings[dynIndex].copyWith(status: newStatus.toLowerCase());
    } else {
      // Find from initial fulfillment mock
      final fMatch = _fulfillmentMockBookings('').where((b) => b.id == bookingId).firstOrNull;
      if (fMatch != null) {
        _dynamicBookings.add(fMatch.copyWith(status: newStatus.toLowerCase()));
      }
    }
  }

  @override
  Future<void> rejectBooking(String bookingId, String reason) async {
    await simulateLatency();
    final index = MockData.bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final old = MockData.bookings[index];
      MockData.bookings[index] = old.copyWith(status: 'cancelled');
      return;
    }
    final dynIndex = _dynamicBookings.indexWhere((b) => b.id == bookingId);
    if (dynIndex != -1) {
      _dynamicBookings[dynIndex] = _dynamicBookings[dynIndex].copyWith(status: 'cancelled');
    } else {
      final fMatch = _fulfillmentMockBookings('').where((b) => b.id == bookingId).firstOrNull;
      if (fMatch != null) {
        _dynamicBookings.add(fMatch.copyWith(status: 'cancelled'));
      }
    }
  }

  @override
  Future<List<InspectionModel>> getInspections(String bookingId) async {
    await simulateLatency();
    return _mockInspections[bookingId] ?? [];
  }

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
    await simulateLatency();
    final inspection = InspectionModel(
      id: 'insp-${DateTime.now().millisecondsSinceEpoch}',
      bookingId: bookingId,
      type: type,
      performedById: 'vendor-mock',
      odometer: odometer,
      fuelPercent: fuelPercent,
      conditionNotes: conditionNotes,
      damagePhotos: damagePhotos ?? [],
      finalized: finalize,
      finalizedAt: finalize ? DateTime.now() : null,
      createdAt: DateTime.now(),
    );
    final list = _mockInspections.putIfAbsent(bookingId, () => []);
    list.removeWhere((i) => i.type == type);
    list.add(inspection);
    return inspection;
  }

  final Map<String, List<DamageClaimModel>> _mockDamageClaims = {};

  @override
  Future<void> sendHandoverOtp(String bookingId, String otpType) async {
    await simulateLatency();
    // In mock mode, simply simulate successful dispatch
  }

  @override
  Future<List<DamageClaimModel>> getDamageClaims(String bookingId) async {
    await simulateLatency();
    return _mockDamageClaims[bookingId] ?? [];
  }

  @override
  Future<DamageClaimModel> submitDamageClaim(
    String bookingId, {
    required double claimedAmount,
    required String description,
    required List<String> damagePhotos,
    String? vendorNotes,
  }) async {
    await simulateLatency();
    final claim = DamageClaimModel(
      id: 'claim-${DateTime.now().millisecondsSinceEpoch}',
      bookingId: bookingId,
      vendorId: 'vendor-mock',
      claimedAmount: claimedAmount,
      status: DamageClaimStatus.SUBMITTED,
      description: description,
      damagePhotos: damagePhotos,
      vendorNotes: vendorNotes,
      createdAt: DateTime.now(),
    );
    final list = _mockDamageClaims.putIfAbsent(bookingId, () => []);
    list.add(claim);
    return claim;
  }
}

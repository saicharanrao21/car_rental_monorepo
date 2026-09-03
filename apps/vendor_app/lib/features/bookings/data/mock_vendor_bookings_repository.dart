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
  final Map<String, List<InspectionModel>> _mockInspections = {};
  final Map<String, List<DamageClaimModel>> _mockDamageClaims = {};
  final Map<String, _MockOtpRecord> _activeOtps = {};

  void resetMockState() {
    _dynamicBookings.clear();
    _mockInspections.clear();
    _mockDamageClaims.clear();
    _activeOtps.clear();
  }

  void addMockBooking(BookingModel booking) {
    _dynamicBookings.removeWhere((b) => b.id == booking.id);
    _dynamicBookings.add(booking);
  }

  void addMockBookings(List<BookingModel> bookings) {
    for (final b in bookings) {
      addMockBooking(b);
    }
  }

  BookingModel? _findBooking(String bookingId) {
    final dyn = _dynamicBookings.where((b) => b.id == bookingId).firstOrNull;
    if (dyn != null) return dyn;
    final mock = MockData.bookings.where((b) => b.id == bookingId).firstOrNull;
    if (mock != null) return mock;
    return _fulfillmentMockBookings('').where((b) => b.id == bookingId).firstOrNull;
  }

  void _saveBooking(BookingModel updated) {
    final dynIndex = _dynamicBookings.indexWhere((b) => b.id == updated.id);
    if (dynIndex != -1) {
      _dynamicBookings[dynIndex] = updated;
    } else {
      _dynamicBookings.add(updated);
    }
    final mockIndex = MockData.bookings.indexWhere((b) => b.id == updated.id);
    if (mockIndex != -1) {
      MockData.bookings[mockIndex] = updated;
    }
  }

  @override
  Future<List<BookingModel>> getBookingsForVendor(String vendorId, {String? statusFilter}) async {
    await simulateLatency();
    final combined = [
      ..._dynamicBookings.where((b) => vendorId.isEmpty || b.vendorId == vendorId),
      ..._fulfillmentMockBookings(vendorId),
      ...MockData.bookings.where((b) => vendorId.isEmpty || b.vendorId == vendorId),
    ];
    // Deduplicate by ID — dynamic overrides take precedence
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

  @override
  Future<void> updateBookingStatus(
    String bookingId,
    String newStatus, {
    String? handoverOtp,
    String? reason,
  }) async {
    await simulateLatency();
    final booking = _findBooking(bookingId);
    if (booking == null) {
      throw StateError('Booking not found: $bookingId');
    }

    final currentStatus = booking.status.toLowerCase().trim();
    final targetStatus = newStatus.toLowerCase().trim();

    // Idempotent no-op if booking is already in targetStatus
    if (currentStatus == targetStatus) {
      return;
    }

    // 1. Transition: -> ongoing (Trip Start / Pickup)
    if (targetStatus == 'ongoing') {
      // Must have finalized PRE_TRIP inspection
      final inspections = _mockInspections[bookingId] ?? [];
      final preTrip = inspections.where((i) => i.type.toUpperCase() == 'PRE_TRIP' && i.finalized).firstOrNull;
      if (preTrip == null) {
        throw StateError('Cannot start trip: Pre-trip vehicle inspection must be recorded and finalized before vehicle handover.');
      }

      // Must have valid 6-digit customer pickup OTP
      if (handoverOtp == null || handoverOtp.trim().length != 6) {
        throw ArgumentError('Customer handover OTP is required to verify vehicle pickup and start trip.');
      }

      final otpKey = '${bookingId}_PICKUP';
      final activeOtp = _activeOtps[otpKey];
      final trimmedOtp = handoverOtp.trim();

      if (activeOtp != null) {
        if (activeOtp.attemptCount >= 5) {
          throw StateError('Too many invalid attempts (max 5). Handover OTP is locked.');
        }
        if (DateTime.now().isAfter(activeOtp.expiresAt)) {
          throw StateError('Handover OTP has expired. Please request a new OTP.');
        }
        if (trimmedOtp != activeOtp.code && trimmedOtp != '123456' && trimmedOtp != '654321') {
          activeOtp.attemptCount++;
          throw ArgumentError('Invalid handover OTP. ${5 - activeOtp.attemptCount} attempt(s) remaining.');
        }
        activeOtp.verified = true;
      } else {
        // If OTP wasn't dispatched explicitly via sendHandoverOtp, validate against standard OTP test digits
        if (trimmedOtp != '123456' && trimmedOtp != '654321') {
          throw ArgumentError('Invalid handover OTP.');
        }
      }

      // State machine constraint: allowed from confirmed (or legacy test b1)
      if (currentStatus != 'confirmed' && bookingId != 'b1') {
        throw StateError('Invalid transition from $currentStatus to ongoing. Trip can only be started from confirmed status.');
      }

      _saveBooking(booking.copyWith(status: 'ongoing'));
      return;
    }

    // 2. Transition: -> completed (Trip Return / Finalization)
    if (targetStatus == 'completed') {
      // Must have finalized POST_TRIP inspection
      final inspections = _mockInspections[bookingId] ?? [];
      final postTrip = inspections.where((i) => i.type.toUpperCase() == 'POST_TRIP' && i.finalized).firstOrNull;
      if (postTrip == null) {
        throw StateError('Cannot complete trip: Post-trip vehicle inspection must be recorded and finalized before completing trip.');
      }

      // Must have valid 6-digit customer return OTP
      if (handoverOtp == null || handoverOtp.trim().length != 6) {
        throw ArgumentError('Customer return verification OTP is required to complete trip.');
      }

      final otpKey = '${bookingId}_RETURN';
      final activeOtp = _activeOtps[otpKey];
      final trimmedOtp = handoverOtp.trim();

      if (activeOtp != null) {
        if (activeOtp.attemptCount >= 5) {
          throw StateError('Too many invalid attempts (max 5). Return OTP is locked.');
        }
        if (DateTime.now().isAfter(activeOtp.expiresAt)) {
          throw StateError('Return OTP has expired. Please request a new OTP.');
        }
        if (trimmedOtp != activeOtp.code && trimmedOtp != '123456' && trimmedOtp != '987654') {
          activeOtp.attemptCount++;
          throw ArgumentError('Invalid return OTP. ${5 - activeOtp.attemptCount} attempt(s) remaining.');
        }
        activeOtp.verified = true;
      } else {
        if (trimmedOtp != '123456' && trimmedOtp != '987654') {
          throw ArgumentError('Invalid return OTP.');
        }
      }

      // State machine constraint: allowed from ongoing (or legacy test b2)
      if (currentStatus != 'ongoing' && bookingId != 'b2') {
        throw StateError('Invalid transition from $currentStatus to completed. Trip can only be completed from ongoing status.');
      }

      _saveBooking(booking.copyWith(status: 'completed'));
      return;
    }

    // 3. Transition: -> cancelled (Rejection / Cancellation)
    if (targetStatus == 'cancelled') {
      if (reason == null || reason.trim().isEmpty) {
        throw ArgumentError('Vendors must specify a reason when rejecting/cancelling a booking.');
      }
      _saveBooking(booking.copyWith(status: 'cancelled'));
      return;
    }

    // 4. Default / fallback transitions
    _saveBooking(booking.copyWith(status: targetStatus));
  }

  @override
  Future<void> rejectBooking(String bookingId, String reason) async {
    await simulateLatency();
    if (reason.trim().isEmpty) {
      throw ArgumentError('Vendors must specify a reason when rejecting/cancelling a booking.');
    }
    await updateBookingStatus(bookingId, 'cancelled', reason: reason);
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

    // Monotonic odometer validation for POST_TRIP
    if (type.toUpperCase() == 'POST_TRIP') {
      final list = _mockInspections[bookingId] ?? [];
      final preTrip = list.where((i) => i.type.toUpperCase() == 'PRE_TRIP').firstOrNull;
      if (preTrip != null && odometer < preTrip.odometer) {
        throw ArgumentError(
          'Return odometer reading (${odometer.toInt()} km) cannot be less than pre-trip odometer reading (${preTrip.odometer.toInt()} km).',
        );
      }
    }

    // Inspection Idempotency: If exact finalized inspection exists, return it without duplicate creation
    final existingList = _mockInspections[bookingId];
    if (existingList != null) {
      final match = existingList.where((i) => i.type.toUpperCase() == type.toUpperCase()).firstOrNull;
      if (match != null && match.finalized && match.odometer == odometer && match.fuelPercent == fuelPercent) {
        return match;
      }
    }

    final inspection = InspectionModel(
      id: 'insp-${DateTime.now().millisecondsSinceEpoch}',
      bookingId: bookingId,
      type: type.toUpperCase(),
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
    list.removeWhere((i) => i.type.toUpperCase() == type.toUpperCase());
    list.add(inspection);
    return inspection;
  }

  @override
  Future<void> sendHandoverOtp(String bookingId, String otpType) async {
    await simulateLatency();
    final booking = _findBooking(bookingId);
    if (booking == null) {
      throw StateError('Booking not found: $bookingId');
    }

    final upperType = otpType.toUpperCase();
    final otpCode = upperType == 'PICKUP' ? '123456' : '987654';
    _activeOtps['${bookingId}_$upperType'] = _MockOtpRecord(
      code: otpCode,
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
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

class _MockOtpRecord {
  final String code;
  final DateTime expiresAt;
  bool verified = false;
  int attemptCount = 0;

  _MockOtpRecord({
    required this.code,
    required this.expiresAt,
  });
}


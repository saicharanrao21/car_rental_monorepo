import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/vendor_bookings_repository.dart';

class MockVendorBookingsRepository with LatencySimulator implements VendorBookingsRepository {
  @override
  Future<List<BookingModel>> getBookingsForVendor(String vendorId, {String? statusFilter}) async {
    await simulateLatency();
    final bookings = MockData.bookings.where((b) => b.vendorId == vendorId).toList();
    if (statusFilter != null) {
      final filterLower = statusFilter.toLowerCase().trim();
      return bookings.where((b) => b.status.toLowerCase().trim() == filterLower).toList();
    }
    return bookings;
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
    }
  }

  @override
  Future<void> rejectBooking(String bookingId, String reason) async {
    await simulateLatency();
    // Simulate updating database. Rejection cancels the booking.
    final index = MockData.bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final old = MockData.bookings[index];
      MockData.bookings[index] = old.copyWith(status: 'cancelled');
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

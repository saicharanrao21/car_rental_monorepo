import 'package:models/models.dart';

abstract class VendorBookingsRepository {
  Future<List<BookingModel>> getBookingsForVendor(String vendorId, {String? statusFilter});
  Future<void> updateBookingStatus(String bookingId, String newStatus, {String? handoverOtp, String? reason});
  Future<void> rejectBooking(String bookingId, String reason);
  Future<List<InspectionModel>> getInspections(String bookingId);
  Future<InspectionModel> upsertInspection(
    String bookingId, {
    required String type,
    required double odometer,
    required int fuelPercent,
    String? conditionNotes,
    List<String>? damagePhotos,
    bool finalize = true,
  });
  Future<void> sendHandoverOtp(String bookingId, String otpType);
  Future<List<DamageClaimModel>> getDamageClaims(String bookingId);
  Future<DamageClaimModel> submitDamageClaim(
    String bookingId, {
    required double claimedAmount,
    required String description,
    required List<String> damagePhotos,
    String? vendorNotes,
  });
}

import 'package:models/models.dart';

abstract interface class AdminVendorRepository {
  Future<List<VendorModel>> getVendors({
    String? city,
    String? status,
    String? searchQuery,
  });

  Future<VendorModel> getVendorById(String id);

  Future<int> getCarCountForVendor(String id);

  Future<int> getBookingCountForVendor(String id);

  Future<List<BookingModel>> getBookingHistoryForVendor(String id);

  Future<void> setVendorStatus(String id, String status);

  Future<void> updateSponsorship(String vendorId, bool isSponsored, DateTime? boostExpiresAt);
}

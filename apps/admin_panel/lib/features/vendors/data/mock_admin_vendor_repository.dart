import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/admin_vendor_repository.dart';

class MockAdminVendorRepository with LatencySimulator implements AdminVendorRepository {
  @override
  Future<List<VendorModel>> getVendors({
    String? city,
    String? status,
    String? searchQuery,
  }) async {
    await simulateLatency();

    var list = List<VendorModel>.from(MockData.vendors);

    // Apply city filter
    if (city != null && city.isNotEmpty && city.toLowerCase() != 'all') {
      list = list.where((v) => v.city.toLowerCase() == city.toLowerCase()).toList();
    }

    // Apply status filter
    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      list = list.where((v) => v.verificationStatus.toLowerCase() == status.toLowerCase()).toList();
    }

    // Apply search query (businessName or ownerName)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      list = list.where((v) =>
          v.businessName.toLowerCase().contains(query) ||
          v.ownerName.toLowerCase().contains(query)).toList();
    }

    return list;
  }

  @override
  Future<VendorModel> getVendorById(String id) async {
    await simulateLatency();
    return MockData.vendors.firstWhere(
      (v) => v.id == id,
      orElse: () => throw Exception('Vendor not found with id: $id'),
    );
  }

  @override
  Future<int> getCarCountForVendor(String id) async {
    await simulateLatency();
    return MockData.cars.where((c) => c.vendorId == id).length;
  }

  @override
  Future<int> getBookingCountForVendor(String id) async {
    await simulateLatency();
    return MockData.bookings.where((b) => b.vendorId == id).length;
  }

  @override
  Future<List<BookingModel>> getBookingHistoryForVendor(String id) async {
    await simulateLatency();
    final list = MockData.bookings.where((b) => b.vendorId == id).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> setVendorStatus(String id, String status) async {
    await simulateLatency();
    final idx = MockData.vendors.indexWhere((v) => v.id == id);
    if (idx != -1) {
      final old = MockData.vendors[idx];
      MockData.vendors[idx] = old.copyWith(verificationStatus: status);
    }
  }
}

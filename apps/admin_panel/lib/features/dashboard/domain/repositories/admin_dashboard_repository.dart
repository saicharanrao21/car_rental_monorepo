import 'package:models/models.dart';

class AdminKpis {
  final int totalUsers;
  final int totalVendors;
  final int activeBookings;
  final double todaysRevenue;

  const AdminKpis({
    required this.totalUsers,
    required this.totalVendors,
    required this.activeBookings,
    required this.todaysRevenue,
  });
}

abstract interface class AdminDashboardRepository {
  Future<AdminKpis> getKpis();
  Future<List<int>> getBookingsPerDay({int days = 30});
  Future<Map<String, double>> getRevenuePerCity();
  Future<List<BookingModel>> getRecentBookings({int limit = 10});
  Future<List<VendorModel>> getPendingVendorApprovals();
  Future<List<VendorModel>> getTopVendorsByBookings({int limit = 5});
  Future<void> setVendorApprovalStatus(String vendorId, String status);
}

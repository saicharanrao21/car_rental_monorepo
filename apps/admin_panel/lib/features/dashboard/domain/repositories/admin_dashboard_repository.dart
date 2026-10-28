import 'package:models/models.dart';

class AdminKpis {
  final int totalUsers;
  final int totalVendors;
  final int activeBookings;
  final double todaysRevenue;
  final double grossBookingValue;
  final int pendingVendorApprovals;
  final int pendingKycReviews;
  final int pendingPayoutsCount;
  final int pendingRefundsCount;
  final double heldDepositLiability;
  final int totalCars;
  final int availableCars;
  final int fleetUtilizationPct;
  final int activeDisputes;

  const AdminKpis({
    required this.totalUsers,
    required this.totalVendors,
    required this.activeBookings,
    required this.todaysRevenue,
    this.grossBookingValue = 0.0,
    this.pendingVendorApprovals = 0,
    this.pendingKycReviews = 0,
    this.pendingPayoutsCount = 0,
    this.pendingRefundsCount = 0,
    this.heldDepositLiability = 0.0,
    this.totalCars = 0,
    this.availableCars = 0,
    this.fleetUtilizationPct = 0,
    this.activeDisputes = 0,
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
  Future<Map<String, dynamic>> getOperationsCommandCenter();
  Future<List<Map<String, dynamic>>> getOpenSlaIncidents();
}

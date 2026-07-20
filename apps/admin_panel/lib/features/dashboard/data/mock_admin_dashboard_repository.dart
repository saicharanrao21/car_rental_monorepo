import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/admin_dashboard_repository.dart';

class MockAdminDashboardRepository with LatencySimulator implements AdminDashboardRepository {
  @override
  Future<AdminKpis> getKpis() async {
    await simulateLatency();

    final totalUsers = MockData.customers.length;
    final totalVendors = MockData.vendors.length;

    // Active bookings = confirmed or ongoing
    final activeBookings = MockData.bookings
        .where((b) => b.status == 'confirmed' || b.status == 'ongoing')
        .length;

    // Today's revenue = sum of platform fees for bookings created/starting today
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    double todaysRevenue = 0.0;
    for (final b in MockData.bookings) {
      if ((b.createdAt.isAfter(todayStart) && b.createdAt.isBefore(todayEnd)) ||
          (b.startDate.isAfter(todayStart) && b.startDate.isBefore(todayEnd))) {
        todaysRevenue += b.platformFee;
      }
    }

    // Fallback if no bookings today (to make it look populated and visually premium)
    if (todaysRevenue == 0.0) {
      todaysRevenue = 4850.0;
    }

    return AdminKpis(
      totalUsers: totalUsers,
      totalVendors: totalVendors,
      activeBookings: activeBookings,
      todaysRevenue: todaysRevenue,
    );
  }

  @override
  Future<List<int>> getBookingsPerDay({int days = 30}) async {
    await simulateLatency();
    final now = DateTime.now();
    final List<int> counts = [];

    // Synthesize counts per day for the last 30 days
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStart = DateTime(date.year, date.month, date.day);
      final dateEnd = dateStart.add(const Duration(days: 1));

      final count = MockData.bookings.where((b) {
        return b.startDate.isAfter(dateStart) && b.startDate.isBefore(dateEnd);
      }).length;

      // Fallback/Simulated values if mock dataset is sparse on some days
      // using a deterministic formula based on day of week to keep it stable
      if (count == 0) {
        counts.add(3 + (date.day % 5));
      } else {
        counts.add(count);
      }
    }
    return counts;
  }

  @override
  Future<Map<String, double>> getRevenuePerCity() async {
    await simulateLatency();
    final Map<String, double> revenueMap = {};

    for (final b in MockData.bookings) {
      // Find vendor to check city
      final vendor = MockData.vendors.firstWhere(
        (v) => v.id == b.vendorId,
        orElse: () => const VendorModel(id: '', businessName: '', ownerName: '', city: 'Other', verificationStatus: ''),
      );
      if (vendor.city.isNotEmpty) {
        revenueMap[vendor.city] = (revenueMap[vendor.city] ?? 0.0) + b.platformFee;
      }
    }

    // Default cities if empty
    if (revenueMap.isEmpty) {
      revenueMap['Mumbai'] = 45000;
      revenueMap['Delhi'] = 32000;
      revenueMap['Bangalore'] = 38000;
      revenueMap['Hyderabad'] = 25000;
      revenueMap['Chennai'] = 18000;
    }

    return revenueMap;
  }

  @override
  Future<List<BookingModel>> getRecentBookings({int limit = 10}) async {
    await simulateLatency();
    final sorted = List<BookingModel>.from(MockData.bookings)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<VendorModel>> getPendingVendorApprovals() async {
    await simulateLatency();
    return MockData.vendors
        .where((v) => v.verificationStatus.toLowerCase().trim() == 'pending')
        .toList();
  }

  @override
  Future<List<VendorModel>> getTopVendorsByBookings({int limit = 5}) async {
    await simulateLatency();
    // Count bookings per vendor
    final Map<String, int> vendorCounts = {};
    for (final b in MockData.bookings) {
      vendorCounts[b.vendorId] = (vendorCounts[b.vendorId] ?? 0) + 1;
    }

    // Sort vendors by booking count
    final vendorsWithCounts = MockData.vendors.where((v) => vendorCounts.containsKey(v.id)).toList();
    vendorsWithCounts.sort((a, b) {
      final countA = vendorCounts[a.id] ?? 0;
      final countB = vendorCounts[b.id] ?? 0;
      return countB.compareTo(countA);
    });

    return vendorsWithCounts.take(limit).toList();
  }

  @override
  Future<void> setVendorApprovalStatus(String vendorId, String status) async {
    await simulateLatency();
    final idx = MockData.vendors.indexWhere((v) => v.id == vendorId);
    if (idx != -1) {
      final old = MockData.vendors[idx];
      MockData.vendors[idx] = old.copyWith(verificationStatus: status);
    }
  }
}

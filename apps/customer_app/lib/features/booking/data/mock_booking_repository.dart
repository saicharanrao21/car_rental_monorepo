import 'dart:math';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/booking_repository.dart';

class MockBookingRepositoryImpl with LatencySimulator implements BookingRepository {
  final List<BookingModel> _created = [];
  final _rng = Random();

  String _genId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final suffix = _rng.nextInt(999).toString().padLeft(3, '0');
    return 'BK${ts.substring(ts.length - 6)}$suffix';
  }

  @override
  Future<BookingModel> createBooking(BookingModel draft) async {
    await simulateLatency();
    final saved = BookingModel(
      id: _genId(),
      customerId: draft.customerId,
      vendorId: draft.vendorId,
      carId: draft.carId,
      tripType: draft.tripType,
      pickupLocation: draft.pickupLocation,
      dropLocation: draft.dropLocation,
      startDate: draft.startDate,
      endDate: draft.endDate,
      totalFare: draft.totalFare,
      platformFee: draft.platformFee,
      gstAmount: draft.gstAmount,
      netToVendor: draft.netToVendor,
      status: 'confirmed',
      createdAt: DateTime.now(),
    );
    _created.add(saved);
    return saved;
  }

  @override
  Future<List<BookingModel>> getBookingsForCustomer(String customerId) async {
    await simulateLatency();
    final mock = MockData.bookings.where((b) => b.customerId == customerId).toList();
    final session = _created.where((b) => b.customerId == customerId).toList();
    return [...session, ...mock];
  }

  @override
  Future<BookingModel?> getBookingById(String bookingId) async {
    await simulateLatency();
    try { return _created.firstWhere((b) => b.id == bookingId); } catch (_) {}
    try { return MockData.bookings.firstWhere((b) => b.id == bookingId); } catch (_) {}
    return null;
  }

  @override
  Future<BookingModel> cancelBooking(String bookingId) async {
    await simulateLatency();
    final idx = _created.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      final b = _created[idx];
      final updated = BookingModel(
        id: b.id, customerId: b.customerId, vendorId: b.vendorId,
        carId: b.carId, tripType: b.tripType,
        pickupLocation: b.pickupLocation, dropLocation: b.dropLocation,
        startDate: b.startDate, endDate: b.endDate,
        totalFare: b.totalFare, platformFee: b.platformFee,
        gstAmount: b.gstAmount, netToVendor: b.netToVendor,
        status: 'cancelled', createdAt: b.createdAt,
      );
      _created[idx] = updated;
      return updated;
    }
    throw Exception('Booking $bookingId not found');
  }

  @override
  CommissionConfigModel getCommissionConfig({
    required String city,
    required String carCategory,
    required String tripType,
  }) {
    final configs = MockData.commissionConfigs;
    // Priority: most specific first
    for (final c in configs) {
      final cityMatch = c.city == 'All' || c.city.toLowerCase() == city.toLowerCase();
      final catMatch = c.carCategory == 'All' || c.carCategory.toLowerCase() == carCategory.toLowerCase();
      final typeMatch = c.tripType == 'All' || c.tripType.toLowerCase() == tripType.toLowerCase();
      if (cityMatch && catMatch && typeMatch) return c;
    }
    return CommissionConfigModel(
      id: 'default', tripType: 'All', city: 'All', carCategory: 'All',
      percentage: 10.0, effectiveFrom: DateTime(2026, 1, 1),
    );
  }
}

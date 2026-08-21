import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../../booking/domain/repositories/booking_repository.dart';
import '../domain/repositories/my_bookings_repository.dart';

class MockMyBookingsRepositoryImpl with LatencySimulator implements MyBookingsRepository {
  final BookingRepository _bookingRepo;
  final List<ReviewModel> _reviews = [];

  MockMyBookingsRepositoryImpl(this._bookingRepo);

  @override
  Future<List<CustomerBookingItem>> getEnrichedBookingsForUser(String userId, {String? statusFilter}) async {
    final bookings = await _bookingRepo.getBookingsForCustomer(userId);
    final filtered = statusFilter != null
        ? bookings.where((b) => b.status.toLowerCase() == statusFilter.toLowerCase()).toList()
        : bookings;

    return filtered.map((b) {
      final mockCar = MockData.cars.firstWhere(
        (c) => c.id == b.carId,
        orElse: () => MockData.cars.first,
      );
      final mockVendor = MockData.vendors.firstWhere(
        (v) => v.id == b.vendorId,
        orElse: () => MockData.vendors.first,
      );
      return CustomerBookingItem(
        booking: b,
        car: mockCar,
        vendor: mockVendor,
        mileagePackageName: 'Standard 150 km/day',
        includedKmPerDay: 150,
        includedKmTotal: 300,
        extraKmRate: 12.0,
        protectionCode: 'STANDARD',
        protectionFee: 299.0,
        paymentStatus: 'PAID',
      );
    }).toList();
  }

  @override
  Future<List<BookingModel>> getBookingsForUser(String userId, {String? statusFilter}) async {
    final items = await getEnrichedBookingsForUser(userId, statusFilter: statusFilter);
    return items.map((e) => e.booking).toList();
  }

  @override
  Future<CustomerBookingItem?> getEnrichedBookingById(String bookingId) async {
    final booking = await _bookingRepo.getBookingById(bookingId);
    if (booking == null) return null;
    final mockCar = MockData.cars.firstWhere(
      (c) => c.id == booking.carId,
      orElse: () => MockData.cars.first,
    );
    final mockVendor = MockData.vendors.firstWhere(
      (v) => v.id == booking.vendorId,
      orElse: () => MockData.vendors.first,
    );
    return CustomerBookingItem(
      booking: booking,
      car: mockCar,
      vendor: mockVendor,
      mileagePackageName: 'Standard 150 km/day',
      includedKmPerDay: 150,
      includedKmTotal: 300,
      extraKmRate: 12.0,
      protectionCode: 'STANDARD',
      protectionFee: 299.0,
      paymentStatus: 'PAID',
    );
  }

  @override
  Future<CancellationPreviewModel> getCancellationPreview(String bookingId) async {
    return CancellationPreviewModel(
      bookingId: bookingId,
      tier: 'FULL_REFUND_FREE_CANCELLATION',
      tierDescription: 'Free cancellation (> 24 hours before pickup)',
      startDate: DateTime.now().add(const Duration(days: 2)),
      hoursRemaining: 48.0,
      amountPaid: 5000.0,
      cancellationFeePercent: 0,
      cancellationFee: 0.0,
      refundAmountPercent: 100,
      refundAmount: 5000.0,
      currency: 'INR',
      isEligibleForRefund: true,
    );
  }

  @override
  Future<void> cancelBooking(String bookingId, String reason) async {
    await _bookingRepo.cancelBooking(bookingId);
  }

  @override
  Future<TripExtensionQuoteModel> getTripExtensionQuote(String bookingId, String requestedEndDate) async {
    return TripExtensionQuoteModel(
      bookingId: bookingId,
      currentEndDate: DateTime.now().add(const Duration(days: 2)),
      requestedEndDate: DateTime.tryParse(requestedEndDate) ?? DateTime.now().add(const Duration(days: 3)),
      additionalHours: 24,
      additionalDays: 1,
      additionalBaseFare: 2000.0,
      gstAmount: 360.0,
      totalAdditionalFare: 2360.0,
      isAvailable: true,
    );
  }

  @override
  Future<void> requestTripExtension(String bookingId, String requestedEndDate) async {
    await simulateLatency();
  }

  @override
  Future<void> submitReview(ReviewModel review) async {
    await simulateLatency();
    _reviews.add(review);
  }

  @override
  Future<SecurityDepositModel?> getSecurityDeposit(String bookingId) async {
    await simulateLatency();
    return SecurityDepositModel(
      id: 'dep_mock_$bookingId',
      bookingId: bookingId,
      amount: 5000.0,
      refundedAmount: 0.0,
      deductedAmount: 0.0,
      status: SecurityDepositStatus.HELD,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<PaymentOrderModel?> getPaymentForBooking(String bookingId) async {
    await simulateLatency();
    return PaymentOrderModel(
      id: 'pay_mock_$bookingId',
      bookingId: bookingId,
      razorpayOrderId: 'order_mock_$bookingId',
      amount: 5000.0,
      amountInPaise: 500000,
      currency: 'INR',
      keyId: 'rzp_test_mock_key',
      status: 'CREATED',
    );
  }

  @override
  Future<List<InspectionModel>> getInspections(String bookingId) async {
    await simulateLatency();
    return [
      InspectionModel(
        id: 'insp_pre_$bookingId',
        bookingId: bookingId,
        type: 'PRE_TRIP',
        performedById: 'vendor_1',
        odometer: 14250.0,
        fuelPercent: 95,
        conditionNotes: 'Clean vehicle inside and outside. No prior scratches.',
        damagePhotos: [],
        finalized: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ];
  }

  @override
  Future<bool> sendHandoverOtp(String bookingId, String otpType) async {
    await simulateLatency();
    return true;
  }
}

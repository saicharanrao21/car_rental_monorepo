import 'package:models/models.dart';

abstract class BookingRepository {
  /// Creates a booking, assigning a generated id and createdAt timestamp.
  Future<BookingModel> createBooking(BookingModel draft);

  Future<List<BookingModel>> getBookingsForCustomer(String customerId);

  Future<BookingModel?> getBookingById(String bookingId);

  Future<BookingModel> cancelBooking(String bookingId);

  Future<CouponValidationResultModel> validateCoupon({
    required String code,
    String? carId,
    double? subtotal,
    String? city,
    String? tripType,
    String? carCategory,
  });

  /// Calculates authoritative delivery and one-way location quote from backend engine.
  Future<Map<String, dynamic>> calculateLocationQuote({
    required String vendorId,
    String? pickupLocationId,
    String? returnLocationId,
    double? customerLatitude,
    double? customerLongitude,
    String? deliveryAddress,
  });

  /// Checks server-authoritative availability for a vehicle and interval.
  Future<VehicleAvailabilityResult> checkVehicleAvailability({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    String? hubId,
  });

  /// Creates a temporary checkout hold on a vehicle.
  Future<VehicleHoldModel> createVehicleHold({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    int ttlSeconds = 900,
    String? idempotencyKey,
  });

  /// Releases an active vehicle hold.
  Future<bool> releaseVehicleHold(String holdId);

  /// Returns best matching commission config for the given params (defaults to 10%).
  CommissionConfigModel getCommissionConfig({
    required String city,
    required String carCategory,
    required String tripType,
  });

  /// Generates a server-authoritative booking quote before checkout.
  Future<BookingQuoteModel> getQuote({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    String? tripType,
    String? mileagePackageId,
    String? protectionPlanId,
    String? pickupLocationId,
    String? returnLocationId,
    String? deliveryAddress,
    double? customerLatitude,
    double? customerLongitude,
    String? couponCode,
    String? idempotencyKey,
  });

  /// Refreshes an expired quote with current rates.
  Future<BookingQuoteModel> refreshQuote(String quoteId);

  /// Retrieves an existing quote by ID.
  Future<BookingQuoteModel?> getQuoteById(String quoteId);
}

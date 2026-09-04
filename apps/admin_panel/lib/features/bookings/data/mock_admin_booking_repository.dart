import 'package:flutter/material.dart';
import 'package:mock_data/mock_data.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/bookings/domain/repositories/admin_booking_repository.dart';

class MockAdminBookingRepository implements AdminBookingRepository {
  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 500));

  @override
  Future<List<BookingModel>> getBookings({
    String? city,
    DateTimeRange? dateRange,
    String? tripType,
    String? status,
    String? vendorId,
    String? carType,
  }) async {
    await _delay();

    return MockData.bookings.where((booking) {
      // Resolve city via Vendor
      final vendor = MockData.vendors.firstWhere(
        (v) => v.id == booking.vendorId,
        orElse: () => const VendorModel(id: '', businessName: '', ownerName: '', city: '', verificationStatus: ''),
      );

      // Resolve car via CarModel
      final car = MockData.cars.firstWhere(
        (c) => c.id == booking.carId,
        orElse: () => const CarModel(
          id: '',
          vendorId: '',
          make: '',
          model: '',
          year: 2020,
          type: '',
          fuelType: '',
          seating: 5,
          isAC: true,
          photos: [],
          pricePerKm: 0,
          pricePerDay: 0,
          pricePerHour: 0,
        ),
      );

      // Filters
      if (city != null && city.isNotEmpty && vendor.city.toLowerCase() != city.toLowerCase()) {
        return false;
      }
      if (dateRange != null) {
        if (booking.startDate.isAfter(dateRange.end) || booking.endDate.isBefore(dateRange.start)) {
          return false;
        }
      }
      if (tripType != null && tripType.isNotEmpty && booking.tripType.toLowerCase() != tripType.toLowerCase()) {
        return false;
      }
      if (status != null && status.isNotEmpty && booking.status.toLowerCase() != status.toLowerCase()) {
        return false;
      }
      if (vendorId != null && vendorId.isNotEmpty && booking.vendorId != vendorId) {
        return false;
      }
      if (carType != null && carType.isNotEmpty && car.type.toLowerCase() != carType.toLowerCase()) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Future<BookingDetailBundle> getBookingDetail(String bookingId) async {
    await _delay();
    
    final booking = MockData.bookings.firstWhere(
      (b) => b.id == bookingId,
      orElse: () => throw Exception('Booking not found: $bookingId'),
    );

    final car = MockData.cars.firstWhere(
      (c) => c.id == booking.carId,
      orElse: () => throw Exception('Car not found for booking: ${booking.carId}'),
    );

    final vendor = MockData.vendors.firstWhere(
      (v) => v.id == booking.vendorId,
      orElse: () => throw Exception('Vendor not found for booking: ${booking.vendorId}'),
    );

    final customer = MockData.customers.firstWhere(
      (c) => c.id == booking.customerId,
      orElse: () => UserModel(id: booking.customerId, name: 'Unknown Customer', phone: '', role: 'customer'),
    );

    return BookingDetailBundle(
      booking: booking,
      car: car,
      vendor: vendor,
      customer: customer,
    );
  }

  @override
  Future<void> overrideBookingStatus(String bookingId, String newStatus) async {
    await _delay();
    final idx = MockData.bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      final old = MockData.bookings[idx];
      MockData.bookings[idx] = old.copyWith(status: newStatus);
    }
  }

  @override
  Future<void> flagBookingDispute(String bookingId, String note) async {
    await _delay();
    final idx = MockData.bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      final old = MockData.bookings[idx];
      if (note.isEmpty) {
        MockData.bookings[idx] = old.copyWith(
          disputeFlag: false,
          disputeNote: null,
        );
      } else {
        MockData.bookings[idx] = old.copyWith(
          disputeFlag: true,
          disputeNote: note,
        );
      }
    }
  }

  @override
  Future<PaymentOrderModel?> getBookingPayment(String bookingId) async {
    await _delay();
    return PaymentOrderModel(
      id: 'pay_$bookingId',
      bookingId: bookingId,
      amount: 4500.0,
      amountInPaise: 450000,
      currency: 'INR',
      keyId: 'rzp_test_mock',
      status: 'PAID',
      razorpayOrderId: 'order_mock_$bookingId',
      razorpayPaymentId: 'pay_mock_$bookingId',
      gatewayProvider: 'razorpay',
    );
  }


  @override
  Future<void> issueAdminRefund({
    required String bookingId,
    required double amount,
    required String reason,
    required String idempotencyKey,
  }) async {
    await _delay();
  }
}

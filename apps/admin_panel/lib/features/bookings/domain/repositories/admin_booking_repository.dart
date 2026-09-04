import 'package:flutter/material.dart';
import 'package:models/models.dart';

class BookingDetailBundle {
  final BookingModel booking;
  final CarModel car;
  final VendorModel vendor;
  final UserModel customer;

  const BookingDetailBundle({
    required this.booking,
    required this.car,
    required this.vendor,
    required this.customer,
  });
}

abstract class AdminBookingRepository {
  Future<List<BookingModel>> getBookings({
    String? city,
    DateTimeRange? dateRange,
    String? tripType,
    String? status,
    String? vendorId,
    String? carType,
  });

  Future<BookingDetailBundle> getBookingDetail(String bookingId);

  Future<void> overrideBookingStatus(String bookingId, String newStatus);

  Future<void> flagBookingDispute(String bookingId, String note);

  Future<PaymentOrderModel?> getBookingPayment(String bookingId);

  Future<void> issueAdminRefund({
    required String bookingId,
    required double amount,
    required String reason,
    required String idempotencyKey,
  });
}

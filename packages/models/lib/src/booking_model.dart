import 'package:freezed_annotation/freezed_annotation.dart';

part 'booking_model.freezed.dart';
part 'booking_model.g.dart';

@freezed
class BookingModel with _$BookingModel {
  const factory BookingModel({
    required String id,
    required String customerId,
    required String vendorId,
    required String carId,
    required String tripType, // Local, Outstation, Airport, Self-Drive
    required String pickupLocation,
    String? dropLocation,
    required DateTime startDate,
    required DateTime endDate,
    required double totalFare,
    required double platformFee,
    required double gstAmount,
    required double netToVendor,
    required String status, // pending, confirmed, ongoing, completed, cancelled
    required DateTime createdAt,
    @Default(false) bool disputeFlag,
    String? disputeNote,
    String? pickupHubId,
    String? returnHubId,
    String? pickupName,
    String? dropName,
    double? returnFee,
    double? oneWayFee,
  }) = _BookingModel;

  factory BookingModel.fromJson(Map<String, dynamic> json) => _$BookingModelFromJson(json);
}

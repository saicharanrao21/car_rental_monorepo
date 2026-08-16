import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import '../../domain/repositories/booking_repository.dart';
import 'booking_providers.dart';

// ── Step counter ─────────────────────────────────────────────────────────────

final currentStepProvider = StateProvider.autoDispose<int>((ref) => 0);

// ── Draft model ──────────────────────────────────────────────────────────────

class BookingDraft {
  final String carId;
  final String vendorId;
  final String tripType;
  final String pickupLocation;
  final String dropLocation;
  final DateTime? startDate;
  final DateTime? endDate;
  final int estimatedDistanceKm;
  // Add-ons
  final bool driverIncluded;
  final bool childSeat;
  final bool extraLuggage;
  // Contact
  final String contactName;
  final String contactPhone;
  // Fare (set in step 3)
  final double baseFare;
  final double platformFee;
  final double gst;
  final double totalFare;
  final double netToVendor;
  final double commissionPercent;

  // Coupon
  final String? appliedCouponCode;
  final double couponDiscountAmount;
  final CouponValidationResultModel? appliedCoupon;

  const BookingDraft({
    this.carId = '',
    this.vendorId = '',
    this.tripType = 'Local',
    this.pickupLocation = '',
    this.dropLocation = '',
    this.startDate,
    this.endDate,
    this.estimatedDistanceKm = 50,
    this.driverIncluded = true,
    this.childSeat = false,
    this.extraLuggage = false,
    this.contactName = '',
    this.contactPhone = '',
    this.baseFare = 0,
    this.platformFee = 0,
    this.gst = 0,
    this.totalFare = 0,
    this.netToVendor = 0,
    this.commissionPercent = 10.0,
    this.appliedCouponCode,
    this.couponDiscountAmount = 0.0,
    this.appliedCoupon,
  });

  int get rentalDays {
    if (startDate == null || endDate == null) return 1;
    return endDate!.difference(startDate!).inDays.clamp(1, 9999);
  }

  BookingDraft copyWith({
    String? carId, String? vendorId, String? tripType,
    String? pickupLocation, String? dropLocation,
    DateTime? startDate, DateTime? endDate,
    int? estimatedDistanceKm,
    bool? driverIncluded, bool? childSeat, bool? extraLuggage,
    String? contactName, String? contactPhone,
    double? baseFare, double? platformFee, double? gst,
    double? totalFare, double? netToVendor, double? commissionPercent,
    String? appliedCouponCode, double? couponDiscountAmount,
    CouponValidationResultModel? appliedCoupon,
  }) {
    return BookingDraft(
      carId: carId ?? this.carId,
      vendorId: vendorId ?? this.vendorId,
      tripType: tripType ?? this.tripType,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropLocation: dropLocation ?? this.dropLocation,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      estimatedDistanceKm: estimatedDistanceKm ?? this.estimatedDistanceKm,
      driverIncluded: driverIncluded ?? this.driverIncluded,
      childSeat: childSeat ?? this.childSeat,
      extraLuggage: extraLuggage ?? this.extraLuggage,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      baseFare: baseFare ?? this.baseFare,
      platformFee: platformFee ?? this.platformFee,
      gst: gst ?? this.gst,
      totalFare: totalFare ?? this.totalFare,
      netToVendor: netToVendor ?? this.netToVendor,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      appliedCouponCode: appliedCouponCode ?? this.appliedCouponCode,
      couponDiscountAmount: couponDiscountAmount ?? this.couponDiscountAmount,
      appliedCoupon: appliedCoupon ?? this.appliedCoupon,
    );
  }
}

// ── Draft notifier ───────────────────────────────────────────────────────────

class BookingDraftNotifier extends AutoDisposeNotifier<BookingDraft> {
  @override
  BookingDraft build() => const BookingDraft();

  void init({
    required CarModel car,
    required String vendorId,
    required String tripType,
    String pickupLocation = '',
    String dropLocation = '',
    DateTime? startDate,
    DateTime? endDate,
    String contactName = '',
    String contactPhone = '',
  }) {
    final defaultTripType = car.availableTripTypes.contains(tripType)
        ? tripType
        : (car.availableTripTypes.isNotEmpty ? car.availableTripTypes.first : 'Local');

    state = BookingDraft(
      carId: car.id,
      vendorId: vendorId,
      tripType: defaultTripType,
      pickupLocation: pickupLocation,
      dropLocation: dropLocation,
      startDate: startDate ?? DateTime(2026, 8, 24, 10, 0),
      endDate: endDate ?? DateTime(2026, 8, 26, 10, 0),
      driverIncluded: defaultTripType != 'Self-Drive',
      contactName: contactName,
      contactPhone: contactPhone,
    );
  }

  void update(BookingDraft Function(BookingDraft) fn) { state = fn(state); }

  /// Compute and store fare components using FareCalculatorService.
  void computeFare({
    required CarModel car,
    required String vendorCity,
    required BookingRepository repo,
  }) {
    final config = repo.getCommissionConfig(
      city: vendorCity,
      carCategory: car.type,
      tripType: state.tripType,
    );
    final result = FareCalculatorService.calculateFare(
      distanceKm: state.estimatedDistanceKm.toDouble(),
      basePackagePrice: car.pricePerDay * state.rentalDays,
      pricePerKm: car.pricePerKm,
      commissionPercent: config.percentage,
    );
    state = state.copyWith(
      baseFare: result.baseFare,
      platformFee: result.platformFee,
      gst: result.gst,
      totalFare: result.total,
      netToVendor: result.netToVendor,
      commissionPercent: config.percentage,
    );
  }
}

final bookingDraftProvider =
    AutoDisposeNotifierProvider<BookingDraftNotifier, BookingDraft>(
        BookingDraftNotifier.new);

// ── Submit booking ────────────────────────────────────────────────────────────

class CreateBookingFlowNotifier extends AutoDisposeAsyncNotifier<BookingModel?> {
  @override
  Future<BookingModel?> build() async => null;

  Future<BookingModel> submit({
    required String customerId,
    required BookingDraft draft,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(bookingRepositoryProvider);
      final now = DateTime.now();
      final bookingDraft = BookingModel(
        id: 'draft',
        customerId: customerId,
        vendorId: draft.vendorId,
        carId: draft.carId,
        tripType: draft.tripType,
        pickupLocation: draft.pickupLocation.isEmpty ? 'TBD' : draft.pickupLocation,
        dropLocation: draft.dropLocation.isEmpty ? null : draft.dropLocation,
        startDate: draft.startDate ?? now,
        endDate: draft.endDate ?? now.add(const Duration(days: 1)),
        totalFare: draft.totalFare,
        platformFee: draft.platformFee,
        gstAmount: draft.gst,
        netToVendor: draft.netToVendor,
        status: 'confirmed',
        createdAt: now,
      );
      final created = await repo.createBooking(bookingDraft);
      state = AsyncValue.data(created);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final createBookingFlowProvider =
    AutoDisposeAsyncNotifierProvider<CreateBookingFlowNotifier, BookingModel?>(
        CreateBookingFlowNotifier.new);

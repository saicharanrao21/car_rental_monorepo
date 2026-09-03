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
  // Delivery Add-ons (Phase 4 Feature 26)
  final bool hasDoorstepDelivery;
  final String deliveryAddress;
  final double deliveryFee;
  final bool hasDoorstepPickup;
  final String returnPickupAddress;
  final double returnPickupFee;
  // Additional Driver Add-on (Phase 4 Feature 29)
  final bool hasAdditionalDriver;
  final String additionalDriverName;
  final String additionalDriverPhone;
  final String additionalDriverLicence;
  final double additionalDriverFee;
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

  // Protection Package Add-on (Feature 17)
  final String? selectedProtectionPackageId;
  final ProtectionPackageModel? selectedProtectionPackage;
  final double protectionFee;

  // Configurable Mileage Package (Phase 10)
  final String? selectedMileagePackageId;
  final MileagePackageModel? selectedMileagePackage;

  // Coupon
  final String? appliedCouponCode;
  final double couponDiscountAmount;
  final CouponValidationResultModel? appliedCoupon;

  // Structured Location & Fulfillment snapshot fields
  final String? pickupHubId;
  final String? returnHubId;
  final String? pickupName;
  final String? dropName;
  final String? pickupAddress;
  final double pickupFee;
  final double returnFee;
  final double oneWayFee;
  final String? deliveryType;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final bool isDifferentReturnLocation;
  final bool isQuoteLoading;
  final double quoteDistanceKm;
  final String? quoteErrorReason;

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
    this.hasDoorstepDelivery = false,
    this.deliveryAddress = '',
    this.deliveryFee = 0.0,
    this.hasDoorstepPickup = false,
    this.returnPickupAddress = '',
    this.returnPickupFee = 0.0,
    this.hasAdditionalDriver = false,
    this.additionalDriverName = '',
    this.additionalDriverPhone = '',
    this.additionalDriverLicence = '',
    this.additionalDriverFee = 0.0,
    this.selectedProtectionPackageId,
    this.selectedProtectionPackage,
    this.protectionFee = 0.0,
    this.selectedMileagePackageId,
    this.selectedMileagePackage,
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
    this.pickupHubId,
    this.returnHubId,
    this.pickupName,
    this.dropName,
    this.pickupAddress,
    this.pickupFee = 0.0,
    this.returnFee = 0.0,
    this.oneWayFee = 0.0,
    this.deliveryType,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.pickupLatitude,
    this.pickupLongitude,
    this.isDifferentReturnLocation = false,
    this.isQuoteLoading = false,
    this.quoteDistanceKm = 0.0,
    this.quoteErrorReason,
  });

  int get rentalDays {
    if (startDate == null || endDate == null) return 1;
    return endDate!.difference(startDate!).inDays.clamp(1, 9999);
  }

  BookingDraft copyWith({
    String? carId,
    String? vendorId,
    String? tripType,
    String? pickupLocation,
    String? dropLocation,
    DateTime? startDate,
    DateTime? endDate,
    int? estimatedDistanceKm,
    bool? driverIncluded,
    bool? childSeat,
    bool? extraLuggage,
    bool? hasDoorstepDelivery,
    String? deliveryAddress,
    double? deliveryFee,
    bool? hasDoorstepPickup,
    String? returnPickupAddress,
    double? returnPickupFee,
    bool? hasAdditionalDriver,
    String? additionalDriverName,
    String? additionalDriverPhone,
    String? additionalDriverLicence,
    double? additionalDriverFee,
    String? selectedProtectionPackageId,
    ProtectionPackageModel? selectedProtectionPackage,
    double? protectionFee,
    String? selectedMileagePackageId,
    MileagePackageModel? selectedMileagePackage,
    String? contactName,
    String? contactPhone,
    double? baseFare,
    double? platformFee,
    double? gst,
    double? totalFare,
    double? netToVendor,
    double? commissionPercent,
    String? appliedCouponCode,
    double? couponDiscountAmount,
    CouponValidationResultModel? appliedCoupon,
    String? pickupHubId,
    String? returnHubId,
    String? pickupName,
    String? dropName,
    String? pickupAddress,
    double? pickupFee,
    double? returnFee,
    double? oneWayFee,
    String? deliveryType,
    double? deliveryLatitude,
    double? deliveryLongitude,
    double? pickupLatitude,
    double? pickupLongitude,
    bool? isDifferentReturnLocation,
    bool? isQuoteLoading,
    double? quoteDistanceKm,
    String? quoteErrorReason,
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
      hasDoorstepDelivery: hasDoorstepDelivery ?? this.hasDoorstepDelivery,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      hasDoorstepPickup: hasDoorstepPickup ?? this.hasDoorstepPickup,
      returnPickupAddress: returnPickupAddress ?? this.returnPickupAddress,
      returnPickupFee: returnPickupFee ?? this.returnPickupFee,
      hasAdditionalDriver: hasAdditionalDriver ?? this.hasAdditionalDriver,
      additionalDriverName: additionalDriverName ?? this.additionalDriverName,
      additionalDriverPhone:
          additionalDriverPhone ?? this.additionalDriverPhone,
      additionalDriverLicence:
          additionalDriverLicence ?? this.additionalDriverLicence,
      additionalDriverFee: additionalDriverFee ?? this.additionalDriverFee,
      selectedProtectionPackageId:
          selectedProtectionPackageId ?? this.selectedProtectionPackageId,
      selectedProtectionPackage:
          selectedProtectionPackage ?? this.selectedProtectionPackage,
      protectionFee: protectionFee ?? this.protectionFee,
      selectedMileagePackageId:
          selectedMileagePackageId ?? this.selectedMileagePackageId,
      selectedMileagePackage:
          selectedMileagePackage ?? this.selectedMileagePackage,
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
      pickupHubId: pickupHubId ?? this.pickupHubId,
      returnHubId: returnHubId ?? this.returnHubId,
      pickupName: pickupName ?? this.pickupName,
      dropName: dropName ?? this.dropName,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupFee: pickupFee ?? this.pickupFee,
      returnFee: returnFee ?? this.returnFee,
      oneWayFee: oneWayFee ?? this.oneWayFee,
      deliveryType: deliveryType ?? this.deliveryType,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      isDifferentReturnLocation:
          isDifferentReturnLocation ?? this.isDifferentReturnLocation,
      isQuoteLoading: isQuoteLoading ?? this.isQuoteLoading,
      quoteDistanceKm: quoteDistanceKm ?? this.quoteDistanceKm,
      quoteErrorReason: quoteErrorReason ?? this.quoteErrorReason,
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
    MileagePackageModel? defaultPackage;
    if (car.rawMileagePackages.isNotEmpty) {
      final packages = car.rawMileagePackages
          .map((p) =>
              MileagePackageModel.fromJson(Map<String, dynamic>.from(p as Map)))
          .where((p) => p.isActive && p.tripType == tripType)
          .toList();
      if (packages.isNotEmpty) {
        defaultPackage =
            packages.firstWhere((p) => p.isDefault, orElse: () => packages.first);
      }
    }

    state = BookingDraft(
      carId: car.id,
      vendorId: vendorId,
      tripType: tripType,
      pickupLocation: pickupLocation,
      dropLocation: dropLocation,
      startDate: startDate ?? DateTime(2026, 8, 24, 10, 0),
      endDate: endDate ?? DateTime(2026, 8, 26, 10, 0),
      driverIncluded: tripType != 'Self-Drive',
      selectedMileagePackageId: defaultPackage?.id,
      selectedMileagePackage: defaultPackage,
      contactName: contactName,
      contactPhone: contactPhone,
    );
  }

  void update(BookingDraft Function(BookingDraft) fn) {
    state = fn(state);
  }

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

    final isPackageTier = state.selectedMileagePackage != null;
    final basePackagePrice = isPackageTier
        ? state.selectedMileagePackage!.basePricePerDay * state.rentalDays
        : car.pricePerDay * state.rentalDays;
    final distanceKm = isPackageTier ? 0.0 : state.estimatedDistanceKm.toDouble();
    final pricePerKm = isPackageTier ? 0.0 : car.pricePerKm;

    final result = FareCalculatorService.calculateFare(
      distanceKm: distanceKm,
      basePackagePrice: basePackagePrice,
      pricePerKm: pricePerKm,
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
  /// Authoritatively quotes fulfillment costs from the backend
  Future<void> refreshAuthoritativeQuote({
    required BookingRepository repo,
    String? vendorId,
    String? carId,
  }) async {
    final vId = (vendorId != null && vendorId.isNotEmpty) ? vendorId : state.vendorId;
    if (vId.isEmpty) return;

    state = state.copyWith(isQuoteLoading: true, quoteErrorReason: null);

    try {
      final res = await repo.calculateLocationQuote(
        vendorId: vId,
        pickupLocationId: state.pickupHubId,
        returnLocationId: state.isDifferentReturnLocation ? state.returnHubId : state.pickupHubId,
        customerLatitude: state.deliveryLatitude,
        customerLongitude: state.deliveryLongitude,
        deliveryAddress: state.hasDoorstepDelivery ? state.deliveryAddress : null,
      );

      final isAvail = res['isAvailable'] as bool? ?? true;
      final deliveryFee = (res['deliveryFee'] as num?)?.toDouble() ?? 0.0;
      final pickupFee = (res['pickupFee'] as num?)?.toDouble() ?? 0.0;
      final returnFee = (res['returnFee'] as num?)?.toDouble() ?? 0.0;
      final oneWayFee = ((res['oneWaySurcharge'] ?? res['oneWayFee']) as num?)?.toDouble() ?? 0.0;
      final distKm = (res['distanceKm'] as num?)?.toDouble() ?? 0.0;
      final reason = res['reason']?.toString();

      state = state.copyWith(
        isQuoteLoading: false,
        deliveryFee: state.hasDoorstepDelivery ? deliveryFee : 0.0,
        pickupFee: pickupFee,
        returnFee: returnFee,
        oneWayFee: state.isDifferentReturnLocation ? oneWayFee : 0.0,
        quoteDistanceKm: distKm,
        quoteErrorReason: isAvail ? null : (reason ?? 'Fulfillment option unavailable'),
      );
    } catch (e) {
      state = state.copyWith(
        isQuoteLoading: false,
        quoteErrorReason: e.toString().replaceAll('Exception: ', '').replaceAll('DioException: ', ''),
      );
    }
  }
}

final bookingDraftProvider =
    AutoDisposeNotifierProvider<BookingDraftNotifier, BookingDraft>(
        BookingDraftNotifier.new);

// ── Submit booking ────────────────────────────────────────────────────────────

class CreateBookingFlowNotifier
    extends AutoDisposeAsyncNotifier<BookingModel?> {
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
      final defaultStart = draft.startDate ?? now.add(const Duration(days: 6));
      final defaultEnd = draft.endDate ?? now.add(const Duration(days: 8));
      final bookingDraft = BookingModel(
        id: 'draft',
        customerId: customerId,
        vendorId: draft.vendorId,
        carId: draft.carId,
        tripType: draft.tripType,
        pickupLocation:
            draft.pickupLocation.isEmpty ? 'TBD' : draft.pickupLocation,
        dropLocation: draft.dropLocation.isEmpty ? null : draft.dropLocation,
        startDate: defaultStart.isBefore(now)
            ? now.add(const Duration(days: 6))
            : defaultStart,
        endDate: defaultEnd.isBefore(now)
            ? now.add(const Duration(days: 8))
            : defaultEnd,
        totalFare: draft.totalFare,
        platformFee: draft.platformFee,
        gstAmount: draft.gst,
        netToVendor: draft.netToVendor,
        status: 'confirmed',
        createdAt: now,
        pickupHubId: draft.pickupHubId,
        returnHubId: draft.isDifferentReturnLocation ? draft.returnHubId : draft.pickupHubId,
        pickupName: draft.pickupName,
        dropName: draft.dropName,
        pickupAddress: draft.pickupAddress,
        deliveryAddress: draft.hasDoorstepDelivery ? draft.deliveryAddress : null,
        deliveryFee: draft.hasDoorstepDelivery ? draft.deliveryFee : 0.0,
        pickupFee: draft.pickupFee,
        returnFee: draft.returnFee,
        oneWayFee: draft.isDifferentReturnLocation ? draft.oneWayFee : 0.0,
        deliveryType: draft.hasDoorstepDelivery
            ? 'DOORSTEP_DELIVERY'
            : (draft.pickupHubId != null ? 'HUB_PICKUP' : 'STANDARD'),
        deliveryLatitude: draft.deliveryLatitude,
        deliveryLongitude: draft.deliveryLongitude,
        pickupLatitude: draft.pickupLatitude,
        pickupLongitude: draft.pickupLongitude,
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

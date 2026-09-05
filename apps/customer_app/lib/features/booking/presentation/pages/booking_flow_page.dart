import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';
import '../providers/booking_providers.dart';
import '../../../car_detail/presentation/providers/car_detail_providers.dart';
import '../../../home/home_providers.dart';
import '../../../search/presentation/providers/search_providers.dart';
import '../../../../core/providers/session_provider.dart';
import '../widgets/booking_progress_indicator.dart';
import '../widgets/booking_sticky_bottom_bar.dart';
import '../widgets/booking_price_breakdown_card.dart';
import '../widgets/trip_details_step.dart';
import '../widgets/addons_step.dart';
import '../widgets/fare_breakdown_step.dart';
import '../widgets/contact_confirm_step.dart';
import '../widgets/payment_step.dart';

const _stepTitles = [
  'Trip Details',
  'Plan & Add-ons',
  'Contact Info',
  'Review & Fare',
  'Payment',
];

class BookingFlowPage extends ConsumerStatefulWidget {
  final String carId;

  const BookingFlowPage({super.key, required this.carId});

  @override
  ConsumerState<BookingFlowPage> createState() => _BookingFlowPageState();
}

class _BookingFlowPageState extends ConsumerState<BookingFlowPage> {
  bool _initialized = false;
  final _contactFormKey = GlobalKey<FormState>();
  final _paymentKey = GlobalKey<PaymentStepState>();

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(currentStepProvider);
    final detailVal = ref.watch(carDetailDataProvider(widget.carId));
    final tripType = ref.watch(selectedTripTypeProvider);
    final draft = ref.watch(bookingDraftProvider);
    final repo = ref.watch(bookingRepositoryProvider);

    return Scaffold(
      backgroundColor: DDSColors.bgCanvas,
      appBar: AppBar(
        title: Text(
          'Book — ${_stepTitles[step]}',
          style: DDSTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: DDSColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DDSColors.textPrimary),
          onPressed: () => _prev(ref),
        ),
        backgroundColor: DDSColors.surfaceCard,
        elevation: 0,
      ),
      body: detailVal.when(
        loading: () => const AppLoader(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(carDetailDataProvider(widget.carId)),
        ),
        data: (detail) {
          // Defensive Check: If this car does not support the selected trip type,
          // do NOT silently mutate trip type or proceed with an invalid draft.
          final isCompatible = detail.car.availableTripTypes.contains(tripType);
          if (!isCompatible) {
            return _IncompatibleTripTypeView(
              car: detail.car,
              requestedTripType: tripType,
            );
          }

          // Initialise draft once for compatible vehicle
          if (!_initialized) {
            _initialized = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final session = ref.read(sessionProvider);
              final dateRange = ref.read(selectedDateRangeProvider);
              final searchDates = ref.read(searchDatesProvider);
              final pickup = ref.read(pickupLocationProvider) ??
                  ref.read(searchPickupLocationProvider);
              final drop = ref.read(dropLocationProvider) ??
                  ref.read(searchDropLocationProvider);
              final structuredPickup = ref.read(structuredPickupLocationProvider);
              final structuredDrop = ref.read(structuredDropLocationProvider);

              ref.read(bookingDraftProvider.notifier).init(
                    car: detail.car,
                    vendorId: detail.vendor.id,
                    tripType: tripType,
                    pickupLocation: pickup ?? '',
                    dropLocation: drop ?? '',
                    startDate: dateRange?.start ?? searchDates?.start,
                    endDate: dateRange?.end ?? searchDates?.end,
                    contactName: session.user?.name ?? '',
                    contactPhone: session.user?.phone ?? '',
                    pickupHubId: structuredPickup?.id,
                    returnHubId: structuredDrop?.id,
                    pickupAddress: structuredPickup?.address,
                    pickupLatitude: structuredPickup?.lat,
                    pickupLongitude: structuredPickup?.lng,
                    pickupFee: structuredPickup?.fee ?? 0.0,
                    returnFee: structuredDrop?.fee ?? 0.0,
                    pickupName: structuredPickup?.name,
                    dropName: structuredDrop?.name,
                  );
            });
          }

          // Compute live fare snapshot for sticky bottom bar & review
          final rentalDays = draft.rentalDays;
          double discountPercent = 0.0;
          String discountLabel = '';
          final weeklyPct = (detail.car.weeklyDiscountPercent != null &&
                  detail.car.weeklyDiscountPercent! > 0)
              ? detail.car.weeklyDiscountPercent!
              : 15.0;
          final monthlyPct = (detail.car.monthlyDiscountPercent != null &&
                  detail.car.monthlyDiscountPercent! > 0)
              ? detail.car.monthlyDiscountPercent!
              : 25.0;

          if (rentalDays >= 30) {
            discountPercent = monthlyPct;
            discountLabel = 'Monthly discount (${discountPercent.toInt()}%)';
          } else if (rentalDays >= 7) {
            discountPercent = weeklyPct;
            discountLabel = 'Weekly discount (${discountPercent.toInt()}%)';
          }

          final isPackageTier = draft.selectedMileagePackage != null;
          final originalRentalFare = isPackageTier
              ? draft.selectedMileagePackage!.basePricePerDay * rentalDays
              : detail.car.pricePerDay * rentalDays;
          final discountAmount = originalRentalFare * (discountPercent / 100.0);
          final actualBasePackagePrice = originalRentalFare - discountAmount;

          final config = repo.getCommissionConfig(
            city: detail.vendor.city,
            carCategory: detail.car.type,
            tripType: draft.tripType,
          );
          final distanceKm =
              isPackageTier ? 0.0 : draft.estimatedDistanceKm.toDouble();
          final pricePerKm = isPackageTier ? 0.0 : detail.car.pricePerKm;

          final fareResult = FareCalculatorService.calculateFare(
            distanceKm: distanceKm,
            basePackagePrice: actualBasePackagePrice,
            pricePerKm: pricePerKm,
            commissionPercent: config.percentage,
          );

          final totalAddons = draft.protectionFee +
              draft.deliveryFee +
              draft.returnPickupFee +
              draft.additionalDriverFee;
          final calculatedTotal = (fareResult.total +
                  totalAddons -
                  draft.couponDiscountAmount)
              .clamp(0.0, double.infinity);

          final primaryButtonText = _getPrimaryButtonText(step, calculatedTotal);
          final isPaymentLoading =
              ref.watch(createBookingFlowProvider).isLoading;

          return Column(
            children: [
              // ── Progress Indicator ──────────────────────────────────
              BookingProgressIndicator(
                currentStep: step,
                stepTitles: _stepTitles,
              ),

              // ── Step Content ────────────────────────────────────────
              Expanded(
                child: IndexedStack(
                  index: step,
                  children: [
                    TripDetailsStep(
                      car: detail.car,
                      vendor: detail.vendor,
                      onNext: () => _next(ref),
                    ),
                    AddonsStep(
                      car: detail.car,
                      vendor: detail.vendor,
                      onBack: () => _prev(ref),
                      onNext: () => _next(ref),
                    ),
                    ContactConfirmStep(
                      formKey: _contactFormKey,
                      onBack: () => _prev(ref),
                      onNext: () => _next(ref),
                    ),
                    FareBreakdownStep(
                      car: detail.car,
                      vendor: detail.vendor,
                      onBack: () => _prev(ref),
                      onNext: () => _next(ref),
                    ),
                    PaymentStep(
                      key: _paymentKey,
                      onBack: () => _prev(ref),
                      onSuccess: (bookingId) {
                        context.go('/booking/confirmation/$bookingId');
                      },
                    ),
                  ],
                ),
              ),

              // ── Sticky Bottom Action Bar ────────────────────────────
              BookingStickyBottomBar(
                totalAmount: calculatedTotal,
                primaryButtonText: primaryButtonText,
                isLoading: isPaymentLoading,
                showBackButton: step > 0,
                onBackPressed: () => _prev(ref),
                onBreakdownPressed: () {
                  AppBottomSheet.show(
                    context,
                    title: 'Fare Breakdown',
                    child: BookingPriceBreakdownCard(
                      car: detail.car,
                      vendor: detail.vendor,
                      originalRentalFare: originalRentalFare,
                      discountPercent: discountPercent,
                      discountLabel: discountLabel,
                      discountAmount: discountAmount,
                      result: fareResult,
                      finalPayable: calculatedTotal,
                      config: config,
                    ),
                  );
                },
                onPrimaryPressed: () => _handlePrimaryAction(
                  ref,
                  step: step,
                  fareResult: fareResult,
                  calculatedTotal: calculatedTotal,
                  config: config,
                  car: detail.car,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getPrimaryButtonText(int step, double total) {
    switch (step) {
      case 0:
        return 'Next: Add-ons';
      case 1:
        return 'Next: Contact';
      case 2:
        return 'Review Booking →';
      case 3:
        return 'Proceed to Pay →';
      case 4:
      default:
        return 'Pay ${IndianCurrencyFormatter.format(total, showDecimals: false)}';
    }
  }

  void _handlePrimaryAction(
    WidgetRef ref, {
    required int step,
    required FareCalculatorResult fareResult,
    required double calculatedTotal,
    required CommissionConfigModel config,
    required CarModel car,
  }) {
    if (step == 0) {
      final draft = ref.read(bookingDraftProvider);
      final hasPackages = car.rawMileagePackages.isNotEmpty;
      if (hasPackages && draft.selectedMileagePackageId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a mileage package to continue.'),
          ),
        );
        return;
      }
      if (draft.startDate != null && draft.endDate != null) {
        _checkAvailabilityAndProceed(ref, car, draft);
        return;
      }
      _next(ref);
    } else if (step == 1) {
      _next(ref);
    } else if (step == 2) {
      if (_contactFormKey.currentState?.validate() ?? true) {
        _next(ref);
      }
    } else if (step == 3) {
      // Persist finalized fare breakdown onto draft before proceeding to payment
      ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
            baseFare: fareResult.baseFare,
            platformFee: fareResult.platformFee,
            gst: fareResult.gst,
            totalFare: calculatedTotal,
            netToVendor: fareResult.netToVendor,
            commissionPercent: config.percentage,
          ));
      _next(ref);
    } else if (step == 4) {
      _paymentKey.currentState?.startPaymentFlow();
    }
  }

  Future<void> _checkAvailabilityAndProceed(
    WidgetRef ref,
    CarModel car,
    BookingDraft draft,
  ) async {
    final repo = ref.read(bookingRepositoryProvider);
    try {
      final res = await repo.checkVehicleAvailability(
        carId: car.id,
        startDate: draft.startDate!,
        endDate: draft.endDate!,
        hubId: draft.pickupHubId,
      );

      if (!mounted) return;

      if (!res.available) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Vehicle Not Available'),
            content: Text(res.reason ?? 'This vehicle is not available for the selected dates.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Change Dates'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/search');
                },
                child: const Text('Find Other Cars'),
              ),
            ],
          ),
        );
        return;
      }

      _next(ref);
    } catch (e) {
      // Proceed on network timeout to let checkout transaction perform authoritative check
      if (mounted) _next(ref);
    }
  }

  void _next(WidgetRef ref) {
    final step = ref.read(currentStepProvider);
    if (step < _stepTitles.length - 1) {
      ref.read(currentStepProvider.notifier).state = step + 1;
    }
  }

  void _prev(WidgetRef ref) {
    final step = ref.read(currentStepProvider);
    if (step > 0) {
      ref.read(currentStepProvider.notifier).state = step - 1;
    } else {
      context.pop();
    }
  }
}

class _IncompatibleTripTypeView extends ConsumerWidget {
  final CarModel car;
  final String requestedTripType;

  const _IncompatibleTripTypeView({
    required this.car,
    required this.requestedTripType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCity = ref.read(selectedCityProvider);

    return Padding(
      padding: const EdgeInsets.all(DDSSpacing.xl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(DDSSpacing.lg),
              decoration: BoxDecoration(
                color: DDSColors.accentAmber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: DDSColors.accentAmber,
              ),
            ),
            const Gap(DDSSpacing.lg),
            Text(
              'Trip Type Not Supported',
              style: DDSTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: DDSColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(DDSSpacing.sm),
            Text(
              '${car.make} ${car.model} (${car.year}) is not eligible for $requestedTripType bookings. '
              'This car only supports: ${car.availableTripTypes.join(', ')}.',
              style: DDSTypography.bodyMedium.copyWith(
                color: DDSColors.textMuted,
                height: 1.4,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(DDSSpacing.xl),
            AppButton(
              text: 'Browse $requestedTripType Cars',
              onPressed: () {
                context.push(
                  '/search?city=${Uri.encodeComponent(selectedCity)}'
                  '&tripType=${Uri.encodeComponent(requestedTripType)}'
                  '&start='
                  '&end='
                  '&pickup='
                  '&drop=',
                );
              },
            ),
            const Gap(DDSSpacing.sm),
            OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: DDSRadius.mediumBorderRadius,
                ),
                side: const BorderSide(color: DDSColors.borderMedium),
              ),
              child: Text(
                'Go Back',
                style: DDSTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: DDSColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

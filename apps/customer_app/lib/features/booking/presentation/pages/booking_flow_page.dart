import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';
import '../../../car_detail/presentation/providers/car_detail_providers.dart';
import '../../../home/home_providers.dart';
import '../../../search/presentation/providers/search_providers.dart';
import '../../../../core/providers/session_provider.dart';
import '../widgets/trip_details_step.dart';
import '../widgets/addons_step.dart';
import '../widgets/fare_breakdown_step.dart';
import '../widgets/contact_confirm_step.dart';
import '../widgets/payment_step.dart';

const _stepTitles = [
  'Trip Details',
  'Add-ons',
  'Fare Breakdown',
  'Contact Info',
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

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(currentStepProvider);
    final detailVal = ref.watch(carDetailDataProvider(widget.carId));
    final tripType = ref.watch(selectedTripTypeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Book — ${_stepTitles[step]}'),
        leading: step == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _prev(ref),
              ),
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
              final pickup = ref.read(pickupLocationProvider) ?? ref.read(searchPickupLocationProvider);
              final drop = ref.read(dropLocationProvider) ?? ref.read(searchDropLocationProvider);

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
                  );
            });
          }

          return Column(
            children: [
              // ── Step Indicator ────────────────────────────────────────
              _StepIndicator(current: step, total: _stepTitles.length),

              // ── Step Content ──────────────────────────────────────────
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
                      onBack: () => _prev(ref),
                      onNext: () => _next(ref),
                    ),
                    FareBreakdownStep(
                      car: detail.car,
                      vendor: detail.vendor,
                      onBack: () => _prev(ref),
                      onNext: () => _next(ref),
                    ),
                    ContactConfirmStep(
                      onBack: () => _prev(ref),
                      onNext: () => _next(ref),
                    ),
                    PaymentStep(
                      onBack: () => _prev(ref),
                      onSuccess: (bookingId) {
                        context.go('/booking/confirmation/$bookingId');
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
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
    final cs = Theme.of(context).colorScheme;
    final selectedCity = ref.read(selectedCityProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Colors.amber,
              ),
            ),
            const Gap(24),
            Text(
              'Trip Type Not Supported',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(12),
            Text(
              '${car.make} ${car.model} (${car.year}) is not eligible for $requestedTripType bookings. '
              'This car only supports: ${car.availableTripTypes.join(', ')}.',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(32),
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
            const Gap(12),
            OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(total, (i) {
              final isPassed = i < current;
              final isCurrent = i == current;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? AppColors.primary
                        : isCurrent
                            ? AppColors.accent
                            : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const Gap(8),
          Text(
            'Step ${current + 1} of $total: ${_stepTitles[current]}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

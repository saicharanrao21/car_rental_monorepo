import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          // Initialise draft once
          if (!_initialized) {
            _initialized = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final session = ref.read(sessionProvider);
              final tripType = ref.read(selectedTripTypeProvider);
              final dateRange = ref.read(selectedDateRangeProvider);
              final searchDates = ref.read(searchDatesProvider);
              final pickup = ref.read(pickupLocationProvider);
              final drop = ref.read(dropLocationProvider);

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

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(total, (i) {
              final isDone = i < current;
              final isActive = i == current;
              return Expanded(
                child: Row(
                  children: [
                    _Dot(isDone: isDone, isActive: isActive, index: i),
                    if (i < total - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isDone ? AppColors.primary : Colors.grey[300],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const Gap(6),
          Text(
            'Step ${current + 1} of $total — ${_stepTitles[current]}',
            style: const TextStyle(
                fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool isDone;
  final bool isActive;
  final int index;

  const _Dot({required this.isDone, required this.isActive, required this.index});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 28 : 22,
      height: isActive ? 28 : 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone
            ? AppColors.primary
            : isActive
                ? AppColors.primary
                : Colors.grey[200],
        border: isActive ? Border.all(color: AppColors.primary, width: 2) : null,
        boxShadow: isActive
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8)]
            : null,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, color: Colors.white, size: 14)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : Colors.grey,
                ),
              ),
      ),
    );
  }
}

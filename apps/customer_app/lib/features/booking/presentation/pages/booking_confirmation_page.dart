import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';
import '../providers/booking_providers.dart';

class BookingConfirmationPage extends ConsumerWidget {
  final String bookingId;

  const BookingConfirmationPage({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingWithDetailsVal =
        ref.watch(bookingWithDetailsProvider(bookingId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Booking Confirmed',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: bookingWithDetailsVal.when(
        loading: () => const AppLoader(),
        error: (err, stack) => ErrorStateWidget(
          message: 'Error loading booking details: $err',
          onRetry: () =>
              ref.invalidate(bookingWithDetailsProvider(bookingId)),
        ),
        data: (details) {
          if (details == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.search_off_outlined,
                        color: Colors.amber,
                        size: 48,
                      ),
                    ),
                    const Gap(16),
                    Text(
                      'Booking not found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      'The requested booking record could not be loaded.',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const Gap(24),
                    AppButton(
                      text: 'Back to Home',
                      onPressed: () {
                        ref.invalidate(currentStepProvider);
                        ref.invalidate(bookingDraftProvider);
                        context.go('/home');
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          final booking = details.booking;
          final car = details.car;
          final vendor = details.vendor;

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Success Badge & Headline ─────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 64,
                    ),
                  ),
                ),
                const Gap(16),
                Text(
                  'Booking Confirmed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const Gap(4),
                Text(
                  'Booking ID: ${booking.id}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(20),

                // ── Vendor Coordination Card ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_in_talk_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Handover Coordination',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: cs.onSurface,
                              ),
                            ),
                            const Gap(2),
                            Text(
                              '${vendor.businessName} will contact you shortly to coordinate vehicle handover & delivery.',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(16),

                // ── Trip Summary Card ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const Gap(12),
                      Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.25),
                      ),
                      const Gap(10),
                      _summaryRow(
                        'Vehicle',
                        '${car.make} ${car.model}',
                        Icons.directions_car_outlined,
                        cs,
                      ),
                      const Gap(8),
                      _summaryRow(
                        'Trip Type',
                        booking.tripType,
                        Icons.category_outlined,
                        cs,
                      ),
                      const Gap(8),
                      _summaryRow(
                        'Pickup Location',
                        booking.pickupLocation,
                        Icons.location_on_outlined,
                        cs,
                      ),
                      if (booking.dropLocation != null &&
                          booking.dropLocation!.isNotEmpty) ...[
                        const Gap(8),
                        _summaryRow(
                          'Drop Location',
                          booking.dropLocation!,
                          Icons.flag_outlined,
                          cs,
                        ),
                      ],
                      const Gap(8),
                      _summaryRow(
                        'Duration',
                        '${booking.startDate.toDDMMYYYY()} → ${booking.endDate.toDDMMYYYY()}',
                        Icons.calendar_today_outlined,
                        cs,
                      ),
                      const Gap(12),
                      Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                      const Gap(10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Paid / Payable',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            IndianCurrencyFormatter.format(
                              booking.totalFare,
                              showDecimals: false,
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(24),

                // ── Action Buttons ───────────────────────────────────
                AppButton(
                  text: 'View Booking Details',
                  onPressed: () {
                    context.go('/bookings/${booking.id}');
                  },
                ),
                const Gap(12),
                OutlinedButton(
                  onPressed: () {
                    ref.invalidate(currentStepProvider);
                    ref.invalidate(bookingDraftProvider);
                    context.go('/home');
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'Back to Home',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryRow(
      String label, String value, IconData icon, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const Gap(8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: cs.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

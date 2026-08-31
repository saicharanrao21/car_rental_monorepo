import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
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

    return Scaffold(
      backgroundColor: DDSColors.bgCanvas,
      appBar: AppBar(
        title: Text(
          'Booking Confirmed',
          style: DDSTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: DDSColors.textPrimary,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: DDSColors.surfaceCard,
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
                padding: const EdgeInsets.all(DDSSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DDSSpacing.md),
                      decoration: BoxDecoration(
                        color: DDSColors.accentAmber.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.search_off_outlined,
                        color: DDSColors.accentAmber,
                        size: 48,
                      ),
                    ),
                    const Gap(DDSSpacing.md),
                    Text(
                      'Booking not found',
                      style: DDSTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                    const Gap(DDSSpacing.xs),
                    Text(
                      'The requested booking record could not be loaded.',
                      style: DDSTypography.bodyMedium.copyWith(
                        color: DDSColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const Gap(DDSSpacing.lg),
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

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(DDSSpacing.md, DDSSpacing.lg, DDSSpacing.md, DDSSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Success Badge & Headline ─────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(DDSSpacing.lg),
                    decoration: const BoxDecoration(
                      color: DDSColors.successGreenBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: DDSColors.successGreen,
                      size: 56,
                    ),
                  ),
                ),
                const Gap(DDSSpacing.md),
                Text(
                  'Payment Successful!',
                  textAlign: TextAlign.center,
                  style: DDSTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DDSColors.textPrimary,
                  ),
                ),
                const Gap(DDSSpacing.xxs),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: booking.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Booking ID copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: DDSRadius.pillBorderRadius,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Booking #${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length).toUpperCase()}',
                        style: DDSTypography.bodyMedium.copyWith(
                          color: DDSColors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const Gap(4),
                      const Icon(Icons.copy_outlined, size: 13, color: DDSColors.textMuted),
                    ],
                  ),
                ),
                const Gap(DDSSpacing.lg),

                // ── Owner Review Status Card ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(DDSSpacing.md),
                  decoration: BoxDecoration(
                    color: DDSColors.accentAmber.withValues(alpha: 0.1),
                    borderRadius: DDSRadius.largeBorderRadius,
                    border: Border.all(
                      color: DDSColors.accentAmber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(DDSSpacing.xs),
                        decoration: BoxDecoration(
                          color: DDSColors.accentAmber.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          color: DDSColors.accentAmber,
                          size: 20,
                        ),
                      ),
                      const Gap(DDSSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Awaiting Owner Confirmation',
                              style: DDSTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: DDSColors.textPrimary,
                              ),
                            ),
                            const Gap(2),
                            Text(
                              'Your payment has been received. The host will confirm handover within 15 minutes.',
                              style: DDSTypography.bodyMedium.copyWith(
                                color: DDSColors.textSecondary,
                                height: 1.3,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(DDSSpacing.md),

                // ── Security Deposit 100% Refundable Guarantee Card ──
                Container(
                  padding: const EdgeInsets.all(DDSSpacing.md),
                  decoration: BoxDecoration(
                    color: DDSColors.infoBlueBg,
                    borderRadius: DDSRadius.largeBorderRadius,
                    border: Border.all(
                      color: DDSColors.primaryBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: DDSColors.primaryBlue, size: 22),
                      const Gap(DDSSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '100% Refundable Security Deposit',
                              style: DDSTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: DDSColors.primaryBlue,
                              ),
                            ),
                            const Gap(2),
                            Text(
                              'Held safely in DriveGo escrow. Automatically initiated for refund to your payment source within 48h after return vehicle inspection.',
                              style: DDSTypography.bodyMedium.copyWith(
                                fontSize: 11,
                                color: DDSColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(DDSSpacing.md),

                // ── Trip Summary Card ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(DDSSpacing.md),
                  decoration: BoxDecoration(
                    color: DDSColors.surfaceCard,
                    borderRadius: DDSRadius.largeBorderRadius,
                    border: const Border.fromBorderSide(
                      BorderSide(color: DDSColors.borderLight),
                    ),
                    boxShadow: DDSElevation.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip Summary',
                        style: DDSTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: DDSColors.textPrimary,
                        ),
                      ),
                      const Gap(DDSSpacing.sm),
                      const Divider(
                        height: 1,
                        color: DDSColors.borderLight,
                      ),
                      const Gap(DDSSpacing.sm),
                      _summaryRow(
                        'Vehicle',
                        '${car.make} ${car.model}',
                        Icons.directions_car_outlined,
                      ),
                      const Gap(8),
                      _summaryRow(
                        'Trip Type',
                        booking.tripType,
                        Icons.category_outlined,
                      ),
                      const Gap(8),
                      _summaryRow(
                        'Pickup Location',
                        booking.pickupLocation,
                        Icons.location_on_outlined,
                      ),
                      if (booking.dropLocation != null &&
                          booking.dropLocation!.isNotEmpty) ...[
                        const Gap(8),
                        _summaryRow(
                          'Drop Location',
                          booking.dropLocation!,
                          Icons.flag_outlined,
                        ),
                      ],
                      const Gap(8),
                      _summaryRow(
                        'Duration',
                        '${booking.startDate.toDDMMYYYY()} → ${booking.endDate.toDDMMYYYY()}',
                        Icons.calendar_today_outlined,
                      ),
                      const Gap(DDSSpacing.sm),
                      const Divider(
                        height: 1,
                        color: DDSColors.borderLight,
                      ),
                      const Gap(DDSSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Paid',
                            style: DDSTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: DDSColors.textPrimary,
                            ),
                          ),
                          Text(
                            IndianCurrencyFormatter.format(
                              booking.totalFare,
                              showDecimals: false,
                            ),
                            style: DDSTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              color: DDSColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(DDSSpacing.lg),

                // ── Action Buttons ───────────────────────────────────
                AppButton(
                  text: 'View My Bookings',
                  onPressed: () {
                    ref.invalidate(currentStepProvider);
                    ref.invalidate(bookingDraftProvider);
                    context.go('/bookings');
                  },
                ),
                const Gap(DDSSpacing.sm),
                OutlinedButton(
                  onPressed: () {
                    ref.invalidate(currentStepProvider);
                    ref.invalidate(bookingDraftProvider);
                    context.go('/home');
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: DDSRadius.mediumBorderRadius,
                    ),
                    side: const BorderSide(
                      color: DDSColors.borderMedium,
                    ),
                  ),
                  child: Text(
                    'Back to Home Marketplace',
                    style: DDSTypography.titleMedium.copyWith(
                      color: DDSColors.textPrimary,
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

  Widget _summaryRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DDSColors.textMuted),
        const Gap(8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: DDSTypography.bodyMedium.copyWith(
              color: DDSColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: DDSTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: DDSColors.textPrimary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

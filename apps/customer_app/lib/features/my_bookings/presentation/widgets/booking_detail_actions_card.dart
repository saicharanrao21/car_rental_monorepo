import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:go_router/go_router.dart';
import '../../domain/repositories/my_bookings_repository.dart';
import 'booking_handover_otp_modal.dart';
import 'booking_inspection_modal.dart';
import 'booking_extend_trip_modal.dart';
import 'booking_cancel_modal.dart';
import '../../../emergency/presentation/widgets/emergency_bottom_sheet.dart';

class BookingDetailActionsCard extends StatelessWidget {
  final CustomerBookingItem item;
  final bool isProcessingPayment;
  final VoidCallback? onPaymentTap;
  final VoidCallback? onRefresh;

  const BookingDetailActionsCard({
    super.key,
    required this.item,
    this.isProcessingPayment = false,
    this.onPaymentTap,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final booking = item.booking;
    final car = item.car;
    final status = booking.status.toLowerCase();

    final isPending = status == 'pending';
    final isConfirmed = status == 'confirmed';
    final isHandoverReady = status == 'handover_ready';
    final isOngoing = status == 'ongoing';
    final isReturnPending = status == 'return_pending';
    final isCancelled = status == 'cancelled' ||
        status == 'refunded' ||
        status == 'refund_pending' ||
        status == 'disputed' ||
        status == 'expired';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Pending Payment CTA
        if (isPending) ...[
          AppButton(
            text: 'Complete Payment (${IndianCurrencyFormatter.format(booking.totalFare, showDecimals: false)})',
            isLoading: isProcessingPayment,
            onPressed: isProcessingPayment ? null : onPaymentTap,
          ),
          const Gap(10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[700],
              side: BorderSide(color: Colors.red[300]!),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final cancelled = await BookingCancelModal.show(context, bookingId: booking.id);
              if (cancelled == true && onRefresh != null) onRefresh!();
            },
            child: const Text('Cancel Booking'),
          ),
          const Gap(16),
        ],

        // 2. Confirmed & Upcoming CTAs
        if (isConfirmed || isHandoverReady) ...[
          FilledButton.icon(
            icon: const Icon(Icons.pin_outlined, size: 18),
            label: Text(
              isHandoverReady ? 'Show Pickup PIN to Host' : 'View Pickup Handover PIN',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: isHandoverReady ? Colors.amber[900] : AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => BookingHandoverOtpModal.show(context, bookingId: booking.id, otpType: 'PICKUP'),
          ),
          const Gap(10),
          OutlinedButton.icon(
            icon: const Icon(Icons.checklist_rounded, size: 16),
            label: const Text('View Inspection Checklist', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => BookingInspectionModal.show(context, bookingId: booking.id),
          ),
          const Gap(10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[700],
              side: BorderSide(color: Colors.red[200]!),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final cancelled = await BookingCancelModal.show(context, bookingId: booking.id);
              if (cancelled == true && onRefresh != null) onRefresh!();
            },
            child: const Text('Cancel Booking'),
          ),
          const Gap(16),
        ],

        // 3. Ongoing Active Trip CTAs
        if (isOngoing || isReturnPending) ...[
          FilledButton.icon(
            icon: const Icon(Icons.more_time_rounded, size: 18),
            label: const Text('Extend Trip Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final extended = await BookingExtendTripModal.show(context, item: item);
              if (extended == true && onRefresh != null) onRefresh!();
            },
          ),
          const Gap(10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.pin_outlined, size: 16),
                  label: const Text('Return PIN', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => BookingHandoverOtpModal.show(context, bookingId: booking.id, otpType: 'RETURN'),
                ),
              ),
              const Gap(10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.checklist_rounded, size: 16),
                  label: const Text('Inspection', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => BookingInspectionModal.show(context, bookingId: booking.id),
                ),
              ),
            ],
          ),
          const Gap(10),
          OutlinedButton.icon(
            icon: const Icon(Icons.emergency_outlined, color: Colors.red, size: 18),
            label: const Text(
              'Emergency Assistance (SOS)',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final dispatched = await EmergencyBottomSheet.show(
                context,
                bookingId: booking.id,
                carDetails: car != null ? '${car.make} ${car.model} (${car.registrationNumber})' : booking.tripType,
              );
              if (dispatched == true && onRefresh != null) onRefresh!();
            },
          ),
          const Gap(16),
        ],

        // 4. Cancelled Action
        if (isCancelled) ...[
          AppButton(
            text: 'Explore Other Cars',
            onPressed: () => context.go('/home'),
          ),
          const Gap(16),
        ],
      ],
    );
  }
}

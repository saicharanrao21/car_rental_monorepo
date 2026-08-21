import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../../domain/repositories/my_bookings_repository.dart';

class BookingDetailPricingCard extends StatelessWidget {
  final CustomerBookingItem item;
  final VoidCallback? onInvoiceTap;

  const BookingDetailPricingCard({
    super.key,
    required this.item,
    this.onInvoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    final booking = item.booking;
    final cs = Theme.of(context).colorScheme;

    final deliveryFee = (item.deliveryFee != null && item.deliveryFee! > 0) ? item.deliveryFee! : 0.0;
    final protectionFee = (item.protectionFee != null && item.protectionFee! > 0) ? item.protectionFee! : 0.0;
    final baseFare = booking.totalFare - booking.gstAmount - deliveryFee - protectionFee;
    final displayBaseFare = baseFare > 0 ? baseFare : (booking.totalFare - booking.gstAmount);

    final isPending = booking.status.toLowerCase() == 'pending';
    final isCancelled = booking.status.toLowerCase() == 'cancelled' ||
        booking.status.toLowerCase() == 'refunded' ||
        booking.status.toLowerCase() == 'refund_pending' ||
        booking.status.toLowerCase() == 'disputed' ||
        booking.status.toLowerCase() == 'expired';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment & Fare Breakdown',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              _paymentStatusBadge(context),
            ],
          ),
          const Gap(14),

          _fareRow(context, 'Vehicle & Trip Base Fare', displayBaseFare),
          if (deliveryFee > 0)
            _fareRow(context, 'Doorstep Delivery Fee', deliveryFee),
          if (protectionFee > 0)
            _fareRow(context, 'Zero-Deductible Protection', protectionFee),
          if (booking.gstAmount > 0)
            _fareRow(context, 'Goods & Services Tax (GST 18%)', booking.gstAmount),

          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPending ? 'Total Amount Payable' : 'Total Amount Paid',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              PriceTag(
                amount: booking.totalFare,
                amountStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          if (item.razorpayPaymentId != null && item.razorpayPaymentId!.isNotEmpty) ...[
            const Gap(10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, size: 14, color: Colors.green),
                  const Gap(6),
                  Expanded(
                    child: Text(
                      'Payment Reference: ${item.razorpayPaymentId}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!isPending && !isCancelled && onInvoiceTap != null) ...[
            const Gap(14),
            OutlinedButton.icon(
              icon: const Icon(Icons.receipt_long_outlined, size: 16),
              label: const Text('Download Official GST Tax Invoice', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onInvoiceTap,
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentStatusBadge(BuildContext context) {
    final status = item.paymentStatus?.toUpperCase() ??
        (item.booking.status.toLowerCase() == 'pending' ? 'PENDING' : 'PAID');

    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'PAID':
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green[800]!;
        label = 'PAID IN FULL';
        break;
      case 'PENDING':
      case 'CREATED':
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber[900]!;
        label = 'PAYMENT PENDING';
        break;
      case 'REFUNDED':
        bg = Colors.blue.withValues(alpha: 0.12);
        fg = Colors.blue[800]!;
        label = 'REFUNDED';
        break;
      case 'FAILED':
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red[800]!;
        label = 'FAILED';
        break;
      default:
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green[800]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _fareRow(BuildContext context, String label, double amount) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          Text(
            IndianCurrencyFormatter.format(amount, showDecimals: false),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

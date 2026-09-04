import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../../domain/repositories/my_bookings_repository.dart';

class BookingRefundTrackerCard extends StatelessWidget {
  final CustomerBookingItem item;

  const BookingRefundTrackerCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final booking = item.booking;
    final cs = Theme.of(context).colorScheme;
    final status = booking.status.toLowerCase();
    final isRefunded = status == 'refunded' || item.paymentStatus?.toLowerCase() == 'refunded';
    final reason = item.cancellationReason ?? 'Requested by customer';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.history_outlined, size: 18, color: Colors.red),
                    Gap(8),
                    Expanded(
                      child: Text(
                        'Cancellation & Refund Details',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRefunded ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isRefunded ? 'REFUND CREDITED' : 'REFUND IN PROGRESS',
                  style: TextStyle(
                    color: isRefunded ? Colors.green[800] : Colors.amber[900],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Stepper
          _stepRow(
            icon: Icons.cancel_outlined,
            iconColor: Colors.red,
            title: 'Booking Cancelled',
            subtitle: 'Reason: $reason',
            isDone: true,
          ),
          _stepLine(isDone: true),
          _stepRow(
            icon: Icons.shield_outlined,
            iconColor: Colors.blue,
            title: 'Policy Verified & Refund Calculated',
            subtitle: item.cancellationFee != null && item.cancellationFee! > 0
                ? 'Cancellation fee: ₹${item.cancellationFee!.toInt()}'
                : 'Free cancellation • 100% Refund Approved',
            isDone: true,
          ),
          _stepLine(isDone: isRefunded),
          _stepRow(
            icon: isRefunded ? Icons.check_circle : Icons.hourglass_top_outlined,
            iconColor: isRefunded ? Colors.green : Colors.amber[800]!,
            title: isRefunded ? 'Refund Credited to Original Method' : 'Transfer in Progress',
            subtitle: isRefunded
                ? 'Amount of ${IndianCurrencyFormatter.format(item.refundAmount ?? booking.totalFare, showDecimals: false)} settled'
                : 'Expected within 5-7 business days via Razorpay / Bank',
            isDone: isRefunded,
          ),

          const Gap(14),
          const Divider(height: 1),
          const Gap(10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Net Refundable Amount:', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              Text(
                IndianCurrencyFormatter.format(item.refundAmount ?? booking.totalFare, showDecimals: false),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDone,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDone ? iconColor.withValues(alpha: 0.12) : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: isDone ? iconColor : Colors.grey),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDone ? Colors.black87 : Colors.grey,
                ),
              ),
              const Gap(2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepLine({required bool isDone}) {
    return Container(
      margin: const EdgeInsets.only(left: 13),
      width: 2,
      height: 20,
      color: isDone ? Colors.green : Colors.grey[300],
    );
  }
}

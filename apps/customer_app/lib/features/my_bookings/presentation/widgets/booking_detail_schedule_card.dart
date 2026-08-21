import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';
import '../../domain/repositories/my_bookings_repository.dart';

class BookingDetailScheduleCard extends StatelessWidget {
  final CustomerBookingItem item;

  const BookingDetailScheduleCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final booking = item.booking;
    final cs = Theme.of(context).colorScheme;
    final durationDays = booking.endDate.difference(booking.startDate).inDays;
    final displayDays = durationDays > 0 ? durationDays : 1;

    final dateFormat = DateFormat('EEE, dd MMM yyyy • hh:mm a');
    final hasDoorstepDelivery = item.deliveryAddress != null && item.deliveryAddress!.isNotEmpty;
    final hasDoorstepPickup = item.pickupAddress != null && item.pickupAddress!.isNotEmpty;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trip Schedule & Locations',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$displayDays Day${displayDays > 1 ? "s" : ""} Rental',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(16),

          // Pickup Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 48,
                    color: Colors.grey[300],
                  ),
                ],
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'PICKUP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (hasDoorstepDelivery) ...[
                          const Gap(6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'DOORSTEP DELIVERY',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Gap(2),
                    Text(
                      dateFormat.format(booking.startDate),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const Gap(2),
                    Text(
                      hasDoorstepDelivery ? item.deliveryAddress! : booking.pickupLocation,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Return Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red[600],
                  shape: BoxShape.circle,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'DROP-OFF / RETURN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (hasDoorstepPickup) ...[
                          const Gap(6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'DOORSTEP PICKUP',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Gap(2),
                    Text(
                      dateFormat.format(booking.endDate),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const Gap(2),
                    Text(
                      hasDoorstepPickup
                          ? item.pickupAddress!
                          : (booking.dropLocation ?? booking.pickupLocation),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

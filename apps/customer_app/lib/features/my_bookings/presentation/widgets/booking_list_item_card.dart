import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../../domain/repositories/my_bookings_repository.dart';

class BookingListItemCard extends StatelessWidget {
  final CustomerBookingItem item;
  final VoidCallback? onCancelTap;
  final VoidCallback? onInvoiceTap;

  const BookingListItemCard({
    super.key,
    required this.item,
    this.onCancelTap,
    this.onInvoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    final booking = item.booking;
    final car = item.car;
    final vendor = item.vendor;
    final cs = Theme.of(context).colorScheme;

    final carTitle = car != null ? '${car.make} ${car.model}' : '${booking.tripType} Booking';
    final carSub = car != null ? '${car.type} • ${car.seating} Seats • ${car.fuelType}' : booking.tripType;
    final photoUrl = car?.photos.isNotEmpty == true ? car!.photos.first : null;
    final shortId = booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase();
    final status = booking.status.toLowerCase();

    final isUpcoming = status == 'confirmed' || status == 'pending' || status == 'handover_ready';
    final isOngoing = status == 'ongoing' || status == 'return_pending';
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled' ||
        status == 'refunded' ||
        status == 'refund_pending' ||
        status == 'disputed' ||
        status == 'expired';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/bookings/${booking.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Vehicle Image & Info Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 84,
                    height: 64,
                    color: cs.surfaceContainerHighest,
                    child: photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: cs.surfaceContainerHighest,
                              child: Icon(
                                Icons.directions_car,
                                size: 36,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            errorWidget: (_, __, ___) => Icon(
                              Icons.directions_car,
                              size: 36,
                              color: cs.onSurfaceVariant,
                            ),
                          )
                        : Icon(
                            Icons.directions_car,
                            size: 36,
                            color: cs.onSurfaceVariant,
                          ),
                  ),
                ),
                const Gap(12),
                // Title, Reference & Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              carTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Gap(6),
                          StatusBadge(status: booking.status),
                        ],
                      ),
                      const Gap(3),
                      Text(
                        carSub,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                      const Gap(3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#$shortId',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (vendor != null) ...[
                            const Gap(8),
                            Expanded(
                              child: Text(
                                vendor.businessName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(12),
            const Divider(height: 1),
            const Gap(12),

            // Schedule & Dates Row
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.primary),
                const Gap(6),
                Expanded(
                  child: Text(
                    '${booking.startDate.toDDMMYYYY()} → ${booking.endDate.toDDMMYYYY()}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    booking.tripType,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(8),

            // Location Row
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: Colors.grey),
                const Gap(6),
                Expanded(
                  child: Text(
                    item.deliveryAddress?.isNotEmpty == true
                        ? '${item.deliveryAddress} (Doorstep)'
                        : booking.pickupLocation,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (item.mileagePackageName != null || item.protectionCode != null) ...[
              const Gap(8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (item.mileagePackageName != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.speed_outlined, size: 14, color: Colors.grey),
                        const Gap(4),
                        Text(
                          item.mileagePackageName!,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  if (item.protectionCode != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, size: 14, color: Colors.green),
                        const Gap(4),
                        Text(
                          item.protectionCode == 'ZERO_DEP' ? 'Zero Deductible' : 'Protected',
                          style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                ],
              ),
            ],

            const Gap(12),
            const Divider(height: 1),
            const Gap(12),

            // Bottom Action Bar: Fare & Context CTA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCancelled ? 'Refund Amount' : 'Total Fare',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                    const Gap(2),
                    PriceTag(
                      amount: isCancelled && item.refundAmount != null
                          ? item.refundAmount!
                          : booking.totalFare,
                      amountStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCancelled ? Colors.grey[800] : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUpcoming && onCancelTap != null && status != 'pending') ...[
                      TextButton(
                        onPressed: onCancelTap,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red[700],
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                      ),
                      const Gap(6),
                    ],
                    if (isCompleted && onInvoiceTap != null) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.receipt_outlined, size: 14),
                        label: const Text('Invoice', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: onInvoiceTap,
                      ),
                      const Gap(6),
                    ],
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isOngoing
                            ? Colors.green[700]
                            : isCancelled
                                ? Colors.grey[800]
                                : AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => context.push('/bookings/${booking.id}'),
                      child: Text(
                        isOngoing
                            ? 'Manage Trip'
                            : status == 'pending'
                                ? 'Pay & Confirm'
                                : 'View Details',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

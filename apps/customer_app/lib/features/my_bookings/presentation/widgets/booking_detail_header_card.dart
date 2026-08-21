import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../../domain/repositories/my_bookings_repository.dart';

class BookingDetailHeaderCard extends StatelessWidget {
  final CustomerBookingItem item;

  const BookingDetailHeaderCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final booking = item.booking;
    final car = item.car;
    final vendor = item.vendor;
    final cs = Theme.of(context).colorScheme;
    final photoUrl = car?.photos.isNotEmpty == true ? car!.photos.first : null;
    final shortId = booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 100,
                  height: 75,
                  color: cs.surfaceContainerHighest,
                  child: photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Icon(
                            Icons.directions_car,
                            size: 40,
                            color: cs.onSurfaceVariant,
                          ),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.directions_car,
                            size: 40,
                            color: cs.onSurfaceVariant,
                          ),
                        )
                      : Icon(
                          Icons.directions_car,
                          size: 40,
                          color: cs.onSurfaceVariant,
                        ),
                ),
              ),
              const Gap(14),
              // Car Title & Specs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            car != null ? '${car.make} ${car.model}' : '${booking.tripType} Booking',
                            style: const TextStyle(
                              fontSize: 17,
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
                    const Gap(4),
                    if (car != null)
                      Text(
                        '${car.year} • ${car.type} • ${car.seating} Seats • ${car.fuelType}',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      )
                    else
                      Text(
                        booking.tripType,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    const Gap(4),
                    if (car != null && car.registrationNumber.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          car.registrationNumber,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(12),
          const Divider(height: 1),
          const Gap(10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tag, size: 14, color: Colors.grey),
                  const Gap(4),
                  Text(
                    'Booking ID: #$shortId',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (vendor != null)
                Text(
                  'Host: ${vendor.businessName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

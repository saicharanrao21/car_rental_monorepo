import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'status_badge.dart';
import 'price_tag.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final String carMake;
  final String carModel;
  final String? carPhoto;
  final String partnerName;
  final VoidCallback onTap;

  const BookingCard({
    super.key,
    required this.booking,
    required this.carMake,
    required this.carModel,
    this.carPhoto,
    required this.partnerName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              color: Colors.grey[300],
              child: carPhoto != null && carPhoto!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: carPhoto!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.directions_car,
                        size: 80,
                        color: Colors.grey,
                      ),
                    )
                  : const Icon(
                      Icons.directions_car,
                      size: 80,
                      color: Colors.grey,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$carMake $carModel',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Gap(8),
                      StatusBadge(status: booking.status),
                    ],
                  ),
                  const Gap(8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      const Gap(4),
                      Text(
                        partnerName,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  const Gap(8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const Gap(4),
                      Text(
                        '${booking.startDate.toDDMMYYYY()} - ${booking.endDate.toDDMMYYYY()}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  const Gap(16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Fare',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          PriceTag(amount: booking.totalFare),
                        ],
                      ),
                      Text(
                        booking.tripType,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

class CarCard extends StatelessWidget {
  final CarModel car;
  final VoidCallback onTap;
  final bool isWishlisted;
  final VoidCallback? onWishlistToggle;
  final double imageHeight;

  const CarCard({
    super.key,
    required this.car,
    required this.onTap,
    this.isWishlisted = false,
    this.onWishlistToggle,
    this.imageHeight = 150.0,
  });

  @override
  Widget build(BuildContext context) {
    final distanceKm = car.distanceKm;
    final isSponsored = car.isSponsored || (car.vendor != null && car.vendor!['isSponsored'] == true);
    final vendorDisplayName = car.vendor?['displayName'] ?? car.vendor?['businessName'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Car Image Container with Badges & Wishlist Button
            Stack(
              children: [
                Container(
                  height: imageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: car.photos.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: Image.network(
                            car.photos.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, size: 80, color: Colors.grey),
                          ),
                        )
                      : const Icon(Icons.directions_car, size: 80, color: Colors.grey),
                ),
                // Sponsored Badge
                if (isSponsored)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber[700],
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.white),
                          Gap(4),
                          Text(
                            'Sponsored',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Wishlist Heart Button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      icon: Icon(
                        isWishlisted ? Icons.favorite : Icons.favorite_border,
                        color: isWishlisted ? Colors.red : Colors.grey[700],
                        size: 20,
                      ),
                      onPressed: onWishlistToggle,
                      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${car.make} ${car.model}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          car.type,
                          style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (vendorDisplayName != null && vendorDisplayName.toString().isNotEmpty) ...[
                    const Gap(4),
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 14, color: AppColors.primary),
                        const Gap(4),
                        Expanded(
                          child: Text(
                            vendorDisplayName.toString(),
                            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Gap(8),
                  Row(
                    children: [
                      const Icon(Icons.event_seat, size: 16, color: Colors.grey),
                      const Gap(4),
                      Text('${car.seating} Seats'),
                      const Gap(12),
                      const Icon(Icons.ac_unit, size: 16, color: Colors.grey),
                      const Gap(4),
                      Text(car.isAC ? 'AC' : 'Non-AC'),
                      if (distanceKm != null) ...[
                        const Gap(12),
                        const Icon(Icons.location_on, size: 16, color: Colors.blue),
                        const Gap(4),
                        Expanded(
                          child: Text(
                            '${distanceKm.toStringAsFixed(1)} km away',
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Gap(16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Starts from', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            '₹${car.pricePerDay.toStringAsFixed(0)}/day',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: onTap,
                        child: const Text('Book Now'),
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

import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'drivego_button.dart';
import 'drivego_price_tag.dart';
import 'drivego_status_badge.dart';

/// DriveGo Design System (DDS) — Standard Vehicle Card Component
class CarCard extends StatelessWidget {
  final CarModel car;
  final VoidCallback onTap;
  final bool isWishlisted;
  final VoidCallback? onWishlistToggle;
  final double imageHeight;
  final String ctaText;

  const CarCard({
    super.key,
    required this.car,
    required this.onTap,
    this.isWishlisted = false,
    this.onWishlistToggle,
    this.imageHeight = 150.0,
    this.ctaText = 'Book Now',
  });

  @override
  Widget build(BuildContext context) {
    final distanceKm = car.distanceKm;
    final isSponsored = car.isSponsored || (car.vendor != null && car.vendor!['isSponsored'] == true);
    final isFeatured = car.vendor != null && car.vendor!['isFeatured'] == true;
    final vendorDisplayName = car.vendor?['displayName'] ?? car.vendor?['businessName'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.mediumBorderRadius,
        border: Border.all(color: DDSColors.borderLight),
        boxShadow: DDSElevation.subtleShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: DDSRadius.mediumBorderRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Car Image Container with Badges & Wishlist Button
              Stack(
                children: [
                  Container(
                    height: imageHeight,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: DDSColors.surfaceSubtle,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(DDSRadius.medium),
                      ),
                    ),
                    child: car.photos.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(DDSRadius.medium),
                            ),
                            child: Image.network(
                              car.photos.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.directions_car_rounded, size: 64, color: DDSColors.textMuted),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.directions_car_rounded, size: 64, color: DDSColors.textMuted),
                          ),
                  ),

                  // Top Left Badges: Sponsored, Featured, or Category Badge
                  if (isSponsored)
                    const Positioned(
                      top: 10,
                      left: 10,
                      child: DriveGoStatusBadge(
                        label: 'SPONSORED',
                        variant: DriveGoBadgeVariant.sponsored,
                      ),
                    )
                  else if (isFeatured)
                    const Positioned(
                      top: 10,
                      left: 10,
                      child: DriveGoStatusBadge(
                        label: 'FEATURED',
                        variant: DriveGoBadgeVariant.info,
                      ),
                    )
                  else
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DDSColors.primaryNavy.withValues(alpha: 0.85),
                          borderRadius: DDSRadius.smallBorderRadius,
                        ),
                        child: Text(
                          car.type.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  // Wishlist Heart Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      elevation: 2,
                      shadowColor: Colors.black26,
                      child: IconButton(
                        icon: Icon(
                          isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isWishlisted ? DDSColors.errorRed : DDSColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: onWishlistToggle,
                        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                        padding: EdgeInsets.zero,
                        tooltip: isWishlisted ? 'Remove from Saved' : 'Save Car',
                      ),
                    ),
                  ),
                ],
              ),

              // Car Details Container
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Category Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${car.make} ${car.model}',
                            style: DDSTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DDSColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSponsored) ...[
                          const Gap(6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: DDSColors.primaryBlue.withValues(alpha: 0.08),
                              borderRadius: DDSRadius.smallBorderRadius,
                            ),
                            child: Text(
                              car.type,
                              style: const TextStyle(
                                color: DDSColors.primaryBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Vendor Display Name
                    if (vendorDisplayName != null && vendorDisplayName.toString().isNotEmpty) ...[
                      const Gap(4),
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, size: 14, color: DDSColors.primaryBlue),
                          const Gap(4),
                          Expanded(
                            child: Text(
                              vendorDisplayName.toString(),
                              style: DDSTypography.bodyMedium.copyWith(
                                color: DDSColors.textMuted,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const Gap(10),

                    // Specs Row (Seats, Fuel, AC, Distance)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildSpecChip(Icons.event_seat_outlined, '${car.seating} Seats'),
                        _buildSpecChip(Icons.local_gas_station_outlined, car.fuelType),
                        _buildSpecChip(Icons.ac_unit_rounded, car.isAC ? 'AC' : 'Non-AC'),
                        if (distanceKm != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me_rounded, size: 13, color: DDSColors.primaryBlue),
                              const Gap(3),
                              Text(
                                '${distanceKm.toStringAsFixed(1)} km',
                                style: DDSTypography.labelSmall.copyWith(
                                  color: DDSColors.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    const Gap(14),
                    const Divider(height: 1, color: DDSColors.borderLight),
                    const Gap(12),

                    // Price & Booking CTA
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Starts from',
                              style: DDSTypography.labelSmall.copyWith(
                                color: DDSColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            DriveGoPriceTag(
                              amount: car.pricePerDay,
                              suffix: '/day',
                              amountStyle: DDSTypography.priceDisplay.copyWith(
                                color: DDSColors.textPrimary,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        DriveGoButton(
                          text: ctaText,
                          size: DriveGoButtonSize.compact,
                          isFullWidth: false,
                          onPressed: onTap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: DDSColors.textMuted),
        const Gap(3),
        Text(
          label,
          style: DDSTypography.labelSmall.copyWith(
            color: DDSColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}


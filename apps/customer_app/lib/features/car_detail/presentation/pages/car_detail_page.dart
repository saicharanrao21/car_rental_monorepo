import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import 'package:gap/gap.dart';
import '../providers/car_detail_providers.dart';
import '../../../wishlist/wishlist_providers.dart';
import '../../../home/recently_viewed_providers.dart';
import '../../../../core/providers/api_providers.dart';

class CarDetailPage extends ConsumerStatefulWidget {
  final String carId;

  const CarDetailPage({
    super.key,
    required this.carId,
  });

  @override
  ConsumerState<CarDetailPage> createState() => _CarDetailPageState();
}

class _CarDetailPageState extends ConsumerState<CarDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiClient = ref.read(apiClientProvider);
      recordCarView(apiClient, widget.carId);
      ref.invalidate(recentlyViewedCarsProvider);
    });
  }

  double _getCommissionPercentage(String city, String carCategory) {
    final configs = MockData.commissionConfigs;
    final match = configs.firstWhere(
      (c) => (c.city == 'All' || c.city.toLowerCase() == city.toLowerCase()) &&
             (c.carCategory == 'All' || c.carCategory.toLowerCase() == carCategory.toLowerCase()),
      orElse: () => CommissionConfigModel(
        id: 'default',
        tripType: 'All',
        city: 'All',
        carCategory: 'All',
        percentage: 10.0,
        effectiveFrom: DateTime(2026, 1, 1),
      ),
    );
    return match.percentage;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final detailVal = ref.watch(carDetailDataProvider(widget.carId));
    final wishlistedIds = ref.watch(wishlistIdsProvider);
    final isWishlisted = wishlistedIds.contains(widget.carId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Details'),
        actions: [
          IconButton(
            icon: Icon(
              isWishlisted ? Icons.favorite : Icons.favorite_border,
              color: isWishlisted ? Colors.red : Theme.of(context).colorScheme.onPrimary,
            ),
            tooltip: isWishlisted ? 'Remove from Wishlist' : 'Add to Wishlist',
            onPressed: () {
              ref.read(wishlistIdsProvider.notifier).toggle(widget.carId);
            },
          ),
        ],
      ),
      body: detailVal.when(
        data: (data) {
          final car = data.car;
          final vendor = data.vendor;
          final reviews = data.reviews;

          final vendorDisplayName = vendor.displayName ?? vendor.businessName;

          // Compute star breakdown
          final totalReviewsCount = reviews.length;
          final starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
          double totalRatingSum = 0;
          for (var review in reviews) {
            totalRatingSum += review.rating;
            final rounded = review.rating.round();
            if (starCounts.containsKey(rounded)) {
              starCounts[rounded] = starCounts[rounded]! + 1;
            }
          }
          final averageRating = totalReviewsCount > 0 ? totalRatingSum / totalReviewsCount : 0.0;

          // Calculate estimated fare
          final commissionPercent = _getCommissionPercentage(vendor.city, car.type);
          final fareResult = FareCalculatorService.calculateFare(
            distanceKm: 50.0,
            basePackagePrice: car.pricePerDay,
            pricePerKm: car.pricePerKm,
            commissionPercent: commissionPercent,
          );

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ImageCarousel(
                      imageUrls: car.photos,
                      height: 250,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${car.make} ${car.model}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Gap(4),
                                    Text(
                                      '${car.year} • ${car.fuelType}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(
                                status: car.isAvailable ? 'AVAILABLE' : 'BLOCKED',
                              ),
                            ],
                          ),
                          if (vendor.isSponsored) ...[
                            const Gap(10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber[300]!),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, size: 14, color: Colors.amber),
                                  const Gap(6),
                                  Text(
                                    'Sponsored Listing',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[900],
                                    ),
                                  ),
                                  const Gap(6),
                                  Expanded(
                                    child: Text(
                                      '• This listing is promoted by the partner',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.amber[900]?.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Gap(20),
                          Row(
                            children: [
                              Expanded(child: _buildSpecTile(context, Icons.event_seat, '${car.seating} Seater')),
                              const Gap(12),
                              Expanded(child: _buildSpecTile(context, Icons.ac_unit, car.isAC ? 'Air Conditioned' : 'Non AC')),
                            ],
                          ),
                          const Gap(24),
                          const Text(
                            'Rental Pricing Plans',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Gap(12),
                          Row(
                            children: [
                              _buildPricePlanTile(context, 'Hourly', car.pricePerHour, '/ hr'),
                              _buildPricePlanTile(context, 'Daily', car.pricePerDay, '/ day'),
                              _buildPricePlanTile(context, 'Kilometer', car.pricePerKm, '/ km'),
                            ],
                          ),
                          const Gap(24),
                          const Text(
                            'Vendor Details',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Gap(12),
                          AppCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vendorDisplayName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Gap(4),
                                          Text(
                                            vendor.locality != null ? '${vendor.locality}, ${vendor.city}' : vendor.city,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (vendor.verificationStatus == 'verified')
                                      const Icon(Icons.verified, color: Colors.blue, size: 20),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 18),
                                            const Gap(4),
                                            Text(
                                              vendor.rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Vendor Rating',
                                          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${vendor.totalTrips}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Trips Completed',
                                          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Gap(24),
                          const Text(
                            'Reviews',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Gap(12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      averageRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Gap(4),
                                    StarRating(rating: averageRating, size: 16),
                                    const Gap(8),
                                    Text(
                                      '$totalReviewsCount reviews',
                                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              const VerticalDivider(width: 24),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  children: [5, 4, 3, 2, 1].map((level) {
                                    final count = starCounts[level] ?? 0;
                                    final pct = totalReviewsCount > 0 ? count / totalReviewsCount : 0.0;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        children: [
                                          Text('$level ★', style: const TextStyle(fontSize: 10)),
                                          const Gap(8),
                                          Expanded(
                                            child: Container(
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: cs.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: FractionallySizedBox(
                                                alignment: Alignment.centerLeft,
                                                widthFactor: pct,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber,
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const Gap(8),
                                          SizedBox(
                                            width: 20,
                                            child: Text(
                                              '$count',
                                              style: const TextStyle(fontSize: 10),
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                          const Gap(16),
                          if (reviews.isEmpty)
                            const Text('No reviews yet.')
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: reviews.take(5).length,
                              separatorBuilder: (context, index) => const Divider(height: 24),
                              itemBuilder: (context, index) {
                                final r = reviews[index];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Verified Customer',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          r.createdAt.toDDMMYYYY(),
                                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                    const Gap(4),
                                    StarRating(rating: r.rating, size: 14),
                                    const Gap(6),
                                    Text(
                                      r.comment,
                                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  final tripFare = fareResult.baseFare + fareResult.platformFee;
                                  AppBottomSheet.show(
                                    context,
                                    title: 'Estimated Fare Breakdown',
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Trip Fare', style: TextStyle(fontWeight: FontWeight.bold)),
                                              Text(IndianCurrencyFormatter.format(tripFare, showDecimals: false), style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        const Gap(4),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('GST (18%)'),
                                              Text(IndianCurrencyFormatter.format(fareResult.gst, showDecimals: false)),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 20),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Total Estimated Fare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              PriceTag(amount: fareResult.total, amountStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                                            ],
                                          ),
                                        ),
                                        const Gap(16),
                                      ],
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      'Est. Fare (50km)',
                                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                    ),
                                    const Gap(4),
                                    Icon(Icons.info_outline, size: 14, color: cs.primary),
                                  ],
                                ),
                              ),
                              const Gap(4),
                              PriceTag(
                                amount: fareResult.total,
                                amountStyle: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: AppButton(
                            text: 'Book Now',
                            onPressed: () {
                              context.push('/booking/${car.id}');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const AppLoader(),
        error: (err, stack) => ErrorStateWidget(
          message: 'Failed to load details: ${err.toString()}',
          onRetry: () => ref.invalidate(carDetailDataProvider(widget.carId)),
        ),
      ),
    );
  }

  Widget _buildSpecTile(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const Gap(10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricePlanTile(BuildContext context, String title, double amount, String suffix) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            const Gap(8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: PriceTag(
                amount: amount,
                suffix: suffix,
                amountStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
                suffixStyle: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

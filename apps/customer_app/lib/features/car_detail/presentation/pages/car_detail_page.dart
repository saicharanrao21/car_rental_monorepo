import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../providers/car_detail_providers.dart';
import '../../../wishlist/wishlist_providers.dart';
import '../../../home/recently_viewed_providers.dart';
import '../../../home/home_providers.dart';
import '../../../search/presentation/providers/search_providers.dart';
import '../../../../core/providers/api_providers.dart';
import '../widgets/car_image_gallery.dart';
import '../widgets/car_identity_section.dart';
import '../widgets/car_specifications_section.dart';
import '../widgets/selected_trip_summary_card.dart';
import '../widgets/mileage_package_selector.dart';
import '../widgets/car_pricing_section.dart';
import '../widgets/car_features_section.dart';
import '../widgets/car_vendor_section.dart';
import '../widgets/car_booking_bottom_bar.dart';

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
  MileagePackageModel? _selectedMileagePackage;

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
    return 10.0;
  }

  void _handleShare(CarModel car) {
    Clipboard.setData(
      ClipboardData(
        text: 'Check out ${car.make} ${car.model} (${car.year}) on DriveGo: '
            '₹${car.pricePerDay.toStringAsFixed(0)}/day in ${car.vendor != null ? car.vendor!['city'] ?? 'Mumbai' : 'Mumbai'}',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vehicle link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailVal = ref.watch(carDetailDataProvider(widget.carId));
    final wishlistedIds = ref.watch(wishlistIdsProvider);
    final isWishlisted = wishlistedIds.contains(widget.carId);
    final dates = ref.watch(searchDatesProvider) ?? ref.watch(selectedDateRangeProvider);
    final tripType = ref.watch(searchTripTypeProvider) ?? ref.watch(selectedTripTypeProvider) ?? 'Self-Drive';
    final pickup = ref.watch(pickupLocationProvider) ?? ref.watch(searchPickupLocationProvider);
    final drop = ref.watch(dropLocationProvider) ?? ref.watch(searchDropLocationProvider);
    final city = ref.watch(selectedCityProvider);

    final durationDays = dates != null ? math.max(1, dates.duration.inDays) : 1;

    return Scaffold(
      backgroundColor: DDSColors.bgCanvas,
      body: detailVal.when(
        data: (data) {
          final car = data.car;
          final vendor = data.vendor;
          final reviews = data.reviews;

          final effectiveBasePrice =
              _selectedMileagePackage?.basePricePerDay ?? car.pricePerDay;

          // Calculate authoritative estimated fare using FareCalculatorService
          final commissionPercent = _getCommissionPercentage(vendor.city, car.type);
          final fareResult = FareCalculatorService.calculateFare(
            distanceKm: 0,
            basePackagePrice: effectiveBasePrice * durationDays,
            pricePerKm: car.pricePerKm,
            commissionPercent: commissionPercent,
          );

          return Stack(
            children: [
              SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. Image Gallery Hero ────────────────────────────────
                    CarImageGallery(
                      photos: car.photos,
                      carMake: car.make,
                      carModel: car.model,
                      carType: car.type,
                      isSponsored: car.isSponsored || vendor.isSponsored,
                      isWishlisted: isWishlisted,
                      onWishlistToggle: () {
                        ref.read(wishlistIdsProvider.notifier).toggle(widget.carId);
                      },
                      onShare: () => _handleShare(car),
                      onBackPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    ),

                    // ── 2. Content Sections ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DDSSpacing.md,
                        DDSSpacing.md,
                        DDSSpacing.md,
                        DDSSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Vehicle Unavailable Warning Banner if blocked
                          if (!car.isAvailable) ...[
                            Container(
                              padding: const EdgeInsets.all(DDSSpacing.md),
                              decoration: BoxDecoration(
                                color: DDSColors.errorRedBg,
                                borderRadius: BorderRadius.circular(DDSRadius.medium),
                                border: Border.all(color: DDSColors.errorRed.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: DDSColors.errorRed,
                                    size: 20,
                                  ),
                                  const Gap(10),
                                  Expanded(
                                    child: Text(
                                      'This vehicle is currently unavailable for selected dates.',
                                      style: DDSTypography.bodyMedium.copyWith(
                                        color: DDSColors.errorRed,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(16),
                          ],

                          // Vehicle Identity & Rating
                          CarIdentitySection(
                            car: car,
                            vendor: vendor,
                            reviewsCount: reviews.length,
                          ),
                          const Gap(20),

                          // Selected Trip Availability Summary
                          SelectedTripSummaryCard(
                            dates: dates,
                            tripType: tripType,
                            city: city,
                            pickup: pickup,
                            drop: drop,
                            onChangeSearch: () => context.push('/search'),
                          ),
                          const Gap(24),

                          // Specifications
                          CarSpecificationsSection(car: car),
                          const Gap(24),

                          // Configurable Mileage Packages (if available)
                          if (car.rawMileagePackages.isNotEmpty) ...[
                            MileagePackageSelector(
                              rawPackages: car.rawMileagePackages,
                              tripType: tripType,
                              selectedPackageId: _selectedMileagePackage?.id,
                              onPackageSelected: (pkg) {
                                setState(() {
                                  _selectedMileagePackage = pkg;
                                });
                              },
                            ),
                            const Gap(24),
                          ],

                          // Rental Pricing Plans
                          CarPricingSection(
                            car: car,
                            baseFare: fareResult.baseFare,
                            platformFee: fareResult.platformFee,
                            gst: fareResult.gst,
                            totalFare: fareResult.total,
                            durationDays: durationDays,
                          ),
                          const Gap(24),

                          // Inclusions & Rental Policies
                          const CarFeaturesSection(),
                          const Gap(24),

                          // Host Information & Customer Reviews
                          CarVendorSection(
                            vendor: vendor,
                            reviews: reviews,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── 3. Sticky Bottom Action Bar ──────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CarBookingBottomBar(
                  totalFare: fareResult.total,
                  baseFare: fareResult.baseFare,
                  platformFee: fareResult.platformFee,
                  gst: fareResult.gst,
                  durationDays: durationDays,
                  pricePerDay: effectiveBasePrice,
                  isAvailable: car.isAvailable,
                  onBookNow: () {
                    context.push('/booking/${car.id}');
                  },
                ),
              ),
            ],
          );
        },
        loading: () => _buildLoadingSkeleton(),
        error: (err, stack) => Scaffold(
          appBar: AppBar(
            title: const Text('Car Details'),
            backgroundColor: DDSColors.surfaceCard,
          ),
          body: DriveGoErrorState(
            title: 'Unable to Load Vehicle',
            message: 'Failed to load vehicle details. Please check connection and retry.',
            onRetry: () => ref.invalidate(carDetailDataProvider(widget.carId)),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: [
        // Shimmer Hero
        Container(
          height: 290,
          width: double.infinity,
          color: DDSColors.surfaceSubtle,
        ),
        const Gap(16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DDSSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 24,
                width: 220,
                decoration: BoxDecoration(
                  color: DDSColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(DDSRadius.small),
                ),
              ),
              const Gap(8),
              Container(
                height: 14,
                width: 140,
                decoration: BoxDecoration(
                  color: DDSColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(DDSRadius.small),
                ),
              ),
              const Gap(24),
              // Shimmer Specs
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: DDSColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(DDSRadius.medium),
                      ),
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: DDSColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(DDSRadius.medium),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

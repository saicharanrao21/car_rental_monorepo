import 'package:flutter/material.dart';
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

    return Scaffold(
      body: detailVal.when(
        data: (data) {
          final car = data.car;
          final vendor = data.vendor;
          final reviews = data.reviews;

          final effectiveBasePrice = _selectedMileagePackage?.basePricePerDay ?? car.pricePerDay;

          // Calculate estimated fare using FareCalculatorService
          final commissionPercent = _getCommissionPercentage(vendor.city, car.type);
          final fareResult = FareCalculatorService.calculateFare(
            distanceKm: 50.0,
            basePackagePrice: effectiveBasePrice,
            pricePerKm: car.pricePerKm,
            commissionPercent: commissionPercent,
          );

          return Stack(
            children: [
              SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. Image Gallery Hero with Floating Actions ──────────
                    CarImageGallery(
                      photos: car.photos,
                      carType: car.type,
                      isSponsored: car.isSponsored || vendor.isSponsored,
                      isWishlisted: isWishlisted,
                      onWishlistToggle: () {
                        ref.read(wishlistIdsProvider.notifier).toggle(widget.carId);
                      },
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
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                          CarPricingSection(car: car),
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
                  onBookNow: () {
                    context.push('/booking/${car.id}');
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: AppLoader()),
        error: (err, stack) => Scaffold(
          appBar: AppBar(title: const Text('Car Details')),
          body: ErrorStateWidget(
            message: 'Failed to load details: ${err.toString()}',
            onRetry: () => ref.invalidate(carDetailDataProvider(widget.carId)),
          ),
        ),
      ),
    );
  }
}

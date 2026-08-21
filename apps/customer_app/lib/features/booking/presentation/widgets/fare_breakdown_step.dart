import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';
import '../providers/booking_providers.dart';
import '../../../referral/presentation/providers/referral_providers.dart';
import 'booking_review_summary_card.dart';
import 'booking_price_breakdown_card.dart';

class FareBreakdownStep extends ConsumerStatefulWidget {
  final CarModel car;
  final VendorModel vendor;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const FareBreakdownStep({
    super.key,
    required this.car,
    required this.vendor,
    required this.onBack,
    required this.onNext,
  });

  @override
  ConsumerState<FareBreakdownStep> createState() => _FareBreakdownStepState();
}

class _FareBreakdownStepState extends ConsumerState<FareBreakdownStep> {
  final TextEditingController _couponController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon(double subtotal) async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(bookingRepositoryProvider);
      final draft = ref.read(bookingDraftProvider);

      final result = await repo.validateCoupon(
        code: code,
        carId: widget.car.id,
        subtotal: subtotal,
        city: widget.vendor.city,
        tripType: draft.tripType,
        carCategory: widget.car.type,
      );

      if (result.valid) {
        ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
              appliedCouponCode: result.code,
              couponDiscountAmount: result.discountAmount,
              appliedCoupon: result,
            ));
        _couponController.clear();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('DioException: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeCoupon() {
    ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
          appliedCouponCode: '',
          couponDiscountAmount: 0.0,
          appliedCoupon: null,
        ));
    setState(() {
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final repo = ref.watch(bookingRepositoryProvider);
    final cs = Theme.of(context).colorScheme;

    final rentalDays = draft.rentalDays;
    double discountPercent = 0.0;
    String discountLabel = '';

    final weeklyPct = (widget.car.weeklyDiscountPercent != null &&
            widget.car.weeklyDiscountPercent! > 0)
        ? widget.car.weeklyDiscountPercent!
        : 15.0;
    final monthlyPct = (widget.car.monthlyDiscountPercent != null &&
            widget.car.monthlyDiscountPercent! > 0)
        ? widget.car.monthlyDiscountPercent!
        : 25.0;

    if (rentalDays >= 30) {
      discountPercent = monthlyPct;
      discountLabel = 'Monthly discount applied (${discountPercent.toInt()}%)';
    } else if (rentalDays >= 7) {
      discountPercent = weeklyPct;
      discountLabel = 'Weekly discount applied (${discountPercent.toInt()}%)';
    }

    final isPackageTier = draft.selectedMileagePackage != null;
    final originalRentalFare = isPackageTier
        ? draft.selectedMileagePackage!.basePricePerDay * rentalDays
        : widget.car.pricePerDay * rentalDays;
    final discountAmount = originalRentalFare * (discountPercent / 100.0);
    final actualBasePackagePrice = originalRentalFare - discountAmount;

    // Compute fare on every relevant change
    final config = repo.getCommissionConfig(
      city: widget.vendor.city,
      carCategory: widget.car.type,
      tripType: draft.tripType,
    );
    final distanceKm = isPackageTier ? 0.0 : draft.estimatedDistanceKm.toDouble();
    final pricePerKm = isPackageTier ? 0.0 : widget.car.pricePerKm;

    final result = FareCalculatorService.calculateFare(
      distanceKm: distanceKm,
      basePackagePrice: actualBasePackagePrice,
      pricePerKm: pricePerKm,
      commissionPercent: config.percentage,
    );

    final totalAddons = draft.protectionFee +
        draft.deliveryFee +
        draft.returnPickupFee +
        draft.additionalDriverFee;
    final finalPayable = (result.total +
            totalAddons -
            draft.couponDiscountAmount)
        .clamp(0.0, double.infinity);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review your complete booking summary, apply coupons, and inspect the price breakdown.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const Gap(14),

          // ── Booking Review Summary Card ───────────────────────────
          BookingReviewSummaryCard(
            car: widget.car,
            vendor: widget.vendor,
          ),
          const Gap(14),

          // ── Coupon / Promo Code Card ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_offer_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      'Promo Code / Coupon',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const Gap(10),
                if (draft.appliedCouponCode != null &&
                    draft.appliedCouponCode!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                        const Gap(8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Code: ${draft.appliedCouponCode}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'You save ₹${draft.couponDiscountAmount.toInt()}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: Colors.red),
                          onPressed: _removeCoupon,
                          tooltip: 'Remove Coupon',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponController,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(fontSize: 13, color: cs.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Enter promo code',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: cs.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            errorText: _errorMessage,
                          ),
                        ),
                      ),
                      const Gap(8),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _applyCoupon(result.total),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Apply',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Gap(14),

          // ── Referral Reward Eligibility Banner ────────────────────
          ref.watch(refereeEligibilityProvider).when(
                data: (eligibility) {
                  final isEligible = eligibility['eligible'] == true;
                  final discount =
                      (eligibility['discountAmount'] as num?)?.toDouble() ??
                          250.0;
                  final minBooking =
                      (eligibility['minBookingAmount'] as num?)?.toDouble() ??
                          1000.0;

                  if (!isEligible) return const SizedBox.shrink();

                  return Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCE93D8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.card_giftcard,
                          color: Color(0xFF8E24AA),
                          size: 22,
                        ),
                        const Gap(10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Referral Reward (₹${discount.toInt()} Off)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF6A1B9A),
                                ),
                              ),
                              Text(
                                '₹${discount.toInt()} discount on qualifying bookings (min. ₹${minBooking.toInt()})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E24AA),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'APPLIED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

          // ── Price Breakdown Card ───────────────────────────────────
          BookingPriceBreakdownCard(
            car: widget.car,
            vendor: widget.vendor,
            originalRentalFare: originalRentalFare,
            discountPercent: discountPercent,
            discountLabel: discountLabel,
            discountAmount: discountAmount,
            result: result,
            finalPayable: finalPayable,
            config: config,
          ),
          const Gap(14),

          // ── Transparent Pricing Assurance ──────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined, color: Colors.green, size: 18),
                Gap(8),
                Expanded(
                  child: Text(
                    'Transparent pricing with zero hidden charges. Fare locked at booking confirmation.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

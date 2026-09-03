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

    // Authoritative calculations
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
        draft.pickupFee +
        draft.returnFee +
        draft.oneWayFee +
        draft.additionalDriverFee;
    final finalPayable = (result.total +
            totalAddons -
            draft.couponDiscountAmount)
        .clamp(0.0, double.infinity);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(DDSSpacing.md, DDSSpacing.md, DDSSpacing.md, DDSSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review your complete booking summary, apply coupons, and inspect the price breakdown.',
            style: DDSTypography.bodyMedium.copyWith(
              color: DDSColors.textSecondary,
              height: 1.4,
              fontSize: 12,
            ),
          ),
          const Gap(DDSSpacing.md),

          // ── Booking Review Summary Card ───────────────────────────
          BookingReviewSummaryCard(
            car: widget.car,
            vendor: widget.vendor,
          ),
          const Gap(DDSSpacing.md),

          // ── Coupon / Promo Code Card ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(DDSSpacing.md),
            decoration: BoxDecoration(
              color: DDSColors.surfaceCard,
              borderRadius: DDSRadius.largeBorderRadius,
              border: const Border.fromBorderSide(
                BorderSide(color: DDSColors.borderLight),
              ),
              boxShadow: DDSElevation.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_offer_outlined,
                        size: 16,
                        color: DDSColors.primaryBlue,
                      ),
                    ),
                    const Gap(DDSSpacing.xs),
                    Text(
                      'Promo Code / Coupon',
                      style: DDSTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Gap(DDSSpacing.sm),
                if (draft.appliedCouponCode != null &&
                    draft.appliedCouponCode!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: DDSSpacing.sm, vertical: DDSSpacing.xs),
                    decoration: BoxDecoration(
                      color: DDSColors.successGreenBg,
                      borderRadius: DDSRadius.mediumBorderRadius,
                      border: Border.all(
                        color: DDSColors.successGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: DDSColors.successGreen,
                          size: 18,
                        ),
                        const Gap(DDSSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Code: ${draft.appliedCouponCode}',
                                style: DDSTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: DDSColors.successGreen,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'You save ₹${draft.couponDiscountAmount.toInt()}',
                                style: DDSTypography.bodyMedium.copyWith(
                                  color: DDSColors.successGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: DDSColors.errorRed),
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
                          style: DDSTypography.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'Enter promo code',
                            hintStyle: DDSTypography.bodyMedium.copyWith(
                              color: DDSColors.textMuted,
                              fontSize: 12,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: DDSRadius.mediumBorderRadius,
                              borderSide: const BorderSide(
                                color: DDSColors.borderMedium,
                              ),
                            ),
                            errorText: _errorMessage,
                          ),
                        ),
                      ),
                      const Gap(DDSSpacing.xs),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _applyCoupon(result.total),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DDSColors.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: DDSRadius.mediumBorderRadius,
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
                              : Text(
                                  'Apply',
                                  style: DDSTypography.labelSmall.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Gap(DDSSpacing.md),

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
                    padding: const EdgeInsets.all(DDSSpacing.sm),
                    margin: const EdgeInsets.only(bottom: DDSSpacing.md),
                    decoration: BoxDecoration(
                      color: DDSColors.accentAmber.withValues(alpha: 0.12),
                      borderRadius: DDSRadius.largeBorderRadius,
                      border: Border.all(color: DDSColors.accentAmber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.card_giftcard,
                          color: DDSColors.accentAmber,
                          size: 22,
                        ),
                        const Gap(DDSSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'First-Booking Referral Reward (₹${discount.toInt()} Off)',
                                style: DDSTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: DDSColors.textPrimary,
                                ),
                              ),
                              Text(
                                '₹${discount.toInt()} discount on qualifying bookings (min. ₹${minBooking.toInt()})',
                                style: DDSTypography.bodyMedium.copyWith(
                                  fontSize: 11,
                                  color: DDSColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: DDSColors.accentAmber,
                            borderRadius: DDSRadius.smallBorderRadius,
                          ),
                          child: Text(
                            'ELIGIBLE',
                            style: DDSTypography.labelSmall.copyWith(
                              color: Colors.black,
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

          // ── Security Deposit Info Banner ───────────────────────────
          Container(
            padding: const EdgeInsets.all(DDSSpacing.md),
            margin: const EdgeInsets.only(bottom: DDSSpacing.md),
            decoration: BoxDecoration(
              color: DDSColors.infoBlueBg,
              borderRadius: DDSRadius.largeBorderRadius,
              border: Border.all(color: DDSColors.primaryBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: DDSColors.primaryBlue, size: 20),
                const Gap(DDSSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '100% Refundable Security Deposit',
                        style: DDSTypography.titleMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DDSColors.primaryBlue,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        'Security deposit is held securely during your rental and automatically initiated for refund within 48 hours of vehicle return inspection.',
                        style: DDSTypography.bodyMedium.copyWith(
                          fontSize: 11,
                          color: DDSColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
          const Gap(DDSSpacing.md),

          // ── Transparent Pricing Assurance ──────────────────────────
          Container(
            padding: const EdgeInsets.all(DDSSpacing.sm),
            decoration: BoxDecoration(
              color: DDSColors.successGreenBg,
              borderRadius: DDSRadius.mediumBorderRadius,
              border: Border.all(color: DDSColors.successGreen.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: DDSColors.successGreen, size: 18),
                const Gap(DDSSpacing.xs),
                Expanded(
                  child: Text(
                    'Transparent pricing with zero hidden charges. Fare locked at booking confirmation.',
                    style: DDSTypography.bodyMedium.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: DDSColors.successGreen,
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

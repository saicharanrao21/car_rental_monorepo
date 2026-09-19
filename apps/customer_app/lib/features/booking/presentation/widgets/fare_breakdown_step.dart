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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = ref.read(bookingRepositoryProvider);
      ref.read(bookingDraftProvider.notifier).fetchAuthoritativeQuote(
            repo: repo,
            carId: widget.car.id,
          );
    });
  }

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

  Future<void> _applyCouponCode(String code, double subtotal) async {
    _couponController.text = code;
    await _applyCoupon(subtotal);
  }

  Future<void> _openAvailableCouponsSheet(BuildContext context, double subtotal) async {
    final repo = ref.read(bookingRepositoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AvailableCouponsSheet(
        subtotal: subtotal,
        onSelectCoupon: (code) {
          Navigator.of(ctx).pop();
          _applyCouponCode(code, subtotal);
        },
        fetchCoupons: () => repo.getAvailableCoupons(city: widget.vendor.city),
      ),
    );
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
          const Gap(DDSSpacing.sm),

          // ── Canonical Server Quote Status Banner ──
          if (draft.isQuoteLoading)
            Container(
              margin: const EdgeInsets.only(bottom: DDSSpacing.sm),
              padding: const EdgeInsets.all(DDSSpacing.sm),
              decoration: BoxDecoration(
                color: DDSColors.infoBlueBg,
                borderRadius: DDSRadius.mediumBorderRadius,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const Gap(DDSSpacing.sm),
                  Expanded(
                    child: Text(
                      'Calculating server-authoritative quote...',
                      style: DDSTypography.labelSmall.copyWith(
                        color: DDSColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (draft.authoritativeQuote != null) ...[
            if (draft.authoritativeQuote!.isExpired)
              Container(
                margin: const EdgeInsets.only(bottom: DDSSpacing.sm),
                padding: const EdgeInsets.all(DDSSpacing.sm),
                decoration: BoxDecoration(
                  color: DDSColors.errorRed.withValues(alpha: 0.1),
                  borderRadius: DDSRadius.mediumBorderRadius,
                  border: Border.all(color: DDSColors.errorRed.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_off_outlined, color: DDSColors.errorRed, size: 20),
                    const Gap(DDSSpacing.sm),
                    Expanded(
                      child: Text(
                        'Quote expired. Please refresh to lock latest rates before payment.',
                        style: DDSTypography.labelSmall.copyWith(
                          color: DDSColors.errorRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final repo = ref.read(bookingRepositoryProvider);
                        ref.read(bookingDraftProvider.notifier).refreshExpiredQuote(repo: repo);
                      },
                      child: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: DDSSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: DDSSpacing.sm, vertical: 8),
                decoration: BoxDecoration(
                  color: DDSColors.successGreenBg,
                  borderRadius: DDSRadius.mediumBorderRadius,
                  border: Border.all(color: DDSColors.successGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: DDSColors.successGreen, size: 18),
                    const Gap(DDSSpacing.xs),
                    Expanded(
                      child: Text(
                        'Server Quote Active • Rate Guaranteed for 15 mins',
                        style: DDSTypography.labelSmall.copyWith(
                          color: DDSColors.successGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const Gap(DDSSpacing.xs),

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
                    Expanded(
                      child: Text(
                        'Promo Code / Coupon',
                        style: DDSTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: DDSColors.textPrimary,
                        ),
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
                            minimumSize: const Size(80, 40),
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
                  const Gap(DDSSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openAvailableCouponsSheet(context, result.total),
                      icon: const Icon(Icons.local_offer_outlined, size: 15, color: DDSColors.primaryBlue),
                      label: Text(
                        'View Available Offers & Coupons',
                        style: DDSTypography.bodyMedium.copyWith(
                          color: DDSColors.primaryBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
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
            quote: draft.authoritativeQuote,
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

class _AvailableCouponsSheet extends StatefulWidget {
  final double subtotal;
  final ValueChanged<String> onSelectCoupon;
  final Future<List<Map<String, dynamic>>> Function() fetchCoupons;

  const _AvailableCouponsSheet({
    required this.subtotal,
    required this.onSelectCoupon,
    required this.fetchCoupons,
  });

  @override
  State<_AvailableCouponsSheet> createState() => _AvailableCouponsSheetState();
}

class _AvailableCouponsSheetState extends State<_AvailableCouponsSheet> {
  late Future<List<Map<String, dynamic>>> _futureCoupons;

  @override
  void initState() {
    super.initState();
    _futureCoupons = widget.fetchCoupons();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DDSColors.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.local_offer, color: DDSColors.primaryBlue, size: 20),
                const Gap(8),
                Text(
                  'Available Offers & Coupons',
                  style: DDSTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DDSColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureCoupons,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: DDSColors.errorRed, size: 36),
                          const Gap(12),
                          Text(
                            'Failed to load offers',
                            style: DDSTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: DDSColors.textPrimary,
                            ),
                          ),
                          const Gap(8),
                          ElevatedButton(
                            onPressed: () => setState(() {
                              _futureCoupons = widget.fetchCoupons();
                            }),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final coupons = snapshot.data ?? [];
                if (coupons.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.discount_outlined, size: 48, color: DDSColors.textMuted.withValues(alpha: 0.5)),
                          const Gap(12),
                          Text(
                            'No coupons currently available',
                            style: DDSTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: DDSColors.textPrimary,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            'Check back soon or enter your promo code manually.',
                            textAlign: TextAlign.center,
                            style: DDSTypography.bodyMedium.copyWith(
                              color: DDSColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  itemCount: coupons.length,
                  separatorBuilder: (_, __) => const Gap(12),
                  itemBuilder: (context, index) {
                    final c = coupons[index];
                    final code = c['code']?.toString() ?? '';
                    final discountType = c['discountType']?.toString() ?? 'PERCENTAGE';
                    final discountVal = (c['discountValue'] as num?)?.toDouble() ?? 0.0;
                    final maxDiscount = (c['maxDiscountAmount'] as num?)?.toDouble();
                    final minBooking = (c['minBookingAmount'] as num?)?.toDouble();
                    final desc = c['description']?.toString() ?? '';

                    final isPercentage = discountType == 'PERCENTAGE';
                    final discountBadge = isPercentage
                        ? '${discountVal.toInt()}% OFF'
                        : '₹${discountVal.toInt()} OFF';

                    final isMinAmountMet = minBooking == null || widget.subtotal >= minBooking;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: DDSColors.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMinAmountMet
                              ? DDSColors.primaryBlue.withValues(alpha: 0.3)
                              : DDSColors.borderMedium,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: DDSColors.infoBlueBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: DDSColors.primaryBlue.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  code,
                                  style: DDSTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: DDSColors.primaryBlue,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              const Gap(8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: DDSColors.successGreenBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  discountBadge,
                                  style: DDSTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: DDSColors.successGreen,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: isMinAmountMet
                                    ? () => widget.onSelectCoupon(code)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DDSColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: DDSColors.borderMedium,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  minimumSize: const Size(60, 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'APPLY',
                                  style: DDSTypography.labelSmall.copyWith(
                                    color: isMinAmountMet ? Colors.white : DDSColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const Gap(8),
                            Text(
                              desc,
                              style: DDSTypography.bodyMedium.copyWith(
                                fontSize: 12,
                                color: DDSColors.textPrimary,
                              ),
                            ),
                          ],
                          const Gap(6),
                          Wrap(
                            spacing: 12,
                            children: [
                              if (minBooking != null && minBooking > 0)
                                Text(
                                  'Min. booking ₹${minBooking.toInt()}',
                                  style: DDSTypography.labelSmall.copyWith(
                                    fontSize: 11,
                                    color: isMinAmountMet ? DDSColors.textMuted : DDSColors.errorRed,
                                    fontWeight: isMinAmountMet ? FontWeight.normal : FontWeight.w600,
                                  ),
                                ),
                              if (maxDiscount != null && maxDiscount > 0 && isPercentage)
                                Text(
                                  'Max. discount ₹${maxDiscount.toInt()}',
                                  style: DDSTypography.labelSmall.copyWith(
                                    fontSize: 11,
                                    color: DDSColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Gap(12),
        ],
      ),
    );
  }
}

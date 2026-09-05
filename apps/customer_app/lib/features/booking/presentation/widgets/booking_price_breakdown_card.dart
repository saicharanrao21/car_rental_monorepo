import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';

class BookingPriceBreakdownCard extends ConsumerWidget {
  final CarModel car;
  final VendorModel vendor;
  final double originalRentalFare;
  final double discountPercent;
  final String discountLabel;
  final double discountAmount;
  final FareCalculatorResult result;
  final double finalPayable;
  final CommissionConfigModel config;
  final BookingQuoteModel? quote;

  const BookingPriceBreakdownCard({
    super.key,
    required this.car,
    required this.vendor,
    required this.originalRentalFare,
    required this.discountPercent,
    required this.discountLabel,
    required this.discountAmount,
    required this.result,
    required this.finalPayable,
    required this.config,
    this.quote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftProvider);
    final activeQuote = quote ?? draft.authoritativeQuote;
    final tripFare = result.baseFare + result.platformFee;
    final payableTotal = activeQuote?.totalPayable ?? finalPayable;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price Breakdown',
                      style: DDSTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DDSColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (activeQuote != null) ...[
                      const Gap(2),
                      Text(
                        'Quote #${activeQuote.quoteId.length > 8 ? activeQuote.quoteId.substring(0, 8) : activeQuote.quoteId} (${activeQuote.pricingVersion})',
                        style: DDSTypography.labelSmall.copyWith(
                          fontSize: 10,
                          color: DDSColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DDSColors.successGreenBg,
                  borderRadius: DDSRadius.smallBorderRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 12, color: DDSColors.successGreen),
                    const Gap(4),
                    Text(
                      activeQuote != null ? 'Authoritative' : 'Price Locked',
                      style: DDSTypography.labelSmall.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: DDSColors.successGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(DDSSpacing.sm),
          const Divider(
            height: 1,
            color: DDSColors.borderLight,
          ),
          const Gap(DDSSpacing.sm),

          if (activeQuote != null && activeQuote.lineItems.isNotEmpty) ...[
            for (final item in activeQuote.lineItems) ...[
              _row(
                item.name,
                item.amount,
                bold: item.type == 'BASE_RENTAL',
                color: item.amount < 0 ? DDSColors.successGreen : null,
              ),
              const Gap(6),
            ],
          ] else ...[
            // Trip Fare
            _row('Base Trip Fare', tripFare, bold: true),

            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
              child: Column(
                children: [
                  _subRow(
                    draft.selectedMileagePackage != null
                        ? 'Package: ${draft.selectedMileagePackage!.name} (${draft.rentalDays}d × ₹${draft.selectedMileagePackage!.basePricePerDay.toInt()}/d)'
                        : 'Rental (${draft.rentalDays}d × ₹${car.pricePerDay.toInt()}/day)',
                    originalRentalFare,
                  ),
                  if (draft.selectedMileagePackage == null)
                    _subRow(
                      'Distance (${draft.estimatedDistanceKm}km × ₹${car.pricePerKm.toInt()}/km)',
                      car.pricePerKm * draft.estimatedDistanceKm,
                    ),
                ],
              ),
            ),

          // Duration discount
          if (discountPercent > 0) ...[
            const Gap(4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: DDSColors.successGreenBg,
                borderRadius: DDSRadius.mediumBorderRadius,
                border: Border.all(color: DDSColors.successGreen.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.local_offer, size: 14, color: DDSColors.successGreen),
                        const Gap(6),
                        Expanded(
                          child: Text(
                            discountLabel,
                            style: DDSTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: DDSColors.successGreen,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(8),
                  Text(
                    '-${IndianCurrencyFormatter.format(discountAmount, showDecimals: false)}',
                    style: DDSTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: DDSColors.successGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Gap(6),
          _row('GST (18% Statutory Tax)', result.gst),

          // Protection Package
          if (draft.protectionFee > 0) ...[
            const Gap(6),
            _row(
              'Protection Package (${draft.selectedProtectionPackageId == "zero_dep_tier" ? "Premium" : "Standard"})',
              draft.protectionFee,
            ),
          ],

          // Doorstep Delivery
          if (draft.deliveryFee > 0) ...[
            const Gap(6),
            _row('Doorstep Delivery', draft.deliveryFee),
          ],

          // Doorstep Return Pickup / Collection
          if (draft.returnPickupFee > 0) ...[
            const Gap(6),
            _row('Doorstep Collection', draft.returnPickupFee),
          ],

          // Pickup Location Fee
          if (draft.pickupFee > 0) ...[
            const Gap(6),
            _row('Pickup Location Fee', draft.pickupFee),
          ],

          // Return Location Fee
          if (draft.returnFee > 0) ...[
            const Gap(6),
            _row('Return Location Fee', draft.returnFee),
          ],

          // One-Way / Relocation Fee
          if (draft.oneWayFee > 0) ...[
            const Gap(6),
            _row('One-Way Relocation Fee', draft.oneWayFee),
          ],

          // Additional Driver
          if (draft.additionalDriverFee > 0) ...[
            const Gap(6),
            _row('Additional Driver', draft.additionalDriverFee),
          ],

          // Coupon Discount
          if (draft.couponDiscountAmount > 0) ...[
            const Gap(8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Coupon Discount (${draft.appliedCouponCode})',
                    style: DDSTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: DDSColors.successGreen,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(8),
                Text(
                  '-${IndianCurrencyFormatter.format(draft.couponDiscountAmount, showDecimals: false)}',
                  style: DDSTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DDSColors.successGreen,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],

        const Gap(DDSSpacing.sm),
          const Divider(
            height: 1,
            color: DDSColors.borderLight,
          ),
          const Gap(DDSSpacing.sm),

          // Total Rental Charges
          _row(
            'Total Payable Amount',
            payableTotal,
            bold: true,
            color: DDSColors.primaryBlue,
            fontSize: 15,
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    double amount, {
    bool bold = false,
    Color? color,
    double fontSize = 13,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: DDSTypography.bodyMedium.copyWith(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color ?? DDSColors.textPrimary,
              ),
            ),
          ),
          Text(
            IndianCurrencyFormatter.format(amount, showDecimals: false),
            style: DDSTypography.bodyMedium.copyWith(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? DDSColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: DDSTypography.bodyMedium.copyWith(
                fontSize: 11,
                color: DDSColors.textMuted,
              ),
            ),
          ),
          Text(
            IndianCurrencyFormatter.format(amount, showDecimals: false),
            style: DDSTypography.bodyMedium.copyWith(
              fontSize: 11,
              color: DDSColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

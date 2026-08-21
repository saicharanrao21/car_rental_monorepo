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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftProvider);
    final cs = Theme.of(context).colorScheme;
    final tripFare = result.baseFare + result.platformFee;

    return Container(
      padding: const EdgeInsets.all(16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: Colors.green),
                    Gap(4),
                    Text(
                      'Price Locked',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(12),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.25),
          ),
          const Gap(10),

          // Trip Fare
          _row(context, 'Base Trip Fare', tripFare, bold: true),

          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
            child: Column(
              children: [
                _subRow(
                  context,
                  draft.selectedMileagePackage != null
                      ? 'Package: ${draft.selectedMileagePackage!.name} (${draft.rentalDays}d × ₹${draft.selectedMileagePackage!.basePricePerDay.toInt()}/d)'
                      : 'Rental (${draft.rentalDays}d × ₹${car.pricePerDay.toInt()}/day)',
                  originalRentalFare,
                ),
                if (draft.selectedMileagePackage == null)
                  _subRow(
                    context,
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
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_offer, size: 14, color: Colors.green),
                      const Gap(6),
                      Text(
                        discountLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '-${IndianCurrencyFormatter.format(discountAmount, showDecimals: false)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Gap(8),
          _row(context, 'GST (18%)', result.gst),

          // Protection Package
          if (draft.protectionFee > 0) ...[
            const Gap(6),
            _row(
              context,
              'Protection Package (${draft.selectedProtectionPackageId == "zero_dep_tier" ? "Premium" : "Standard"})',
              draft.protectionFee,
            ),
          ],

          // Doorstep Delivery
          if (draft.deliveryFee > 0) ...[
            const Gap(6),
            _row(context, 'Doorstep Delivery', draft.deliveryFee),
          ],

          // Doorstep Pickup
          if (draft.returnPickupFee > 0) ...[
            const Gap(6),
            _row(context, 'Doorstep Return Pickup', draft.returnPickupFee),
          ],

          // Additional Driver
          if (draft.additionalDriverFee > 0) ...[
            const Gap(6),
            _row(context, 'Additional Driver', draft.additionalDriverFee),
          ],

          // Coupon Discount
          if (draft.couponDiscountAmount > 0) ...[
            const Gap(8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Coupon Discount (${draft.appliedCouponCode})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
                  ),
                ),
                Text(
                  '-${IndianCurrencyFormatter.format(draft.couponDiscountAmount, showDecimals: false)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],

          const Gap(10),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
          const Gap(10),

          // Total Payable
          _row(
            context,
            'Total Payable',
            finalPayable,
            bold: true,
            color: AppColors.primary,
            fontSize: 16,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    double amount, {
    bool bold = false,
    Color? color,
    double fontSize = 13,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color ?? cs.onSurface,
              ),
            ),
          ),
          Text(
            IndianCurrencyFormatter.format(amount, showDecimals: false),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subRow(BuildContext context, String label, double amount) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            IndianCurrencyFormatter.format(amount, showDecimals: false),
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

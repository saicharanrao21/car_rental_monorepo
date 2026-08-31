import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'car_price_breakdown_sheet.dart';

class CarPricingSection extends StatelessWidget {
  final CarModel car;
  final double baseFare;
  final double platformFee;
  final double gst;
  final double totalFare;
  final int durationDays;

  const CarPricingSection({
    super.key,
    required this.car,
    this.baseFare = 0.0,
    this.platformFee = 0.0,
    this.gst = 0.0,
    this.totalFare = 0.0,
    this.durationDays = 1,
  });

  @override
  Widget build(BuildContext context) {
    final weeklyDiscount = car.weeklyDiscountPercent;
    final monthlyDiscount = car.monthlyDiscountPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Transparent Pricing',
                style: DDSTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: DDSColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(8),
            InkWell(
              onTap: () => CarPriceBreakdownSheet.show(
                context,
                baseFare: baseFare > 0 ? baseFare : (car.pricePerDay * durationDays),
                platformFee: platformFee,
                gst: gst,
                totalFare: totalFare > 0 ? totalFare : (car.pricePerDay * durationDays),
                durationDays: durationDays,
                pricePerDay: car.pricePerDay,
              ),
              borderRadius: BorderRadius.circular(DDSRadius.small),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View breakdown',
                      style: DDSTypography.labelSmall.copyWith(
                        color: DDSColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Gap(2),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: DDSColors.primaryBlue,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const Gap(12),

        // Plan Rate Cards
        Row(
          children: [
            _buildPricePlanTile(
              context,
              'Hourly Rate',
              car.pricePerHour,
              '/ hr',
            ),
            const Gap(10),
            _buildPricePlanTile(
              context,
              'Daily Rate',
              car.pricePerDay,
              '/ day',
              isPrimary: true,
            ),
            const Gap(10),
            _buildPricePlanTile(
              context,
              'Distance Rate',
              car.pricePerKm,
              '/ km',
            ),
          ],
        ),

        // Refundable Deposit Banner
        const Gap(12),
        Container(
          padding: const EdgeInsets.all(DDSSpacing.md),
          decoration: BoxDecoration(
            color: DDSColors.surfaceCard,
            borderRadius: BorderRadius.circular(DDSRadius.medium),
            border: Border.all(color: DDSColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DDSSpacing.xs),
                decoration: const BoxDecoration(
                  color: DDSColors.successGreenBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_open_outlined,
                  size: 16,
                  color: DDSColors.successGreen,
                ),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zero Hidden Charges • Refundable Deposit',
                      style: DDSTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      'Security deposit is 100% refunded to your account within 48h after return inspection.',
                      style: DDSTypography.labelSmall.copyWith(
                        color: DDSColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Long Duration Discount Tag
        if ((weeklyDiscount != null && weeklyDiscount > 0) ||
            (monthlyDiscount != null && monthlyDiscount > 0)) ...[
          const Gap(10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DDSSpacing.md,
              vertical: DDSSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: DDSColors.infoBlueBg,
              borderRadius: BorderRadius.circular(DDSRadius.medium),
              border: Border.all(
                color: DDSColors.primaryBlue.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.discount_outlined,
                  color: DDSColors.primaryBlue,
                  size: 18,
                ),
                const Gap(10),
                Expanded(
                  child: Text(
                    [
                      if (weeklyDiscount != null && weeklyDiscount > 0)
                        'Save ${weeklyDiscount.toInt()}% on 7+ days',
                      if (monthlyDiscount != null && monthlyDiscount > 0)
                        'Save ${monthlyDiscount.toInt()}% on 30+ days',
                    ].join(' • '),
                    style: DDSTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: DDSColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPricePlanTile(
    BuildContext context,
    String title,
    double amount,
    String suffix, {
    bool isPrimary = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DDSSpacing.xs,
          vertical: DDSSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isPrimary
              ? DDSColors.infoBlueBg
              : DDSColors.surfaceCard,
          borderRadius: BorderRadius.circular(DDSRadius.medium),
          border: Border.all(
            color: isPrimary
                ? DDSColors.primaryBlue
                : DDSColors.borderLight,
            width: isPrimary ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: DDSTypography.labelSmall.copyWith(
                color: isPrimary ? DDSColors.primaryBlue : DDSColors.textSecondary,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${IndianCurrencyFormatter.format(amount, showDecimals: false)} $suffix',
                style: DDSTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? DDSColors.primaryBlue : DDSColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

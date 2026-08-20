import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';

class CarPricingSection extends StatelessWidget {
  final CarModel car;

  const CarPricingSection({
    super.key,
    required this.car,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final weeklyDiscount = car.weeklyDiscountPercent;
    final monthlyDiscount = car.monthlyDiscountPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rental Pricing Plans',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Gap(12),
        Row(
          children: [
            _buildPricePlanTile(context, 'Hourly Plan', car.pricePerHour, '/ hr', cs),
            const Gap(10),
            _buildPricePlanTile(context, 'Daily Plan', car.pricePerDay, '/ day', cs, isPrimary: true),
            const Gap(10),
            _buildPricePlanTile(context, 'Distance Rate', car.pricePerKm, '/ km', cs),
          ],
        ),
        if ((weeklyDiscount != null && weeklyDiscount > 0) || (monthlyDiscount != null && monthlyDiscount > 0)) ...[
          const Gap(12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.discount_outlined, color: AppColors.primary, size: 18),
                const Gap(10),
                Expanded(
                  child: Text(
                    [
                      if (weeklyDiscount != null && weeklyDiscount > 0) 'Save ${weeklyDiscount.toInt()}% on 7+ days',
                      if (monthlyDiscount != null && monthlyDiscount > 0) 'Save ${monthlyDiscount.toInt()}% on 30+ days',
                    ].join(' • '),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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
    String suffix,
    ColorScheme cs, {
    bool isPrimary = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary.withValues(alpha: 0.08) : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? AppColors.primary.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.12),
            width: isPrimary ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: isPrimary ? AppColors.primary : cs.onSurfaceVariant,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: PriceTag(
                amount: amount,
                suffix: suffix,
                amountStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? AppColors.primary : cs.onSurface,
                ),
                suffixStyle: TextStyle(
                  fontSize: 11,
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

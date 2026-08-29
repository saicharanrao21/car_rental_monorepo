import 'package:flutter/material.dart';
import 'package:core/core.dart';

/// DriveGo Design System (DDS) — Standard Price & Tariff Presentation Component
class DriveGoPriceTag extends StatelessWidget {
  final double amount;
  final double? originalAmount;
  final String? suffix;
  final TextStyle? amountStyle;
  final TextStyle? suffixStyle;
  final Color? color;
  final bool showDecimals;

  const DriveGoPriceTag({
    super.key,
    required this.amount,
    this.originalAmount,
    this.suffix,
    this.amountStyle,
    this.suffixStyle,
    this.color,
    this.showDecimals = false,
  });

  @override
  Widget build(BuildContext context) {
    final formattedAmount = IndianCurrencyFormatter.format(amount, showDecimals: showDecimals);
    final effectiveColor = color ?? DDSColors.accentAmber;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (originalAmount != null && originalAmount! > amount) ...[
          Text(
            IndianCurrencyFormatter.format(originalAmount!, showDecimals: showDecimals),
            style: DDSTypography.bodyMedium.copyWith(
              decoration: TextDecoration.lineThrough,
              color: DDSColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          formattedAmount,
          style: amountStyle ??
              DDSTypography.priceDisplay.copyWith(color: effectiveColor),
        ),
        if (suffix != null && suffix!.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            suffix!,
            style: suffixStyle ??
                DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:core/core.dart';

class PriceTag extends StatelessWidget {
  final double amount;
  final String? suffix;
  final TextStyle? amountStyle;
  final TextStyle? suffixStyle;

  const PriceTag({
    super.key,
    required this.amount,
    this.suffix,
    this.amountStyle,
    this.suffixStyle,
  });

  @override
  Widget build(BuildContext context) {
    final formattedAmount = IndianCurrencyFormatter.format(amount, showDecimals: false);

    return RichText(
      text: TextSpan(
        text: formattedAmount,
        style: amountStyle ??
            const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
        children: suffix != null
            ? [
                TextSpan(
                  text: suffix,
                  style: suffixStyle ??
                      const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: Colors.grey,
                      ),
                ),
              ]
            : [],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'drivego_price_tag.dart';

/// Legacy PriceTag maintained for backward compatibility.
/// Forwards directly to DriveGo Design System (DDS) DriveGoPriceTag.
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
    return DriveGoPriceTag(
      amount: amount,
      suffix: suffix,
      amountStyle: amountStyle,
      suffixStyle: suffixStyle,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

class BookingPaymentMethodSelector extends StatelessWidget {
  final int selectedMethod;
  final ValueChanged<int> onMethodSelected;

  const BookingPaymentMethodSelector({
    super.key,
    required this.selectedMethod,
    required this.onMethodSelected,
  });

  static const _methods = [
    (Icons.currency_rupee, 'UPI / QR Code', 'Google Pay, PhonePe, Paytm, BHIM'),
    (Icons.credit_card_outlined, 'Debit / Credit Card', 'Visa, Mastercard, RuPay, Diners'),
    (Icons.account_balance_outlined, 'Net Banking', 'All major Indian banks supported'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Payment Method',
          style: DDSTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: DDSColors.textPrimary,
          ),
        ),
        const Gap(DDSSpacing.sm),
        ..._methods.asMap().entries.map((e) {
          final idx = e.key;
          final (icon, title, subtitle) = e.value;
          final isSelected = selectedMethod == idx;

          return Padding(
            padding: const EdgeInsets.only(bottom: DDSSpacing.sm),
            child: InkWell(
              onTap: () => onMethodSelected(idx),
              borderRadius: DDSRadius.mediumBorderRadius,
              child: AnimatedContainer(
                duration: DDSMotion.fast,
                padding: const EdgeInsets.all(DDSSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DDSColors.infoBlueBg
                      : DDSColors.surfaceCard,
                  borderRadius: DDSRadius.largeBorderRadius,
                  border: Border.all(
                    color: isSelected
                        ? DDSColors.primaryBlue
                        : DDSColors.borderLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? DDSElevation.cardShadow
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? DDSColors.primaryBlue : DDSColors.textMuted,
                      size: 20,
                    ),
                    const Gap(DDSSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(DDSSpacing.xs),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? DDSColors.primaryBlue.withValues(alpha: 0.12)
                            : DDSColors.surfaceSubtle,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? DDSColors.primaryBlue : DDSColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const Gap(DDSSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: DDSTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isSelected ? DDSColors.primaryBlue : DDSColors.textPrimary,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            subtitle,
                            style: DDSTypography.bodyMedium.copyWith(
                              fontSize: 11,
                              color: DDSColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

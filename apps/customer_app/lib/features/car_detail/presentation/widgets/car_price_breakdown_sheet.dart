import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';

class CarPriceBreakdownSheet extends StatelessWidget {
  final double baseFare;
  final double platformFee;
  final double gst;
  final double totalFare;
  final double securityDeposit;
  final int durationDays;
  final double pricePerDay;

  const CarPriceBreakdownSheet({
    super.key,
    required this.baseFare,
    required this.platformFee,
    required this.gst,
    required this.totalFare,
    this.securityDeposit = 0.0,
    this.durationDays = 1,
    required this.pricePerDay,
  });

  static Future<void> show(
    BuildContext context, {
    required double baseFare,
    required double platformFee,
    required double gst,
    required double totalFare,
    double securityDeposit = 0.0,
    int durationDays = 1,
    required double pricePerDay,
  }) {
    return DriveGoBottomSheet.show(
      context,
      title: 'Price Breakdown',
      child: CarPriceBreakdownSheet(
        baseFare: baseFare,
        platformFee: platformFee,
        gst: gst,
        totalFare: totalFare,
        securityDeposit: securityDeposit,
        durationDays: durationDays,
        pricePerDay: pricePerDay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPayable = totalFare + securityDeposit;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 1. Rental Fare Section ──────────────────────────────────────────
          Text(
            'Rental Charges',
            style: DDSTypography.labelSmall.copyWith(
              color: DDSColors.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const Gap(8),
          _buildLineItem(
            label: 'Base Rental Fare ($durationDays ${durationDays == 1 ? 'day' : 'days'})',
            amount: baseFare > 0 ? baseFare : (pricePerDay * durationDays),
          ),
          const Gap(8),
          _buildLineItem(
            label: 'Platform & Facilitation Fee',
            amount: platformFee,
          ),
          const Gap(8),
          _buildLineItem(
            label: 'GST (18% Statutory Tax)',
            amount: gst,
          ),

          const Gap(12),
          const Divider(color: DDSColors.borderLight),
          const Gap(12),

          // ── 2. Trip Total ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total Rental Fare',
                  style: DDSTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DDSColors.textPrimary,
                  ),
                ),
              ),
              const Gap(8),
              Text(
                IndianCurrencyFormatter.format(totalFare, showDecimals: false),
                style: DDSTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: DDSColors.textPrimary,
                ),
              ),
            ],
          ),

          const Gap(16),

          // ── 3. Refundable Security Deposit ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(DDSSpacing.md),
            decoration: BoxDecoration(
              color: DDSColors.successGreenBg,
              borderRadius: BorderRadius.circular(DDSRadius.medium),
              border: Border.all(color: DDSColors.successGreen.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: DDSColors.successGreen,
                          ),
                          const Gap(8),
                          Flexible(
                            child: Text(
                              'Refundable Security Deposit',
                              style: DDSTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: DDSColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),
                    Text(
                      securityDeposit > 0
                          ? IndianCurrencyFormatter.format(securityDeposit, showDecimals: false)
                          : '₹0 (Zero Deposit)',
                      style: DDSTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DDSColors.successGreen,
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Text(
                  '100% refundable upon vehicle return inspection within 48 hours to original payment method.',
                  style: DDSTypography.labelSmall.copyWith(
                    color: DDSColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const Gap(16),
          const Divider(color: DDSColors.borderLight),
          const Gap(12),

          // ── 4. Total Payable Amount ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DDSSpacing.md,
              vertical: DDSSpacing.md,
            ),
            decoration: BoxDecoration(
              color: DDSColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(DDSRadius.medium),
              border: Border.all(color: DDSColors.borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Payable Now',
                        style: DDSTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DDSColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Includes rental + refundable deposit',
                        style: DDSTypography.labelSmall.copyWith(
                          color: DDSColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                Text(
                  IndianCurrencyFormatter.format(totalPayable, showDecimals: false),
                  style: DDSTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DDSColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),

          const Gap(20),

          // Dismiss Button
          DriveGoButton(
            text: 'Got It',
            variant: DriveGoButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Gap(12),
        ],
      ),
    );
  }

  Widget _buildLineItem({required String label, required double amount}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: DDSTypography.bodyMedium.copyWith(
              color: DDSColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Gap(8),
        Text(
          IndianCurrencyFormatter.format(amount, showDecimals: false),
          style: DDSTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: DDSColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

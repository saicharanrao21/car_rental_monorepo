import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import 'car_price_breakdown_sheet.dart';

class CarBookingBottomBar extends StatelessWidget {
  final double totalFare;
  final double baseFare;
  final double platformFee;
  final double gst;
  final double securityDeposit;
  final int durationDays;
  final double pricePerDay;
  final bool isAvailable;
  final VoidCallback onBookNow;

  const CarBookingBottomBar({
    super.key,
    required this.totalFare,
    required this.baseFare,
    required this.platformFee,
    required this.gst,
    this.securityDeposit = 0.0,
    this.durationDays = 1,
    required this.pricePerDay,
    this.isAvailable = true,
    required this.onBookNow,
  });

  void _showBreakdown(BuildContext context) {
    CarPriceBreakdownSheet.show(
      context,
      baseFare: baseFare,
      platformFee: platformFee,
      gst: gst,
      totalFare: totalFare,
      securityDeposit: securityDeposit,
      durationDays: durationDays,
      pricePerDay: pricePerDay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTotal = totalFare > 0 ? totalFare : (pricePerDay * durationDays);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DDSSpacing.md,
        vertical: DDSSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DDSRadius.large),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // ── Left: Price & Breakdown Link ─────────────────────────────────
            Expanded(
              flex: 5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showBreakdown(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            durationDays > 1
                                ? 'Est. Total ($durationDays days)'
                                : 'Daily Rate',
                            style: DDSTypography.labelSmall.copyWith(
                              color: DDSColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Gap(4),
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: DDSColors.primaryBlue,
                        ),
                      ],
                    ),
                  ),
                  const Gap(2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          IndianCurrencyFormatter.format(
                            effectiveTotal,
                            showDecimals: false,
                          ),
                          style: DDSTypography.headlineMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: DDSColors.primaryBlue,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (durationDays <= 1) ...[
                          const Gap(3),
                          Text(
                            '/ day',
                            style: DDSTypography.labelSmall.copyWith(
                              color: DDSColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),

            // ── Right: Continue CTA ─────────────────────────────────────────
            Expanded(
              flex: 6,
              child: DriveGoButton(
                text: isAvailable ? 'Book Now' : 'Unavailable',
                variant: DriveGoButtonVariant.primary,
                icon: isAvailable
                    ? const Icon(Icons.arrow_forward, size: 16, color: Colors.white)
                    : null,
                onPressed: isAvailable ? onBookNow : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

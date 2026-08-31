import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

class BookingStickyBottomBar extends StatelessWidget {
  final double totalAmount;
  final String primaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onBackPressed;
  final VoidCallback? onBreakdownPressed;
  final bool isLoading;
  final bool showBackButton;

  const BookingStickyBottomBar({
    super.key,
    required this.totalAmount,
    required this.primaryButtonText,
    required this.onPrimaryPressed,
    this.onBackPressed,
    this.onBreakdownPressed,
    this.isLoading = false,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        border: const Border(
          top: BorderSide(
            color: DDSColors.borderLight,
            width: 1,
          ),
        ),
        boxShadow: DDSElevation.floatingShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DDSSpacing.md, vertical: DDSSpacing.sm),
          child: Row(
            children: [
              // Total Fare Column
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: onBreakdownPressed,
                  borderRadius: DDSRadius.smallBorderRadius,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total Payable',
                              style: DDSTypography.labelSmall.copyWith(
                                color: DDSColors.textMuted,
                              ),
                            ),
                            if (onBreakdownPressed != null) ...[
                              const Gap(3),
                              const Icon(
                                Icons.info_outline,
                                size: 13,
                                color: DDSColors.textMuted,
                              ),
                            ],
                          ],
                        ),
                        const Gap(1),
                        Text(
                          IndianCurrencyFormatter.format(totalAmount,
                              showDecimals: false),
                          style: DDSTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: DDSColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Gap(DDSSpacing.sm),

              // Back Button (if enabled)
              if (showBackButton && onBackPressed != null) ...[
                OutlinedButton(
                  onPressed: isLoading ? null : onBackPressed,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    minimumSize: const Size(44, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: DDSRadius.mediumBorderRadius,
                    ),
                    side: const BorderSide(
                      color: DDSColors.borderMedium,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: DDSColors.textPrimary,
                  ),
                ),
                const Gap(DDSSpacing.xs),
              ],

              // Primary Action CTA
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onPrimaryPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DDSColors.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: DDSRadius.mediumBorderRadius,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            primaryButtonText,
                            style: DDSTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

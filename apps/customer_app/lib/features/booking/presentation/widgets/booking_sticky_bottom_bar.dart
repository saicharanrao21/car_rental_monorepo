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
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Total Fare Column
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: onBreakdownPressed,
                  borderRadius: BorderRadius.circular(8),
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
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            if (onBreakdownPressed != null) ...[
                              const Gap(3),
                              Icon(
                                Icons.info_outline,
                                size: 13,
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                        const Gap(1),
                        Text(
                          IndianCurrencyFormatter.format(totalAmount,
                              showDecimals: false),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Gap(10),

              // Back Button (if enabled)
              if (showBackButton && onBackPressed != null) ...[
                OutlinedButton(
                  onPressed: isLoading ? null : onBackPressed,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    minimumSize: const Size(44, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: cs.onSurface,
                  ),
                ),
                const Gap(8),
              ],

              // Primary Action CTA
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onPrimaryPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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

import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

class BookingProgressIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> stepTitles;

  const BookingProgressIndicator({
    super.key,
    required this.currentStep,
    required this.stepTitles,
  });

  @override
  Widget build(BuildContext context) {
    final total = stepTitles.length;

    return Container(
      decoration: const BoxDecoration(
        color: DDSColors.surfaceCard,
        border: Border(
          bottom: BorderSide(
            color: DDSColors.borderLight,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DDSSpacing.md, vertical: DDSSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(total, (i) {
              final isPassed = i < currentStep;
              final isCurrent = i == currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: DDSMotion.fast,
                  curve: DDSMotion.standardCurve,
                  height: 4,
                  margin: EdgeInsets.only(right: i < total - 1 ? DDSSpacing.xxs : 0),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? DDSColors.successGreen
                        : isCurrent
                            ? DDSColors.primaryBlue
                            : DDSColors.surfaceSubtle,
                    borderRadius: DDSRadius.pillBorderRadius,
                  ),
                ),
              );
            }),
          ),
          const Gap(DDSSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${currentStep + 1} of $total: ${stepTitles[currentStep]}',
                style: DDSTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: DDSColors.textPrimary,
                ),
              ),
              if (currentStep < total - 1)
                Text(
                  'Next: ${stepTitles[currentStep + 1]}',
                  style: DDSTypography.labelSmall.copyWith(
                    color: DDSColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

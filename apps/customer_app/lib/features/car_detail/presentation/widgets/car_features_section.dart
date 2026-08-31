import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

class CarFeaturesSection extends StatelessWidget {
  const CarFeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final inclusions = [
      (
        icon: Icons.event_available_outlined,
        title: 'Free Cancellation',
        subtitle: 'Cancel up to 6 hours before trip start for a 100% full refund',
      ),
      (
        icon: Icons.security_outlined,
        title: 'Comprehensive Insurance',
        subtitle: 'Standard protection package with third-party liability coverage included',
      ),
      (
        icon: Icons.support_agent_outlined,
        title: '24/7 Roadside Assistance',
        subtitle: 'Dedicated emergency and roadside breakdown support across India',
      ),
      (
        icon: Icons.cleaning_services_outlined,
        title: 'Clean & Sanitized',
        subtitle: 'Deep cleaned and rigorously sanitized before vehicle handover',
      ),
    ];

    final policies = [
      (
        title: 'Documents Required',
        desc: 'Original Driving Licence and Aadhaar / Passport required at handover inspection.',
      ),
      (
        title: 'Fuel Policy',
        desc: 'Return the vehicle with the same fuel level as received during initial inspection.',
      ),
      (
        title: 'Refundable Security Deposit',
        desc: 'Zero or minimal deposit. Any held deposit is refunded within 48h after return.',
      ),
      (
        title: 'Age Eligibility',
        desc: 'Primary driver must be at least 21 years old with valid driving licence.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Rental Inclusions ─────────────────────────────────────────────
        Text(
          'What is Included',
          style: DDSTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: DDSColors.textPrimary,
          ),
        ),
        const Gap(12),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DDSSpacing.md,
            vertical: DDSSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: DDSColors.surfaceCard,
            borderRadius: BorderRadius.circular(DDSRadius.medium),
            border: Border.all(color: DDSColors.borderLight),
          ),
          child: Column(
            children: inclusions.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: DDSSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DDSSpacing.xs - 1),
                      decoration: const BoxDecoration(
                        color: DDSColors.infoBlueBg,
                        borderRadius: BorderRadius.all(Radius.circular(DDSRadius.small)),
                      ),
                      child: Icon(
                        item.icon,
                        size: 18,
                        color: DDSColors.primaryBlue,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: DDSTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DDSColors.textPrimary,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            item.subtitle,
                            style: DDSTypography.labelSmall.copyWith(
                              color: DDSColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const Gap(24),

        // ── 2. Rental Guidelines & Policies ──────────────────────────────────
        Text(
          'Rental Policies & Guidelines',
          style: DDSTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: DDSColors.textPrimary,
          ),
        ),
        const Gap(12),
        Container(
          padding: const EdgeInsets.all(DDSSpacing.md),
          decoration: BoxDecoration(
            color: DDSColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(DDSRadius.medium),
            border: Border.all(color: DDSColors.borderLight),
          ),
          child: Column(
            children: policies.map((policy) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: DDSSpacing.xxs + 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: DDSColors.primaryBlue,
                    ),
                    const Gap(10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: DDSTypography.bodyMedium.copyWith(
                            color: DDSColors.textPrimary,
                            height: 1.35,
                          ),
                          children: [
                            TextSpan(
                              text: '${policy.title}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: DDSColors.textPrimary,
                              ),
                            ),
                            TextSpan(text: policy.desc),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

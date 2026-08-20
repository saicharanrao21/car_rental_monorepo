import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

class CarFeaturesSection extends StatelessWidget {
  const CarFeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final inclusions = [
      (
        icon: Icons.event_available_outlined,
        title: 'Free Cancellation',
        subtitle: 'Cancel up to 6 hours before trip start for a full refund',
      ),
      (
        icon: Icons.security_outlined,
        title: 'Comprehensive Insurance',
        subtitle: 'Standard insurance included with third-party liability coverage',
      ),
      (
        icon: Icons.support_agent_outlined,
        title: '24/7 Roadside Assistance',
        subtitle: 'Emergency on-road breakdown support across India',
      ),
      (
        icon: Icons.cleaning_services_outlined,
        title: 'Clean & Sanitized',
        subtitle: 'Thoroughly sanitized and inspected before handover',
      ),
    ];

    final policies = [
      (
        title: 'Documents Required',
        desc: 'Original Driving License and Aadhaar / Passport required at pickup.',
      ),
      (
        title: 'Fuel Policy',
        desc: 'Return the vehicle with the same fuel level as received.',
      ),
      (
        title: 'Refundable Security Deposit',
        desc: 'Zero to minimal deposit. Refunds are credited within 48 hours of return.',
      ),
      (
        title: 'Age Eligibility',
        desc: 'Driver must be at least 21 years old with valid driving experience.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Rental Inclusions ─────────────────────────────────────────────
        const Text(
          'What is Included',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Gap(12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: inclusions.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, size: 18, color: AppColors.primary),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
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
        const Text(
          'Rental Policies & Guidelines',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Gap(12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: policies.map((policy) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, size: 16, color: AppColors.primary),
                    const Gap(10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.3),
                          children: [
                            TextSpan(
                              text: '${policy.title}: ',
                              style: const TextStyle(fontWeight: FontWeight.bold),
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

import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';

/// DriveGo Design System (DDS) — Trust & Assurance Section for Customer Home
class HomeTrustAssuranceWidget extends StatelessWidget {
  const HomeTrustAssuranceWidget({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      _TrustItem(
        icon: Icons.verified_user_rounded,
        iconColor: DDSColors.primaryBlue,
        title: 'Verified Partners',
        subtitle: '100% KYC verified hosts & quality checked fleet',
      ),
      _TrustItem(
        icon: Icons.receipt_long_rounded,
        iconColor: DDSColors.successGreen,
        title: 'Transparent Pricing',
        subtitle: 'Zero hidden fees with clear GST breakdown',
      ),
      _TrustItem(
        icon: Icons.key_rounded,
        iconColor: DDSColors.accentAmber,
        title: 'Digital OTP Handover',
        subtitle: 'Fast vehicle handover with pre-trip inspection',
      ),
      _TrustItem(
        icon: Icons.support_agent_rounded,
        iconColor: DDSColors.electricCobalt,
        title: '24/7 Roadside Help',
        subtitle: 'Dedicated customer support for peace of mind',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DriveGoSectionHeader(title: 'The DriveGo Assurance'),
        const Gap(12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.25,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DDSColors.surfaceCard,
                borderRadius: DDSRadius.mediumBorderRadius,
                border: Border.all(color: DDSColors.borderLight),
                boxShadow: DDSElevation.subtleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.iconColor.withValues(alpha: 0.1),
                      borderRadius: DDSRadius.smallBorderRadius,
                    ),
                    child: Icon(item.icon, size: 20, color: item.iconColor),
                  ),
                  const Gap(8),
                  Text(
                    item.title,
                    style: DDSTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DDSColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(2),
                  Expanded(
                    child: Text(
                      item.subtitle,
                      style: DDSTypography.labelSmall.copyWith(
                        fontSize: 10,
                        color: DDSColors.textMuted,
                        height: 1.3,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TrustItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _TrustItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
}

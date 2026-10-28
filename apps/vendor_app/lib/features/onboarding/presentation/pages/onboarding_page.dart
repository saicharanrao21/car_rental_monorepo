import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDSColors.bgCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(16),
              // Brand Mark
              const Center(
                child: DriveGoBrandMark(
                  size: 72,
                  isVendor: true,
                  showWordmark: true,
                ),
              ),
              const Gap(32),

              Text(
                'Grow Your Fleet Business',
                textAlign: TextAlign.center,
                style: DDSTypography.headlineLarge.copyWith(
                  color: DDSColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(12),
              Text(
                'Manage your vehicles, track reservations in real-time, and scale your rental operations with India’s leading partner network.',
                textAlign: TextAlign.center,
                style: DDSTypography.bodyLarge.copyWith(
                  color: DDSColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const Gap(32),

              // Feature 1
              _buildFeatureCard(
                icon: Icons.hub_rounded,
                iconColor: DDSColors.primaryBlue,
                title: 'Complete Fleet Visibility',
                description: 'Track bookings, monitor vehicle readiness, and control availability across your branch locations.',
              ),
              const Gap(12),

              // Feature 2
              _buildFeatureCard(
                icon: Icons.shield_rounded,
                iconColor: DDSColors.accentTeal,
                title: 'Verified Customer Network',
                description: 'Mandatory Aadhaar and Driving Licence KYC on every trip protects your assets from day one.',
              ),
              const Gap(12),

              // Feature 3
              _buildFeatureCard(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: DDSColors.successGreen,
                title: 'Automated Daily Payouts',
                description: 'Transparent commission structures and guaranteed fast settlements straight into your business account.',
              ),

              const Gap(40),
              DriveGoButton(
                text: 'Partner Sign In',
                onPressed: () {
                  context.go('/auth/phone');
                },
                size: DriveGoButtonSize.large,
              ),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return DriveGoCard(
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: DDSRadius.smallBorderRadius,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DDSTypography.titleMedium.copyWith(
                    color: DDSColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: DDSTypography.bodySmall.copyWith(
                    color: DDSColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

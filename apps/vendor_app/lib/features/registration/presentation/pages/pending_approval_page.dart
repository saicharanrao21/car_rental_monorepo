import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/vendor_session_provider.dart';

class PendingApprovalPage extends ConsumerWidget {
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Icon illustration of review
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_empty,
                    size: 80,
                    color: Colors.amber,
                  ),
                ),
              ),
              const Gap(40),
              const Text(
                'Application Under Review',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(16),
              Text(
                'Our team is currently reviewing your documents. This process usually takes between 24-48 hours. We will notify you as soon as your account is verified.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const Gap(32),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    // Contact Support TODO no-op
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support contact: support@drivepartner.com (TODO)')),
                    );
                  },
                  icon: const Icon(Icons.help_outline, color: AppColors.primary),
                  label: const Text(
                    'Contact Support',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              AppButton(
                text: 'Logout & Exit',
                backgroundColor: Colors.grey[200],
                onPressed: () {
                  ref.read(vendorSessionProvider.notifier).logout();
                  context.go('/auth/phone');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

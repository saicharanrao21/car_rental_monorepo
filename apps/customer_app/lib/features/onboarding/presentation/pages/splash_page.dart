import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import '../../../../core/providers/session_provider.dart';
import '../providers/onboarding_providers.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppStartup();
    });
  }

  Future<void> _checkAppStartup() async {
    final minBrandDuration = Future.delayed(const Duration(milliseconds: 800));

    final sessionNotifier = ref.read(sessionProvider.notifier);
    final onboardingNotifier = ref.read(onboardingProvider.notifier);

    await Future.wait([
      minBrandDuration,
      sessionNotifier.checkSession(),
      onboardingNotifier.checkOnboardingStatus(),
    ]);

    if (!mounted) return;

    final onboardingState = ref.read(onboardingProvider);
    final sessionState = ref.read(sessionProvider);

    if (!onboardingState.hasCompletedOnboarding) {
      context.go('/onboarding');
    } else if (sessionState.isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/auth/phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_car,
                size: 80,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'DriveEase',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Premium Car Rentals',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

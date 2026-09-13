import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/vendor_session_provider.dart';

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
    final sessionNotifier = ref.read(vendorSessionProvider.notifier);

    await Future.wait([
      minBrandDuration,
      sessionNotifier.checkSession(),
    ]);

    if (!mounted) return;

    final sessionState = ref.read(vendorSessionProvider);
    final status = ref.read(vendorApprovalStatusProvider);

    if (sessionState.isAuthenticated) {
      if (status == VendorApprovalStatus.verified) {
        context.go('/dashboard');
      } else {
        context.go('/registration/pending');
      }
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_filled,
              size: 80,
              color: Colors.white,
            ),
            Gap(20),
            Text(
              'DrivePartner',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            Gap(8),
            Text(
              'Grow your rental business',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

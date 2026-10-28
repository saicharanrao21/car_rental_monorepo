import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/vendor_session_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppStartup();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAppStartup() async {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final minBrandDuration = disableAnimations
        ? Future.value()
        : Future.delayed(const Duration(milliseconds: 800));

    final sessionNotifier = ref.read(vendorSessionProvider.notifier);

    try {
      await Future.wait([
        minBrandDuration,
        sessionNotifier.checkSession().catchError((_) {}),
      ]);
    } catch (_) {
      // Continue to unauthenticated destination safely
    }

    if (!mounted || _navigated) return;
    _navigated = true;

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
    return Scaffold(
      backgroundColor: DDSColors.primaryNavy,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const DriveGoBrandMark(
                        size: 96,
                        isVendor: true,
                        showWordmark: false,
                      ),
                      const Gap(24),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Drive',
                            style: DDSTypography.displayLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Go',
                            style: DDSTypography.displayLarge.copyWith(
                              color: DDSColors.primaryBlue,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: DDSColors.accentTeal,
                              borderRadius: DDSRadius.smallBorderRadius,
                            ),
                            child: Text(
                              'PARTNER',
                              style: DDSTypography.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(8),
                      Text(
                        'FLEET & RENTAL OPERATIONS',
                        style: DDSTypography.labelSmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

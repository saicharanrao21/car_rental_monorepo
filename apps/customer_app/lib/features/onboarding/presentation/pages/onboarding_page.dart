import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/onboarding_providers.dart';

class OnboardingSlideData {
  final String title;
  final String subtitle;
  final Widget illustration;

  const OnboardingSlideData({
    required this.title,
    required this.subtitle,
    required this.illustration,
  });
}

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<OnboardingSlideData> _getSlides(BuildContext context) {
    return [
      OnboardingSlideData(
        title: 'Find Your Drive',
        subtitle:
            'Discover curated, high-performance vehicles near you. Real-time GPS discovery and upfront transparent pricing.',
        illustration: _buildCarIllustration(),
      ),
      OnboardingSlideData(
        title: 'Book With Confidence',
        subtitle:
            'Rent with total peace of mind. Every drive includes comprehensive insurance, zero hidden deposits, and 24/7 roadside assistance.',
        illustration: _buildSecurityIllustration(),
      ),
      OnboardingSlideData(
        title: 'Ready When You Are',
        subtitle:
            'Choose contactless hub pickup or doorstep delivery. Unlock your journey seamlessly right from your phone.',
        illustration: _buildReadyIllustration(),
      ),
    ];
  }

  Widget _buildCarIllustration() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: DDSColors.primaryBlue.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              color: DDSColors.primaryBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DriveGoBrandMark(size: 72, showWordmark: false),
              Gap(12),
              Icon(
                Icons.directions_car_filled_rounded,
                size: 54,
                color: DDSColors.primaryBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityIllustration() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: DDSColors.successGreen.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              color: DDSColors.successGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_rounded,
                size: 72,
                color: DDSColors.successGreen,
              ),
              Gap(10),
              Icon(
                Icons.health_and_safety_rounded,
                size: 38,
                color: DDSColors.primaryNavy,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadyIllustration() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: DDSColors.accentAmber.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              color: DDSColors.accentAmber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.key_rounded,
                size: 64,
                color: DDSColors.accentAmber,
              ),
              Gap(10),
              Icon(
                Icons.location_on_rounded,
                size: 42,
                color: DDSColors.primaryBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onNext(int slideCount) async {
    if (_currentIndex < slideCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      await ref.read(onboardingProvider.notifier).completeOnboarding();
      if (mounted) {
        context.go('/auth/phone');
      }
    }
  }

  Future<void> _onSkip() async {
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go('/auth/phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = _getSlides(context);

    return Scaffold(
      backgroundColor: DDSColors.bgCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_currentIndex < slides.length - 1)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _onSkip,
                child: Text(
                  'Skip',
                  style: DDSTypography.labelLarge.copyWith(
                    color: DDSColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: slides.length,
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          slide.illustration,
                          const Gap(48),
                          Text(
                            slide.title,
                            style: DDSTypography.headlineLarge.copyWith(
                              color: DDSColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Gap(16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              slide.subtitle,
                              style: DDSTypography.bodyLarge.copyWith(
                                color: DDSColors.textSecondary,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Dynamic Segmented Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slides.length, (index) {
                  final isActive = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? DDSColors.primaryBlue : DDSColors.borderMedium,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const Gap(36),
              DriveGoButton(
                text: _currentIndex == slides.length - 1 ? 'Get Started' : 'Continue',
                onPressed: () => _onNext(slides.length),
                size: DriveGoButtonSize.large,
              ),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }
}

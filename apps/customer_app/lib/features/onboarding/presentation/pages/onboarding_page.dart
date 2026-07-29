import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

class OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;

  const OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final List<OnboardingSlide> _slides = const [
    OnboardingSlide(
      icon: Icons.search_outlined,
      title: 'Find Your Perfect Car',
      description: 'Choose from our curated fleet of high-quality premium cars available in your city.',
    ),
    OnboardingSlide(
      icon: Icons.speed,
      title: 'Book Instantly',
      description: 'Experience seamless bookings with zero paperwork, transparent pricing, and instant confirmation.',
    ),
    OnboardingSlide(
      icon: Icons.verified_user_outlined,
      title: 'Trusted Partners',
      description: 'Rent with peace of mind from our fully verified local vendors ensuring top safety standards.',
    ),
  ];

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

  void _onNext() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/auth/phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_currentIndex < _slides.length - 1)
            TextButton(
              onPressed: () => context.go('/auth/phone'),
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
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
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            slide.icon,
                            size: 100,
                            color: AppColors.primary,
                          ),
                        ),
                        const Gap(40),
                        Text(
                          slide.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Gap(16),
                        Text(
                          slide.description,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (index) {
                  final isActive = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const Gap(40),
              AppButton(
                text: _currentIndex == _slides.length - 1 ? 'Get Started' : 'Next',
                onPressed: _onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

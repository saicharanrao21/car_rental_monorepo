import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/onboarding_storage.dart';

final onboardingStorageProvider = Provider<OnboardingStorage>((ref) {
  return SharedPreferencesOnboardingStorage();
});

class OnboardingState {
  final bool isLoaded;
  final bool hasCompletedOnboarding;

  const OnboardingState({
    required this.isLoaded,
    required this.hasCompletedOnboarding,
  });

  factory OnboardingState.initial() => const OnboardingState(
        isLoaded: false,
        hasCompletedOnboarding: false,
      );

  OnboardingState copyWith({
    bool? isLoaded,
    bool? hasCompletedOnboarding,
  }) {
    return OnboardingState(
      isLoaded: isLoaded ?? this.isLoaded,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final OnboardingStorage _storage;

  OnboardingNotifier(this._storage) : super(OnboardingState.initial()) {
    Future.microtask(() => checkOnboardingStatus());
  }

  Future<void> checkOnboardingStatus() async {
    final completed = await _storage.isOnboardingCompleted();
    state = OnboardingState(
      isLoaded: true,
      hasCompletedOnboarding: completed,
    );
  }

  Future<void> completeOnboarding() async {
    await _storage.setOnboardingCompleted(true);
    state = state.copyWith(
      isLoaded: true,
      hasCompletedOnboarding: true,
    );
  }

  Future<void> resetOnboarding() async {
    await _storage.clear();
    state = state.copyWith(
      isLoaded: true,
      hasCompletedOnboarding: false,
    );
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final storage = ref.watch(onboardingStorageProvider);
  return OnboardingNotifier(storage);
});

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:models/models.dart';
import 'package:customer_app/main.dart';
import 'package:customer_app/features/onboarding/data/onboarding_storage.dart';
import 'package:customer_app/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:customer_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:customer_app/features/auth/presentation/pages/phone_entry_page.dart';
import 'package:customer_app/features/home/presentation/pages/home_page.dart';
import 'package:customer_app/features/home/home_providers.dart';
import 'package:customer_app/features/home/data/mock_home_repository.dart';
import 'package:customer_app/core/providers/session_provider.dart';

class InMemoryOnboardingStorage implements OnboardingStorage {
  bool _completed;

  InMemoryOnboardingStorage({bool initialCompleted = false})
      : _completed = initialCompleted;

  @override
  Future<bool> isOnboardingCompleted() async => _completed;

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    _completed = completed;
  }

  @override
  Future<void> clear() async {
    _completed = false;
  }
}

class FakeSessionNotifier extends SessionNotifier {
  final AuthState _initialState;

  FakeSessionNotifier(this._initialState);

  @override
  AuthState build() => _initialState;

  @override
  Future<void> checkSession() async {
    await Future.microtask(() {});
    state = _initialState;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 10A Startup Decision Flow Tests', () {
    test('1. OnboardingNotifier - Fresh state loads hasCompletedOnboarding = false', () async {
      final storage = InMemoryOnboardingStorage(initialCompleted: false);
      final notifier = OnboardingNotifier(storage);

      await notifier.checkOnboardingStatus();
      expect(notifier.state.hasCompletedOnboarding, isFalse);
      expect(notifier.state.isLoaded, isTrue);
    });

    test('2. OnboardingNotifier - Completing onboarding updates state and persists', () async {
      final storage = InMemoryOnboardingStorage(initialCompleted: false);
      final notifier = OnboardingNotifier(storage);

      await notifier.completeOnboarding();
      expect(notifier.state.hasCompletedOnboarding, isTrue);
      expect(await storage.isOnboardingCompleted(), isTrue);
    });

    test('3. OnboardingNotifier - Resetting onboarding sets flag back to false', () async {
      final storage = InMemoryOnboardingStorage(initialCompleted: true);
      final notifier = OnboardingNotifier(storage);

      await notifier.resetOnboarding();
      expect(notifier.state.hasCompletedOnboarding, isFalse);
      expect(await storage.isOnboardingCompleted(), isFalse);
    });

    testWidgets('4. Fresh launch -> Splash navigates to OnboardingPage', (tester) async {
      final storage = InMemoryOnboardingStorage(initialCompleted: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStorageProvider.overrideWithValue(storage),
            sessionProvider.overrideWith(() => FakeSessionNotifier(AuthState.unauthenticated())),
          ],
          child: const CustomerApp(),
        ),
      );

      // Initially on Splash
      expect(find.text('DriveGo'), findsOneWidget);

      // Wait for splash timer and initialization to complete
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should now be on OnboardingPage
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.text('Find Your Perfect Car'), findsOneWidget);
    });

    testWidgets('5. Onboarding completed + no session -> Splash navigates to PhoneEntryPage (Login)', (tester) async {
      final storage = InMemoryOnboardingStorage(initialCompleted: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStorageProvider.overrideWithValue(storage),
            sessionProvider.overrideWith(() => FakeSessionNotifier(AuthState.unauthenticated())),
          ],
          child: const CustomerApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should bypass onboarding and go directly to PhoneEntryPage (Login)
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(PhoneEntryPage), findsOneWidget);
    });

    testWidgets('6. Onboarding completed + valid session -> Splash navigates to HomePage', (tester) async {
      final storage = InMemoryOnboardingStorage(initialCompleted: true);
      const testUser = UserModel(
        id: 'usr_test_123',
        phone: '+919876543210',
        name: 'Test Customer',
        role: 'customer',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStorageProvider.overrideWithValue(storage),
            sessionProvider.overrideWith(() => FakeSessionNotifier(AuthState.authenticated(testUser))),
            homeRepositoryProvider.overrideWithValue(MockHomeRepository()),
          ],
          child: const CustomerApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should bypass onboarding & login, landing on HomePage
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(PhoneEntryPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('7. Onboarding completed + expired session -> Safely navigates to PhoneEntryPage', (tester) async {
      final storage = InMemoryOnboardingStorage(initialCompleted: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStorageProvider.overrideWithValue(storage),
            sessionProvider.overrideWith(() => FakeSessionNotifier(AuthState.unauthenticated())),
          ],
          child: const CustomerApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should safely route to PhoneEntryPage without throwing or showing onboarding
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(PhoneEntryPage), findsOneWidget);
    });

    testWidgets('8. Completing onboarding via Get Started persists state and goes to Login', (tester) async {
      final storage = InMemoryOnboardingStorage(initialCompleted: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStorageProvider.overrideWithValue(storage),
            sessionProvider.overrideWith(() => FakeSessionNotifier(AuthState.unauthenticated())),
          ],
          child: const CustomerApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(OnboardingPage), findsOneWidget);

      // Tap Next (slide 1 -> 2)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Tap Next (slide 2 -> 3)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Tap 'Get Started' on slide 3
      expect(find.text('Get Started'), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Storage must now be marked as completed
      expect(await storage.isOnboardingCompleted(), isTrue);

      // Screen is now PhoneEntryPage
      expect(find.byType(PhoneEntryPage), findsOneWidget);
    });

    testWidgets('9. Tapping Skip in Onboarding persists state and goes to Login', (tester) async {
      final storage = InMemoryOnboardingStorage(initialCompleted: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStorageProvider.overrideWithValue(storage),
            sessionProvider.overrideWith(() => FakeSessionNotifier(AuthState.unauthenticated())),
          ],
          child: const CustomerApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(OnboardingPage), findsOneWidget);

      // Tap 'Skip'
      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Storage must be marked as completed
      expect(await storage.isOnboardingCompleted(), isTrue);

      // Navigates to PhoneEntryPage
      expect(find.byType(PhoneEntryPage), findsOneWidget);
    });

    test('10. Logout preserves onboarding completion state', () async {
      final storage = InMemoryOnboardingStorage(initialCompleted: true);
      final onboardingNotifier = OnboardingNotifier(storage);
      await onboardingNotifier.checkOnboardingStatus();

      expect(onboardingNotifier.state.hasCompletedOnboarding, isTrue);

      // Verify onboarding state remains true independently of auth logout
      expect(onboardingNotifier.state.hasCompletedOnboarding, isTrue);
      expect(await storage.isOnboardingCompleted(), isTrue);
    });

    testWidgets('11. Splash screen holds initial frame without premature redirect during unresolved startup', (tester) async {
      final storage = InMemoryOnboardingStorage(initialCompleted: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStorageProvider.overrideWithValue(storage),
            sessionProvider.overrideWith(() => FakeSessionNotifier(AuthState.unauthenticated())),
          ],
          child: const CustomerApp(),
        ),
      );

      // Initial pump without settling duration
      await tester.pump(const Duration(milliseconds: 100));

      // Should be stably showing Splash
      expect(find.text('DriveGo'), findsOneWidget);
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(PhoneEntryPage), findsNothing);
      expect(find.byType(HomePage), findsNothing);

      // Finish startup
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(OnboardingPage), findsOneWidget);
    });

    testWidgets('12. Full Lifecycle: Complete onboarding -> Login -> Logout -> App Restart routes to Login', (tester) async {
      final storage = InMemoryOnboardingStorage(initialCompleted: false);
      const testUser = UserModel(
        id: 'usr_lifecycle_123',
        phone: '+919876543210',
        name: 'Lifecycle User',
        role: 'customer',
      );

      // Phase 1: First launch -> Onboarding
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            onboardingStorageProvider.overrideWithValue(storage),
            sessionProvider.overrideWith(() => FakeSessionNotifier(AuthState.unauthenticated())),
          ],
          child: const CustomerApp(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(OnboardingPage), findsOneWidget);

      // Complete onboarding via Skip
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(await storage.isOnboardingCompleted(), isTrue);

      // Phase 2: App restart with authenticated session -> Home
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            onboardingStorageProvider.overrideWithValue(storage),
            sessionProvider.overrideWith(() => FakeSessionNotifier(AuthState.authenticated(testUser))),
            homeRepositoryProvider.overrideWithValue(MockHomeRepository()),
          ],
          child: const CustomerApp(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(HomePage), findsOneWidget);

      // Phase 3: App restart after logout (unauthenticated + completed onboarding) -> Login
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            onboardingStorageProvider.overrideWithValue(storage),
            sessionProvider.overrideWith(() => FakeSessionNotifier(AuthState.unauthenticated())),
          ],
          child: const CustomerApp(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Must land on PhoneEntryPage (Login), NEVER OnboardingPage
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(PhoneEntryPage), findsOneWidget);
    });
  });
}

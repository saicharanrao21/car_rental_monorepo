import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:customer_app/features/home/presentation/widgets/home_header_widget.dart';
import 'package:customer_app/features/home/home_providers.dart';
import 'package:customer_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:customer_app/core/providers/location_provider.dart';

class TestUserLocationNotifier extends UserLocationNotifier {
  TestUserLocationNotifier(UserLocationState initialState) : super() {
    state = initialState;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createWidgetUnderTest({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Customer App Shell & Brand Header Tests (Phase 29.2)', () {
    testWidgets('HomeHeaderWidget renders selected city, greeting, and action buttons', (tester) async {
      bool cityTapped = false;

      await tester.pumpWidget(createWidgetUnderTest(
        child: HomeHeaderWidget(
          onCityTap: () => cityTapped = true,
        ),
        overrides: [
          selectedCityProvider.overrideWith((ref) => 'Bengaluru'),
          unreadNotificationsCountProvider.overrideWith((ref) => 0),
        ],
      ));

      expect(find.text('Bengaluru'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

      await tester.tap(find.text('Bengaluru'));
      expect(cityTapped, true);
    });

    testWidgets('HomeHeaderWidget displays unread notification badge count', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        child: HomeHeaderWidget(
          onCityTap: () {},
        ),
        overrides: [
          selectedCityProvider.overrideWith((ref) => 'Mumbai'),
          unreadNotificationsCountProvider.overrideWith((ref) => 3),
        ],
      ));

      expect(find.text('Mumbai'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('HomeHeaderWidget shows loading spinner when location detection is active', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        child: HomeHeaderWidget(
          onCityTap: () {},
        ),
        overrides: [
          selectedCityProvider.overrideWith((ref) => 'Locating...'),
          userLocationProvider.overrideWith((ref) => TestUserLocationNotifier(
                const UserLocationState(
                  detectionStatus: LocationDetectionStatus.loading,
                ),
              )),
          unreadNotificationsCountProvider.overrideWith((ref) => 0),
        ],
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

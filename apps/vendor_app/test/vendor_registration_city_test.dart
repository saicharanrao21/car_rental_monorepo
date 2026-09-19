import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/core/providers/supported_cities_provider.dart';
import 'package:vendor_app/features/registration/presentation/pages/registration_stepper_page.dart';
import 'package:vendor_app/features/registration/presentation/providers/registration_providers.dart';

class MockStepNotifier extends RegistrationStepNotifier {
  MockStepNotifier() {
    state = 1; // Step 2 (0-indexed: 1)
  }
}

void main() {
  testWidgets('RegistrationStepperPage Step 2 dynamically renders platform supported city Karimnagar', (tester) async {
    const mockCities = [
      SupportedCityModel(
        id: 'city-1',
        name: 'karimnagar',
        state: 'Telangana',
        latitude: 18.2623,
        longitude: 79.074,
        isActive: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorSupportedCitiesProvider.overrideWith((ref) async => mockCities),
          registrationStepProvider.overrideWith((ref) => MockStepNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RegistrationStepperPage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Business Details step is shown
    expect(find.text('Business Details'), findsOneWidget);
    expect(find.text('Operating City'), findsOneWidget);

    // Verify Karimnagar is dynamically loaded and displayed (capitalized)
    expect(find.text('Karimnagar'), findsOneWidget);

    // Verify old hardcoded cities are NOT in the dropdown
    expect(find.text('Mumbai'), findsNothing);
    expect(find.text('Delhi'), findsNothing);
    expect(find.text('Bangalore'), findsNothing);
  });
}

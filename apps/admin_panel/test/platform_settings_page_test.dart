import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_panel/features/settings/presentation/pages/platform_settings_page.dart';
import 'package:admin_panel/features/settings/presentation/providers/settings_providers.dart';
import 'package:admin_panel/features/settings/domain/repositories/platform_settings_repository.dart';

class MockPlatformSettingsRepository implements PlatformSettingsRepository {
  PlatformSettings current = const PlatformSettings(
    platformName: 'DriveGo India',
    gstNumber: '29AAAAA0000A1Z5',
    supportEmail: 'support@drivego.in',
    supportPhone: '+919876543210',
    appVersion: '1.2.0',
    enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
  );

  bool updateCalled = false;
  PlatformSettings? lastUpdated;

  @override
  Future<PlatformSettings> getSettings() async {
    return current;
  }

  @override
  Future<void> updateSettings(PlatformSettings settings) async {
    updateCalled = true;
    lastUpdated = settings;
    current = settings;
  }
}

void main() {
  testWidgets('PlatformSettingsPage renders form fields with platform settings', (tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mockRepo = MockPlatformSettingsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformSettingsRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: PlatformSettingsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('System Settings'), findsOneWidget);
    expect(find.textContaining('Configure drivego platform core configurations'), findsOneWidget);

    // Verify Form Fields
    expect(find.widgetWithText(TextFormField, 'DriveGo India'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '29AAAAA0000A1Z5'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'support@drivego.in'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '+919876543210'), findsOneWidget);

    // Verify Save Button
    expect(find.text('Save Platform Settings'), findsOneWidget);
  });

  testWidgets('PlatformSettingsPage updates settings on Save click', (tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mockRepo = MockPlatformSettingsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformSettingsRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: PlatformSettingsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Update Platform Name field
    final nameField = find.widgetWithText(TextFormField, 'DriveGo India');
    await tester.enterText(nameField, 'DriveGo Mobility');
    await tester.pumpAndSettle();

    // Tap Save Settings
    final saveButton = find.text('Save Platform Settings');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(mockRepo.updateCalled, isTrue);
    expect(mockRepo.lastUpdated?.platformName, 'DriveGo Mobility');
    expect(find.text('Settings saved successfully!'), findsOneWidget);
  });
}

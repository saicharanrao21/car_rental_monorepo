import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  testWidgets('LocationPreviewCard renders address, map pin, coordinates and ETA', (tester) async {
    bool navigated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationPreviewCard(
            title: 'Vehicle Pickup Hub',
            address: 'Hitec City Main Road, Hyderabad',
            latitude: 17.4483,
            longitude: 78.3915,
            distanceText: '12.4 km',
            etaText: '25 mins',
            onNavigate: () {
              navigated = true;
            },
          ),
        ),
      ),
    );

    // Verify Title and Address
    expect(find.text('Vehicle Pickup Hub'), findsOneWidget);
    expect(find.text('Hitec City Main Road, Hyderabad'), findsOneWidget);

    // Verify Distance & ETA Badges
    expect(find.text('12.4 km'), findsOneWidget);
    expect(find.text('25 mins'), findsOneWidget);

    // Verify GPS coordinates display
    expect(find.text('17.448, 78.391'), findsOneWidget);
    expect(find.text('GPS Verified'), findsOneWidget);

    // Tap Navigate
    await tester.tap(find.text('Open in Maps'));
    await tester.pump();
    expect(navigated, true);
  });
}

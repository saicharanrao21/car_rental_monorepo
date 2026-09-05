import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:vendor_app/features/fleet/presentation/pages/add_edit_car_page.dart';

final evidenceDir = Directory(r'd:\Flutter\car_rental_monorepo\docs\evidence\phase35');

Future<void> saveScreenshot(WidgetTester tester, GlobalKey key, String filename) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(() async {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is RenderRepaintBoundary) {
      final image = await renderObject.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('${evidenceDir.path}/$filename');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      // ignore: avoid_print
      print('[PHASE_35_EVIDENCE] Saved ${file.path} (${file.lengthSync()} bytes)');
    }
  });
}

void main() {
  setUpAll(() async {
    DDSTypography.useSystemFallbackInTests = true;
    if (!evidenceDir.existsSync()) {
      evidenceDir.createSync(recursive: true);
    }
  });

  group('Phase 35 Vendor Evidence Capture Suite', () {
    testWidgets('03_vendor_pricing_server_authoritative.png', (tester) async {
      tester.view.physicalSize = const Size(420 * 2, 900 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: const Color(0xFF0F172A),
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF38BDF8),
                surface: Color(0xFF1E293B),
              ),
            ),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: Container(
                    width: 420,
                    height: 880,
                    color: const Color(0xFF0F172A),
                    child: const AddEditCarPage(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nextButton = find.text('Continue');
      expect(nextButton, findsOneWidget);

      final step0Fields = find.byType(TextField);
      await tester.enterText(step0Fields.at(0), 'Hyundai');
      await tester.enterText(step0Fields.at(1), 'Creta');
      await tester.enterText(step0Fields.at(3), 'MH02AB1234');

      await tester.tap(nextButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(nextButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Commercial Rates & Pricing'), findsOneWidget);
      expect(find.text('Server-Authoritative Pricing Active'), findsOneWidget);

      await saveScreenshot(tester, key, '03_vendor_pricing_server_authoritative.png');
    });
  });
}

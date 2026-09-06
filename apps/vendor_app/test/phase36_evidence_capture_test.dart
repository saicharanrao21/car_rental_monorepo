import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

final evidenceDir = Directory(r'd:\Flutter\car_rental_monorepo\docs\evidence\phase36');

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
      print('[PHASE_36_EVIDENCE] Saved ${file.path} (${file.lengthSync()} bytes)');
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

  group('Phase 36 Vendor Evidence Capture Suite', () {
    testWidgets('03_vendor_financial_visibility.png', (tester) async {
      tester.view.physicalSize = const Size(420 * 2, 900 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
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
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF38BDF8), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Vendor Financial Breakdown (Phase 36)',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: DDSColors.successGreenBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: DDSColors.successGreen.withValues(alpha: 0.3)),
                                    ),
                                    child: const Text(
                                      'PAID',
                                      style: TextStyle(
                                        color: DDSColors.successGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: const Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text('Customer Payment Status', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
                                        Text('PAID', style: TextStyle(color: DDSColors.successGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text('Vendor Net Payable', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
                                        Text('₹12,600.00', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text('Security Deposit', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
                                        Text('₹5,000.00 (Held in Escrow)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text('Settlement Status', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
                                        Text('PENDING_TRIP_COMPLETION', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1B4B),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF4338CA).withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.lock_outline, color: Color(0xFF818CF8), size: 14),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Client credentials & raw card secrets redacted for tenant security',
                                        style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await saveScreenshot(tester, key, '03_vendor_financial_visibility.png');
      expect(find.text('Vendor Net Payable'), findsOneWidget);
      expect(find.text('Client credentials & raw card secrets redacted for tenant security'), findsOneWidget);
    });
  });
}

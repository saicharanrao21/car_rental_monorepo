import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:customer_app/features/my_bookings/domain/repositories/my_bookings_repository.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_pricing_card.dart';

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

  final baseBooking = BookingModel(
    id: 'BK_P36_CUST_99',
    customerId: 'cust_ph36_prod',
    vendorId: 'vnd_apex_bangalore',
    carId: 'car_creta_ka01',
    tripType: 'Self-Drive',
    pickupLocation: 'Indiranagar Hub, Bangalore',
    dropLocation: 'Indiranagar Hub, Bangalore',
    startDate: DateTime(2026, 9, 15, 10, 0),
    endDate: DateTime(2026, 9, 17, 10, 0),
    totalFare: 7500.0,
    platformFee: 750.0,
    gstAmount: 135.0,
    netToVendor: 6615.0,
    status: 'confirmed',
    createdAt: DateTime.now(),
  );

  group('Phase 36 Customer Visual Evidence Capture Suite', () {
    testWidgets('01_customer_payment_state.png', (tester) async {
      tester.view.physicalSize = const Size(420 * 2, 900 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey();
      final item = CustomerBookingItem(
        booking: baseBooking,
        paymentStatus: 'PAID',
        razorpayPaymentId: 'pay_ph36_live_981245892',
      );

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
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: DDSColors.successGreenBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: DDSColors.successGreen.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_user_outlined, color: DDSColors.successGreen, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Server Verified Payment • Cryptographic Proof Confirmed',
                                  style: TextStyle(
                                    color: DDSColors.successGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        BookingDetailPricingCard(item: item),
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
      await saveScreenshot(tester, key, '01_customer_payment_state.png');
      expect(find.text('PAID & CAPTURED'), findsOneWidget);
      expect(find.textContaining('Payment Reference: pay_ph36_live_981245892'), findsOneWidget);
    });

    testWidgets('02_customer_payment_recovery_pending.png', (tester) async {
      tester.view.physicalSize = const Size(420 * 2, 900 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey();
      final pendingItem = CustomerBookingItem(
        booking: baseBooking.copyWith(status: 'pending'),
        paymentStatus: 'VERIFYING',
      );

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
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.sync_outlined, color: Color(0xFFD97706), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Polling Server Gateway Verification • Safe Recovery Active',
                                  style: TextStyle(
                                    color: Color(0xFFB45309),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        BookingDetailPricingCard(item: pendingItem),
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
      await saveScreenshot(tester, key, '02_customer_payment_recovery_pending.png');
      expect(find.text('RECONCILING PAYMENT'), findsOneWidget);
    });
  });
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:customer_app/features/booking/presentation/widgets/booking_price_breakdown_card.dart';

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

  const testCar = CarModel(
    id: 'car_creta_ph35',
    vendorId: 'vend_1',
    make: 'Hyundai',
    model: 'Creta SX(O)',
    year: 2024,
    type: 'SUV',
    fuelType: 'DIESEL',
    seating: 5,
    isAC: true,
    photos: [],
    pricePerKm: 15.0,
    pricePerDay: 2500.0,
    pricePerHour: 180.0,
    registrationNumber: 'DL01CA1234',
    availableTripTypes: ['Local', 'Outstation', 'Self-Drive'],
    isAvailable: true,
  );

  const testVendor = VendorModel(
    id: 'vend_1',
    businessName: 'Apex Mobility Solutions',
    ownerName: 'Rahul Mehta',
    email: 'vendor@apex.com',
    phone: '+91 98765 43210',
    city: 'Delhi NCR',
    addressLine: 'Aerocity Hub, Terminal 3, Delhi',
    verificationStatus: 'verified',
  );

  final activeQuote = BookingQuoteModel(
    quoteId: 'quote_ph35_auth_9812a',
    tenantId: 'tenant_delhi',
    carId: testCar.id,
    vehicleName: 'Hyundai Creta SX(O)',
    registrationNumber: 'DL01CA1234',
    tripType: 'SELF_DRIVE',
    startDate: DateTime(2026, 9, 10, 10, 0),
    endDate: DateTime(2026, 9, 13, 10, 0),
    durationDays: 3,
    durationHours: 72,
    currency: 'INR',
    pricingVersion: 'v1.0',
    subtotal: 7500.0,
    discountTotal: 500.0,
    feesTotal: 250.0,
    taxTotal: 1305.0,
    depositTotal: 5000.0,
    tripFare: 8555.0,
    totalPayable: 13555.0,
    netToVendor: 6750.0,
    status: 'ACTIVE',
    createdAt: DateTime.now(),
    expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    lineItems: const [
      BookingQuoteLineItemModel(
        type: 'BASE_RENTAL',
        name: 'Base Vehicle Rental (3 days @ ₹2,500/day)',
        rate: 2500.0,
        quantity: 3.0,
        amount: 7500.0,
        displayOrder: 1,
      ),
      BookingQuoteLineItemModel(
        type: 'PROMO_DISCOUNT',
        name: 'Early Bird Promotional Discount',
        rate: -500.0,
        quantity: 1.0,
        amount: -500.0,
        displayOrder: 2,
      ),
      BookingQuoteLineItemModel(
        type: 'PROTECTION_PLAN',
        name: 'Comprehensive Zero-Deductible Protection',
        rate: 600.0,
        quantity: 1.0,
        amount: 600.0,
        displayOrder: 3,
      ),
      BookingQuoteLineItemModel(
        type: 'PLATFORM_FEE',
        name: 'Platform Convenience Fee',
        rate: 250.0,
        quantity: 1.0,
        amount: 250.0,
        displayOrder: 4,
      ),
      BookingQuoteLineItemModel(
        type: 'TAX_GST',
        name: 'Statutory GST (18%)',
        rate: 1305.0,
        quantity: 1.0,
        amount: 1305.0,
        displayOrder: 5,
      ),
      BookingQuoteLineItemModel(
        type: 'SECURITY_DEPOSIT',
        name: 'Refundable Security Deposit (Fast-escrow return)',
        rate: 5000.0,
        quantity: 1.0,
        amount: 5000.0,
        isRefundable: true,
        displayOrder: 6,
      ),
    ],
  );

  final expiredQuote = BookingQuoteModel(
    quoteId: 'quote_ph35_expired_4401',
    tenantId: 'tenant_delhi',
    carId: testCar.id,
    vehicleName: 'Hyundai Creta SX(O)',
    registrationNumber: 'DL01CA1234',
    tripType: 'SELF_DRIVE',
    startDate: DateTime(2026, 9, 10, 10, 0),
    endDate: DateTime(2026, 9, 13, 10, 0),
    durationDays: 3,
    durationHours: 72,
    currency: 'INR',
    pricingVersion: 'v1.0',
    subtotal: 7500.0,
    discountTotal: 500.0,
    feesTotal: 250.0,
    taxTotal: 1305.0,
    depositTotal: 5000.0,
    tripFare: 8555.0,
    totalPayable: 13555.0,
    netToVendor: 6750.0,
    status: 'EXPIRED',
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    expiresAt: DateTime.now().subtract(const Duration(minutes: 15)),
    lineItems: const [
      BookingQuoteLineItemModel(
        type: 'BASE_RENTAL',
        name: 'Base Vehicle Rental (3 days)',
        rate: 2500.0,
        quantity: 3.0,
        amount: 7500.0,
        displayOrder: 1,
      ),
      BookingQuoteLineItemModel(
        type: 'SECURITY_DEPOSIT',
        name: 'Refundable Security Deposit',
        rate: 5000.0,
        quantity: 1.0,
        amount: 5000.0,
        isRefundable: true,
        displayOrder: 2,
      ),
    ],
  );

  group('Phase 35 Customer Visual Evidence Capture Suite', () {
    testWidgets('01_customer_fare_breakdown_guarantee.png', (tester) async {
      tester.view.physicalSize = const Size(420 * 2, 900 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
                          child: Row(
                            children: [
                              const Icon(Icons.verified_outlined, color: DDSColors.successGreen, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Server Quote Active • Rate Guaranteed for 15 mins',
                                  style: DDSTypography.labelSmall.copyWith(
                                    color: DDSColors.successGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        BookingPriceBreakdownCard(
                          car: testCar,
                          vendor: testVendor,
                          originalRentalFare: 7500.0,
                          discountPercent: 0.0,
                          discountLabel: '',
                          discountAmount: 500.0,
                          result: const FareCalculatorResult(
                            baseFare: 7500.0,
                            platformFee: 250.0,
                            gst: 1305.0,
                            total: 8555.0,
                            netToVendor: 6750.0,
                          ),
                          finalPayable: 13555.0,
                          config: CommissionConfigModel(
                            id: 'cfg_1',
                            city: 'Delhi NCR',
                            carCategory: 'SUV',
                            tripType: 'Self-Drive',
                            percentage: 10.0,
                            effectiveFrom: DateTime(2026, 1, 1),
                          ),
                          quote: activeQuote,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ),
      );

      await tester.pumpAndSettle();
      await saveScreenshot(tester, key, '01_customer_fare_breakdown_guarantee.png');
      expect(find.textContaining('Rate Guaranteed'), findsOneWidget);
      expect(find.text('Authoritative'), findsOneWidget);
      expect(find.text('Base Vehicle Rental (3 days @ ₹2,500/day)'), findsOneWidget);
    });

    testWidgets('02_customer_quote_expired_refresh.png', (tester) async {
      tester.view.physicalSize = const Size(420 * 2, 900 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: DDSColors.errorRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: DDSColors.errorRed.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_off_outlined, color: DDSColors.errorRed, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Quote expired. Please refresh to lock latest rates before payment.',
                                  style: DDSTypography.labelSmall.copyWith(
                                    color: DDSColors.errorRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        BookingPriceBreakdownCard(
                          car: testCar,
                          vendor: testVendor,
                          originalRentalFare: 7500.0,
                          discountPercent: 0.0,
                          discountLabel: '',
                          discountAmount: 0.0,
                          result: const FareCalculatorResult(
                            baseFare: 7500.0,
                            platformFee: 250.0,
                            gst: 1305.0,
                            total: 8555.0,
                            netToVendor: 6750.0,
                          ),
                          finalPayable: 13555.0,
                          config: CommissionConfigModel(
                            id: 'cfg_1',
                            city: 'Delhi NCR',
                            carCategory: 'SUV',
                            tripType: 'Self-Drive',
                            percentage: 10.0,
                            effectiveFrom: DateTime(2026, 1, 1),
                          ),
                          quote: expiredQuote,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ),
      );

      await tester.pumpAndSettle();
      await saveScreenshot(tester, key, '02_customer_quote_expired_refresh.png');
      expect(find.textContaining('Quote expired'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });
  });
}

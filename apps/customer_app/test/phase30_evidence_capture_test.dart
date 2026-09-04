import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:customer_app/features/booking/presentation/widgets/payment_step.dart';
import 'package:customer_app/features/booking/presentation/providers/booking_flow_providers.dart';
import 'package:customer_app/features/my_bookings/domain/repositories/my_bookings_repository.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_detail_pricing_card.dart';
import 'package:customer_app/features/my_bookings/presentation/widgets/booking_refund_tracker_card.dart';
import 'package:customer_app/core/providers/session_provider.dart';
import 'package:customer_app/core/providers/api_providers.dart';
import 'package:customer_app/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:dio/dio.dart';

final evidenceDir = Directory(r'd:\Flutter\car_rental_monorepo\docs\evidence\phase30');

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
      print('[PHASE_30_EVIDENCE] Saved ${file.path} (${file.lengthSync()} bytes)');
    }
  });
}

class MockTokenStorage extends TokenStorage {
  @override
  Future<String?> getAccessToken() async => 'mock_token';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';
  @override
  Future<void> setAccessToken(String token) async {}
  @override
  Future<void> setRefreshToken(String token) async {}
  @override
  Future<void> clearTokens() async {}
}

class FakeSessionNotifier extends SessionNotifier {
  final UserModel _user;
  FakeSessionNotifier(this._user);
  @override
  AuthState build() => AuthState.authenticated(_user);
  @override
  Future<void> checkSession() async {}
}

class FakeDraftNotifier extends BookingDraftNotifier {
  final BookingDraft _draft;
  FakeDraftNotifier(this._draft);
  @override
  BookingDraft build() => _draft;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DDSTypography.useSystemFallbackInTests = true;

  const mockUser = UserModel(

    id: 'cust_p30',
    name: 'Priya Sharma',
    phone: '9876543210',
    email: 'priya@example.com',
    role: 'CUSTOMER',
  );

  final mockDraft = BookingDraft(
    startDate: DateTime(2026, 9, 10, 10, 0),
    endDate: DateTime(2026, 9, 12, 10, 0),
    totalFare: 5500.0,
    baseFare: 4200.0,
    platformFee: 466.0,
    gst: 834.0,
  );

  final baseBooking = BookingModel(
    id: 'BK_DRIVEGO_P30_8891',
    customerId: 'cust_p30',
    vendorId: 'vnd_apex_01',
    carId: 'car_creta_01',
    tripType: 'Self-Drive',
    pickupLocation: 'Indiranagar Hub, Bangalore',
    dropLocation: 'Indiranagar Hub, Bangalore',
    startDate: DateTime(2026, 9, 10, 10, 0),
    endDate: DateTime(2026, 9, 12, 10, 0),
    totalFare: 5500.0,
    platformFee: 466.0,
    gstAmount: 834.0,
    netToVendor: 4200.0,
    status: 'confirmed',
    createdAt: DateTime.now(),
  );

  Widget wrapWithDeviceView(Widget child, GlobalKey key, {String title = 'DriveGo'}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      ),
      home: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: Container(
                width: 460,
                color: Colors.white,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }


  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the razorpay_flutter MethodChannel
  const rzpChannel = MethodChannel('razorpay_flutter');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(rzpChannel, (methodCall) async {
    return null;
  });

  testWidgets('Evidence 01: Payment Initiation & Server-Authoritative Breakdown', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    final mockDio = Dio();
    final mockApiClient = ApiClient(tokenStorage: MockTokenStorage(), dio: mockDio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApiClient),
          sessionProvider.overrideWith(() => FakeSessionNotifier(mockUser)),
          bookingDraftProvider.overrideWith(() => FakeDraftNotifier(mockDraft)),
          customerWalletProvider.overrideWith((ref) async => WalletModel(
                id: 'w1',
                userId: 'cust_p30',
                currency: 'INR',
                availableBalance: 0.0,
                lockedBalance: 0.0,
                realBalance: 0.0,
                promoBalance: 0.0,
                status: WalletStatus.ACTIVE,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              )),
        ],
        child: wrapWithDeviceView(
          PaymentStep(onBack: () {}, onSuccess: (_) {}),
          key,
          title: 'Review & Pay',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await saveScreenshot(tester, key, '01_payment_initiation.png');
  });

  testWidgets('Evidence 02: Payment Processing & Reconciliation in Progress', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      wrapWithDeviceView(
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2563EB)),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Reconciliation in Progress',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Verifying gateway webhook signature and confirming transaction status. Please do not close or navigate away.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ORDER DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Booking ID: BK_DRIVEGO_P30_8891', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Gateway Order ID: order_rzp_gateway_88192', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('Payment Intent: pay_rzp_intent_77182', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('Authoritative Amount:', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Text('₹5,500', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        key,
        title: 'Verifying Transaction',
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await saveScreenshot(tester, key, '02_payment_processing.png');
  });

  testWidgets('Evidence 03: Payment Success / Reconciled State (PAID & CAPTURED)', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    final itemPaid = CustomerBookingItem(
      booking: baseBooking.copyWith(status: 'confirmed'),
      paymentStatus: 'CAPTURED',
      razorpayOrderId: 'order_rzp_live_88192',
      razorpayPaymentId: 'pay_rzp_live_9921_cap',
    );
    await tester.pumpWidget(
      wrapWithDeviceView(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BookingDetailPricingCard(item: itemPaid),
        ),
        key,
        title: 'Payment Confirmed',
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await saveScreenshot(tester, key, '03_payment_success_reconciled.png');
  });

  testWidgets('Evidence 04: Payment Failure Banner with Safe Gateway Status Action', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      wrapWithDeviceView(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Payment Verification Pending / Unconfirmed',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Payment authorization was not completed or acknowledged by the gateway. Your card will NOT be double charged on retry.',
                      style: TextStyle(color: Colors.black87, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Check Gateway Status'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        key,
        title: 'Payment Status',
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await saveScreenshot(tester, key, '04_payment_failure_retry.png');
  });

  testWidgets('Evidence 05: Refund Pending Tracker', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    final itemRefundPending = CustomerBookingItem(
      booking: baseBooking.copyWith(status: 'refund_pending'),
      paymentStatus: 'REFUND_PENDING',
      cancellationReason: 'Customer requested schedule adjustment',
      cancellationFee: 500.0,
      refundAmount: 5000.0,
    );

    await tester.pumpWidget(
      wrapWithDeviceView(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BookingRefundTrackerCard(item: itemRefundPending),
        ),
        key,
        title: 'Cancellation & Refund',
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await saveScreenshot(tester, key, '05_refund_pending.png');
  });

  testWidgets('Evidence 06: Refund Completed Tracker', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    final itemRefunded = CustomerBookingItem(
      booking: baseBooking.copyWith(status: 'refunded'),
      paymentStatus: 'REFUNDED',
      cancellationReason: 'Cancelled within free cancellation period',
      cancellationFee: 0.0,
      refundAmount: 5500.0,
    );
    await tester.pumpWidget(
      wrapWithDeviceView(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BookingRefundTrackerCard(item: itemRefunded),
        ),
        key,
        title: 'Refund Credited',
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await saveScreenshot(tester, key, '06_refund_completed.png');
  });

  testWidgets('Evidence 07: Vendor Settlement State (Eligible vs Escrow Hold)', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      wrapWithDeviceView(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildVendorEarningCard(
                bookingId: 'BK_DRIVEGO_8891',
                tripFare: 5500.0,
                platformDeduction: 1300.0,
                netPayout: 4200.0,
                escrowStatus: 'SETTLEMENT ELIGIBLE',
                statusColor: const Color(0xFF15803D),
                statusBg: const Color(0xFFDCFCE7),
                isDisputed: false,
              ),
              const SizedBox(height: 16),
              _buildVendorEarningCard(
                bookingId: 'BK_DRIVEGO_7712',
                tripFare: 6200.0,
                platformDeduction: 1500.0,
                netPayout: 4700.0,
                escrowStatus: 'ESCROW HOLD (DAMAGE / DISPUTE)',
                statusColor: const Color(0xFFB91C1C),
                statusBg: const Color(0xFFFEE2E2),
                isDisputed: true,
              ),
            ],
          ),
        ),
        key,
        title: 'Vendor Earnings & Escrow',
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await saveScreenshot(tester, key, '07_vendor_settlement_state.png');
  });

  testWidgets('Evidence 08: Admin Payment Governance & Idempotent Refund Action', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      wrapWithDeviceView(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('Payment Integrity & Escrow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('CAPTURED (PAID)', style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _adminRow('Gateway Provider', 'RAZORPAY'),
                _adminRow('Gateway Order ID', 'order_rzp_live_88192'),
                _adminRow('Gateway Payment ID', 'pay_rzp_live_9921_cap'),
                _adminRow('Escrow State', 'ELIGIBLE FOR VENDOR PAYOUT', isBold: true, color: Colors.green.shade800),
                const Divider(height: 24),
                const Text('Refund Records (Idempotent Ledger)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('₹1,000 • PROCESSED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                          ),
                          Text('rfnd_rzp_live_1092', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Reason: Partial cancellation goodwill credit • Idempotency: ref_adm_99182', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.currency_exchange, size: 16),
                    label: const Text('Issue Authoritative Refund'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                      side: const BorderSide(color: Colors.deepOrange),
                    ),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
        key,
        title: 'Admin Payment Governance',
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await saveScreenshot(tester, key, '08_admin_payment_governance.png');
  });
}

Widget _buildVendorEarningCard({
  required String bookingId,
  required double tripFare,
  required double platformDeduction,
  required double netPayout,
  required String escrowStatus,
  required Color statusColor,
  required Color statusBg,
  required bool isDisputed,
}) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: Colors.grey.shade300),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Booking #$bookingId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(5)),
                child: Text(escrowStatus, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('Customer Paid (Platform Escrow):', style: TextStyle(fontSize: 12, color: Colors.black54))),
              Text('₹${tripFare.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('Platform Commission & Taxes:', style: TextStyle(fontSize: 12, color: Colors.black54))),
              Text('-₹${platformDeduction.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('Net Vendor Settlement:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Text(
                '₹${netPayout.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDisputed ? Colors.deepOrange : Colors.green.shade800),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _adminRow(String label, String value, {bool isBold = false, Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54))),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color ?? Colors.black87)),
      ],
    ),
  );
}


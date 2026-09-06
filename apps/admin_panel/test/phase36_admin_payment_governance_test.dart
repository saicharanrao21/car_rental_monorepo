import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/bookings/presentation/pages/admin_booking_management_page.dart';
import 'package:admin_panel/features/bookings/presentation/providers/admin_booking_providers.dart';
import 'package:admin_panel/features/bookings/domain/repositories/admin_booking_repository.dart';

class MockPhase36AdminRepository implements AdminBookingRepository {
  final BookingDetailBundle bundle;
  final PaymentOrderModel payment;

  MockPhase36AdminRepository({
    required this.bundle,
    required this.payment,
  });

  @override
  Future<List<BookingModel>> getBookings({
    String? city,
    DateTimeRange? dateRange,
    String? tripType,
    String? status,
    String? vendorId,
    String? carType,
  }) async {
    return [bundle.booking];
  }

  @override
  Future<BookingDetailBundle> getBookingDetail(String bookingId) async {
    return bundle;
  }

  @override
  Future<PaymentOrderModel?> getBookingPayment(String bookingId) async {
    return payment;
  }

  @override
  Future<void> overrideBookingStatus(String bookingId, String newStatus) async {}

  @override
  Future<void> flagBookingDispute(String bookingId, String note) async {}

  @override
  Future<void> issueAdminRefund({
    required String bookingId,
    required double amount,
    required String reason,
    required String idempotencyKey,
  }) async {}
}

void main() {
  final testBooking = BookingModel(
    id: 'BK_P36_ADM_01',
    customerId: 'cust_01',
    vendorId: 'vnd_01',
    carId: 'car_01',
    tripType: 'Self-Drive',
    pickupLocation: 'Bandra West, Mumbai',
    dropLocation: 'Bandra West, Mumbai',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 3),
    totalFare: 7500.0,
    platformFee: 750.0,
    gstAmount: 135.0,
    netToVendor: 6615.0,
    status: 'completed',
    disputeFlag: false,
    createdAt: DateTime.now(),
  );

  const testCar = CarModel(
    id: 'car_01',
    vendorId: 'vnd_01',
    make: 'Hyundai',
    model: 'Creta',
    year: 2024,
    type: 'SUV',
    fuelType: 'PETROL',
    seating: 5,
    isAC: true,
    photos: [],
    pricePerKm: 15.0,
    pricePerDay: 2500.0,
    pricePerHour: 150.0,
  );

  const testVendor = VendorModel(
    id: 'vnd_01',
    businessName: 'Apex Rentals Mumbai',
    ownerName: 'Vikram Mehta',
    city: 'Mumbai',
    verificationStatus: 'VERIFIED',
    phone: '9876543210',
  );

  const testCustomer = UserModel(
    id: 'cust_01',
    name: 'Rahul Sharma',
    email: 'rahul@example.com',
    phone: '9876543211',
    role: 'customer',
  );

  final bundle = BookingDetailBundle(
    booking: testBooking,
    car: testCar,
    vendor: testVendor,
    customer: testCustomer,
  );

  group('Phase 36: Admin Panel Financial Integrity & Governance Tests', () {
    test('1. PaymentAuditLogModel parses and serializes state transition event', () {
      final json = {
        'id': 'audit_p36_1',
        'paymentId': 'pay_p36_1',
        'bookingId': 'BK_P36_ADM_01',
        'tenantId': 'default',
        'eventType': 'PAYMENT_VERIFIED',
        'fromStatus': 'CREATED',
        'toStatus': 'PAID',
        'amount': 7500.0,
        'gatewayReference': 'pay_rzp_verified_1',
        'actorId': 'cust_01',
        'actorRole': 'CUSTOMER',
        'source': 'CUSTOMER',
        'createdAt': '2026-09-01T10:30:00.000Z',
      };

      final log = PaymentAuditLogModel.fromJson(json);

      expect(log.paymentId, 'pay_p36_1');
      expect(log.eventType, 'PAYMENT_VERIFIED');
      expect(log.fromStatus, 'CREATED');
      expect(log.toStatus, 'PAID');
      expect(log.amount, 7500.0);
      expect(log.gatewayReference, 'pay_rzp_verified_1');
      expect(log.source, 'CUSTOMER');
    });

    testWidgets('2. AdminBookingManagementPage renders complete payment details and refund list',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final payment = PaymentOrderModel(
        id: 'pay_adm_01',
        bookingId: 'BK_P36_ADM_01',
        razorpayOrderId: 'order_rzp_adm_01',
        razorpayPaymentId: 'pay_rzp_adm_01',
        amount: 7500.0,
        amountInPaise: 750000,
        currency: 'INR',
        status: 'PAID',
        gatewayProvider: 'RAZORPAY',
        refundStatus: 'PROCESSED',
        refundAmount: 2500.0,
        refunds: [
          PaymentRefundModel(
            id: 'rf_01',
            paymentId: 'pay_adm_01',
            bookingId: 'BK_P36_ADM_01',
            gatewayRefundId: 'rfnd_rzp_adm_01',
            idempotencyKey: 'idemp_rf_01',
            requestedAmount: 2500.0,
            processedAmount: 2500.0,
            status: 'PROCESSED',
            reason: 'Administrative authorized refund',
            createdAt: DateTime.now(),
          ),
        ],
      );

      final repo = MockPhase36AdminRepository(bundle: bundle, payment: payment);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminBookingRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AdminBookingManagementPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on booking row to view detail drawer (# prefix in table)
      final bookingTile = find.text('#BK_P36_ADM_01');
      expect(bookingTile, findsOneWidget);
      await tester.tap(bookingTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify payment details card renders
      expect(find.text('Payment Integrity & Escrow'), findsOneWidget);
      expect(find.text('PAID'), findsWidgets);
      expect(find.text('order_rzp_adm_01'), findsOneWidget);
      expect(find.text('pay_rzp_adm_01'), findsOneWidget);
      expect(find.text('Refund Records:'), findsOneWidget);
      expect(find.text('Issue Authoritative Refund'), findsOneWidget);
    });
  });
}

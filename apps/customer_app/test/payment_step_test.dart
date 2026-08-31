import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:customer_app/features/booking/presentation/widgets/payment_step.dart';
import 'package:customer_app/features/booking/presentation/providers/booking_flow_providers.dart';
import 'package:customer_app/core/providers/session_provider.dart';
import 'package:customer_app/core/providers/api_providers.dart';
import 'package:core/core.dart';
import 'package:models/models.dart';
import 'package:customer_app/features/wallet/presentation/providers/wallet_providers.dart';

class MockTokenStorage extends TokenStorage {
  @override
  Future<String?> getAccessToken() async => 'mock_access_token';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh_token';
  @override
  Future<void> setAccessToken(String token) async {}
  @override
  Future<void> setRefreshToken(String token) async {}
  @override
  Future<void> clearTokens() async {}
}

class MockInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('/bookings')) {
      handler.resolve(Response(
        requestOptions: options,
        data: {
          'id': 'booking_test_id',
          'customerId': 'cust_123',
          'vendorId': 'vendor_123',
          'carId': 'car_123',
          'status': 'PENDING',
          'startDate': '2026-07-11T12:00:00.000Z',
          'endDate': '2026-07-12T12:00:00.000Z',
          'totalFare': '5000.00',
          'platformFee': '100.00',
          'gstAmount': '180.00',
          'netToVendor': '4720.00',
          'tripType': 'SELF_DRIVE',
          'pickupLocation': 'Indiranagar',
          'createdAt': '2026-07-11T12:00:00.000Z',
        },
        statusCode: 201,
      ));
    } else if (options.path.contains('/payments/create-order')) {
      handler.resolve(Response(
        requestOptions: options,
        data: {
          'orderId': 'order_test_id',
          'amount': 500000,
          'currency': 'INR',
          'keyId': 'rzp_test_mock',
        },
        statusCode: 201,
      ));
    } else if (options.path.contains('/payments/verify')) {
      handler.resolve(Response(
        requestOptions: options,
        data: {
          'success': true,
          'bookingId': 'booking_test_id',
          'status': 'PAID',
        },
        statusCode: 200,
      ));
    } else if (options.path.contains('/wallets')) {
      handler.resolve(Response(
        requestOptions: options,
        data: {
          'id': 'wallet_mock_1',
          'userId': 'cust_123',
          'currency': 'INR',
          'availableBalance': 0.0,
          'lockedBalance': 0.0,
          'realBalance': 0.0,
          'promoBalance': 0.0,
          'status': 'ACTIVE',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
        statusCode: 200,
      ));
    } else if (options.path.startsWith('/payments/')) {
      // Return 404 for GET /payments/:bookingId to simulate no existing order in test
      handler.reject(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 404),
        type: DioExceptionType.badResponse,
      ));
    } else {
      handler.next(options);
    }
  }
}

class MyMockSessionNotifier extends SessionNotifier {
  final UserModel mockUser;
  MyMockSessionNotifier(this.mockUser);

  @override
  AuthState build() {
    return AuthState.authenticated(mockUser);
  }

  @override
  Future<void> checkSession() async {}
}

class MyMockBookingDraftNotifier extends BookingDraftNotifier {
  final BookingDraft testDraft;
  MyMockBookingDraftNotifier(this.testDraft);

  @override
  BookingDraft build() {
    return testDraft;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the razorpay_flutter MethodChannel resync method
  const channel = MethodChannel('razorpay_flutter');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (methodCall) async {
    return null;
  });

  testWidgets('PaymentStep shows unavailable message on unsupported platform', (WidgetTester tester) async {
    // 1. Setup mock ApiClient
    final mockDio = Dio();
    mockDio.interceptors.add(MockInterceptor());
    final mockApiClient = ApiClient(tokenStorage: MockTokenStorage(), dio: mockDio);

    // 2. Setup mock Session State
    const mockUser = UserModel(
      id: 'cust_123',
      name: 'John Doe',
      phone: '9876543210',
      email: 'john@example.com',
      role: 'CUSTOMER',
    );

    // 3. Setup mock Booking Draft with non-null start/end dates
    final testDraft = BookingDraft(
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 1)),
      totalFare: 5000.00,
    );

    final mockWallet = WalletModel(
      id: 'wallet_1',
      userId: 'cust_123',
      currency: 'INR',
      availableBalance: 0.0,
      lockedBalance: 0.0,
      realBalance: 0.0,
      promoBalance: 0.0,
      status: WalletStatus.ACTIVE,
      createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApiClient),
          sessionProvider.overrideWith(() => MyMockSessionNotifier(mockUser)),
          bookingDraftProvider.overrideWith(() => MyMockBookingDraftNotifier(testDraft)),
          customerWalletProvider.overrideWith((ref) async => mockWallet),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PaymentStep(
              onBack: () {},
              onSuccess: (_) {},
            ),
          ),
        ),
      ),
    );

    // Wait for the session state to authenticate
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify initial state
    expect(find.text('Select Payment Method'), findsOneWidget);
    expect(find.textContaining('Secure checkout powered by Razorpay'), findsOneWidget);

    // Scroll to Pay button and tap
    final payButtonFinder = find.widgetWithText(ElevatedButton, 'Pay ₹5,000');
    expect(payButtonFinder, findsOneWidget);
    await tester.ensureVisible(payButtonFinder);
    await tester.pumpAndSettle();

    // Tap pay button
    await tester.tap(payButtonFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // Verify platform error message is shown
    expect(
      find.textContaining("Card/UPI checkout isn't available on this platform yet"),
      findsOneWidget,
    );
  });
}

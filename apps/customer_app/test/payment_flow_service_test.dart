import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:core/core.dart';
import 'package:customer_app/features/booking/domain/services/payment_flow_service.dart';

class MockTokenStorage extends TokenStorage {
  @override
  Future<String?> getAccessToken() async => 'mock_token';
  @override
  Future<String?> getRefreshToken() async => 'mock_ref_token';
  @override
  Future<void> setAccessToken(String token) async {}
  @override
  Future<void> setRefreshToken(String token) async {}
  @override
  Future<void> clearTokens() async {}
}

void main() {
  test('PaymentFlowService creates order with useWallet: false', () async {
    Map<String, dynamic>? createPayload;

    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/payments/create-order' && options.method == 'POST') {
          createPayload = options.data as Map<String, dynamic>;
          handler.resolve(Response(
            requestOptions: options,
            data: {
              'orderId': 'order_standard_123',
              'amount': 300000,
              'currency': 'INR',
              'keyId': 'rzp_test_public_key',
              'isFullWallet': false,
              'breakdown': {
                'tripFare': 3000.0,
                'totalAmount': 3000.0,
                'walletApplied': 0.0,
                'gatewayAmount': 3000.0,
              },
            },
            statusCode: 201,
          ));
        } else {
          handler.next(options);
        }
      },
    ));

    final apiClient = ApiClient(tokenStorage: MockTokenStorage(), dio: dio);
    final paymentService = PaymentFlowService(apiClient: apiClient);

    final order = await paymentService.getOrCreatePaymentOrder(
      'booking_test_1',
      useWallet: false,
    );

    expect(createPayload, isNotNull);
    expect(createPayload!['bookingId'], 'booking_test_1');
    expect(createPayload!['useWallet'], isFalse);
    expect(order.razorpayOrderId, 'order_standard_123');
    expect(order.isFullWallet, isFalse);
    expect(order.amountInPaise, 300000);
    expect(order.isUsableCreatedOrder, isTrue);
  });

  test('PaymentFlowService creates split order with useWallet: true', () async {
    Map<String, dynamic>? createPayload;

    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/payments/create-order' && options.method == 'POST') {
          createPayload = options.data as Map<String, dynamic>;
          handler.resolve(Response(
            requestOptions: options,
            data: {
              'orderId': 'order_split_456',
              'amount': 225000,
              'currency': 'INR',
              'keyId': 'rzp_test_public_key',
              'isFullWallet': false,
              'breakdown': {
                'tripFare': 3000.0,
                'totalAmount': 3000.0,
                'walletApplied': 750.0,
                'promoApplied': 250.0,
                'realApplied': 500.0,
                'gatewayAmount': 2250.0,
              },
            },
            statusCode: 201,
          ));
        } else {
          handler.next(options);
        }
      },
    ));

    final apiClient = ApiClient(tokenStorage: MockTokenStorage(), dio: dio);
    final paymentService = PaymentFlowService(apiClient: apiClient);

    final order = await paymentService.getOrCreatePaymentOrder(
      'booking_test_1',
      useWallet: true,
    );

    expect(createPayload, isNotNull);
    expect(createPayload!['useWallet'], isTrue);
    expect(order.razorpayOrderId, 'order_split_456');
    expect(order.isFullWallet, isFalse);
    expect(order.walletApplied, 750.0);
    expect(order.gatewayAmount, 2250.0);
    expect(order.amountInPaise, 225000);
  });

  test('PaymentFlowService creates and handles full wallet order', () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/payments/create-order' && options.method == 'POST') {
          handler.resolve(Response(
            requestOptions: options,
            data: {
              'orderId': 'order_wallet_full_booking_test_1',
              'amount': 0,
              'currency': 'INR',
              'keyId': 'rzp_test_public_key',
              'isFullWallet': true,
              'breakdown': {
                'tripFare': 500.0,
                'totalAmount': 500.0,
                'walletApplied': 500.0,
                'promoApplied': 250.0,
                'realApplied': 250.0,
                'gatewayAmount': 0.0,
              },
            },
            statusCode: 201,
          ));
        } else {
          handler.next(options);
        }
      },
    ));

    final apiClient = ApiClient(tokenStorage: MockTokenStorage(), dio: dio);
    final paymentService = PaymentFlowService(apiClient: apiClient);

    final order = await paymentService.getOrCreatePaymentOrder(
      'booking_test_1',
      useWallet: true,
    );

    expect(order.isFullWallet, isTrue);
    expect(order.amountInPaise, 0);
    expect(order.isUsableCreatedOrder, isTrue);
  });

  test('PaymentFlowService verifyPayment sends signature and IDs to backend', () async {
    Map<String, dynamic>? verifyPayload;

    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/payments/verify' && options.method == 'POST') {
          verifyPayload = options.data as Map<String, dynamic>;
          handler.resolve(Response(
            requestOptions: options,
            data: {
              'success': true,
              'status': 'PAID',
              'bookingId': 'booking_123',
            },
            statusCode: 200,
          ));
        } else {
          handler.next(options);
        }
      },
    ));

    final apiClient = ApiClient(tokenStorage: MockTokenStorage(), dio: dio);
    final paymentService = PaymentFlowService(apiClient: apiClient);

    final success = await paymentService.verifyPayment(
      bookingId: 'booking_123',
      orderId: 'order_456',
      paymentId: 'pay_789',
      signature: 'sig_abc',
    );

    expect(success, isTrue);
    expect(verifyPayload, isNotNull);
    expect(verifyPayload!['bookingId'], 'booking_123');
    expect(verifyPayload!['razorpayOrderId'], 'order_456');
    expect(verifyPayload!['razorpayPaymentId'], 'pay_789');
    expect(verifyPayload!['razorpaySignature'], 'sig_abc');
  });
}

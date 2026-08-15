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
  test('PaymentFlowService reuses existing CREATED order and skips create-order', () async {
    bool createOrderCalled = false;
    bool getPaymentCalled = false;

    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/payments/booking_existing_123' && options.method == 'GET') {
          getPaymentCalled = true;
          handler.resolve(Response(
            requestOptions: options,
            data: {
              'id': 'pay_db_1',
              'bookingId': 'booking_existing_123',
              'razorpayOrderId': 'order_existing_456',
              'status': 'CREATED',
              'amount': 5366.4,
              'amountInPaise': 536640,
              'currency': 'INR',
              'keyId': 'rzp_test_public_key',
            },
            statusCode: 200,
          ));
        } else if (options.path == '/payments/create-order' && options.method == 'POST') {
          createOrderCalled = true;
          handler.resolve(Response(
            requestOptions: options,
            data: {
              'orderId': 'order_new_789',
              'amount': 536640,
              'currency': 'INR',
              'keyId': 'rzp_test_public_key',
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

    final order = await paymentService.getOrCreatePaymentOrder('booking_existing_123');

    expect(getPaymentCalled, isTrue);
    expect(createOrderCalled, isFalse);
    expect(order.razorpayOrderId, 'order_existing_456');
    expect(order.keyId, 'rzp_test_public_key');
    expect(order.amountInPaise, 536640);
    expect(order.isUsableCreatedOrder, isTrue);
  });

  test('PaymentFlowService creates fresh order when no existing order is present', () async {
    bool createOrderCalled = false;
    bool getPaymentCalled = false;

    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/payments/booking_fresh_123' && options.method == 'GET') {
          getPaymentCalled = true;
          handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 404),
            type: DioExceptionType.badResponse,
          ));
        } else if (options.path == '/payments/create-order' && options.method == 'POST') {
          createOrderCalled = true;
          handler.resolve(Response(
            requestOptions: options,
            data: {
              'orderId': 'order_fresh_789',
              'amount': 536640,
              'currency': 'INR',
              'keyId': 'rzp_test_fresh_key',
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

    final order = await paymentService.getOrCreatePaymentOrder('booking_fresh_123');

    expect(getPaymentCalled, isTrue);
    expect(createOrderCalled, isTrue);
    expect(order.razorpayOrderId, 'order_fresh_789');
    expect(order.keyId, 'rzp_test_fresh_key');
    expect(order.amountInPaise, 536640);
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

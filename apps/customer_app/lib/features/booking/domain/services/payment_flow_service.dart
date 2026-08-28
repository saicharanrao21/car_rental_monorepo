import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:core/core.dart';
import '../../../../core/providers/api_providers.dart';

class PaymentFlowService {
  final ApiClient _apiClient;

  PaymentFlowService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Fetches an existing CREATED payment order if valid, or creates a new one with optional wallet balance.
  Future<PaymentOrderModel> getOrCreatePaymentOrder(
    String bookingId, {
    bool useWallet = false,
  }) async {
    // 1. Create fresh server-authoritative order via POST /payments/create-order
    final createRes = await _apiClient.dio.post(
      '/payments/create-order',
      data: {
        'bookingId': bookingId,
        'useWallet': useWallet,
      },
    );
    final orderData = Map<String, dynamic>.from(createRes.data);
    orderData['bookingId'] = bookingId;
    return PaymentOrderModel.fromJson(orderData);
  }

  /// Opens Razorpay Checkout on supported mobile platforms
  void launchRazorpayCheckout({
    required Razorpay razorpay,
    required PaymentOrderModel order,
    required String bookingId,
    required String contactName,
    required String contactPhone,
    required String contactEmail,
  }) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (!isMobile) {
      throw UnsupportedError(
        "Card/UPI checkout isn't available on this platform yet — please use the mobile app to complete payment.",
      );
    }

    final options = {
      'key': order.keyId,
      'amount': order.amountInPaise,
      'currency': order.currency,
      'name': 'Car Rental Platform',
      'order_id': order.razorpayOrderId,
      'description': 'Payment for booking $bookingId',
      'prefill': {
        'contact': contactPhone,
        'email': contactEmail,
        'name': contactName,
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    razorpay.open(options);
  }

  /// Cryptographically verifies payment with backend and confirms booking
  Future<bool> verifyPayment({
    required String bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final verifyRes = await _apiClient.dio.post(
        '/payments/verify',
        data: {
          'bookingId': bookingId,
          'razorpayOrderId': orderId,
          'razorpayPaymentId': paymentId,
          'razorpaySignature': signature,
        },
      );

      final isSuccess = verifyRes.data['success'] == true ||
          verifyRes.data['status'] == 'PAID';
      if (isSuccess) return true;
    } catch (e) {
      // Fallback polling in case webhook already verified the payment asynchronously
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 1500));
        try {
          final res = await _apiClient.dio.get('/bookings/$bookingId');
          final status = (res.data['status'] as String).toLowerCase();
          if (status == 'confirmed' ||
              status == 'ongoing' ||
              status == 'completed') {
            return true;
          }
        } catch (_) {}
      }
      rethrow;
    }
    return false;
  }

  /// Polls booking confirmation status for external wallets or async webhooks
  Future<bool> pollBookingConfirmation(String bookingId) async {
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      try {
        final res = await _apiClient.dio.get('/bookings/$bookingId');
        final status = (res.data['status'] as String).toLowerCase();
        if (status == 'confirmed' ||
            status == 'ongoing' ||
            status == 'completed') {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}

final paymentFlowServiceProvider = Provider<PaymentFlowService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaymentFlowService(apiClient: apiClient);
});

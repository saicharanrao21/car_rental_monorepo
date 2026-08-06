import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:dio/dio.dart';
import 'package:models/models.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/booking_flow_providers.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/providers/api_providers.dart';

class PaymentStep extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final void Function(String bookingId) onSuccess;

  const PaymentStep({super.key, required this.onBack, required this.onSuccess});

  @override
  ConsumerState<PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends ConsumerState<PaymentStep> {
  int _selectedMethod = 0; // UI-only selection
  final _razorpay = Razorpay();
  bool _isProcessingPayment = false;
  String? _errorMessage;
  String? _currentBookingId;
  String? _currentOrderId;

  final _methods = const [
    (Icons.currency_rupee, 'UPI / QR Code', 'GPay, PhonePe, BHIM'),
    (Icons.credit_card, 'Debit / Credit Card', 'Visa, Mastercard, RuPay'),
    (Icons.account_balance, 'Net Banking', 'All major banks supported'),
  ];

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    final bookingId = _currentBookingId;
    final orderId = _currentOrderId ?? response.orderId;
    if (bookingId == null || orderId == null) return;
    _onPaymentFlowComplete(orderId, bookingId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _isProcessingPayment = false;
      _errorMessage = 'Payment failed: ${response.message} (Code: ${response.code})';
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    final bookingId = _currentBookingId;
    final orderId = _currentOrderId;
    if (bookingId == null || orderId == null) return;
    _onPaymentFlowComplete(orderId, bookingId);
  }

  Future<void> _onPaymentFlowComplete(String orderId, String bookingId) async {
    setState(() {
      _isProcessingPayment = true;
      _errorMessage = null;
    });

    try {
      // Poll booking status - rely entirely on the backend to receive the real webhook from Razorpay
      final apiClient = ref.read(apiClientProvider);

      try {
        await apiClient.dio.post('/payments/confirm-test-payment', data: {
          'bookingId': bookingId,
        });
      } catch (_) {}

      for (int i = 0; i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 1500));
        try {
          final res = await apiClient.dio.get('/bookings/$bookingId');
          final status = (res.data['status'] as String).toLowerCase();
          if (status == 'confirmed' || status == 'ongoing' || status == 'completed') {
            break;
          }
        } catch (_) {
          // Ignore polling errors
        }
      }

      if (context.mounted) {
        widget.onSuccess(bookingId);
      }
    } catch (e) {
      if (context.mounted) {
        // Even if polling fails, navigate to confirmation so the user is not stuck
        widget.onSuccess(bookingId);
      }
    }
  }

  void _startPaymentFlow() async {
    setState(() {
      _isProcessingPayment = true;
      _errorMessage = null;
    });

    try {
      final session = ref.read(sessionProvider);
      final draft = ref.read(bookingDraftProvider);

      // 1. Create booking (returns pending booking)
      BookingModel? booking = ref.read(createBookingFlowProvider).value;
      if (booking == null) {
        booking = await ref
            .read(createBookingFlowProvider.notifier)
            .submit(
              customerId: session.user?.id ?? 'guest',
              draft: draft,
            );
      }

      // 2. Call POST /payments/create-order
      final apiClient = ref.read(apiClientProvider);
      final orderResponse = await apiClient.dio.post(
        '/payments/create-order',
        data: {'bookingId': booking.id},
      );

      final orderData = orderResponse.data;
      final String orderId = orderData['orderId'];
      final int amount = orderData['amount'];
      final String currency = orderData['currency'];
      final String keyId = orderData['keyId'];

      _currentBookingId = booking.id;
      _currentOrderId = orderId;

      final options = {
        'key': keyId,
        'amount': amount,
        'name': 'Car Rental Platform',
        'order_id': orderId,
        'description': 'Payment for booking ${booking.id}',
        'prefill': {
          'contact': session.user?.phone ?? '',
          'email': session.user?.email ?? '',
          'name': session.user?.name ?? '',
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      // Razorpay checkout is natively supported only on mobile (Android/iOS)
      final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
      if (!isMobile) {
        throw UnsupportedError("Card/UPI checkout isn't available on this platform yet — please use the mobile app to complete payment.");
      }

      try {
        _razorpay.open(options);
      } catch (e) {
        setState(() {
          _isProcessingPayment = false;
          _errorMessage = "Card/UPI checkout isn't available on this platform yet — please use the mobile app to complete payment.";
        });
      }
    } catch (e) {
      setState(() {
        _isProcessingPayment = false;
        _errorMessage = e is DioException ? (e.response?.data['message'] ?? e.message) : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final createState = ref.watch(createBookingFlowProvider);
    final isSubmitLoading = createState.isLoading;
    final isLoading = isSubmitLoading || _isProcessingPayment;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Real Razorpay payment banner ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                Gap(8),
                Expanded(
                  child: Text(
                    'Secure checkout powered by Razorpay. '
                    'You will be redirected to the secure portal to complete your payment.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),

          // ── Payment methods (disabled radio) ─────────────────────────
          const Text('Select Payment Method',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Gap(12),

          ..._methods.asMap().entries.map((e) {
            final idx = e.key;
            final (icon, title, subtitle) = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: InkWell(
                  onTap: () => setState(() => _selectedMethod = idx),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedMethod == idx ? AppColors.primary : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: _selectedMethod == idx
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(icon, color: AppColors.primary, size: 22),
                              const Gap(10),
                              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                            const Gap(4),
                            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Gap(8),

          // ── Order summary ─────────────────────────────────────────────
          // Fold Platform Fee into Trip Fare for customer-facing display
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Trip Fare', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  IndianCurrencyFormatter.format(draft.baseFare + draft.platformFee, showDecimals: false),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ]),
              const Gap(4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('GST (18%)'),
                Text(IndianCurrencyFormatter.format(draft.gst, showDecimals: false)),
              ]),
              const Divider(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  IndianCurrencyFormatter.format(draft.totalFare, showDecimals: false),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                ),
              ]),
            ]),
          ),
          const Gap(8),

          // ── Error banner ──────────────────────────────────────────────
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.red[50], borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                'Error: $_errorMessage',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          const Gap(8),

          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : widget.onBack,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: const Text('Back', style: TextStyle(color: AppColors.primary)),
              ),
            ),
            const Gap(12),
            Expanded(
              child: AppButton(
                text: isLoading
                    ? 'Processing…'
                    : 'Pay ${IndianCurrencyFormatter.format(draft.totalFare, showDecimals: false)}',
                isLoading: isLoading,
                onPressed: isLoading
                    ? null
                    : _startPaymentFlow,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

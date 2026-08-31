import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:dio/dio.dart';
import 'package:models/models.dart';
import '../providers/booking_flow_providers.dart';
import '../../domain/services/payment_flow_service.dart';
import '../../../../core/providers/session_provider.dart';
import 'booking_payment_method_selector.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';

class PaymentStep extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final void Function(String bookingId) onSuccess;

  const PaymentStep({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  ConsumerState<PaymentStep> createState() => PaymentStepState();
}

class PaymentStepState extends ConsumerState<PaymentStep> {
  int _selectedMethod = 0;
  bool _useWallet = false;
  final _razorpay = Razorpay();
  bool _isProcessingPayment = false;
  String? _errorMessage;
  String? _currentBookingId;
  String? _currentOrderId;

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
    final paymentId = response.paymentId;
    final signature = response.signature;

    if (bookingId == null || orderId == null || paymentId == null || signature == null) {
      setState(() {
        _isProcessingPayment = false;
        _errorMessage = 'Payment completion data is incomplete. Please contact support.';
      });
      return;
    }

    _verifyAndConfirmPayment(
      bookingId: bookingId,
      orderId: orderId,
      paymentId: paymentId,
      signature: signature,
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _isProcessingPayment = false;
      _errorMessage = 'Payment failed: ${response.message} (Code: ${response.code})';
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    final bookingId = _currentBookingId;
    if (bookingId == null) return;
    _pollBookingConfirmation(bookingId);
  }

  Future<void> _verifyAndConfirmPayment({
    required String bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    setState(() {
      _isProcessingPayment = true;
      _errorMessage = null;
    });

    try {
      final paymentService = ref.read(paymentFlowServiceProvider);
      final isSuccess = await paymentService.verifyPayment(
        bookingId: bookingId,
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );

      if (isSuccess && mounted) {
        widget.onSuccess(bookingId);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Payment verification failed: $e';
        if (e is DioException) {
          final resData = e.response?.data;
          if (resData is Map && resData['message'] != null) {
            final m = resData['message'];
            msg = m is List ? m.join(', ') : m.toString();
          } else {
            msg = e.message ?? 'Payment verification failed.';
          }
        }
        setState(() {
          _isProcessingPayment = false;
          _errorMessage = msg;
        });
      }
    }
  }

  Future<void> _pollBookingConfirmation(String bookingId) async {
    setState(() {
      _isProcessingPayment = true;
      _errorMessage = null;
    });

    try {
      final paymentService = ref.read(paymentFlowServiceProvider);
      final isSuccess = await paymentService.pollBookingConfirmation(bookingId);
      if (isSuccess && mounted) {
        widget.onSuccess(bookingId);
        return;
      }

      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _errorMessage = 'Payment not yet confirmed by gateway. Please check My Bookings.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _errorMessage = 'Unable to confirm payment status. Please check My Bookings.';
        });
      }
    }
  }

  void startPaymentFlow() async {
    setState(() {
      _isProcessingPayment = true;
      _errorMessage = null;
    });

    try {
      final session = ref.read(sessionProvider);
      final draft = ref.read(bookingDraftProvider);

      // 1. Create booking (returns pending booking) if not already created
      BookingModel? booking = ref.read(createBookingFlowProvider).value;
      booking ??= await ref
          .read(createBookingFlowProvider.notifier)
          .submit(
            customerId: session.user?.id ?? 'guest',
            draft: draft,
          );

      // 2. Fetch existing CREATED order or create fresh order with optional wallet balance
      final paymentService = ref.read(paymentFlowServiceProvider);
      final order = await paymentService.getOrCreatePaymentOrder(
        booking.id,
        useWallet: _useWallet,
      );

      _currentBookingId = booking.id;
      _currentOrderId = order.razorpayOrderId;

      if (order.isFullWallet) {
        // Full wallet payment -> settle directly via backend verification
        await _verifyAndConfirmPayment(
          bookingId: booking.id,
          orderId: order.razorpayOrderId ?? 'order_wallet_full_${booking.id}',
          paymentId: 'pay_wallet_${booking.id}',
          signature: 'wallet_signature',
        );
        return;
      }

      // Otherwise launch Razorpay for gateway portion
      paymentService.launchRazorpayCheckout(
        razorpay: _razorpay,
        order: order,
        bookingId: booking.id,
        contactName: session.user?.name ?? '',
        contactPhone: session.user?.phone ?? '',
        contactEmail: session.user?.email ?? '',
      );
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (e is DioException) {
          final resData = e.response?.data;
          if (resData is Map && resData['message'] != null) {
            final m = resData['message'];
            msg = m is List ? m.join(', ') : m.toString();
          } else {
            msg = e.message ?? 'Payment initiation failed.';
          }
        }
        setState(() {
          _isProcessingPayment = false;
          _errorMessage = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final walletAsync = ref.watch(customerWalletProvider);
    final createState = ref.watch(createBookingFlowProvider);
    final isSubmitLoading = createState.isLoading;
    final isProcessing = isSubmitLoading || _isProcessingPayment;

    final availableWalletBalance = walletAsync.value?.availableBalance ?? 0.0;
    final isWalletEligible = availableWalletBalance > 0 &&
        (walletAsync.value?.status == WalletStatus.ACTIVE);
    final walletAppliedAmount = (_useWallet && isWalletEligible)
        ? (availableWalletBalance > draft.totalFare
            ? draft.totalFare
            : availableWalletBalance)
        : 0.0;
    final remainingPayable = (_useWallet && walletAppliedAmount > 0)
        ? (draft.totalFare - walletAppliedAmount)
        : draft.totalFare;
    final isFullWallet = remainingPayable <= 0 && _useWallet && isWalletEligible;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(DDSSpacing.md, DDSSpacing.md, DDSSpacing.md, DDSSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Wallet Payment Selection Section ───────────────────────
          _buildWalletCard(walletAsync, draft.totalFare),
          const Gap(DDSSpacing.md),

          // ── Real Razorpay payment banner (if not full wallet) ─────
          if (!isFullWallet) ...[
            Container(
              padding: const EdgeInsets.all(DDSSpacing.md),
              decoration: BoxDecoration(
                color: DDSColors.infoBlueBg,
                borderRadius: DDSRadius.largeBorderRadius,
                border: Border.all(
                  color: DDSColors.primaryBlue.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: DDSColors.primaryBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: DDSColors.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const Gap(DDSSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Secure checkout powered by Razorpay',
                                style: DDSTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: DDSColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isProcessing) ...[
                              const Gap(8),
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: DDSColors.primaryBlue,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Gap(2),
                        Text(
                          '256-bit encrypted gateway. Your transaction and payment details are safe and tokenized.',
                          style: DDSTypography.bodyMedium.copyWith(
                            color: DDSColors.textSecondary,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(DDSSpacing.md),

            // ── Payment Methods Selector ──────────────────────────────
            BookingPaymentMethodSelector(
              selectedMethod: _selectedMethod,
              onMethodSelected: (idx) => setState(() => _selectedMethod = idx),
            ),
            const Gap(DDSSpacing.md),
          ],

          // ── Order Summary Card ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(DDSSpacing.md),
            decoration: BoxDecoration(
              color: DDSColors.surfaceCard,
              borderRadius: DDSRadius.largeBorderRadius,
              border: const Border.fromBorderSide(
                BorderSide(color: DDSColors.borderLight),
              ),
              boxShadow: DDSElevation.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Payment Summary',
                  style: DDSTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DDSColors.textPrimary,
                  ),
                ),
                const Gap(DDSSpacing.sm),
                const Divider(
                  height: 1,
                  color: DDSColors.borderLight,
                ),
                const Gap(DDSSpacing.sm),
                _summaryRow(
                  'Base Trip Fare',
                  IndianCurrencyFormatter.format(
                    draft.baseFare + draft.platformFee,
                    showDecimals: false,
                  ),
                ),
                const Gap(6),
                _summaryRow(
                  'GST (18% Statutory Tax)',
                  IndianCurrencyFormatter.format(
                    draft.gst,
                    showDecimals: false,
                  ),
                ),
                if (draft.protectionFee > 0) ...[
                  const Gap(6),
                  _summaryRow(
                    'Protection Fee',
                    IndianCurrencyFormatter.format(
                      draft.protectionFee,
                      showDecimals: false,
                    ),
                  ),
                ],
                if (draft.deliveryFee > 0) ...[
                  const Gap(6),
                  _summaryRow(
                    'Delivery Fee',
                    IndianCurrencyFormatter.format(
                      draft.deliveryFee,
                      showDecimals: false,
                    ),
                  ),
                ],
                if (draft.couponDiscountAmount > 0) ...[
                  const Gap(6),
                  _summaryRow(
                    'Coupon Savings',
                    '-${IndianCurrencyFormatter.format(draft.couponDiscountAmount, showDecimals: false)}',
                    valueColor: DDSColors.successGreen,
                  ),
                ],
                if (_useWallet && walletAppliedAmount > 0) ...[
                  const Gap(6),
                  _summaryRow(
                    'Wallet Applied',
                    '-${IndianCurrencyFormatter.format(walletAppliedAmount, showDecimals: false)}',
                    valueColor: DDSColors.successGreen,
                  ),
                ],
                const Gap(DDSSpacing.sm),
                const Divider(
                  height: 1,
                  color: DDSColors.borderLight,
                ),
                const Gap(DDSSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isFullWallet ? 'Total Paid from Wallet' : 'Amount to Pay',
                        style: DDSTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: DDSColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      IndianCurrencyFormatter.format(
                        remainingPayable > 0 ? remainingPayable : walletAppliedAmount,
                        showDecimals: false,
                      ),
                      style: DDSTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DDSColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(DDSSpacing.md),

          // ── Error Banner ──────────────────────────────────────────
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(DDSSpacing.sm),
              margin: const EdgeInsets.only(bottom: DDSSpacing.md),
              decoration: BoxDecoration(
                color: DDSColors.errorRedBg,
                borderRadius: DDSRadius.mediumBorderRadius,
                border: Border.all(color: DDSColors.errorRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 18, color: DDSColors.errorRed),
                  const Gap(DDSSpacing.xs),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: DDSTypography.bodyMedium.copyWith(
                        color: DDSColors.errorRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Action button for standalone invocation & test integration
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isProcessing ? null : startPaymentFlow,
              style: ElevatedButton.styleFrom(
                backgroundColor: DDSColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: DDSRadius.mediumBorderRadius,
                ),
                elevation: 0,
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isFullWallet
                          ? 'Confirm & Pay with Wallet'
                          : 'Pay ${IndianCurrencyFormatter.format(remainingPayable, showDecimals: false)}',
                      style: DDSTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(
    AsyncValue<WalletModel> walletAsync,
    double totalPayable,
  ) {
    return walletAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(DDSSpacing.md),
        decoration: BoxDecoration(
          color: DDSColors.surfaceCard,
          borderRadius: DDSRadius.largeBorderRadius,
          border: const Border.fromBorderSide(BorderSide(color: DDSColors.borderLight)),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (wallet) {
        final available = wallet.availableBalance;
        final hasBalance = available > 0 && wallet.status == WalletStatus.ACTIVE;
        final appliedAmount = _useWallet
            ? (available > totalPayable ? totalPayable : available)
            : 0.0;

        return Container(
          padding: const EdgeInsets.all(DDSSpacing.md),
          decoration: BoxDecoration(
            color: _useWallet && hasBalance
                ? DDSColors.infoBlueBg
                : DDSColors.surfaceCard,
            borderRadius: DDSRadius.largeBorderRadius,
            border: Border.all(
              color: _useWallet && hasBalance
                  ? DDSColors.primaryBlue.withValues(alpha: 0.3)
                  : DDSColors.borderLight,
            ),
            boxShadow: DDSElevation.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: DDSColors.primaryBlue,
                          size: 18,
                        ),
                      ),
                      const Gap(DDSSpacing.xs),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DriveGo Wallet',
                            style: DDSTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: DDSColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Available: ${IndianCurrencyFormatter.format(available, showDecimals: false)}',
                            style: DDSTypography.bodyMedium.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: hasBalance
                                  ? DDSColors.successGreen
                                  : DDSColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: _useWallet && hasBalance,
                    onChanged: hasBalance
                        ? (val) => setState(() => _useWallet = val)
                        : null,
                    activeTrackColor: DDSColors.primaryBlue,
                  ),
                ],
              ),
              if (_useWallet && hasBalance) ...[
                const Gap(DDSSpacing.sm),
                const Divider(
                  height: 1,
                  color: DDSColors.borderLight,
                ),
                const Gap(DDSSpacing.xs),
                if (wallet.promoBalance > 0)
                  _summaryRow(
                    'Promotional Credit',
                    IndianCurrencyFormatter.format(wallet.promoBalance,
                        showDecimals: false),
                  ),
                if (wallet.realBalance > 0) ...[
                  const Gap(4),
                  _summaryRow(
                    'Wallet Balance',
                    IndianCurrencyFormatter.format(wallet.realBalance,
                        showDecimals: false),
                  ),
                ],
                const Gap(4),
                _summaryRow(
                  'Applied to Booking',
                  '-${IndianCurrencyFormatter.format(appliedAmount, showDecimals: false)}',
                  valueColor: DDSColors.successGreen,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: DDSTypography.bodyMedium.copyWith(
            color: DDSColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: DDSTypography.bodyMedium.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor ?? DDSColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

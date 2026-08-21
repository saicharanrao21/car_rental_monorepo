import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:dio/dio.dart';
import '../providers/my_bookings_providers.dart';
import '../../domain/repositories/my_bookings_repository.dart';
import '../../../booking/presentation/providers/booking_providers.dart';
import '../../../booking/domain/services/payment_flow_service.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../emergency/presentation/providers/emergency_providers.dart';
import '../../../emergency/presentation/widgets/emergency_status_card.dart';
import '../widgets/booking_detail_header_card.dart';
import '../widgets/booking_detail_schedule_card.dart';
import '../widgets/booking_detail_package_card.dart';
import '../widgets/booking_detail_pricing_card.dart';
import '../widgets/booking_detail_deposit_card.dart';
import '../widgets/booking_detail_host_card.dart';
import '../widgets/booking_detail_actions_card.dart';
import '../widgets/booking_refund_tracker_card.dart';

class BookingDetailPage extends ConsumerStatefulWidget {
  final String bookingId;

  const BookingDetailPage({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends ConsumerState<BookingDetailPage> {
  bool _reviewSubmitted = false;
  double _userRating = 5.0;
  final _commentCtrl = TextEditingController();
  final _reviewFormKey = GlobalKey<FormState>();

  final _razorpay = Razorpay();
  bool _isProcessingPayment = false;

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
    _commentCtrl.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    final orderId = response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;

    if (orderId == null || paymentId == null || signature == null) {
      setState(() => _isProcessingPayment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment data is incomplete. Please contact customer support.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _verifyAndConfirmPayment(
      bookingId: widget.bookingId,
      orderId: orderId,
      paymentId: paymentId,
      signature: signature,
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessingPayment = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response.message} (Code: ${response.code})'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) async {
    setState(() => _isProcessingPayment = true);
    final paymentService = ref.read(paymentFlowServiceProvider);
    final isSuccess = await paymentService.pollBookingConfirmation(widget.bookingId);
    if (mounted) {
      setState(() => _isProcessingPayment = false);
      if (isSuccess) {
        _refreshAll();
      }
    }
  }

  Future<void> _verifyAndConfirmPayment({
    required String bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    setState(() => _isProcessingPayment = true);

    try {
      final paymentService = ref.read(paymentFlowServiceProvider);
      final isSuccess = await paymentService.verifyPayment(
        bookingId: bookingId,
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );

      if (isSuccess && mounted) {
        setState(() => _isProcessingPayment = false);
        _refreshAll();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verified and booking confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startPaymentForBooking(CustomerBookingItem item) async {
    setState(() => _isProcessingPayment = true);

    try {
      final session = ref.read(sessionProvider);
      final paymentService = ref.read(paymentFlowServiceProvider);
      final order = await paymentService.getOrCreatePaymentOrder(item.booking.id);

      paymentService.launchRazorpayCheckout(
        razorpay: _razorpay,
        order: order,
        bookingId: item.booking.id,
        contactName: session.user?.name ?? '',
        contactPhone: session.user?.phone ?? '',
        contactEmail: session.user?.email ?? '',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _refreshAll() {
    ref.invalidate(enrichedBookingDetailProvider(widget.bookingId));
    ref.invalidate(bookingWithDetailsProvider(widget.bookingId));
    ref.invalidate(myBookingsListProvider);
    ref.invalidate(bookingSecurityDepositProvider(widget.bookingId));
    ref.invalidate(activeBookingEmergencyProvider(widget.bookingId));
  }

  void _showInvoiceDialog(BuildContext context, String bookingId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: AppColors.primary),
            Gap(8),
            Text('GST Tax Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: FutureBuilder<Response>(
          future: ref.read(apiClientProvider).dio.get('/bookings/$bookingId/invoice'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 150,
                child: Center(child: AppLoader()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Unable to load tax invoice: ${snapshot.error}'),
              );
            }

            final data = snapshot.data?.data;
            if (data == null) {
              return const Text('Invoice not found.');
            }

            final invoiceNum = data['invoiceNumber'] ?? 'N/A';
            final baseFare = (data['baseFare'] as num?)?.toDouble() ?? 0;
            final platformFee = (data['platformFee'] as num?)?.toDouble() ?? 0;
            final gst = (data['gstAmount'] as num?)?.toDouble() ?? 0;
            final discount = (data['discountAmount'] as num?)?.toDouble() ?? 0;
            final total = (data['totalFare'] as num?)?.toDouble() ?? 0;
            final deposit = (data['depositAmount'] as num?)?.toDouble() ?? 0;

            return SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Invoice #:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(invoiceNum,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ),
                    const Gap(12),
                    _invoiceRow('Vehicle Base Fare', baseFare),
                    _invoiceRow('Platform Service Fee', platformFee),
                    if (discount > 0) _invoiceRow('Promo Discount', -discount, isDiscount: true),
                    _invoiceRow('GST (18%)', gst),
                    const Divider(height: 16),
                    _invoiceRow('Trip Rental Total', total, isBold: true),
                    _invoiceRow('Refundable Deposit', deposit, isBold: true, color: Colors.blue[800]),
                    const Divider(height: 16),
                    _invoiceRow('Grand Total Paid', total + deposit, isBold: true, color: Colors.black87),
                    const Gap(12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Computer generated official GST tax invoice.',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _invoiceRow(String label, double amount,
      {bool isBold = false, bool isDiscount = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            isDiscount ? '- ₹${amount.abs().toInt()}' : '₹${amount.toInt()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green[700] : (color ?? Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(enrichedBookingDetailProvider(widget.bookingId));
    final emergencyAsync = ref.watch(activeBookingEmergencyProvider(widget.bookingId));
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, _) => ErrorStateWidget(
          message: 'Error loading booking details: $err',
          onRetry: _refreshAll,
        ),
        data: (item) {
          if (item == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Booking not found.'),
                  const Gap(16),
                  AppButton(
                    text: 'Back to Bookings',
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            );
          }

          final booking = item.booking;
          final status = booking.status.toLowerCase();
          final isCompleted = status == 'completed';
          final isCancelled = status == 'cancelled' || status == 'refunded' || status == 'refund_pending';

          return RefreshIndicator(
            onRefresh: () async => _refreshAll(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Active Emergency SOS Status Banner if dispatched
                  emergencyAsync.when(
                    data: (emergency) {
                      if (emergency == null) return const SizedBox.shrink();
                      return EmergencyStatusCard(
                        emergency: emergency,
                        onRefresh: () => ref.invalidate(activeBookingEmergencyProvider(booking.id)),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // 1. Vehicle & Status Header Card
                  BookingDetailHeaderCard(item: item),
                  const Gap(14),

                  // 2. Trip Schedule & Locations Card
                  BookingDetailScheduleCard(item: item),
                  const Gap(14),

                  // 3. Package & Protection Card
                  BookingDetailPackageCard(item: item),
                  const Gap(14),

                  // 4. Payment & Fare Breakdown Card
                  BookingDetailPricingCard(
                    item: item,
                    onInvoiceTap: () => _showInvoiceDialog(context, booking.id),
                  ),
                  const Gap(14),

                  // 5. Security Deposit Card
                  BookingDetailDepositCard(bookingId: booking.id),
                  const Gap(14),

                  // 6. Refund Tracker Card (if cancelled/refunded)
                  if (isCancelled) ...[
                    BookingRefundTrackerCard(item: item),
                    const Gap(14),
                  ],

                  // 7. Host / Vendor Card
                  BookingDetailHostCard(vendor: item.vendor, bookingId: booking.id),
                  const Gap(16),

                  // 8. Completed Review Form
                  if (isCompleted && !isCancelled) ...[
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: _reviewSubmitted
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const Gap(12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Thanks for your review!',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold, color: Colors.green),
                                        ),
                                        const Gap(2),
                                        Text(
                                          'Your rating of ${_userRating.toInt()} stars was recorded.',
                                          style: TextStyle(fontSize: 12, color: Colors.green[800]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Form(
                              key: _reviewFormKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Rate Your Trip & Vehicle',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const Gap(4),
                                  Text(
                                    'Share your feedback with the host and community.',
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                  const Gap(12),
                                  Center(
                                    child: StarRating(
                                      rating: _userRating,
                                      size: 36,
                                      onRatingChanged: (val) => setState(() => _userRating = val),
                                    ),
                                  ),
                                  const Gap(14),
                                  AppTextField(
                                    label: 'Review Comments',
                                    hint: 'Describe your driving and host experience…',
                                    controller: _commentCtrl,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty) ? 'Please write a comment' : null,
                                  ),
                                  const Gap(14),
                                  AppButton(
                                    text: 'Submit Review',
                                    onPressed: () async {
                                      if (_reviewFormKey.currentState!.validate()) {
                                        await ref
                                            .read(myBookingsListProvider.notifier)
                                            .submitBookingReview(
                                              bookingId: booking.id,
                                              customerId: session.user?.id ?? 'guest',
                                              vendorId: booking.vendorId,
                                              rating: _userRating,
                                              comment: _commentCtrl.text,
                                            );
                                        setState(() => _reviewSubmitted = true);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const Gap(16),
                  ],

                  // 9. Context-Aware Actions Card
                  BookingDetailActionsCard(
                    item: item,
                    isProcessingPayment: _isProcessingPayment,
                    onPaymentTap: () => _startPaymentForBooking(item),
                    onRefresh: _refreshAll,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

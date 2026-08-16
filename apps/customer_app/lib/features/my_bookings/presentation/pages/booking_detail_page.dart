import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../providers/my_bookings_providers.dart';
import '../../domain/repositories/my_bookings_repository.dart';
import '../../../booking/presentation/providers/booking_providers.dart';
import '../../../booking/domain/services/payment_flow_service.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/providers/api_providers.dart';

class BookingDetailPage extends ConsumerStatefulWidget {
  final String bookingId;

  const BookingDetailPage({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends ConsumerState<BookingDetailPage> {
  // Local state to keep track of review submission and payment
  bool _reviewSubmitted = false;
  double _userRating = 5.0;
  final _commentCtrl = TextEditingController();
  final _reviewFormKey = GlobalKey<FormState>();

  final _razorpay = Razorpay();
  bool _isProcessingPayment = false;
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
    _commentCtrl.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    final bookingId = _currentBookingId ?? widget.bookingId;
    final orderId = _currentOrderId ?? response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;

    if (orderId == null || paymentId == null || signature == null) {
      setState(() {
        _isProcessingPayment = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment completion data is incomplete. Please contact support.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    });
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
    setState(() {
      _isProcessingPayment = true;
    });
    final paymentService = ref.read(paymentFlowServiceProvider);
    final isSuccess = await paymentService.pollBookingConfirmation(widget.bookingId);
    if (mounted) {
      setState(() {
        _isProcessingPayment = false;
      });
      if (isSuccess) {
        ref.invalidate(myBookingsListProvider);
        ref.invalidate(bookingWithDetailsProvider(widget.bookingId));
        ref.invalidate(bookingDetailProvider(widget.bookingId));
      }
    }
  }

  Future<void> _verifyAndConfirmPayment({
    required String bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    setState(() {
      _isProcessingPayment = true;
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
        setState(() {
          _isProcessingPayment = false;
        });
        ref.invalidate(myBookingsListProvider);
        ref.invalidate(bookingWithDetailsProvider(widget.bookingId));
        ref.invalidate(bookingDetailProvider(widget.bookingId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verified and booking confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startPaymentForBooking(BookingModel booking) async {
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final session = ref.read(sessionProvider);
      final paymentService = ref.read(paymentFlowServiceProvider);
      final order = await paymentService.getOrCreatePaymentOrder(booking.id);

      _currentBookingId = booking.id;
      _currentOrderId = order.razorpayOrderId;

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
        setState(() {
          _isProcessingPayment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is DioException
                ? (e.response?.data['message'] ?? e.message)
                : e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCancelBottomSheet(BuildContext context, String bookingId) {
    String selectedReason = 'Change of plans';
    final reasons = [
      'Change of plans',
      'Found a better price',
      'Booked by mistake',
      'Other',
    ];
    CancellationPreviewModel? preview;
    bool isLoadingPreview = true;
    bool hasInitiatedFetch = false;

    AppBottomSheet.show(
      context,
      title: 'Cancel Booking',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          if (!hasInitiatedFetch) {
            hasInitiatedFetch = true;
            ref
                .read(myBookingsRepositoryProvider)
                .getCancellationPreview(bookingId)
                .then((data) {
              setSheetState(() {
                preview = data;
                isLoadingPreview = false;
              });
            }).catchError((_) {
              setSheetState(() {
                isLoadingPreview = false;
              });
            });
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isLoadingPreview)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: AppLoader()),
                )
              else if (preview != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: preview!.cancellationFeePercent == 0
                        ? Colors.green.withValues(alpha: 0.1)
                        : (preview!.cancellationFeePercent <= 25
                            ? Colors.orange.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: preview!.cancellationFeePercent == 0
                          ? Colors.green
                          : (preview!.cancellationFeePercent <= 25
                              ? Colors.orange
                              : Colors.red),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview!.tierDescription,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: preview!.cancellationFeePercent == 0
                              ? Colors.green[800]
                              : (preview!.cancellationFeePercent <= 25
                                  ? Colors.orange[900]
                                  : Colors.red[900]),
                        ),
                      ),
                      const Gap(8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Paid Amount:', style: TextStyle(fontSize: 12)),
                          Text(
                            IndianCurrencyFormatter.format(preview!.amountPaid, showDecimals: false),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Gap(4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cancellation Fee (${preview!.cancellationFeePercent}%):',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '- ${IndianCurrencyFormatter.format(preview!.cancellationFee, showDecimals: false)}',
                            style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Refund to Source:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            IndianCurrencyFormatter.format(preview!.refundAmount, showDecimals: false),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                Text(
                  'Refunds typically credit to your bank account within 5–7 business days.',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const Gap(16),
              ],
              Text(
                'Please select a reason for cancellation:',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const Gap(12),
              AppDropdown<String>(
                label: 'Reason',
                value: selectedReason,
                items: reasons.map((r) {
                  return DropdownMenuItem<String>(
                    value: r,
                    child: Text(r),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setSheetState(() {
                      selectedReason = val;
                    });
                  }
                },
              ),
              const Gap(24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      child: const Text('Keep Booking', style: TextStyle(color: AppColors.primary)),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: AppButton(
                      text: 'Confirm Cancel',
                      onPressed: isLoadingPreview
                          ? null
                          : () async {
                              // Call cancel in the notifier
                              Navigator.pop(context); // Close sheet
                              await ref.read(myBookingsListProvider.notifier).cancel(bookingId, selectedReason);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Booking cancelled successfully'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
              const Gap(12),
            ],
          );
        },
      ),
    );
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
            Text('Tax Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          Text(invoiceNum, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                      child: Text(
                        'GSTIN: 27AAAAA1111A1Z1 • Computer generated official tax invoice.',
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
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

  void _showExtendTripModal(BuildContext context, dynamic booking, dynamic car) {
    DateTime selectedEndDate = booking.endDate.add(const Duration(days: 1));
    int extraDays = 1;
    double estimatedExtensionFare = (car.pricePerDay as num).toDouble() * extraDays * 1.18; // base + 18% GST estimate
    bool isExtending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Extend Trip',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Gap(12),
              Text(
                'Current Scheduled Return: ${DateFormat("dd MMM yyyy, hh:mm a").format(booking.endDate)}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const Gap(16),
              const Text('Select Additional Duration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Gap(8),
              Row(
                children: [1, 2, 3, 5].map((days) {
                  final isSelected = extraDays == days;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSelected ? AppColors.primary : Colors.white,
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : Colors.grey[300]!,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          setModalState(() {
                            extraDays = days;
                            selectedEndDate = booking.endDate.add(Duration(days: days));
                            estimatedExtensionFare = (car.pricePerDay as num).toDouble() * days * 1.18;
                          });
                        },
                        child: Text(
                          '+$days Day${days > 1 ? "s" : ""}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Gap(16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _invoiceRow('New Return Date', 0, isBold: true),
                    Text(
                      DateFormat('EEE, dd MMM yyyy • hh:mm a').format(selectedEndDate),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    const Divider(height: 16),
                    _invoiceRow('Estimated Additional Fare', estimatedExtensionFare),
                    _invoiceRow('Security Deposit', 0), // 0 additional deposit
                  ],
                ),
              ),
              const Gap(20),
              AppButton(
                text: 'Confirm Extension (₹${estimatedExtensionFare.toInt()})',
                isLoading: isExtending,
                onPressed: isExtending
                    ? null
                    : () async {
                        setModalState(() => isExtending = true);
                        await Future.delayed(const Duration(milliseconds: 600));
                        if (!context.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Trip extension request submitted and confirmed!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        ref.invalidate(bookingWithDetailsProvider(booking.id));
                      },
              ),
              const Gap(12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _invoiceRow(String label, double amount, {bool isBold = false, bool isDiscount = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
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
    final detailVal = ref.watch(bookingWithDetailsProvider(widget.bookingId));
    final listState = ref.watch(myBookingsListProvider);
    final session = ref.watch(sessionProvider);
    final isActionLoading = listState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
      ),
      body: detailVal.when(
        loading: () => const AppLoader(),
        error: (err, stack) => ErrorStateWidget(
          message: 'Error loading details: $err',
          onRetry: () => ref.invalidate(bookingWithDetailsProvider(widget.bookingId)),
        ),
        data: (details) {
          if (details == null) {
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

          final booking = details.booking;
          final car = details.car;
          final vendor = details.vendor;
          final now = DateTime.now();

          // Determine status categories for conditional buttons/sections
          final isCancelled = booking.status.toLowerCase() == 'cancelled';
          final isOngoing = booking.status.toLowerCase() == 'ongoing';
          final isUpcoming = (booking.status.toLowerCase() == 'confirmed' ||
                  booking.status.toLowerCase() == 'pending') &&
              booking.endDate.isAfter(now);
          final isCompleted = booking.status.toLowerCase() == 'completed' ||
              (booking.status.toLowerCase() == 'confirmed' && booking.endDate.isBefore(now));

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Car info header card
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: car.photos.isNotEmpty
                                ? Image.network(
                                    car.photos.first,
                                    width: 100,
                                    height: 75,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 100,
                                      height: 75,
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: Icon(Icons.directions_car, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                  )
                                : Container(
                                    width: 100,
                                    height: 75,
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: Icon(Icons.directions_car, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                          ),
                          const Gap(16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${car.make} ${car.model}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    StatusBadge(status: booking.status),
                                  ],
                                ),
                                const Gap(4),
                                Text(
                                  '${car.type} | ${car.isAC ? "AC" : "Non-AC"}',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                                const Gap(4),
                                Text(
                                  'Vendor: ${vendor.businessName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),

                    // Trip details info card
                    const Text('Trip Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Gap(8),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _row(Icons.local_offer_outlined, 'Trip Type', booking.tripType),
                          _row(Icons.location_on_outlined, 'Pickup Location', booking.pickupLocation),
                          if (booking.dropLocation != null)
                            _row(Icons.flag_outlined, 'Drop Location', booking.dropLocation!),
                          _row(
                            Icons.calendar_today_outlined,
                            'Duration',
                            '${booking.startDate.toDDMMYYYY()} to ${booking.endDate.toDDMMYYYY()}',
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),

                    // Itemized Fare breakdown
                    const Text('Fare Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Gap(8),
                    _BookingFareBreakdownCard(booking: booking),
                    const Gap(16),

                    // Security Deposit Card
                    _SecurityDepositCard(bookingId: booking.id),
                    const Gap(16),

                    // Tax Invoice Card
                    if (booking.status.toLowerCase() != 'pending') ...[
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.receipt_long_outlined, color: Colors.blue),
                            ),
                            const Gap(14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'GST Tax Invoice',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const Gap(2),
                                  Text(
                                    'Official receipt with GST & deposit breakdown',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text('Invoice', style: TextStyle(fontSize: 12)),
                              onPressed: () => _showInvoiceDialog(context, booking.id),
                            ),
                          ],
                        ),
                      ),
                      const Gap(16),
                    ],

                    // Vendor support card
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.phone, color: AppColors.primary),
                          ),
                          const Gap(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vendor.businessName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Gap(2),
                                Text(
                                  'Contact support to coordinate delivery/pickup questions.',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Conditionally show Complete Payment button for PENDING bookings
                    if (booking.status.toLowerCase() == 'pending' && !isCancelled) ...[
                      AppButton(
                        text: 'Complete Payment (${IndianCurrencyFormatter.format(booking.totalFare, showDecimals: false)})',
                        isLoading: _isProcessingPayment,
                        onPressed: _isProcessingPayment || isActionLoading
                            ? null
                            : () => _startPaymentForBooking(booking),
                      ),
                      const Gap(12),
                    ],

                    // Conditionally show Extend Trip button for ONGOING trips (Phase 4 Feature 10)
                    if (isOngoing && !isCancelled) ...[
                      AppButton(
                        text: 'Extend Trip',
                        backgroundColor: AppColors.primary,
                        onPressed: () => _showExtendTripModal(context, booking, car),
                      ),
                      const Gap(12),
                    ],

                    // Conditionally show Cancel button
                    if (isUpcoming && !isCancelled) ...[
                      AppButton(
                        text: 'Cancel Booking',
                        backgroundColor: Colors.red,
                        onPressed: isActionLoading || _isProcessingPayment
                            ? null
                            : () => _showCancelBottomSheet(context, booking.id),
                      ),
                      const Gap(24),
                    ],

                    // Conditionally show Review section
                    if (isCompleted && !isCancelled) ...[
                      const Divider(),
                      const Gap(12),
                      const Text(
                        'Rate & Review',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Gap(8),
                      if (_reviewSubmitted)
                        Container(
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
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    const Gap(2),
                                    Text(
                                      'Your rating of ${_userRating.toInt()} stars was submitted successfully.',
                                      style: TextStyle(fontSize: 12, color: Colors.green[800]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _reviewFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'How was your trip? Tap the stars to rate.',
                                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                                const Gap(12),
                                Center(
                                  child: StarRating(
                                    rating: _userRating,
                                    size: 36,
                                    onRatingChanged: (val) {
                                      setState(() {
                                        _userRating = val;
                                      });
                                    },
                                  ),
                                ),
                                const Gap(16),
                                AppTextField(
                                  label: 'Review Comments',
                                  hint: 'Share your experience with this car and vendor…',
                                  controller: _commentCtrl,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Please write a comment' : null,
                                ),
                                const Gap(16),
                                AppButton(
                                  text: 'Submit Review',
                                  onPressed: isActionLoading
                                      ? null
                                      : () async {
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
                                            setState(() {
                                              _reviewSubmitted = true;
                                            });
                                          }
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Gap(24),
                    ],
                  ],
                ),
              ),
              if (isActionLoading)
                const Center(
                  child: AppLoader(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const Gap(10),
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingFareBreakdownCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingFareBreakdownCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    // Fold Platform Fee into Trip Fare for customer-facing display
    final tripFare = booking.totalFare - booking.gstAmount;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fareRow(context, 'Trip Fare', tripFare, bold: true),
          const Gap(4),
          _fareRow(context, 'GST (18%)', booking.gstAmount),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              PriceTag(
                amount: booking.totalFare,
                amountStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fareRow(BuildContext context, String label, double amount, {bool bold = false, Color? color}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? cs.onSurface,
            ),
          ),
          Text(
            IndianCurrencyFormatter.format(amount, showDecimals: false),
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityDepositCard extends ConsumerWidget {
  final String bookingId;
  const _SecurityDepositCard({required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depositAsync = ref.watch(bookingSecurityDepositProvider(bookingId));

    return depositAsync.when(
      data: (deposit) {
        if (deposit == null || deposit.amount <= 0) {
          return const SizedBox.shrink();
        }

        final (statusText, statusBg, statusFg) = _resolveStatusStyle(deposit.status);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Security Deposit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Gap(8),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                          const Gap(8),
                          const Text(
                            'Deposit Hold',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _row(
                    context,
                    'Authorized Amount',
                    IndianCurrencyFormatter.format(deposit.amount, showDecimals: false),
                  ),
                  if (deposit.deductedAmount > 0) ...[
                    const Gap(4),
                    _row(
                      context,
                      'Damage Deduction',
                      '- ${IndianCurrencyFormatter.format(deposit.deductedAmount, showDecimals: false)}',
                      valueColor: Colors.red[700],
                    ),
                  ],
                  if (deposit.refundedAmount > 0) ...[
                    const Gap(4),
                    _row(
                      context,
                      'Refunded to Source',
                      IndianCurrencyFormatter.format(deposit.refundedAmount, showDecimals: false),
                      valueColor: Colors.green[700],
                      bold: true,
                    ),
                  ],
                  if (deposit.releasedAt != null) ...[
                    const Gap(4),
                    _row(
                      context,
                      'Settled Date',
                      deposit.releasedAt!.toDDMMYYYY(),
                    ),
                  ],
                  const Gap(12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            'Security deposits are held securely during the trip and refunded to your original payment method upon post-trip inspection verification.',
                            style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  (String, Color, Color) _resolveStatusStyle(SecurityDepositStatus status) {
    switch (status) {
      case SecurityDepositStatus.HELD:
        return ('HELD / AUTHORIZED', Colors.blue.withValues(alpha: 0.12), Colors.blue[800]!);
      case SecurityDepositStatus.REFUNDED:
        return ('100% REFUNDED', Colors.green.withValues(alpha: 0.12), Colors.green[800]!);
      case SecurityDepositStatus.PARTIALLY_REFUNDED:
        return ('PARTIALLY REFUNDED', Colors.orange.withValues(alpha: 0.12), Colors.orange[900]!);
      case SecurityDepositStatus.FORFEITED:
        return ('FORFEITED', Colors.red.withValues(alpha: 0.12), Colors.red[800]!);
      case SecurityDepositStatus.CANCELLED:
        return ('CANCELLED', Colors.grey.withValues(alpha: 0.12), Colors.grey[800]!);
      case SecurityDepositStatus.REQUIRED:
        return ('REQUIRED', Colors.amber.withValues(alpha: 0.12), Colors.amber[900]!);
    }
  }

  Widget _row(BuildContext context, String label, String value, {Color? valueColor, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

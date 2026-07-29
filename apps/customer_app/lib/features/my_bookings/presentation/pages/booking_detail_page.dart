import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/my_bookings_providers.dart';
import '../../../booking/presentation/providers/booking_providers.dart';
import '../../../../core/providers/session_provider.dart';

class BookingDetailPage extends ConsumerStatefulWidget {
  final String bookingId;

  const BookingDetailPage({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends ConsumerState<BookingDetailPage> {
  // Local state to keep track of review submission
  bool _reviewSubmitted = false;
  double _userRating = 5.0;
  final _commentCtrl = TextEditingController();
  final _reviewFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _showCancelBottomSheet(BuildContext context, String bookingId) {
    String selectedReason = 'Change of plans';
    final reasons = [
      'Change of plans',
      'Found a better price',
      'Booked by mistake',
      'Other',
    ];

    AppBottomSheet.show(
      context,
      title: 'Cancel Booking',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Please select a reason for cancellation. This help us improve our services.',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const Gap(16),
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
                      onPressed: () async {
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
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _fareRow(
                            'Base Package',
                            booking.totalFare - booking.platformFee - booking.gstAmount,
                          ),
                          _fareRow('Platform Fee', booking.platformFee, color: Colors.orange[700]),
                          _fareRow('GST (18%)', booking.gstAmount, color: Colors.orange[700]),
                          const Divider(height: 24),
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
                    ),
                    const Gap(16),

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
                    const Gap(24),

                    // Conditionally show Cancel button
                    if (isUpcoming && !isCancelled) ...[
                      AppButton(
                        text: 'Cancel Booking',
                        backgroundColor: Colors.red,
                        onPressed: isActionLoading
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

  Widget _fareRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: color ?? Theme.of(context).colorScheme.onSurface)),
          Text(
            IndianCurrencyFormatter.format(amount, showDecimals: false),
            style: TextStyle(fontSize: 13, color: color ?? Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

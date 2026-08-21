import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../providers/my_bookings_providers.dart';
import '../../domain/repositories/my_bookings_repository.dart';

class BookingCancelModal extends ConsumerStatefulWidget {
  final String bookingId;

  const BookingCancelModal({
    super.key,
    required this.bookingId,
  });

  static Future<bool?> show(BuildContext context, {required String bookingId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingCancelModal(bookingId: bookingId),
    );
  }

  @override
  ConsumerState<BookingCancelModal> createState() => _BookingCancelModalState();
}

class _BookingCancelModalState extends ConsumerState<BookingCancelModal> {
  String _selectedReason = 'Change of travel plans';
  final _reasons = [
    'Change of travel plans',
    'Found a better alternative/price',
    'Trip postponed / rescheduled',
    'Vehicle or location requirement changed',
    'Booked by mistake',
    'Other reason',
  ];

  CancellationPreviewModel? _preview;
  bool _isLoadingPreview = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchPreview();
  }

  Future<void> _fetchPreview() async {
    try {
      final repo = ref.read(myBookingsRepositoryProvider);
      final preview = await repo.getCancellationPreview(widget.bookingId);
      if (mounted) {
        setState(() {
          _preview = preview;
          _isLoadingPreview = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPreview = false);
      }
    }
  }

  Future<void> _confirmCancellation() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(myBookingsListProvider.notifier).cancel(widget.bookingId, _selectedReason);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
                  Gap(10),
                  Text(
                    'Cancel Booking',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Gap(16),

          if (_isLoadingPreview)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: AppLoader()),
            )
          else if (_preview != null) ...[
            // Policy Breakdown Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _preview!.cancellationFeePercent == 0
                    ? Colors.green.withValues(alpha: 0.08)
                    : Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _preview!.cancellationFeePercent == 0
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.amber.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _preview!.cancellationFeePercent == 0 ? Icons.check_circle : Icons.info,
                        color: _preview!.cancellationFeePercent == 0 ? Colors.green[800] : Colors.amber[900],
                        size: 18,
                      ),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          _preview!.tierDescription,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _preview!.cancellationFeePercent == 0 ? Colors.green[900] : Colors.amber[950],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _row('Total Fare Paid', IndianCurrencyFormatter.format(_preview!.amountPaid, showDecimals: false)),
                  if (_preview!.cancellationFee > 0)
                    _row('Cancellation Fee (${_preview!.cancellationFeePercent}%)',
                        '- ${IndianCurrencyFormatter.format(_preview!.cancellationFee, showDecimals: false)}',
                        color: Colors.red[700]),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Refund to Original Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        IndianCurrencyFormatter.format(_preview!.refundAmount, showDecimals: false),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _preview!.refundAmount > 0 ? Colors.green[800] : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(16),

            const Text(
              'Select Cancellation Reason',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedReason,
                  isExpanded: true,
                  items: _reasons.map((r) {
                    return DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedReason = val);
                  },
                ),
              ),
            ),
            const Gap(16),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_outlined, size: 16, color: Colors.black54),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      'Approved refund of ${IndianCurrencyFormatter.format(_preview!.refundAmount, showDecimals: false)} will be credited to your original payment method in 5-7 business days.',
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(20),

            AppButton(
              text: 'Confirm Cancellation',
              backgroundColor: Colors.red[700],
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _confirmCancellation,
            ),
            const Gap(8),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

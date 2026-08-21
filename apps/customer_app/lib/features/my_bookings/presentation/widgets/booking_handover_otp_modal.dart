import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../providers/my_bookings_providers.dart';

class BookingHandoverOtpModal extends ConsumerStatefulWidget {
  final String bookingId;
  final String otpType; // 'PICKUP' or 'RETURN'

  const BookingHandoverOtpModal({
    super.key,
    required this.bookingId,
    required this.otpType,
  });

  static Future<void> show(
    BuildContext context, {
    required String bookingId,
    String otpType = 'PICKUP',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingHandoverOtpModal(
        bookingId: bookingId,
        otpType: otpType,
      ),
    );
  }

  @override
  ConsumerState<BookingHandoverOtpModal> createState() => _BookingHandoverOtpModalState();
}

class _BookingHandoverOtpModalState extends ConsumerState<BookingHandoverOtpModal> {
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _requestOtp();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(myBookingsRepositoryProvider);
      final success = await repo.sendHandoverOtp(widget.bookingId, widget.otpType);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = success;
          if (!success) {
            _errorMessage = 'Failed to generate handover OTP. Please try again.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPickup = widget.otpType == 'PICKUP';
    final title = isPickup ? 'Pickup Handover Verification' : 'Vehicle Return Verification';

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security_outlined, color: AppColors.primary),
                  ),
                  const Gap(10),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: AppLoader()),
            )
          else if (_isSuccess) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_read_outlined, size: 32, color: Colors.green),
                  ),
                  const Gap(12),
                  const Text(
                    'Handover OTP Dispatched',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Gap(6),
                  const Text(
                    'A secure 6-digit verification PIN has been sent to your registered mobile number and in-app notifications.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const Gap(12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                      const Gap(4),
                      Text(
                        'Valid for 15 minutes',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.black54),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      isPickup
                          ? 'Please inspect the vehicle (odometer, fuel, exterior) with the host before sharing your received 6-digit PIN to release the keys.'
                          : 'Share your received 6-digit return PIN with the host once final inspection is completed.',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Resend OTP'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _requestOtp,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: AppButton(
                    text: 'Done',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const Gap(8),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 32, color: Colors.red),
                  const Gap(8),
                  Text(
                    _errorMessage ?? 'Unable to generate handover OTP.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.red),
                  ),
                ],
              ),
            ),
            const Gap(20),
            AppButton(
              text: 'Try Again',
              onPressed: _requestOtp,
            ),
            const Gap(8),
          ],
        ],
      ),
    );
  }
}

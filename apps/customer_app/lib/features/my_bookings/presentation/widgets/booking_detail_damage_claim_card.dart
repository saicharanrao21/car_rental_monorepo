import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import '../providers/my_bookings_providers.dart';

class BookingDetailDamageClaimCard extends ConsumerWidget {
  final String bookingId;

  const BookingDetailDamageClaimCard({
    super.key,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(bookingDamageClaimsProvider(bookingId));

    return claimsAsync.when(
      data: (claims) {
        if (claims.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: claims.map((claim) => _ClaimItemCard(claim: claim, bookingId: bookingId)).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const Gap(10),
            Expanded(
              child: Text(
                _formatErrorMessage(err),
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: Colors.red),
              onPressed: () => ref.invalidate(bookingDamageClaimsProvider(bookingId)),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatErrorMessage(dynamic err) {
    if (err is DioException) {
      final statusCode = err.response?.statusCode;
      if (statusCode == 401) return 'Session expired. Please log in again to view damage claims.';
      if (statusCode == 403) return 'You are not authorized to view claims for this trip.';
      if (statusCode == 404) return 'No damage claim records found.';
      if (statusCode == 409) return 'Conflict: Claim is currently undergoing concurrent state modification.';
      if (statusCode == 422) return 'Invalid claim request data.';
      if (statusCode != null && statusCode >= 500) return 'Server error loading damage claims. Please try again later.';
      if (err.type == DioExceptionType.connectionTimeout ||
          err.type == DioExceptionType.connectionError ||
          err.type == DioExceptionType.receiveTimeout) {
        return 'Network connection issue. Check internet and retry.';
      }
      final msg = err.response?.data?['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return 'Unable to load damage claims.';
  }
}

class _ClaimItemCard extends ConsumerStatefulWidget {
  final DamageClaimModel claim;
  final String bookingId;

  const _ClaimItemCard({
    required this.claim,
    required this.bookingId,
  });

  @override
  ConsumerState<_ClaimItemCard> createState() => _ClaimItemCardState();
}

class _ClaimItemCardState extends ConsumerState<_ClaimItemCard> {
  void _showDisputeModal(BuildContext context) {
    final disputeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dispute Damage Claim',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  'Provide detailed reasons or counter-evidence regarding the claimed vehicle damages. Our administrative disputes team will review the inspection records.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
                ),
                const Gap(16),
                AppTextField(
                  label: 'Dispute Notes (min 10 characters)',
                  controller: disputeCtrl,
                  maxLines: 4,
                  hint: 'Explain pre-existing damage, dispute incident details, etc...',
                  validator: (val) {
                    if (val == null || val.trim().length < 10) {
                      return 'Please provide at least 10 characters explaining your dispute.';
                    }
                    return null;
                  },
                ),
                const Gap(16),
                AppButton(
                  text: isSubmitting ? 'Submitting Dispute...' : 'Submit Official Dispute',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() => isSubmitting = true);

                          try {
                            final repo = ref.read(myBookingsRepositoryProvider);
                            await repo.disputeDamageClaim(
                              claimId: widget.claim.id,
                              notes: disputeCtrl.text.trim(),
                            );

                            ref.invalidate(bookingDamageClaimsProvider(widget.bookingId));
                            if (ctx.mounted) Navigator.pop(ctx);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text('Your dispute has been recorded and submitted for administrator review.'),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            String errorMsg = 'Failed to submit dispute.';
                            if (e is DioException) {
                              final msg = e.response?.data?['message'];
                              if (msg is String) errorMsg = msg;
                            }
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(backgroundColor: Colors.red, content: Text(errorMsg)),
                              );
                            }
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPhotoViewer(BuildContext context, String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('Unable to load photo', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.claim;
    final (statusLabel, statusBg, statusFg) = _resolveClaimStatusStyle(c.status);
    final canDispute = (c.status == DamageClaimStatus.SUBMITTED || c.status == DamageClaimStatus.UNDER_REVIEW) &&
        (c.customerDispute == null || c.customerDispute!.isEmpty);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.car_crash_outlined, size: 20, color: Colors.red),
                  const Gap(8),
                  Text(
                    'Damage Claim #${c.id.length > 8 ? c.id.substring(0, 8).toUpperCase() : c.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                  statusLabel,
                  style: TextStyle(color: statusFg, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Financial Impact
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Claimed Repair Cost:', style: TextStyle(fontSize: 13, color: Colors.black87)),
              Text(
                IndianCurrencyFormatter.format(c.claimedAmount, showDecimals: false),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
              ),
            ],
          ),
          if (c.approvedAmount != null) ...[
            const Gap(6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Approved Deposit Deduction:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                Text(
                  IndianCurrencyFormatter.format(c.approvedAmount!, showDecimals: false),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                ),
              ],
            ),
          ],
          const Gap(8),
          _buildFinancialImpactBanner(c),

          // Damage Description
          if (c.description.isNotEmpty) ...[
            const Gap(12),
            const Text('Damage Details:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const Gap(4),
            Text(
              c.description,
              style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.3),
            ),
          ],

          // Photographic Evidence
          if (c.damagePhotos.isNotEmpty) ...[
            const Gap(12),
            Text(
              'Photographic Evidence (${c.damagePhotos.length}):',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const Gap(8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.damagePhotos.length,
                separatorBuilder: (_, __) => const Gap(8),
                itemBuilder: (context, idx) {
                  final photo = c.damagePhotos[idx];
                  return GestureDetector(
                    onTap: () => _showPhotoViewer(context, photo),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        photo,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // Adjudication Notes
          if (c.adminNotes != null && c.adminNotes!.isNotEmpty) ...[
            const Gap(12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel, size: 14, color: Colors.blue),
                      Gap(6),
                      Text(
                        'Admin Adjudication Finding',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                  const Gap(4),
                  Text(
                    c.adminNotes!,
                    style: TextStyle(fontSize: 11.5, color: Colors.blue[900], height: 1.3),
                  ),
                ],
              ),
            ),
          ],

          // Customer Dispute Status
          if (c.customerDispute != null && c.customerDispute!.isNotEmpty) ...[
            const Gap(12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                      Gap(6),
                      Text(
                        'Your Dispute Statement',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                  const Gap(4),
                  Text(
                    c.customerDispute!,
                    style: TextStyle(fontSize: 11.5, color: Colors.orange[900], height: 1.3),
                  ),
                ],
              ),
            ),
          ],

          // Dispute Button
          if (canDispute) ...[
            const Gap(14),
            OutlinedButton.icon(
              icon: const Icon(Icons.gavel_outlined, size: 16),
              label: const Text('Dispute This Claim'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[800],
                side: BorderSide(color: Colors.red[300]!),
                minimumSize: const Size(double.infinity, 38),
              ),
              onPressed: () => _showDisputeModal(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialImpactBanner(DamageClaimModel c) {
    String text;
    Color bg;
    Color border;
    Color fg;

    switch (c.status) {
      case DamageClaimStatus.REJECTED:
        text = 'Claim was rejected after review. Your full security deposit is released with zero deduction.';
        bg = Colors.green.withValues(alpha: 0.08);
        border = Colors.green.withValues(alpha: 0.3);
        fg = Colors.green[900]!;
        break;
      case DamageClaimStatus.APPROVED:
      case DamageClaimStatus.PARTIALLY_APPROVED:
      case DamageClaimStatus.SETTLED:
        text = 'Approved repair deduction has been settled from your security deposit. Any remaining balance is refunded to source.';
        bg = Colors.amber.withValues(alpha: 0.08);
        border = Colors.amber.withValues(alpha: 0.3);
        fg = Colors.amber[900]!;
        break;
      case DamageClaimStatus.SUBMITTED:
      case DamageClaimStatus.UNDER_REVIEW:
        text = 'Deposit refund is temporarily held while claims review verifies pre/post trip photos.';
        bg = Colors.blue.withValues(alpha: 0.08);
        border = Colors.blue.withValues(alpha: 0.3);
        fg = Colors.blue[900]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg, height: 1.3)),
    );
  }

  (String, Color, Color) _resolveClaimStatusStyle(DamageClaimStatus status) {
    switch (status) {
      case DamageClaimStatus.SUBMITTED:
        return ('CLAIM SUBMITTED', Colors.blue.withValues(alpha: 0.12), Colors.blue[800]!);
      case DamageClaimStatus.UNDER_REVIEW:
        return ('UNDER REVIEW', Colors.orange.withValues(alpha: 0.12), Colors.orange[900]!);
      case DamageClaimStatus.APPROVED:
        return ('CLAIM APPROVED', Colors.red.withValues(alpha: 0.12), Colors.red[800]!);
      case DamageClaimStatus.PARTIALLY_APPROVED:
        return ('PARTIALLY APPROVED', Colors.amber.withValues(alpha: 0.12), Colors.amber[900]!);
      case DamageClaimStatus.REJECTED:
        return ('CLAIM REJECTED', Colors.green.withValues(alpha: 0.12), Colors.green[800]!);
      case DamageClaimStatus.SETTLED:
        return ('SETTLED', Colors.grey.withValues(alpha: 0.12), Colors.grey[800]!);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../providers/my_bookings_providers.dart';

class BookingDetailDepositCard extends ConsumerWidget {
  final String bookingId;

  const BookingDetailDepositCard({
    super.key,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depositAsync = ref.watch(bookingSecurityDepositProvider(bookingId));

    return depositAsync.when(
      data: (deposit) {
        if (deposit == null || deposit.amount <= 0) {
          return const SizedBox.shrink();
        }

        final (statusText, statusBg, statusFg) = _resolveStatusStyle(deposit.status);

        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                      Gap(8),
                      Text(
                        'Security Deposit Status',
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
                      style: TextStyle(color: statusFg, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _row(
                context,
                'Pre-Authorized Amount',
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
                  'Refunded to Source Bank',
                  IndianCurrencyFormatter.format(deposit.refundedAmount, showDecimals: false),
                  valueColor: Colors.green[700],
                  bold: true,
                ),
              ],
              if (deposit.releasedAt != null) ...[
                const Gap(4),
                _row(
                  context,
                  'Settled On',
                  deposit.releasedAt!.toDDMMYYYY(),
                ),
              ],
              const Gap(12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        'Security deposits are held securely during the trip and refunded to your original payment method automatically upon post-trip vehicle return inspection.',
                        style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  (String, Color, Color) _resolveStatusStyle(SecurityDepositStatus status) {
    switch (status) {
      case SecurityDepositStatus.HELD:
        return ('HELD / SECURE', Colors.blue.withValues(alpha: 0.12), Colors.blue[800]!);
      case SecurityDepositStatus.REFUNDED:
        return ('100% REFUNDED', Colors.green.withValues(alpha: 0.12), Colors.green[800]!);
      case SecurityDepositStatus.PARTIALLY_REFUNDED:
        return ('PARTIALLY REFUNDED', Colors.orange.withValues(alpha: 0.12), Colors.orange[900]!);
      case SecurityDepositStatus.FORFEITED:
        return ('FORFEITED', Colors.red.withValues(alpha: 0.12), Colors.red[800]!);
      case SecurityDepositStatus.CANCELLED:
        return ('RELEASED / CANCELLED', Colors.grey.withValues(alpha: 0.12), Colors.grey[800]!);
      case SecurityDepositStatus.REQUIRED:
        return ('PAYMENT REQUIRED', Colors.amber.withValues(alpha: 0.12), Colors.amber[900]!);
    }
  }

  Widget _row(BuildContext context, String label, String value, {Color? valueColor, bool bold = false}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? cs.onSurface,
          ),
        ),
      ],
    );
  }
}

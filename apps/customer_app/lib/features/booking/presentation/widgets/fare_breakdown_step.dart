import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';
import '../providers/booking_providers.dart';

class FareBreakdownStep extends ConsumerWidget {
  final CarModel car;
  final VendorModel vendor;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const FareBreakdownStep({
    super.key,
    required this.car,
    required this.vendor,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftProvider);
    final repo = ref.watch(bookingRepositoryProvider);

    // Compute fare on every relevant change
    final config = repo.getCommissionConfig(
      city: vendor.city,
      carCategory: car.type,
      tripType: draft.tripType,
    );
    final result = FareCalculatorService.calculateFare(
      distanceKm: draft.estimatedDistanceKm.toDouble(),
      basePackagePrice: car.pricePerDay * draft.rentalDays,
      pricePerKm: car.pricePerKm,
      commissionPercent: config.percentage,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Your fare is calculated based on distance, duration, and applicable platform commission.',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const Gap(16),

          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _row('Rental (${draft.rentalDays}d × ₹${car.pricePerDay.toInt()}/day)',
                    car.pricePerDay * draft.rentalDays),
                _row('Distance (${draft.estimatedDistanceKm}km × ₹${car.pricePerKm.toInt()}/km)',
                    car.pricePerKm * draft.estimatedDistanceKm),
                const Divider(height: 24),
                _row('Base Fare', result.baseFare, bold: true),
                _row('Platform Fee (${config.percentage.toInt()}%)', result.platformFee,
                    color: Colors.orange[700]),
                _row('GST (18% on platform fee)', result.gst, color: Colors.orange[700]),
                const Divider(height: 24),
                _row('Total Payable', result.total,
                    bold: true, color: AppColors.primary, fontSize: 20),
                const Gap(4),
                _row('Vendor Receives', result.netToVendor, color: Colors.grey),
              ],
            ),
          ),
          const Gap(16),

          // Add-ons summary
          if (draft.driverIncluded || draft.childSeat || draft.extraLuggage)
            _addOnsSummary(draft),

          const Gap(8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: const Row(children: [
              Icon(Icons.verified_outlined, color: Colors.green, size: 16),
              Gap(8),
              Expanded(
                child: Text(
                  'No hidden charges. Price locked at confirmation.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ]),
          ),
          const Gap(24),

          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
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
                text: 'Next: Contact',
                onPressed: () {
                  // Persist fare onto draft before moving forward
                  ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                    baseFare: result.baseFare,
                    platformFee: result.platformFee,
                    gst: result.gst,
                    totalFare: result.total,
                    netToVendor: result.netToVendor,
                    commissionPercent: config.percentage,
                  ));
                  onNext();
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _addOnsSummary(BookingDraft draft) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add-ons Requested',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Gap(8),
              if (draft.driverIncluded)
                const _AddOnChip(Icons.person, 'Driver Included'),
              if (draft.childSeat) const _AddOnChip(Icons.child_care, 'Child Seat'),
              if (draft.extraLuggage)
                const _AddOnChip(Icons.luggage_outlined, 'Extra Luggage'),
            ],
          ),
        ),
      );

  Widget _row(String label, double amount,
      {bool bold = false, Color? color, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                      color: color ?? Colors.black87))),
          Text(
            IndianCurrencyFormatter.format(amount, showDecimals: false),
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _AddOnChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AddOnChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const Gap(6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      );
}

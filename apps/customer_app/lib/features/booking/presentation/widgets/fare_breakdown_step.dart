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

    final rentalDays = draft.rentalDays;
    double discountPercent = 0.0;
    String discountLabel = '';

    final weeklyPct = (car.weeklyDiscountPercent != null && car.weeklyDiscountPercent! > 0)
        ? car.weeklyDiscountPercent!
        : 15.0;
    final monthlyPct = (car.monthlyDiscountPercent != null && car.monthlyDiscountPercent! > 0)
        ? car.monthlyDiscountPercent!
        : 25.0;

    if (rentalDays >= 30) {
      discountPercent = monthlyPct;
      discountLabel = 'Monthly discount applied (${discountPercent.toInt()}%)';
    } else if (rentalDays >= 7) {
      discountPercent = weeklyPct;
      discountLabel = 'Weekly discount applied (${discountPercent.toInt()}%)';
    }

    final originalRentalFare = car.pricePerDay * rentalDays;
    final discountAmount = originalRentalFare * (discountPercent / 100.0);
    final actualBasePackagePrice = originalRentalFare - discountAmount;

    // Compute fare on every relevant change
    final config = repo.getCommissionConfig(
      city: vendor.city,
      carCategory: car.type,
      tripType: draft.tripType,
    );
    final result = FareCalculatorService.calculateFare(
      distanceKm: draft.estimatedDistanceKm.toDouble(),
      basePackagePrice: actualBasePackagePrice,
      pricePerKm: car.pricePerKm,
      commissionPercent: config.percentage,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your fare is calculated based on distance, duration, and applicable platform commission.',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Gap(16),

          _CollapsibleFareCard(
            context: context,
            draft: draft,
            car: car,
            originalRentalFare: originalRentalFare,
            discountPercent: discountPercent,
            discountLabel: discountLabel,
            discountAmount: discountAmount,
            result: result,
            config: config,
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
}

class _CollapsibleFareCard extends StatelessWidget {
  final BuildContext context;
  final BookingDraft draft;
  final CarModel car;
  final double originalRentalFare;
  final double discountPercent;
  final String discountLabel;
  final double discountAmount;
  final FareCalculatorResult result;
  final CommissionConfigModel config;

  const _CollapsibleFareCard({
    required this.context,
    required this.draft,
    required this.car,
    required this.originalRentalFare,
    required this.discountPercent,
    required this.discountLabel,
    required this.discountAmount,
    required this.result,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    // Fold Platform Fee into Trip Fare for customer display
    final tripFare = result.baseFare + result.platformFee;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Trip Fare (base + platform fee folded together)
          _row(context, 'Trip Fare', tripFare, bold: true),

          // Sub-details for rental and distance
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2, bottom: 4),
            child: Column(
              children: [
                _subRow(context, 'Rental (${draft.rentalDays}d × ₹${car.pricePerDay.toInt()}/day)', originalRentalFare),
                _subRow(context, 'Distance (${draft.estimatedDistanceKm}km × ₹${car.pricePerKm.toInt()}/km)', car.pricePerKm * draft.estimatedDistanceKm),
              ],
            ),
          ),

          // Multi-day discount (visible by default when applicable)
          if (discountPercent > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.local_offer, size: 12, color: Colors.green[700]),
                        const Gap(4),
                        Text(
                          discountLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-${IndianCurrencyFormatter.format(discountAmount, showDecimals: false)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 20),

          // 2. GST line (tax compliance)
          _row(context, 'GST (18%)', result.gst),

          const Divider(height: 20),

          // 3. Total Payable
          _row(
            context,
            'Total Payable',
            result.total,
            bold: true,
            color: Theme.of(context).colorScheme.primary,
            fontSize: 18,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, double amount, {bool bold = false, Color? color, double fontSize = 13}) {
    final defaultColor = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color ?? defaultColor,
              ),
            ),
          ),
          Text(
            IndianCurrencyFormatter.format(amount, showDecimals: false),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? defaultColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subRow(BuildContext context, String label, double amount, {Color? color}) {
    final defaultColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: color ?? defaultColor),
            ),
          ),
          Text(
            IndianCurrencyFormatter.format(amount, showDecimals: false),
            style: TextStyle(fontSize: 12, color: color ?? defaultColor),
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

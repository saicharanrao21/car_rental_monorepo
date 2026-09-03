import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../../location/presentation/widgets/location_selection_sheet.dart';
import '../providers/booking_flow_providers.dart';
import '../providers/booking_providers.dart';

enum FulfillmentMode {
  hostYard,
  publicTransit,
  doorstep,
}

class FulfillmentSelectionCard extends ConsumerStatefulWidget {
  final CarModel car;
  final VendorModel vendor;

  const FulfillmentSelectionCard({
    super.key,
    required this.car,
    required this.vendor,
  });

  @override
  ConsumerState<FulfillmentSelectionCard> createState() =>
      _FulfillmentSelectionCardState();
}

class _FulfillmentSelectionCardState
    extends ConsumerState<FulfillmentSelectionCard> {
  late final TextEditingController _deliveryAddressController;
  late final TextEditingController _collectionAddressController;
  Timer? _debounceTimer;

  FulfillmentMode _pickupMode = FulfillmentMode.hostYard;
  FulfillmentMode _returnMode = FulfillmentMode.hostYard;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider);

    _deliveryAddressController =
        TextEditingController(text: draft.deliveryAddress);
    _collectionAddressController =
        TextEditingController(text: draft.returnPickupAddress);

    if (draft.hasDoorstepDelivery) {
      _pickupMode = FulfillmentMode.doorstep;
    } else if (draft.pickupName != null &&
        (draft.pickupName!.toLowerCase().contains('airport') ||
            draft.pickupName!.toLowerCase().contains('station'))) {
      _pickupMode = FulfillmentMode.publicTransit;
    } else {
      _pickupMode = FulfillmentMode.hostYard;
    }

    if (draft.hasDoorstepPickup) {
      _returnMode = FulfillmentMode.doorstep;
    } else if (draft.dropName != null &&
        (draft.dropName!.toLowerCase().contains('airport') ||
            draft.dropName!.toLowerCase().contains('station'))) {
      _returnMode = FulfillmentMode.publicTransit;
    } else {
      _returnMode = FulfillmentMode.hostYard;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _deliveryAddressController.dispose();
    _collectionAddressController.dispose();
    super.dispose();
  }

  void _onAddressChanged(String val, {bool isReturn = false}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (isReturn) {
        ref.read(bookingDraftProvider.notifier).update(
              (d) => d.copyWith(returnPickupAddress: val),
            );
      } else {
        ref.read(bookingDraftProvider.notifier).update(
              (d) => d.copyWith(deliveryAddress: val),
            );
      }
      _refreshQuote();
    });
  }

  void _refreshQuote() {
    final repo = ref.read(bookingRepositoryProvider);
    ref.read(bookingDraftProvider.notifier).refreshAuthoritativeQuote(
          repo: repo,
          vendorId: widget.vendor.id,
          carId: widget.car.id,
        );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);

    return Container(
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
          // ── Card Header ───────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: DDSColors.primaryBlue,
                  size: 20,
                ),
              ),
              const Gap(DDSSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Handover & Fulfillment',
                      style: DDSTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DDSColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      'Choose how and where you pick up and return the vehicle',
                      style: DDSTypography.bodyMedium.copyWith(
                        color: DDSColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(DDSSpacing.sm),
          const Divider(height: 1, color: DDSColors.borderLight),
          const Gap(DDSSpacing.md),

          // ── SECTION 1: PICKUP METHOD ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '1. PICKUP METHOD',
                  style: DDSTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DDSColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (draft.pickupFee > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: DDSColors.infoBlueBg,
                    borderRadius: DDSRadius.smallBorderRadius,
                  ),
                  child: Text(
                    '+₹${draft.pickupFee.toInt()} Hub Fee',
                    style: DDSTypography.labelSmall.copyWith(
                      color: DDSColors.primaryBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const Gap(DDSSpacing.xs),
          _buildModeSelector(
            currentMode: _pickupMode,
            onChanged: (mode) {
              setState(() {
                _pickupMode = mode;
              });
              if (mode == FulfillmentMode.doorstep) {
                ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                      hasDoorstepDelivery: true,
                      deliveryType: 'DOORSTEP_DELIVERY',
                    ));
              } else {
                ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                      hasDoorstepDelivery: false,
                      deliveryType: mode == FulfillmentMode.hostYard
                          ? 'HUB_PICKUP'
                          : 'PUBLIC_LOCATION',
                    ));
              }
              _refreshQuote();
            },
          ),
          const Gap(DDSSpacing.sm),
          _buildPickupDetails(draft),

          const Gap(DDSSpacing.md),
          const Divider(height: 1, color: DDSColors.borderLight),
          const Gap(DDSSpacing.md),

          // ── SECTION 2: RETURN METHOD ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '2. RETURN METHOD',
                  style: DDSTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DDSColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (draft.isDifferentReturnLocation && draft.oneWayFee > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: DDSColors.warningOrange.withValues(alpha: 0.12),
                    borderRadius: DDSRadius.smallBorderRadius,
                  ),
                  child: Text(
                    '+₹${draft.oneWayFee.toInt()} One-Way Fee',
                    style: DDSTypography.labelSmall.copyWith(
                      color: DDSColors.warningOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const Gap(DDSSpacing.xs),

          // Same location toggle
          InkWell(
            borderRadius: DDSRadius.mediumBorderRadius,
            onTap: () {
              final newDiff = !draft.isDifferentReturnLocation;
              ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                    isDifferentReturnLocation: newDiff,
                    oneWayFee: newDiff ? d.oneWayFee : 0.0,
                    returnHubId: newDiff ? d.returnHubId : d.pickupHubId,
                    dropName: newDiff ? d.dropName : d.pickupName,
                    dropLocation: newDiff ? d.dropLocation : d.pickupLocation,
                  ));
              _refreshQuote();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: !draft.isDifferentReturnLocation
                    ? DDSColors.successGreenBg
                    : DDSColors.surfaceSubtle,
                borderRadius: DDSRadius.mediumBorderRadius,
                border: Border.all(
                  color: !draft.isDifferentReturnLocation
                      ? DDSColors.successGreen.withValues(alpha: 0.3)
                      : DDSColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    !draft.isDifferentReturnLocation
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: !draft.isDifferentReturnLocation
                        ? DDSColors.successGreen
                        : DDSColors.textMuted,
                    size: 18,
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      'Return to same location as pickup (Free)',
                      style: DDSTypography.bodyMedium.copyWith(
                        fontSize: 12,
                        fontWeight: !draft.isDifferentReturnLocation
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: !draft.isDifferentReturnLocation
                            ? DDSColors.successGreen
                            : DDSColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (draft.isDifferentReturnLocation) ...[
            const Gap(DDSSpacing.sm),
            _buildModeSelector(
              currentMode: _returnMode,
              isReturn: true,
              onChanged: (mode) {
                setState(() {
                  _returnMode = mode;
                });
                if (mode == FulfillmentMode.doorstep) {
                  ref
                      .read(bookingDraftProvider.notifier)
                      .update((d) => d.copyWith(hasDoorstepPickup: true));
                } else {
                  ref
                      .read(bookingDraftProvider.notifier)
                      .update((d) => d.copyWith(hasDoorstepPickup: false));
                }
                _refreshQuote();
              },
            ),
            const Gap(DDSSpacing.sm),
            _buildReturnDetails(draft),
          ],

          const Gap(DDSSpacing.md),
          const Divider(height: 1, color: DDSColors.borderLight),
          const Gap(DDSSpacing.md),

          // ── SECTION 3: AUTHORITATIVE QUOTE BREAKDOWN ───────────────
          _buildQuoteSummary(draft),
        ],
      ),
    );
  }

  Widget _buildModeSelector({
    required FulfillmentMode currentMode,
    required ValueChanged<FulfillmentMode> onChanged,
    bool isReturn = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: _modeChip(
            title: 'Host Yard',
            icon: Icons.storefront_outlined,
            isSelected: currentMode == FulfillmentMode.hostYard,
            onTap: () => onChanged(FulfillmentMode.hostYard),
          ),
        ),
        const Gap(6),
        Expanded(
          child: _modeChip(
            title: 'Airport/Rail',
            icon: Icons.flight_takeoff_outlined,
            isSelected: currentMode == FulfillmentMode.publicTransit,
            onTap: () => onChanged(FulfillmentMode.publicTransit),
          ),
        ),
        const Gap(6),
        Expanded(
          child: _modeChip(
            title: isReturn ? 'Collection' : 'Doorstep',
            icon: Icons.home_outlined,
            isSelected: currentMode == FulfillmentMode.doorstep,
            onTap: () => onChanged(FulfillmentMode.doorstep),
          ),
        ),
      ],
    );
  }

  Widget _modeChip({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: DDSRadius.smallBorderRadius,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? DDSColors.primaryBlue : DDSColors.surfaceSubtle,
          borderRadius: DDSRadius.smallBorderRadius,
          border: Border.all(
            color: isSelected ? DDSColors.primaryBlue : DDSColors.borderLight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : DDSColors.textSecondary,
            ),
            const Gap(4),
            Text(
              title,
              style: DDSTypography.labelSmall.copyWith(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : DDSColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupDetails(BookingDraft draft) {
    if (_pickupMode == FulfillmentMode.doorstep) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _deliveryAddressController,
            style: DDSTypography.bodyMedium,
            decoration: InputDecoration(
              labelText: 'Doorstep Delivery Address',
              hintText: 'House/Flat No, Landmark, Street, Area',
              isDense: true,
              prefixIcon: const Icon(
                Icons.home_outlined,
                size: 18,
                color: DDSColors.primaryBlue,
              ),
              border: OutlineInputBorder(
                borderRadius: DDSRadius.mediumBorderRadius,
                borderSide: const BorderSide(color: DDSColors.borderMedium),
              ),
            ),
            onChanged: (val) => _onAddressChanged(val),
          ),
          const Gap(4),
          Text(
            'Vehicle will be delivered by host representative before trip start.',
            style: DDSTypography.bodyMedium.copyWith(
              color: DDSColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    final isPublic = _pickupMode == FulfillmentMode.publicTransit;
    final displayName = draft.pickupName ??
        (draft.pickupLocation.isNotEmpty
            ? draft.pickupLocation
            : (isPublic ? 'Select Airport / Station' : 'Select Host Yard'));
    final address = draft.pickupAddress ?? widget.vendor.city;

    return InkWell(
      borderRadius: DDSRadius.mediumBorderRadius,
      onTap: () {
        LocationSelectionSheet.show(
          context: context,
          title: isPublic ? 'Select Airport / Transit Point' : 'Select Host Yard / Branch',
          initialValue: displayName,
          city: widget.vendor.city,
          vendorId: isPublic ? null : widget.vendor.id,
          onLocationSelected: (loc, {lat, lng}) {
            ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                  pickupLocation: loc,
                  pickupLatitude: lat,
                  pickupLongitude: lng,
                ));
          },
          onStructuredLocationSelected: (
              {required name, id, address, type, lat, lng, fee, operatingHours}) {
            ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                  pickupLocation: name,
                  pickupName: name,
                  pickupHubId: id,
                  pickupAddress: address,
                  pickupLatitude: lat,
                  pickupLongitude: lng,
                  pickupFee: fee ?? 0.0,
                ));
            _refreshQuote();
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DDSColors.surfaceSubtle,
          borderRadius: DDSRadius.mediumBorderRadius,
          border: Border.all(color: DDSColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(
              isPublic ? Icons.flight_takeoff : Icons.storefront,
              color: DDSColors.primaryBlue,
              size: 20,
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: DDSTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: DDSColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(2),
                  Text(
                    address,
                    style: DDSTypography.bodyMedium.copyWith(
                      color: DDSColors.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: DDSColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnDetails(BookingDraft draft) {
    if (_returnMode == FulfillmentMode.doorstep) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _collectionAddressController,
            style: DDSTypography.bodyMedium,
            decoration: InputDecoration(
              labelText: 'Doorstep Collection Address',
              hintText: 'Address for host to collect vehicle',
              isDense: true,
              prefixIcon: const Icon(
                Icons.pin_drop_outlined,
                size: 18,
                color: DDSColors.warningOrange,
              ),
              border: OutlineInputBorder(
                borderRadius: DDSRadius.mediumBorderRadius,
                borderSide: const BorderSide(color: DDSColors.borderMedium),
              ),
            ),
            onChanged: (val) => _onAddressChanged(val, isReturn: true),
          ),
          const Gap(4),
          Text(
            'Host representative will inspect and collect the car at this location.',
            style: DDSTypography.bodyMedium.copyWith(
              color: DDSColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    final isPublic = _returnMode == FulfillmentMode.publicTransit;
    final displayName = draft.dropName ??
        (draft.dropLocation.isNotEmpty
            ? draft.dropLocation
            : (isPublic ? 'Select Return Transit Point' : 'Select Return Branch'));

    return InkWell(
      borderRadius: DDSRadius.mediumBorderRadius,
      onTap: () {
        LocationSelectionSheet.show(
          context: context,
          title: isPublic
              ? 'Select Return Airport / Transit Hub'
              : 'Select Return Yard / Branch',
          initialValue: displayName,
          city: widget.vendor.city,
          isDropLocation: true,
          vendorId: isPublic ? null : widget.vendor.id,
          onLocationSelected: (loc, {lat, lng}) {
            ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                  dropLocation: loc,
                  deliveryLatitude: lat,
                  deliveryLongitude: lng,
                ));
          },
          onStructuredLocationSelected: (
              {required name, id, address, type, lat, lng, fee, operatingHours}) {
            ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
                  dropLocation: name,
                  dropName: name,
                  returnHubId: id,
                  deliveryAddress: address,
                  deliveryLatitude: lat,
                  deliveryLongitude: lng,
                  returnFee: fee ?? 0.0,
                ));
            _refreshQuote();
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DDSColors.surfaceSubtle,
          borderRadius: DDSRadius.mediumBorderRadius,
          border: Border.all(color: DDSColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(
              isPublic ? Icons.flight_land : Icons.storefront,
              color: DDSColors.warningOrange,
              size: 20,
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: DDSTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: DDSColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(2),
                  Text(
                    'Different return location • Subject to relocation matrix fee',
                    style: DDSTypography.bodyMedium.copyWith(
                      color: DDSColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: DDSColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteSummary(BookingDraft draft) {
    if (draft.isQuoteLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DDSColors.surfaceSubtle,
          borderRadius: DDSRadius.mediumBorderRadius,
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            Gap(10),
            Text(
              'Calculating authoritative fulfillment quote from server...',
              style: TextStyle(fontSize: 11, color: DDSColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (draft.quoteErrorReason != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: DDSRadius.mediumBorderRadius,
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
            const Gap(8),
            Expanded(
              child: Text(
                draft.quoteErrorReason!,
                style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final totalFulfillment = (draft.hasDoorstepDelivery ? draft.deliveryFee : 0.0) +
        draft.pickupFee +
        draft.returnFee +
        (draft.isDifferentReturnLocation ? draft.oneWayFee : 0.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DDSColors.infoBlueBg,
        borderRadius: DDSRadius.mediumBorderRadius,
        border: Border.all(color: DDSColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.verified, size: 16, color: DDSColors.primaryBlue),
                    const Gap(6),
                    Expanded(
                      child: Text(
                        'Authoritative Pricing',
                        style: DDSTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: DDSColors.primaryBlue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Text(
                totalFulfillment > 0
                    ? '+₹${totalFulfillment.toInt()}'
                    : 'Free Fulfillment',
                style: DDSTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: totalFulfillment > 0 ? DDSColors.primaryBlue : DDSColors.successGreen,
                ),
              ),
            ],
          ),
          const Gap(6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (draft.hasDoorstepDelivery && draft.deliveryFee > 0)
                _quoteBadge('Delivery: +₹${draft.deliveryFee.toInt()} (${draft.quoteDistanceKm} km)'),
              if (draft.pickupFee > 0)
                _quoteBadge('Pickup Hub Fee: +₹${draft.pickupFee.toInt()}'),
              if (draft.returnFee > 0)
                _quoteBadge('Return Hub Fee: +₹${draft.returnFee.toInt()}'),
              if (draft.isDifferentReturnLocation && draft.oneWayFee > 0)
                _quoteBadge('One-Way Relocation: +₹${draft.oneWayFee.toInt()}'),
              if (totalFulfillment == 0)
                _quoteBadge('Standard Yard Pickup & Return: Included'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quoteBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DDSRadius.smallBorderRadius,
        border: Border.all(color: DDSColors.primaryBlue.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: DDSColors.primaryBlue),
      ),
    );
  }
}

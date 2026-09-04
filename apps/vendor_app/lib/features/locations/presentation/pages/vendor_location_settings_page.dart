import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../providers/locations_providers.dart';

class VendorLocationSettingsPage extends ConsumerStatefulWidget {
  final double initialScrollOffset;
  const VendorLocationSettingsPage({super.key, this.initialScrollOffset = 0.0});

  @override
  ConsumerState<VendorLocationSettingsPage> createState() =>
      _VendorLocationSettingsPageState();
}

class _VendorLocationSettingsPageState
    extends ConsumerState<VendorLocationSettingsPage> {
  bool _isSaving = false;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController =
        ScrollController(initialScrollOffset: widget.initialScrollOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(vendorLocationsProvider);
    final policyAsync = ref.watch(vendorDeliveryPolicyProvider);
    final operatingMode = ref.watch(pickupOperatingModeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Location & Delivery Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B192C),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined),
            tooltip: 'Add Location',
            onPressed: () => context.push('/locations/add'),
          ),
        ],
      ),
      body: locationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const Gap(12),
              Text('Error loading locations: $err'),
              const Gap(16),
              ElevatedButton(
                onPressed: () => ref.refresh(vendorLocationsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (locations) {
          if (locations.isEmpty) {
            return _buildEmptyState();
          }

          final policy = policyAsync.value;
          if (policy == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOperatingModeSection(operatingMode),
                const Gap(20),
                _buildMyLocationsSection(locations),
                const Gap(20),
                _buildDeliverySettingsSection(policy),
                const Gap(20),
                _buildOneWayMatrixSection(),
                const Gap(32),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'SAVE SETTINGS',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                ),
                const Gap(24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0066FF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off_outlined,
                  size: 48,
                  color: Color(0xFF0066FF),
                ),
              ),
              const Gap(16),
              const Text(
                'SET UP YOUR FIRST PICKUP LOCATION',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B192C),
                  letterSpacing: 0.5,
                ),
              ),
              const Gap(8),
              const Text(
                'You need at least one approved pickup option before customers can book this vehicle.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const Gap(24),
              ElevatedButton.icon(
                onPressed: () => context.push('/locations/add'),
                icon: const Icon(Icons.add_location_alt),
                label: const Text('ADD FIRST LOCATION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperatingModeSection(PickupOperatingMode currentMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.alt_route_rounded, color: Color(0xFF0066FF), size: 20),
              Gap(8),
              Text(
                'WHERE DO YOU HAND OVER CARS?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B192C),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Gap(4),
          const Text(
            'Select how customers can receive and return vehicles from your fleet.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Divider(height: 20),
          ...PickupOperatingMode.values.map((mode) {
            final isSelected = mode == currentMode;
            return InkWell(
              onTap: () {
                ref.read(pickupOperatingModeProvider.notifier).state = mode;
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, right: 10.0),
                      child: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? const Color(0xFF0B192C) : const Color(0xFF334155),
                            ),
                          ),
                          const Gap(2),
                          Text(
                            mode.description,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMyLocationsSection(List<VendorLocationModel> locations) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.storefront_outlined, color: Color(0xFF0066FF), size: 20),
                  Gap(8),
                  Text(
                    'MY LOCATIONS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B192C),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.push('/locations/add'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ ADD LOCATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Gap(10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: locations.length,
            separatorBuilder: (context, index) => const Gap(12),
            itemBuilder: (context, index) {
              final loc = locations[index];
              return _buildLocationCard(loc);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(VendorLocationModel loc) {
    final isActive = loc.status == VendorLocationStatus.active;
    Color typeColor = const Color(0xFF0066FF);
    IconData typeIcon = Icons.store_mall_directory_outlined;
    if (loc.type == VendorLocationType.airport) {
      typeColor = const Color(0xFF7C3AED);
      typeIcon = Icons.local_airport;
    } else if (loc.type == VendorLocationType.branch) {
      typeColor = const Color(0xFF059669);
      typeIcon = Icons.domain;
    } else if (loc.type == VendorLocationType.railwayStation) {
      typeColor = const Color(0xFFD97706);
      typeIcon = Icons.train;
    }

    return InkWell(
      onTap: () => context.push('/locations/${loc.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 18),
                ),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isActive ? const Color(0xFF0B192C) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const Gap(2),
                      Text(
                        loc.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  activeThumbColor: const Color(0xFF059669),
                  onChanged: (val) {
                    ref.read(vendorLocationsProvider.notifier).toggleLocationStatus(loc.id);
                  },
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildCapabilityBadge('Pickup', loc.allowsPickup),
                    const Gap(6),
                    _buildCapabilityBadge('Return', loc.allowsReturn),
                    const Gap(6),
                    _buildCapabilityBadge('Delivery', loc.allowsDelivery),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${loc.assignedCarCount} Cars Assigned',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
            if (loc.pickupFee > 0 || loc.oneWayFee > 0) ...[
              const Gap(8),
              Row(
                children: [
                  if (loc.pickupFee > 0)
                    Text(
                      'Pickup Fee: ₹${loc.pickupFee.toInt()}  ',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  if (loc.oneWayFee > 0)
                    Text(
                      'One-Way Surcharge: ₹${loc.oneWayFee.toInt()}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                    ),
                ],
              ),
            ],
            Consumer(
              builder: (context, ref, _) {
                final excAsync = ref.watch(locationExceptionsProvider(loc.id));
                final exceptions = excAsync.valueOrNull ?? [];
                if (exceptions.isEmpty) return const SizedBox.shrink();
                final closed = exceptions.where((e) => e.isClosed).toList();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        closed.isNotEmpty ? Icons.event_busy : Icons.event_note,
                        size: 14,
                        color: closed.isNotEmpty ? Colors.red.shade700 : Colors.amber.shade800,
                      ),
                      const Gap(4),
                      Text(
                        closed.isNotEmpty
                            ? '${closed.length} Upcoming Closure${closed.length > 1 ? 's' : ''}'
                            : '${exceptions.length} Scheduled Exception${exceptions.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: closed.isNotEmpty ? Colors.red.shade700 : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityBadge(String label, bool isEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isEnabled
            ? const Color(0xFF059669).withValues(alpha: 0.12)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEnabled ? Icons.check : Icons.close,
            size: 11,
            color: isEnabled ? const Color(0xFF059669) : const Color(0xFF94A3B8),
          ),
          const Gap(2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isEnabled ? const Color(0xFF059669) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySettingsSection(VendorDeliveryPolicyModel policy) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.delivery_dining_outlined, color: Color(0xFF0066FF), size: 20),
                  Gap(8),
                  Text(
                    'DELIVERY SETTINGS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B192C),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Switch(
                value: policy.deliveryEnabled,
                activeThumbColor: const Color(0xFF059669),
                onChanged: (val) {
                  ref
                      .read(vendorDeliveryPolicyProvider.notifier)
                      .updatePolicy(policy.copyWith(deliveryEnabled: val));
                },
              ),
            ],
          ),
          const Gap(4),
          Text(
            'Deliver and collect vehicles at customer doorstep address within your service radius.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (policy.deliveryEnabled) ...[
            const Divider(height: 24),
            const Text(
              'Maximum Delivery Radius',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0B192C)),
            ),
            const Gap(8),
            Wrap(
              spacing: 8,
              children: [5.0, 10.0, 15.0, 25.0, 50.0].map((radius) {
                final isSelected = policy.maxDeliveryRadiusKm == radius;
                return ChoiceChip(
                  label: Text('${radius.toInt()} km'),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0066FF),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(vendorDeliveryPolicyProvider.notifier)
                          .updatePolicy(policy.copyWith(maxDeliveryRadiusKm: radius));
                    }
                  },
                );
              }).toList(),
            ),
            const Gap(16),
            const Text(
              'Delivery Pricing Model',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0B192C)),
            ),
            const Gap(8),
            Wrap(
              spacing: 8,
              children: [
                (DeliveryPricingModel.free, 'Free Delivery'),
                (DeliveryPricingModel.fixed, 'Fixed Fee (₹300)'),
                (DeliveryPricingModel.distanceBased, 'Distance Based (₹20/km)'),
              ].map((item) {
                final isSelected = policy.pricingModel == item.$1;
                return ChoiceChip(
                  label: Text(item.$2),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0066FF),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(vendorDeliveryPolicyProvider.notifier)
                          .updatePolicy(policy.copyWith(pricingModel: item.$1));
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOneWayMatrixSection() {
    final matrixAsync = ref.watch(vendorLocationMatrixProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: Color(0xFF0066FF), size: 20),
              Gap(8),
              Text(
                'ONE-WAY PICKUP & RETURN MATRIX',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B192C),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Gap(4),
          const Text(
            'Supported combinations for customers returning vehicle to a different location.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Divider(height: 20),
          matrixAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Matrix unavailable', style: TextStyle(fontSize: 12)),
            data: (matrix) {
              return Column(
                children: matrix.take(4).map((item) {
                  final isOneWay = item.pickupLocationId != item.returnLocationId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          isOneWay ? Icons.arrow_forward_rounded : Icons.replay_rounded,
                          size: 14,
                          color: isOneWay ? const Color(0xFFD97706) : const Color(0xFF059669),
                        ),
                        const Gap(6),
                        Expanded(
                          child: Text(
                            '${item.pickupLocationName} → ${item.returnLocationName}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOneWay)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+₹${item.oneWaySurcharge.toInt()}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                            ),
                          )
                        else
                          const Text(
                            'Standard',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    final policy = ref.read(vendorDeliveryPolicyProvider).value;
    if (policy == null) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(vendorDeliveryPolicyProvider.notifier).updatePolicy(policy);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location & delivery settings saved successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: ${err.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }
}

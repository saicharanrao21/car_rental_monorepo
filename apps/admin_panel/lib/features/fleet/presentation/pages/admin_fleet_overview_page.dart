import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../providers/admin_fleet_providers.dart';
import '../../../vendors/presentation/providers/admin_vendor_providers.dart';

class AdminFleetOverviewPage extends ConsumerStatefulWidget {
  const AdminFleetOverviewPage({super.key});

  @override
  ConsumerState<AdminFleetOverviewPage> createState() => _AdminFleetOverviewPageState();
}

class _AdminFleetOverviewPageState extends ConsumerState<AdminFleetOverviewPage> {
  void _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(title, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDetailPanel(BuildContext context, String carId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close details',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(anim1),
            child: Material(
              color: Colors.white,
              elevation: 16,
              child: SizedBox(
                width: 500,
                height: double.infinity,
                child: _CarDetailPanel(carId: carId),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fleetAsync = ref.watch(adminFleetProvider);
    final cityFilter = ref.watch(fleetCityFilterProvider);
    final carTypeFilter = ref.watch(fleetCarTypeFilterProvider);
    final availabilityFilter = ref.watch(fleetAvailabilityFilterProvider);
    final vendorFilter = ref.watch(fleetVendorFilterProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Filter Top Bar ───
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: AppDropdown<String>(
                      label: 'City',
                      value: cityFilter ?? 'All',
                      items: ['All', ...AppConstants.indianCities]
                          .map((city) => DropdownMenuItem<String>(
                                value: city,
                                child: SizedBox(
                                  width: 80,
                                  child: Text(city, overflow: TextOverflow.ellipsis),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        ref.read(fleetCityFilterProvider.notifier).state =
                            (val == 'All' || val == null) ? null : val;
                      },
                    ),
                  ),
                  const Gap(16),
                  SizedBox(
                    width: 160,
                    child: AppDropdown<String>(
                      label: 'Car Type',
                      value: carTypeFilter ?? 'All',
                      items: ['All', ...AppConstants.carCategories]
                          .map((type) => DropdownMenuItem<String>(
                                value: type,
                                child: SizedBox(
                                  width: 90,
                                  child: Text(type, overflow: TextOverflow.ellipsis),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        ref.read(fleetCarTypeFilterProvider.notifier).state =
                            (val == 'All' || val == null) ? null : val;
                      },
                    ),
                  ),
                  const Gap(16),
                  SizedBox(
                    width: 180,
                    child: AppDropdown<String>(
                      label: 'Availability',
                      value: availabilityFilter == null
                          ? 'All'
                          : (availabilityFilter ? 'Available' : 'Unavailable'),
                      items: const ['All', 'Available', 'Unavailable']
                          .map((status) => DropdownMenuItem<String>(
                                value: status,
                                child: SizedBox(
                                  width: 110,
                                  child: Text(status, overflow: TextOverflow.ellipsis),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val == 'All' || val == null) {
                          ref.read(fleetAvailabilityFilterProvider.notifier).state = null;
                        } else {
                          ref.read(fleetAvailabilityFilterProvider.notifier).state = val == 'Available';
                        }
                      },
                    ),
                  ),
                  const Gap(16),
                  SizedBox(
                    width: 220,
                    child: AppDropdown<String>(
                      label: 'Vendor',
                      value: vendorFilter ?? 'All',
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'All',
                          child: SizedBox(
                            width: 150,
                            child: Text('All Vendors', overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        ...(ref.watch(adminVendorsProvider).value ?? []).map((v) => DropdownMenuItem<String>(
                              value: v.id,
                              child: SizedBox(
                                width: 150,
                                child: Text(v.businessName, overflow: TextOverflow.ellipsis),
                              ),
                            )),
                      ],
                      onChanged: (val) {
                        ref.read(fleetVendorFilterProvider.notifier).state =
                            (val == 'All' || val == null) ? null : val;
                      },
                    ),
                  ),
                  if (cityFilter != null ||
                      carTypeFilter != null ||
                      availabilityFilter != null ||
                      vendorFilter != null) ...[
                    const Gap(16),
                    TextButton.icon(
                      onPressed: () {
                        ref.read(fleetCityFilterProvider.notifier).state = null;
                        ref.read(fleetCarTypeFilterProvider.notifier).state = null;
                        ref.read(fleetAvailabilityFilterProvider.notifier).state = null;
                        ref.read(fleetVendorFilterProvider.notifier).state = null;
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear Filters'),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(24),

            // ─── Fleet Overview Table ───
            Expanded(
              child: fleetAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading fleet list',
                  onRetry: () => ref.invalidate(adminFleetProvider),
                ),
                data: (cars) {
                  if (cars.isEmpty) {
                    return const Center(
                      child: EmptyStateWidget(
                        icon: Icons.directions_car,
                        title: 'No Cars Found',
                        subtitle: 'No vehicles match the filter criteria.',
                      ),
                    );
                  }

                  return AppCard(
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                        columns: const [
                          DataColumn(label: Text('Car Model', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Vendor Partner', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('City', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Seats', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('AC', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Price/Day', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Availability', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: cars.map((c) {
                          final vendor = (ref.watch(adminVendorsProvider).value ?? []).firstWhere(
                            (v) => v.id == c.vendorId,
                            orElse: () => VendorModel(
                              id: c.vendorId,
                              businessName: 'Vendor #${c.vendorId.length > 6 ? c.vendorId.substring(0, 6) : c.vendorId}',
                              ownerName: '',
                              city: '',
                              verificationStatus: '',
                            ),
                          );

                          return DataRow(
                            cells: [
                              DataCell(
                                InkWell(
                                  onTap: () => _showDetailPanel(context, c.id),
                                  child: Text(
                                    '${c.make} ${c.model} (${c.year})',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(c.type)),
                              DataCell(Text(vendor.businessName)),
                              DataCell(Text(vendor.city)),
                              DataCell(Text('${c.seating}')),
                              DataCell(Text(c.isAC ? 'Yes' : 'No')),
                              DataCell(Text('₹${c.pricePerDay.toStringAsFixed(0)}')),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (c.isAvailable ? Colors.green : Colors.red).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (c.isAvailable ? Colors.green : Colors.red).withValues(alpha: 0.24),
                                    ),
                                  ),
                                  child: Text(
                                    c.isAvailable ? 'AVAILABLE' : 'DEACTIVATED',
                                    style: TextStyle(
                                      color: c.isAvailable ? Colors.green : Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                c.isAvailable
                                    ? IconButton(
                                        icon: const Icon(Icons.block, color: Colors.red, size: 20),
                                        tooltip: 'Deactivate listing',
                                        onPressed: () {
                                          _showConfirmDialog(
                                            context: context,
                                            title: 'Deactivate Vehicle Listing',
                                            content: 'Are you sure you want to deactivate ${c.make} ${c.model}? Customers will no longer be able to search for or book this vehicle.',
                                            onConfirm: () => ref
                                                .read(adminFleetControllerProvider.notifier)
                                                .deactivateCarListing(c.id),
                                          );
                                        },
                                      )
                                    : const Icon(Icons.check_circle_outline, color: Colors.grey, size: 20),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarDetailPanel extends ConsumerWidget {
  final String carId;
  const _CarDetailPanel({required this.carId});

  void _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(title, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carAsync = ref.watch(carDetailProvider(carId));
    final controllerState = ref.watch(adminFleetControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Fleet Details'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: carAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (car) {
          final vendor = (ref.watch(adminVendorsProvider).value ?? []).firstWhere(
            (v) => v.id == car.vendorId,
            orElse: () => VendorModel(
              id: car.vendorId,
              businessName: 'Vendor #${car.vendorId.length > 6 ? car.vendorId.substring(0, 6) : car.vendorId}',
              ownerName: '',
              city: '',
              verificationStatus: '',
            ),
          );

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Photo Placeholder
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_outlined, size: 48, color: Colors.grey[400]),
                          const Gap(8),
                          Text(
                            'Vehicle Photo Gallery Placeholder',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Gap(24),

                    // Make & Model details
                    Text(
                      '${car.make} ${car.model}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Gap(4),
                    Text(
                      'Year: ${car.year} | Fuel: ${car.fuelType}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const Gap(16),

                    // Availability Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (car.isAvailable ? Colors.green : Colors.red).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (car.isAvailable ? Colors.green : Colors.red).withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            car.isAvailable ? Icons.check_circle : Icons.error,
                            color: car.isAvailable ? Colors.green : Colors.red,
                            size: 18,
                          ),
                          const Gap(8),
                          Text(
                            car.isAvailable
                                ? 'AVAILABLE FOR CUSTOMER BOOKING'
                                : 'DEACTIVATED BY PLATFORM ADMIN',
                            style: TextStyle(
                              color: car.isAvailable ? Colors.green[800] : Colors.red[800],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 32),

                    // Owning Vendor Details
                    const SectionHeader(title: 'Owning Vendor Partner'),
                    const Gap(12),
                    _DetailRow(label: 'Business Name', value: vendor.businessName),
                    _DetailRow(label: 'Owner Name', value: vendor.ownerName),
                    _DetailRow(label: 'City', value: vendor.city),
                    _DetailRow(label: 'Vendor Contact', value: vendor.phone.isEmpty ? 'N/A' : vendor.phone),
                    const Divider(height: 32),

                    // Specifications
                    const SectionHeader(title: 'Specifications'),
                    const Gap(12),
                    _DetailRow(label: 'Seating Capacity', value: '${car.seating} Seater'),
                    _DetailRow(label: 'Air Conditioning (AC)', value: car.isAC ? 'Yes' : 'No'),
                    _DetailRow(label: 'Vehicle Category', value: car.type),
                    _DetailRow(label: 'Blocked Dates', value: '${car.blockedDates.length} Days Blocked'),
                    const Divider(height: 32),

                    // Pricing Specifications
                    const SectionHeader(title: 'Base Pricing Details'),
                    const Gap(12),
                    _DetailRow(label: 'Price per Day', value: '₹${car.pricePerDay.toStringAsFixed(2)}'),
                    _DetailRow(label: 'Price per Hour', value: '₹${car.pricePerHour.toStringAsFixed(2)}'),
                    _DetailRow(label: 'Price per Excess Km', value: '₹${car.pricePerKm.toStringAsFixed(2)}'),
                    const Divider(height: 32),

                    // Mileage Packages Section
                    const SectionHeader(title: 'Configured Mileage Packages'),
                    const Gap(12),
                    if (car.rawMileagePackages.isEmpty)
                      Text(
                        'No mileage packages configured. (Using legacy pricing rates)',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic),
                      )
                    else
                      ...car.rawMileagePackages.map((rawPkg) {
                        final pkg = MileagePackageModel.fromJson(Map<String, dynamic>.from(rawPkg as Map));
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: pkg.isActive ? Colors.grey[50] : Colors.red.shade50.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: pkg.isActive ? Colors.grey.shade300 : Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                pkg.isUnlimited ? Icons.all_inclusive : Icons.speed,
                                color: pkg.isActive ? AppColors.primary : Colors.grey,
                                size: 20,
                              ),
                              const Gap(10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          pkg.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: pkg.isActive ? Colors.black87 : Colors.grey[700],
                                          ),
                                        ),
                                        const Gap(6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            pkg.tripType,
                                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (pkg.isDefault) ...[
                                          const Gap(4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Default',
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const Gap(2),
                                    Text(
                                      pkg.isUnlimited
                                          ? '₹${pkg.basePricePerDay.toInt()}/day • Unlimited km'
                                          : '₹${pkg.basePricePerDay.toInt()}/day • ${pkg.includedKmPerDay} km/day • Extra: ₹${pkg.extraKmRate.toInt()}/km',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: pkg.isActive,
                                activeThumbColor: AppColors.primary,
                                onChanged: (val) {
                                  ref.read(adminFleetControllerProvider.notifier)
                                      .toggleMileagePackageActive(car.id, pkg.id, val);
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    const Divider(height: 32),

                    // Blocked Dates Details (if any)
                    if (car.blockedDates.isNotEmpty) ...[
                      const SectionHeader(title: 'Upcoming Blocked Dates'),
                      const Gap(12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: car.blockedDates.map((date) {
                          return Chip(
                            label: Text(
                              DateFormat('dd MMM yyyy').format(date),
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.amber[50],
                            side: BorderSide(color: Colors.amber[200]!),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                      const Divider(height: 32),
                    ],

                    const Gap(24),

                    // Actions
                    if (car.isAvailable)
                      AppButton(
                        text: 'Deactivate Listing',
                        backgroundColor: Colors.red[600],
                        onPressed: () {
                          _showConfirmDialog(
                            context: context,
                            title: 'Deactivate Vehicle Listing',
                            content: 'Are you sure you want to deactivate this listing? Customers will no longer be able to find it.',
                            onConfirm: () => ref
                                .read(adminFleetControllerProvider.notifier)
                                .deactivateCarListing(car.id),
                          );
                        },
                      )
                    else
                      const AppButton(
                        text: 'Listing Deactivated',
                        onPressed: null,
                      ),
                    const Gap(40),
                  ],
                ),
              ),
              if (controllerState.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black12,
                    child: const Center(child: AppLoader()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

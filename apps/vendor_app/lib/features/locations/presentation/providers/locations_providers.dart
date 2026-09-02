import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';

enum PickupOperatingMode {
  atMyLocation,
  multipleLocations,
  publicPoints,
  deliveryToCustomers,
  combination,
}

extension PickupOperatingModeExt on PickupOperatingMode {
  String get title {
    switch (this) {
      case PickupOperatingMode.atMyLocation:
        return 'At my location';
      case PickupOperatingMode.multipleLocations:
        return 'At multiple locations';
      case PickupOperatingMode.publicPoints:
        return 'At selected public points';
      case PickupOperatingMode.deliveryToCustomers:
        return 'I deliver to customers';
      case PickupOperatingMode.combination:
        return 'Combination of these';
    }
  }

  String get description {
    switch (this) {
      case PickupOperatingMode.atMyLocation:
        return 'Customers pick up and return vehicles at your primary yard/garage.';
      case PickupOperatingMode.multipleLocations:
        return 'Customers choose between multiple operating branches in your city.';
      case PickupOperatingMode.publicPoints:
        return 'Customers meet you at airports, railway stations, and transport points.';
      case PickupOperatingMode.deliveryToCustomers:
        return 'You deliver and collect vehicles directly at customer doorstep.';
      case PickupOperatingMode.combination:
        return 'Enable yards, airport points, and doorstep delivery simultaneously.';
    }
  }
}

final pickupOperatingModeProvider = StateProvider<PickupOperatingMode>((ref) {
  return PickupOperatingMode.combination;
});

class VendorLocationsNotifier extends StateNotifier<AsyncValue<List<VendorLocationModel>>> {
  final Ref ref;

  VendorLocationsNotifier(this.ref)
      : super(AsyncValue.data(_getStaticMockLocations())) {
    loadLocations();
  }

  Future<void> loadLocations() async {
    try {
      final client = ref.read(apiClientProvider).dio;
      final response = await client.get('/locations/vendors/me/locations');
      if (response.statusCode == 200) {
        final list = (response.data as List<dynamic>)
            .map((json) => VendorLocationModel.fromJson(json as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          state = AsyncValue.data(list);
        }
      }
    } catch (_) {
      // Retain synchronous baseline
    }
  }

  static List<VendorLocationModel> _getStaticMockLocations() {
    return [
      VendorLocationModel(
        id: 'loc_hyd_main_yard',
        vendorId: 'v_1',
        name: 'Hyderabad Main Yard',
        type: VendorLocationType.vendorYard,
        address: 'Plot 42, Silicon Valley, Madhapur',
        locality: 'Madhapur',
        city: 'Hyderabad',
        state: 'Telangana',
        pincode: '500081',
        latitude: 17.4483,
        longitude: 78.3915,
        contactPerson: 'Rahul Verma (Yard Mgr)',
        contactPhone: '+91 98765 43210',
        status: VendorLocationStatus.active,
        allowsPickup: true,
        allowsReturn: true,
        allowsDelivery: true,
        pickupFee: 0,
        returnFee: 0,
        oneWayFee: 0,
        openingTime: '08:00',
        closingTime: '22:00',
        is24x7: false,
        serviceRadiusKm: 25.0,
        assignedCarCount: 8,
        assignedCarIds: ['car_1', 'car_2', 'car_3'],
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime.now(),
      ),
      VendorLocationModel(
        id: 'loc_hyd_airport',
        vendorId: 'v_1',
        name: 'Rajiv Gandhi International Airport (HYD)',
        type: VendorLocationType.airport,
        address: 'Terminal 1 Parking P4, RGIA Shamshabad',
        locality: 'Shamshabad',
        city: 'Hyderabad',
        state: 'Telangana',
        pincode: '500409',
        latitude: 17.2403,
        longitude: 78.4294,
        contactPerson: 'Airport Dispatch Desk',
        contactPhone: '+91 98765 43211',
        status: VendorLocationStatus.active,
        allowsPickup: true,
        allowsReturn: true,
        allowsDelivery: false,
        pickupFee: 300,
        returnFee: 0,
        oneWayFee: 250,
        openingTime: '00:00',
        closingTime: '23:59',
        is24x7: true,
        serviceRadiusKm: 15.0,
        assignedCarCount: 4,
        assignedCarIds: ['car_4', 'car_5'],
        createdAt: DateTime(2026, 2, 10),
        updatedAt: DateTime.now(),
      ),
      VendorLocationModel(
        id: 'loc_hyd_secunderabad',
        vendorId: 'v_1',
        name: 'Secunderabad Branch Hub',
        type: VendorLocationType.branch,
        address: 'Shop 12, Station Road, Secunderabad',
        locality: 'Secunderabad',
        city: 'Hyderabad',
        state: 'Telangana',
        pincode: '500003',
        latitude: 17.4399,
        longitude: 78.4983,
        contactPerson: 'Suresh Kumar',
        contactPhone: '+91 98765 43212',
        status: VendorLocationStatus.active,
        allowsPickup: true,
        allowsReturn: true,
        allowsDelivery: true,
        pickupFee: 0,
        returnFee: 0,
        oneWayFee: 150,
        openingTime: '09:00',
        closingTime: '21:00',
        is24x7: false,
        serviceRadiusKm: 20.0,
        assignedCarCount: 3,
        assignedCarIds: ['car_6'],
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  Future<void> addLocation(VendorLocationModel newLocation) async {
    final current = state.value ?? [];
    state = AsyncValue.data([...current, newLocation]);
    try {
      final client = ref.read(apiClientProvider).dio;
      await client.post('/locations/vendors/me/locations', data: newLocation.toJson());
    } catch (_) {
      // Local state preserved
    }
  }

  Future<void> updateLocation(VendorLocationModel updated) async {
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((loc) => loc.id == updated.id ? updated : loc).toList(),
    );
    try {
      final client = ref.read(apiClientProvider).dio;
      await client.patch('/locations/vendors/me/locations/${updated.id}', data: updated.toJson());
    } catch (_) {}
  }

  Future<void> toggleLocationStatus(String locationId) async {
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((loc) {
        if (loc.id == locationId) {
          final newStatus = loc.status == VendorLocationStatus.active
              ? VendorLocationStatus.inactive
              : VendorLocationStatus.active;
          return loc.copyWith(status: newStatus);
        }
        return loc;
      }).toList(),
    );
  }

  Future<void> deleteLocation(String locationId) async {
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((l) => l.id != locationId).toList());
    try {
      final client = ref.read(apiClientProvider).dio;
      await client.delete('/locations/vendors/me/locations/$locationId');
    } catch (_) {}
  }

  void clearAllLocations() {
    state = const AsyncValue.data([]);
  }
}

final vendorLocationsProvider =
    StateNotifierProvider<VendorLocationsNotifier, AsyncValue<List<VendorLocationModel>>>((ref) {
  return VendorLocationsNotifier(ref);
});

class VendorDeliveryPolicyNotifier extends StateNotifier<AsyncValue<VendorDeliveryPolicyModel>> {
  final Ref ref;

  VendorDeliveryPolicyNotifier(this.ref)
      : super(
          const AsyncValue.data(
            VendorDeliveryPolicyModel(
              vendorId: 'v_1',
              deliveryEnabled: true,
              maxDeliveryRadiusKm: 15.0,
              pricingModel: DeliveryPricingModel.fixed,
              baseDeliveryFee: 300.0,
              perKmDeliveryFee: 20.0,
              freeDeliveryWithinKm: 5.0,
            ),
          ),
        ) {
    loadPolicy();
  }

  Future<void> loadPolicy() async {
    try {
      final client = ref.read(apiClientProvider).dio;
      final response = await client.get('/locations/vendors/me/delivery-policy');
      if (response.statusCode == 200) {
        state = AsyncValue.data(
          VendorDeliveryPolicyModel.fromJson(response.data as Map<String, dynamic>),
        );
      }
    } catch (_) {}
  }

  Future<void> updatePolicy(VendorDeliveryPolicyModel updated) async {
    state = AsyncValue.data(updated);
    try {
      final client = ref.read(apiClientProvider).dio;
      await client.patch('/locations/vendors/me/delivery-policy', data: updated.toJson());
    } catch (_) {}
  }
}

final vendorDeliveryPolicyProvider =
    StateNotifierProvider<VendorDeliveryPolicyNotifier, AsyncValue<VendorDeliveryPolicyModel>>((ref) {
  return VendorDeliveryPolicyNotifier(ref);
});

final vendorLocationMatrixProvider =
    FutureProvider.autoDispose<List<LocationMatrixItemModel>>((ref) async {
  final locationsAsync = ref.watch(vendorLocationsProvider);
  final locations = locationsAsync.value ?? [];
  final activeLocs = locations.where((l) => l.status == VendorLocationStatus.active).toList();

  final List<LocationMatrixItemModel> matrix = [];
  for (final pickup in activeLocs) {
    for (final returnLoc in activeLocs) {
      final isSame = pickup.id == returnLoc.id;
      final surcharge = isSame ? 0.0 : (returnLoc.oneWayFee > 0 ? returnLoc.oneWayFee : 250.0);
      matrix.add(
        LocationMatrixItemModel(
          pickupLocationId: pickup.id,
          returnLocationId: returnLoc.id,
          pickupLocationName: pickup.name,
          returnLocationName: returnLoc.name,
          isSupported: true,
          oneWaySurcharge: surcharge,
        ),
      );
    }
  }
  return matrix;
});

final locationOperationsSummaryProvider =
    FutureProvider.autoDispose<LocationOperationsSummaryModel>((ref) async {
  final locationsAsync = ref.watch(vendorLocationsProvider);
  final locations = locationsAsync.value ?? [];

  final List<LocationOperationsItemSummary> summaryItems = locations.map((loc) {
    final pickups = loc.type == VendorLocationType.airport
        ? 3
        : loc.type == VendorLocationType.branch
            ? 2
            : 8;
    final returns = loc.type == VendorLocationType.airport
        ? 2
        : loc.type == VendorLocationType.branch
            ? 1
            : 5;
    return LocationOperationsItemSummary(
      locationId: loc.id,
      locationName: loc.name,
      locationType: loc.type.toApiString(),
      todayPickups: pickups,
      todayReturns: returns,
      activeVehicles: loc.assignedCarCount,
    );
  }).toList();

  final totalPickups = summaryItems.fold<int>(0, (sum, i) => sum + i.todayPickups);
  final totalReturns = summaryItems.fold<int>(0, (sum, i) => sum + i.todayReturns);

  return LocationOperationsSummaryModel(
    locations: summaryItems,
    totalTodayPickups: totalPickups > 0 ? totalPickups : 13,
    totalTodayReturns: totalReturns > 0 ? totalReturns : 8,
    totalDeliveryRequests: 4,
  );
});

final publicLocationCatalogProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return [
    {
      'id': 'pub_hyd_rgia',
      'name': 'Rajiv Gandhi International Airport (HYD)',
      'type': 'AIRPORT',
      'category': 'Airport Terminal',
      'locality': 'Shamshabad, Hyderabad',
      'address': 'Arrivals Area, RGIA Terminal 1, Shamshabad, Hyderabad, Telangana',
      'latitude': 17.2403,
      'longitude': 78.4294,
      'isApproved': true,
    },
    {
      'id': 'pub_hyd_secunderabad_rail',
      'name': 'Secunderabad Junction Railway Station',
      'type': 'RAILWAY_STATION',
      'category': 'Railway Station',
      'locality': 'Secunderabad',
      'address': 'Station Road, Secunderabad, Telangana 500003',
      'latitude': 17.4338,
      'longitude': 78.5044,
      'isApproved': true,
    },
    {
      'id': 'pub_hyd_hitec_metro',
      'name': 'HITEC City Metro Station Hub',
      'type': 'PUBLIC_POINT',
      'category': 'Metro Station Hub',
      'locality': 'Madhapur',
      'address': 'HITEC City Metro Pillar 1240, Madhapur, Hyderabad, Telangana',
      'latitude': 17.4474,
      'longitude': 78.3762,
      'isApproved': true,
    },
    {
      'id': 'pub_hyd_mgbs_bus',
      'name': 'Mahatma Gandhi Bus Station (MGBS)',
      'type': 'BUS_TERMINAL',
      'category': 'Bus Terminal',
      'locality': 'Gowliguda',
      'address': 'Central Bus Stand Road, Gowliguda, Hyderabad, Telangana',
      'latitude': 17.3789,
      'longitude': 78.4812,
      'isApproved': true,
    },
  ];
});

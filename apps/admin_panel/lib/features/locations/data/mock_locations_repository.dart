import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/locations_repository.dart';

class MockLocationsRepository with LatencySimulator implements LocationsRepository {
  final List<VendorLocationModel> _mockLocations = [
    VendorLocationModel(
      id: 'loc_hyd_1',
      vendorId: 'vnd_1',
      name: 'Madhapur Primary Garage Hub',
      type: VendorLocationType.vendorYard,
      status: VendorLocationStatus.active,
      city: 'Hyderabad',
      state: 'Telangana',
      address: 'Plot 42, Hitec City Main Road',
      latitude: 17.4483,
      longitude: 78.3915,
      pincode: '500081',
      contactPhone: '+919876543210',
      contactPerson: 'Vikram Mehta',
      assignedCarCount: 14,
      openingTime: '07:00',
      closingTime: '23:00',
      is24x7: false,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    ),
    VendorLocationModel(
      id: 'loc_hyd_2',
      vendorId: 'vnd_1',
      name: 'RGIA Airport Express Terminal',
      type: VendorLocationType.airport,
      status: VendorLocationStatus.active,
      city: 'Hyderabad',
      state: 'Telangana',
      address: 'Shamshabad International Airport Terminal 1',
      latitude: 17.2403,
      longitude: 78.4294,
      pincode: '500409',
      contactPhone: '+919876543211',
      assignedCarCount: 8,
      is24x7: true,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      updatedAt: DateTime.now(),
    ),
    VendorLocationModel(
      id: 'loc_hyd_3',
      vendorId: 'vnd_2',
      name: 'Secunderabad Railway Station Hub',
      type: VendorLocationType.railwayStation,
      status: VendorLocationStatus.pendingApproval,
      city: 'Hyderabad',
      state: 'Telangana',
      address: 'Station Road, Secunderabad',
      latitude: 17.4344,
      longitude: 78.5015,
      pincode: '500003',
      contactPhone: '+919876543212',
      assignedCarCount: 5,
      openingTime: '06:00',
      closingTime: '22:00',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now(),
    ),
    VendorLocationModel(
      id: 'loc_blr_1',
      vendorId: 'vnd_3',
      name: 'Indiranagar Urban Hub',
      type: VendorLocationType.branch,
      status: VendorLocationStatus.active,
      city: 'Bengaluru',
      state: 'Karnataka',
      address: '100 Feet Road, HAL 2nd Stage',
      latitude: 12.9784,
      longitude: 77.6408,
      pincode: '560038',
      contactPhone: '+919876543213',
      assignedCarCount: 12,
      openingTime: '08:00',
      closingTime: '22:00',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      updatedAt: DateTime.now(),
    ),
    VendorLocationModel(
      id: 'loc_blr_2',
      vendorId: 'vnd_3',
      name: 'Kempegowda Airport Hub (KIA)',
      type: VendorLocationType.airport,
      status: VendorLocationStatus.active,
      city: 'Bengaluru',
      state: 'Karnataka',
      address: 'Devanahalli, Bengaluru',
      latitude: 13.1986,
      longitude: 77.7066,
      pincode: '560300',
      contactPhone: '+919876543214',
      assignedCarCount: 10,
      is24x7: true,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now(),
    ),
    VendorLocationModel(
      id: 'loc_del_1',
      vendorId: 'vnd_4',
      name: 'Connaught Place Transit Station',
      type: VendorLocationType.publicPoint,
      status: VendorLocationStatus.temporarilyClosed,
      city: 'Delhi',
      state: 'Delhi',
      address: 'Inner Circle, CP',
      latitude: 28.6304,
      longitude: 77.2177,
      pincode: '110001',
      contactPhone: '+919876543215',
      assignedCarCount: 4,
      openingTime: '09:00',
      closingTime: '21:00',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<OperationalLocationOverviewModel> getOperationalOverview({String? city}) async {
    await simulateLatency();

    return const OperationalLocationOverviewModel(
      vendors: [
        VendorLocationItemModel(
          id: 'vnd_1',
          businessName: 'Royal Fleet Garage',
          ownerName: 'Vikram Mehta',
          city: 'Hyderabad',
          latitude: 17.4483,
          longitude: 78.3915,
        ),
        VendorLocationItemModel(
          id: 'vnd_2',
          businessName: 'Coastal Cars Hub',
          ownerName: 'Sunil Rao',
          city: 'Mumbai',
          latitude: 19.0760,
          longitude: 72.8777,
        ),
      ],
      activeBookings: [
        ActiveTripLocationItemModel(
          id: 'bkg_1',
          tripType: 'SELF_DRIVE',
          pickupLocation: 'Hitec City Hub',
          dropLocation: 'RGIA Airport',
          pickupLatitude: 17.4483,
          pickupLongitude: 78.3915,
          deliveryLatitude: null,
          deliveryLongitude: null,
          status: 'ONGOING',
          customerName: 'Rahul Sharma',
          customerPhone: '+919876543210',
          carName: 'Hyundai Creta (AT)',
          registrationNumber: 'TS09EA1234',
        ),
      ],
      activeEmergencies: [
        EmergencyLocationItemModel(
          id: 'sos_1',
          incidentType: 'FLAT_TYRE',
          status: 'REQUESTED',
          latitude: 17.3850,
          longitude: 78.4867,
          locationAddress: 'PVNR Expressway Pillar 120',
          customerName: 'Priya Reddy',
          customerPhone: '+919876543211',
        ),
      ],
      totalHubs: 6,
      totalActiveGarages: 2,
      totalOnTripVehicles: 1,
      totalActiveSosAlerts: 1,
    );
  }

  @override
  Future<LocationAddressModel> reverseGeocode(double lat, double lng) async {
    await simulateLatency();
    return LocationAddressModel(
      formattedAddress: 'Hitec City, Hyderabad, Telangana',
      locality: 'Madhapur',
      city: 'Hyderabad',
      state: 'Telangana',
      postalCode: '500081',
      latitude: lat,
      longitude: lng,
    );
  }

  @override
  Future<RouteEstimateModel> calculateDistance({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    await simulateLatency();
    return const RouteEstimateModel(
      distanceKm: 15.2,
      estimatedMinutes: 30,
      formattedDistance: '15.2 km',
      formattedDuration: '30 mins',
    );
  }

  @override
  Future<List<VendorLocationModel>> getPublicCatalog({String? city}) async {
    await simulateLatency();
    if (city == null || city.isEmpty || city == 'All') {
      return List.unmodifiable(_mockLocations);
    }
    return _mockLocations.where((loc) => loc.city.toLowerCase() == city.toLowerCase()).toList();
  }

  @override
  Future<void> updateLocationStatus(String locationId, String status) async {
    await simulateLatency();
    final idx = _mockLocations.indexWhere((l) => l.id == locationId);
    if (idx != -1) {
      final old = _mockLocations[idx];
      _mockLocations[idx] = old.copyWith(
        status: VendorLocationStatusExt.fromString(status),
      );
    }
  }

  @override
  Future<List<SupportedCityModel>> getSupportedCities({bool includeInactive = true}) async {
    await simulateLatency();
    return [
      const SupportedCityModel(
        id: 'city_hyd',
        name: 'Hyderabad',
        state: 'Telangana',
        latitude: 17.3850,
        longitude: 78.4867,
        isActive: true,
      ),
      const SupportedCityModel(
        id: 'city_blr',
        name: 'Bengaluru',
        state: 'Karnataka',
        latitude: 12.9716,
        longitude: 77.5946,
        isActive: true,
      ),
      const SupportedCityModel(
        id: 'city_del',
        name: 'Delhi',
        state: 'Delhi',
        latitude: 28.7041,
        longitude: 77.1025,
        isActive: true,
      ),
      const SupportedCityModel(
        id: 'city_mum',
        name: 'Mumbai',
        state: 'Maharashtra',
        latitude: 19.0760,
        longitude: 72.8777,
        isActive: true,
      ),
    ];
  }
}

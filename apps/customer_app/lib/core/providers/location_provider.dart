import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:core/core.dart';
import 'api_providers.dart';

enum LocationDetectionStatus {
  idle,
  loading,
  success,
  serviceDisabled,
  permissionDenied,
  permanentlyDenied,
  error,
}

class ServerResolvedPickupHub {
  final String id;
  final String name;
  final String? locality;
  final String city;
  final double? latitude;
  final double? longitude;
  final double distanceKm;
  final double? serviceRadiusKm;
  final String? operatingHours;
  final bool isWithinServiceRadius;

  const ServerResolvedPickupHub({
    required this.id,
    required this.name,
    this.locality,
    required this.city,
    this.latitude,
    this.longitude,
    required this.distanceKm,
    this.serviceRadiusKm,
    this.operatingHours,
    this.isWithinServiceRadius = true,
  });

  factory ServerResolvedPickupHub.fromJson(Map<String, dynamic> json) {
    return ServerResolvedPickupHub(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      locality: json['locality'] as String?,
      city: json['city'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      serviceRadiusKm: (json['serviceRadiusKm'] as num?)?.toDouble(),
      operatingHours: json['operatingHours'] as String?,
      isWithinServiceRadius: json['isWithinServiceRadius'] as bool? ?? true,
    );
  }
}

class CurrentLocationResult {
  final LocationDetectionStatus status;
  final double? latitude;
  final double? longitude;
  final String? message;
  final String? resolvedCity;
  final String? resolvedState;
  final String? resolvedLocality;
  final double? distanceToCityCenterKm;
  final bool isWithinOperationalRange;
  final List<ServerResolvedPickupHub> suggestedPickupLocations;

  const CurrentLocationResult({
    required this.status,
    this.latitude,
    this.longitude,
    this.message,
    this.resolvedCity,
    this.resolvedState,
    this.resolvedLocality,
    this.distanceToCityCenterKm,
    this.isWithinOperationalRange = true,
    this.suggestedPickupLocations = const [],
  });
}

class UserLocationState {
  final double? latitude;
  final double? longitude;
  final bool isPermissionGranted;
  final bool isRequestedThisSession;
  final LocationDetectionStatus detectionStatus;
  final String? lastError;
  final String? resolvedCity;
  final bool isWithinOperationalRange;
  final List<ServerResolvedPickupHub> suggestedPickupLocations;

  const UserLocationState({
    this.latitude,
    this.longitude,
    this.isPermissionGranted = false,
    this.isRequestedThisSession = true,
    this.detectionStatus = LocationDetectionStatus.idle,
    this.lastError,
    this.resolvedCity,
    this.isWithinOperationalRange = true,
    this.suggestedPickupLocations = const [],
  });

  UserLocationState copyWith({
    double? latitude,
    double? longitude,
    bool? isPermissionGranted,
    bool? isRequestedThisSession,
    LocationDetectionStatus? detectionStatus,
    String? lastError,
    String? resolvedCity,
    bool? isWithinOperationalRange,
    List<ServerResolvedPickupHub>? suggestedPickupLocations,
  }) {
    return UserLocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isPermissionGranted: isPermissionGranted ?? this.isPermissionGranted,
      isRequestedThisSession: isRequestedThisSession ?? this.isRequestedThisSession,
      detectionStatus: detectionStatus ?? this.detectionStatus,
      lastError: lastError,
      resolvedCity: resolvedCity ?? this.resolvedCity,
      isWithinOperationalRange: isWithinOperationalRange ?? this.isWithinOperationalRange,
      suggestedPickupLocations: suggestedPickupLocations ?? this.suggestedPickupLocations,
    );
  }
}

class UserLocationNotifier extends StateNotifier<UserLocationState> {
  final ApiClient? apiClient;

  UserLocationNotifier({this.apiClient}) : super(const UserLocationState());

  static const Map<String, List<double>> _cityCoordinates = {
    'Mumbai': [19.0760, 72.8777],
    'Delhi': [28.6139, 77.2090],
    'Bangalore': [12.9716, 77.5946],
    'Pune': [18.5204, 73.8567],
    'Hyderabad': [17.3850, 78.4867],
    'Goa': [15.2993, 74.1240],
    'Chennai': [13.0827, 80.2707],
    'Kolkata': [22.5726, 88.3639],
  };

  /// Explicitly detects current location with server-authoritative resolution
  Future<CurrentLocationResult> detectCurrentLocation() async {
    state = state.copyWith(detectionStatus: LocationDetectionStatus.loading, lastError: null);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          detectionStatus: LocationDetectionStatus.serviceDisabled,
          lastError: 'Location services are disabled on your device.',
        );
        return const CurrentLocationResult(
          status: LocationDetectionStatus.serviceDisabled,
          message: 'Location services are turned off. Please enable GPS in settings.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            detectionStatus: LocationDetectionStatus.permissionDenied,
            lastError: 'Location permission was denied.',
          );
          return const CurrentLocationResult(
            status: LocationDetectionStatus.permissionDenied,
            message: 'Location permission is required to detect your location.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          detectionStatus: LocationDetectionStatus.permanentlyDenied,
          lastError: 'Location permission is permanently denied.',
        );
        return const CurrentLocationResult(
          status: LocationDetectionStatus.permanentlyDenied,
          message: 'Location access is blocked in app settings. Please enable it in system settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      String resolvedCity = _findNearestCity(position.latitude, position.longitude);
      String? resolvedState;
      double? distKm;
      bool isWithinRange = true;
      List<ServerResolvedPickupHub> hubs = [];

      // Server-authoritative resolution via backend
      if (apiClient != null) {
        try {
          final response = await apiClient!.dio.get(
            '/locations/resolve-current-location',
            queryParameters: {
              'lat': position.latitude,
              'lng': position.longitude,
            },
          );

          if (response.statusCode == 200 && response.data is Map) {
            final data = response.data as Map<String, dynamic>;
            final nearest = data['nearestCity'] as Map<String, dynamic>?;
            if (nearest != null) {
              resolvedCity = nearest['name'] as String? ?? resolvedCity;
              resolvedState = nearest['state'] as String?;
              distKm = (nearest['distanceKm'] as num?)?.toDouble();
              isWithinRange = nearest['isWithinOperationalRange'] as bool? ?? true;
            }

            final suggested = data['suggestedPickupLocations'] as List<dynamic>?;
            if (suggested != null) {
              hubs = suggested
                  .map((item) => ServerResolvedPickupHub.fromJson(item as Map<String, dynamic>))
                  .toList();
            }
          }
        } catch (e) {
          debugPrint('Backend location resolution fallback: $e');
        }
      }

      state = state.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        isPermissionGranted: true,
        detectionStatus: LocationDetectionStatus.success,
        resolvedCity: resolvedCity,
        isWithinOperationalRange: isWithinRange,
        suggestedPickupLocations: hubs,
      );

      final message = !isWithinRange
          ? 'You are ${distKm?.toStringAsFixed(0) ?? '>100'}km from $resolvedCity. DriveGo operates within 100km of our active cities.'
          : null;

      return CurrentLocationResult(
        status: LocationDetectionStatus.success,
        latitude: position.latitude,
        longitude: position.longitude,
        resolvedCity: resolvedCity,
        resolvedState: resolvedState,
        resolvedLocality: hubs.isNotEmpty ? hubs.first.name : '$resolvedCity Central Hub',
        distanceToCityCenterKm: distKm,
        isWithinOperationalRange: isWithinRange,
        suggestedPickupLocations: hubs,
        message: message,
      );
    } catch (e) {
      debugPrint('Error detecting location: $e');
      state = state.copyWith(
        detectionStatus: LocationDetectionStatus.error,
        lastError: e.toString(),
      );
      return const CurrentLocationResult(
        status: LocationDetectionStatus.error,
        message: 'Could not retrieve your location. Please select manually.',
      );
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<void> requestLocationPermission(
    BuildContext context, {
    void Function(String city)? onCityAutoSelected,
    void Function(double lat, double lng)? onLocationResolved,
  }) async {
    if (state.isRequestedThisSession) return;

    state = state.copyWith(isRequestedThisSession: true);

    // Show rationale dialog first
    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue),
            SizedBox(width: 8),
            Text('Location Access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'DriveGo uses your location to show cars near you and automatically select your nearest city.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Manual Selection'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary,
              foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow Location'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );

        state = state.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          isPermissionGranted: true,
          detectionStatus: LocationDetectionStatus.success,
        );

        if (onLocationResolved != null) {
          onLocationResolved(position.latitude, position.longitude);
        } else if (onCityAutoSelected != null) {
          final nearest = _findNearestCity(position.latitude, position.longitude);
          onCityAutoSelected(nearest);
        }
      }
    } catch (e) {
      debugPrint('Geolocator error: $e');
    }
  }

  String _findNearestCity(double lat, double lng) {
    String nearest = 'Mumbai';
    double minDistance = double.infinity;

    _cityCoordinates.forEach((city, coords) {
      final distance = _calculateDistance(lat, lng, coords[0], coords[1]);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = city;
      }
    });

    return nearest;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }
}

final userLocationProvider = StateNotifierProvider<UserLocationNotifier, UserLocationState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UserLocationNotifier(apiClient: apiClient);
});

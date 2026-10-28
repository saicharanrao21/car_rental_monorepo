import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/core.dart';
import 'api_providers.dart';

enum LocationSource {
  none,
  gps,
  manual,
  saved,
}

enum LocationDetectionStatus {
  idle,
  loading,
  success,
  serviceDisabled,
  permissionDenied,
  permanentlyDenied,
  timeout,
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
  final String? resolvedLocality;
  final String? resolvedState;
  final LocationSource source;
  final bool isWithinOperationalRange;
  final List<ServerResolvedPickupHub> suggestedPickupLocations;

  const UserLocationState({
    this.latitude,
    this.longitude,
    this.isPermissionGranted = false,
    this.isRequestedThisSession = false,
    this.detectionStatus = LocationDetectionStatus.idle,
    this.lastError,
    this.resolvedCity,
    this.resolvedLocality,
    this.resolvedState,
    this.source = LocationSource.none,
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
    String? resolvedLocality,
    String? resolvedState,
    LocationSource? source,
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
      resolvedLocality: resolvedLocality ?? this.resolvedLocality,
      resolvedState: resolvedState ?? this.resolvedState,
      source: source ?? this.source,
      isWithinOperationalRange: isWithinOperationalRange ?? this.isWithinOperationalRange,
      suggestedPickupLocations: suggestedPickupLocations ?? this.suggestedPickupLocations,
    );
  }
}

class UserLocationNotifier extends StateNotifier<UserLocationState> {
  final ApiClient? apiClient;

  UserLocationNotifier({this.apiClient}) : super(const UserLocationState());

  static const String keySavedCity = 'drivego_selected_city';
  static const String keySavedLat = 'drivego_selected_lat';
  static const String keySavedLng = 'drivego_selected_lng';
  static const String keySavedLocality = 'drivego_selected_locality';
  static const String keySavedState = 'drivego_selected_state';
  static const String keySavedSource = 'drivego_selected_source';

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

  /// Loads saved location from SharedPreferences. Returns true if a valid location was restored.
  Future<bool> loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final city = prefs.getString(keySavedCity);
      if (city != null && city.trim().isNotEmpty) {
        final lat = prefs.getDouble(keySavedLat);
        final lng = prefs.getDouble(keySavedLng);
        final locality = prefs.getString(keySavedLocality);
        final stateName = prefs.getString(keySavedState);
        final sourceStr = prefs.getString(keySavedSource);
        final source = sourceStr == 'manual'
            ? LocationSource.manual
            : LocationSource.saved;

        state = state.copyWith(
          resolvedCity: city.trim(),
          resolvedLocality: locality,
          resolvedState: stateName,
          latitude: lat,
          longitude: lng,
          source: source,
          detectionStatus: LocationDetectionStatus.success,
        );
        return true;
      }
    } catch (e) {
      debugPrint('[UserLocationNotifier] Error loading saved location: $e');
    }
    return false;
  }

  /// Persists selected location to durable storage
  Future<void> saveLocation({
    required String city,
    double? lat,
    double? lng,
    String? locality,
    String? stateName,
    required LocationSource source,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keySavedCity, city.trim());
      if (lat != null) {
        await prefs.setDouble(keySavedLat, lat);
      } else {
        await prefs.remove(keySavedLat);
      }
      if (lng != null) {
        await prefs.setDouble(keySavedLng, lng);
      } else {
        await prefs.remove(keySavedLng);
      }
      if (locality != null) {
        await prefs.setString(keySavedLocality, locality);
      } else {
        await prefs.remove(keySavedLocality);
      }
      if (stateName != null) {
        await prefs.setString(keySavedState, stateName);
      } else {
        await prefs.remove(keySavedState);
      }
      await prefs.setString(keySavedSource, source.name);
    } catch (e) {
      debugPrint('[UserLocationNotifier] Error saving location: $e');
    }
  }

  /// Sets manual location selection explicitly
  Future<void> setManualLocation({
    required String city,
    double? lat,
    double? lng,
    String? locality,
    String? stateName,
  }) async {
    double? resolvedLat = lat;
    double? resolvedLng = lng;
    if (resolvedLat == null || resolvedLng == null) {
      if (_cityCoordinates.containsKey(city)) {
        resolvedLat = _cityCoordinates[city]![0];
        resolvedLng = _cityCoordinates[city]![1];
      }
    }

    state = state.copyWith(
      resolvedCity: city,
      resolvedLocality: locality ?? city,
      resolvedState: stateName,
      latitude: resolvedLat,
      longitude: resolvedLng,
      source: LocationSource.manual,
      detectionStatus: LocationDetectionStatus.success,
      lastError: null,
    );

    await saveLocation(
      city: city,
      lat: resolvedLat,
      lng: resolvedLng,
      locality: locality,
      stateName: stateName,
      source: LocationSource.manual,
    );
  }

  /// Clears saved location
  Future<void> clearSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keySavedCity);
      await prefs.remove(keySavedLat);
      await prefs.remove(keySavedLng);
      await prefs.remove(keySavedLocality);
      await prefs.remove(keySavedState);
      await prefs.remove(keySavedSource);
    } catch (e) {
      debugPrint('[UserLocationNotifier] Error clearing saved location: $e');
    }
    state = const UserLocationState();
  }

  /// Explicitly detects current location with server-authoritative resolution
  Future<CurrentLocationResult> detectCurrentLocation() async {
    state = state.copyWith(
      detectionStatus: LocationDetectionStatus.loading,
      lastError: null,
    );

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

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } on TimeoutException {
        state = state.copyWith(
          detectionStatus: LocationDetectionStatus.timeout,
          lastError: 'Location request timed out. Please select your location manually.',
        );
        return const CurrentLocationResult(
          status: LocationDetectionStatus.timeout,
          message: 'Location request timed out. Please select your location manually.',
        );
      } catch (e) {
        state = state.copyWith(
          detectionStatus: LocationDetectionStatus.error,
          lastError: 'GPS temporarily unavailable: $e',
        );
        return CurrentLocationResult(
          status: LocationDetectionStatus.error,
          message: 'GPS temporarily unavailable: $e',
        );
      }

      String? resolvedCity;
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
              resolvedCity = nearest['name'] as String?;
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
          // Try /supported-cities/nearest fallback
          try {
            final fbResponse = await apiClient!.dio.get(
              '/supported-cities/nearest',
              queryParameters: {
                'lat': position.latitude,
                'lng': position.longitude,
              },
            );
            if (fbResponse.statusCode == 200 && fbResponse.data is Map) {
              final cData = fbResponse.data as Map<String, dynamic>;
              resolvedCity = cData['name'] as String?;
              resolvedState = cData['state'] as String?;
            }
          } catch (_) {}
        }
      }

      // Client-side fallback if backend is unreachable
      resolvedCity ??= _findNearestCity(position.latitude, position.longitude);

      if (resolvedCity == null) {
        state = state.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          detectionStatus: LocationDetectionStatus.error,
          lastError: 'Could not resolve location to a supported city. Please select manually.',
          source: LocationSource.none,
        );
        return const CurrentLocationResult(
          status: LocationDetectionStatus.error,
          message: 'Could not resolve your location. Please select manually.',
        );
      }

      final localityName = hubs.isNotEmpty ? hubs.first.name : resolvedCity;

      state = state.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        isPermissionGranted: true,
        detectionStatus: LocationDetectionStatus.success,
        resolvedCity: resolvedCity,
        resolvedLocality: localityName,
        resolvedState: resolvedState,
        source: LocationSource.gps,
        isWithinOperationalRange: isWithinRange,
        suggestedPickupLocations: hubs,
        lastError: null,
      );

      await saveLocation(
        city: resolvedCity,
        lat: position.latitude,
        lng: position.longitude,
        locality: localityName,
        stateName: resolvedState,
        source: LocationSource.gps,
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
        resolvedLocality: localityName,
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

  Future<CurrentLocationResult?> requestLocationPermission(
    BuildContext context, {
    void Function(String city)? onCityAutoSelected,
    void Function(double lat, double lng)? onLocationResolved,
    bool force = false,
  }) async {
    if (state.isRequestedThisSession && !force) return null;
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

    if (shouldProceed != true) {
      return null;
    }

    final result = await detectCurrentLocation();
    if (result.status == LocationDetectionStatus.success && result.resolvedCity != null) {
      if (onLocationResolved != null && result.latitude != null && result.longitude != null) {
        onLocationResolved(result.latitude!, result.longitude!);
      }
      if (onCityAutoSelected != null) {
        onCityAutoSelected(result.resolvedCity!);
      }
    }
    return result;
  }

  String? _findNearestCity(double lat, double lng) {
    String? nearest;
    double minDistance = double.infinity;

    _cityCoordinates.forEach((city, coords) {
      final distance = _calculateDistance(lat, lng, coords[0], coords[1]);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = city;
      }
    });

    // If farther than 1000km from any known city in India, do not guess
    if (minDistance > 1000) {
      return null;
    }

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

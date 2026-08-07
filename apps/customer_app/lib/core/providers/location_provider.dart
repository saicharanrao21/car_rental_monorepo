import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class UserLocationState {
  final double? latitude;
  final double? longitude;
  final bool isPermissionGranted;
  final bool isRequestedThisSession;

  const UserLocationState({
    this.latitude,
    this.longitude,
    this.isPermissionGranted = false,
    this.isRequestedThisSession = true,
  });

  UserLocationState copyWith({
    double? latitude,
    double? longitude,
    bool? isPermissionGranted,
    bool? isRequestedThisSession,
  }) {
    return UserLocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isPermissionGranted: isPermissionGranted ?? this.isPermissionGranted,
      isRequestedThisSession: isRequestedThisSession ?? this.isRequestedThisSession,
    );
  }
}

class UserLocationNotifier extends StateNotifier<UserLocationState> {
  UserLocationNotifier() : super(const UserLocationState());

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
        );

        if (onLocationResolved != null) {
          onLocationResolved(position.latitude, position.longitude);
        } else if (onCityAutoSelected != null) {
          final nearest = _findNearestCity(position.latitude, position.longitude);
          onCityAutoSelected(nearest);
        }
      }
    } catch (e) {
      // Fallback cleanly on error or timeout
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
  return UserLocationNotifier();
});

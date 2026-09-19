import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'api_providers.dart';

final vendorSupportedCitiesProvider = FutureProvider<List<SupportedCityModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.dio.get('/supported-cities');
    final data = response.data as List<dynamic>;
    final cities = data
        .map((json) => SupportedCityModel.fromJson(Map<String, dynamic>.from(json)))
        .where((c) => c.isActive)
        .toList();
    if (cities.isNotEmpty) {
      return cities;
    }
  } catch (_) {}

  // Fallback to default constants if offline or empty
  return AppConstants.indianCities
      .map((name) => SupportedCityModel(
            id: name.toLowerCase(),
            name: name,
            state: '',
            latitude: 0.0,
            longitude: 0.0,
            isActive: true,
          ))
      .toList();
});

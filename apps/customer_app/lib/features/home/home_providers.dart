import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'domain/repositories/home_repository.dart';
import 'data/api_home_repository.dart';
import '../../core/providers/api_providers.dart';
import '../../core/providers/location_provider.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiHomeRepository(apiClient: apiClient);
});

final selectedCityProvider = StateProvider<String>((ref) => 'Mumbai');

final availableCarsProvider = FutureProvider<List<CarModel>>((ref) async {
  final city = ref.watch(selectedCityProvider);
  final location = ref.watch(userLocationProvider);
  final repo = ref.watch(homeRepositoryProvider);
  return repo.getCarsByCity(
    city,
    lat: location.latitude,
    lng: location.longitude,
    sortBy: 'RECOMMENDED',
  );
});

final topVendorsProvider = FutureProvider<List<VendorModel>>((ref) async {
  final city = ref.watch(selectedCityProvider);
  final repo = ref.watch(homeRepositoryProvider);
  final vendors = await repo.getTopVendorsByCity(city);
  vendors.sort((a, b) => b.rating.compareTo(a.rating));
  return vendors.take(5).toList();
});

final bannersProvider = FutureProvider<List<BannerModel>>((ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  return repo.getBanners();
});

final publicSettingsProvider = FutureProvider<PublicSettingsModel>((ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  return repo.getPublicSettings();
});

final supportedCitiesProvider = FutureProvider<List<SupportedCityModel>>((ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  return repo.getSupportedCities();
});

final selectedTripTypeProvider = StateProvider<String>((ref) => 'Self-Drive');

final selectedDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

final pickupLocationProvider = StateProvider<String?>((ref) => null);

final dropLocationProvider = StateProvider<String?>((ref) => null);

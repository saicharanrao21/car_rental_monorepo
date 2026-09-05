import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/fleet_repository.dart';
import '../../data/api_fleet_repository.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import 'package:models/models.dart';

final fleetRepositoryProvider = Provider<FleetRepository>((ref) {
  return ApiFleetRepository(apiClient: ref.watch(apiClientProvider));
});

final fleetCarsProvider = FutureProvider.autoDispose<List<CarModel>>((ref) async {
  final session = ref.watch(vendorSessionProvider);
  final vendorId = session.vendor?.id;
  if (vendorId == null) {
    throw Exception('No vendor logged in');
  }
  return ref.watch(fleetRepositoryProvider).getCarsForVendor(vendorId);
});

// Grid vs List view mode: true = grid, false = list
final fleetViewGridModeProvider = StateProvider<bool>((ref) => true);

// Search and Filter State Providers
final fleetSearchQueryProvider = StateProvider<String>((ref) => '');
final fleetFilterStatusProvider = StateProvider<String>((ref) => 'ALL');
final fleetFilterFuelProvider = StateProvider<String>((ref) => 'ALL');
final fleetFilterCategoryProvider = StateProvider<String>((ref) => 'ALL');

// Computed Filtered Fleet Cars Provider
final filteredFleetCarsProvider = Provider.autoDispose<AsyncValue<List<CarModel>>>((ref) {
  final carsAsync = ref.watch(fleetCarsProvider);
  final searchQuery = ref.watch(fleetSearchQueryProvider).trim().toLowerCase();
  final statusFilter = ref.watch(fleetFilterStatusProvider);
  final fuelFilter = ref.watch(fleetFilterFuelProvider);
  final categoryFilter = ref.watch(fleetFilterCategoryProvider);

  return carsAsync.whenData((cars) {
    return cars.where((car) {
      // 1. Search Query (Make, Model, Registration Number)
      if (searchQuery.isNotEmpty) {
        final matchesMake = car.make.toLowerCase().contains(searchQuery);
        final matchesModel = car.model.toLowerCase().contains(searchQuery);
        final matchesReg = car.registrationNumber.toLowerCase().contains(searchQuery);
        if (!matchesMake && !matchesModel && !matchesReg) {
          return false;
        }
      }

      // 2. Status Filter
      if (statusFilter != 'ALL') {
        if (statusFilter == 'AVAILABLE' && !car.isAvailable) return false;
        if (statusFilter == 'UNAVAILABLE' && car.isAvailable) return false;
        if (statusFilter == 'BLOCKED' && (car.blockedDates.isEmpty || !car.isAvailable)) return false;
      }

      // 3. Fuel Filter
      if (fuelFilter != 'ALL') {
        if (car.fuelType.toUpperCase() != fuelFilter.toUpperCase()) {
          return false;
        }
      }

      // 4. Category Filter
      if (categoryFilter != 'ALL') {
        if (car.type.toUpperCase() != categoryFilter.toUpperCase()) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});

// Fleet Health Summary Metrics Provider
class FleetHealthSummary {
  final int total;
  final int available;
  final int onTrip;
  final int maintenance;

  const FleetHealthSummary({
    required this.total,
    required this.available,
    required this.onTrip,
    required this.maintenance,
  });
}

final fleetHealthSummaryProvider = Provider.autoDispose<FleetHealthSummary>((ref) {
  final carsAsync = ref.watch(fleetCarsProvider);
  return carsAsync.maybeWhen(
    data: (cars) {
      final total = cars.length;
      final available = cars.where((c) => c.isAvailable && c.blockedDates.isEmpty).length;
      final blocked = cars.where((c) => c.blockedDates.isNotEmpty).length;
      final unavailable = cars.where((c) => !c.isAvailable).length;
      return FleetHealthSummary(
        total: total,
        available: available,
        onTrip: 0, // In dynamic data, active bookings determine onTrip
        maintenance: blocked + unavailable,
      );
    },
    orElse: () => const FleetHealthSummary(total: 0, available: 0, onTrip: 0, maintenance: 0),
  );
});

class FleetController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> toggleAvailability(String carId, bool isAvailable) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(fleetRepositoryProvider).toggleCarAvailability(carId, isAvailable);
      ref.invalidate(fleetCarsProvider);
      ref.invalidate(dashboardStatsProvider);
    });
    state = result;
    return !result.hasError;
  }

  Future<bool> addCar(CarModel car) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(fleetRepositoryProvider).addCar(car);
      ref.invalidate(fleetCarsProvider);
      ref.invalidate(dashboardStatsProvider);
    });
    state = result;
    return !result.hasError;
  }

  Future<bool> updateCar(CarModel car) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(fleetRepositoryProvider).updateCar(car);
      ref.invalidate(fleetCarsProvider);
      ref.invalidate(dashboardStatsProvider);
    });
    state = result;
    return !result.hasError;
  }

  Future<bool> updateBlockedDates(String carId, List<DateTime> blockedDates) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(fleetRepositoryProvider).updateBlockedDates(carId, blockedDates);
      ref.invalidate(fleetCarsProvider);
    });
    state = result;
    return !result.hasError;
  }

  Future<bool> createBlock({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
    required String blockType,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(fleetRepositoryProvider).createVehicleBlock(
            carId: carId,
            startDate: startDate,
            endDate: endDate,
            blockType: blockType,
            reason: reason,
          );
      ref.invalidate(vehicleBlocksProvider(carId));
      ref.invalidate(vehicleTimelineProvider(carId));
      ref.invalidate(fleetCarsProvider);
    });
    state = result;
    return !result.hasError;
  }

  Future<bool> deleteBlock({required String blockId, required String carId}) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(fleetRepositoryProvider).deleteVehicleBlock(blockId);
      ref.invalidate(vehicleBlocksProvider(carId));
      ref.invalidate(vehicleTimelineProvider(carId));
      ref.invalidate(fleetCarsProvider);
    });
    state = result;
    return !result.hasError;
  }
}

final fleetControllerProvider = AutoDisposeAsyncNotifierProvider<FleetController, void>(() {
  return FleetController();
});

final vehicleTimelineProvider = FutureProvider.family.autoDispose<List<AvailabilityTimelineEntry>, String>((ref, carId) async {
  final now = DateTime.now();
  final start = now.subtract(const Duration(days: 7));
  final end = now.add(const Duration(days: 30));
  return ref.watch(fleetRepositoryProvider).getVehicleAvailabilityTimeline(carId, start, end);
});

final vehicleBlocksProvider = FutureProvider.family.autoDispose<List<VehicleBlockModel>, String>((ref, carId) async {
  return ref.watch(fleetRepositoryProvider).getVehicleBlocks(carId);
});

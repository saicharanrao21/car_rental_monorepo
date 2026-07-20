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
}

final fleetControllerProvider = AutoDisposeAsyncNotifierProvider<FleetController, void>(() {
  return FleetController();
});

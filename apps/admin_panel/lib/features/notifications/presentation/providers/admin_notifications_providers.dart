import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/core/providers/api_providers.dart';
import '../../domain/repositories/admin_notifications_repository.dart';
import '../../data/api_admin_notifications_repository.dart';
import '../../data/mock_admin_notifications_repository.dart';

final adminNotificationsRepositoryProvider = Provider<AdminNotificationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiAdminNotificationsRepository(apiClient);
});

class SentNotificationsNotifier extends AsyncNotifier<List<SentNotification>> {
  @override
  Future<List<SentNotification>> build() {
    return ref.read(adminNotificationsRepositoryProvider).getSentHistory();
  }

  Future<void> sendNotification({
    required String target,
    required String title,
    required String body,
  }) async {
    final repo = ref.read(adminNotificationsRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repo.sendNotification(
        target: target,
        title: title,
        body: body,
      );
      final newHistory = await repo.getSentHistory();
      state = AsyncData(newHistory);
    } catch (err, stack) {
      state = AsyncError(err, stack);
    }
  }
}

final sentNotificationsProvider =
    AsyncNotifierProvider<SentNotificationsNotifier, List<SentNotification>>(() {
  return SentNotificationsNotifier();
});

// Compose Form State Providers
final notificationTargetProvider = StateProvider<String>((ref) => 'All Users');
final notificationCityProvider = StateProvider<String>((ref) => 'Mumbai');
final notificationPhoneProvider = StateProvider<String>((ref) => '');
final notificationTitleProvider = StateProvider<String>((ref) => '');
final notificationBodyProvider = StateProvider<String>((ref) => '');

// --- Phase 31: Delivery Governance & Telemetry Providers ---
final notificationDeliveryStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'ALL');
final notificationDeliveryChannelFilterProvider = StateProvider.autoDispose<String>((ref) => 'ALL');

final adminDeliveryStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final repo = ref.watch(adminNotificationsRepositoryProvider);
    return await repo.getDeliveryStats();
  } catch (_) {
    final fallbackRepo = MockAdminNotificationsRepository();
    return await fallbackRepo.getDeliveryStats();
  }
});

class AdminDeliveriesNotifier extends AutoDisposeAsyncNotifier<List<NotificationDeliveryModel>> {
  @override
  Future<List<NotificationDeliveryModel>> build() async {
    final status = ref.watch(notificationDeliveryStatusFilterProvider);
    final channel = ref.watch(notificationDeliveryChannelFilterProvider);

    try {
      final repo = ref.watch(adminNotificationsRepositoryProvider);
      return await repo.getDeliveries(
        status: status,
        channel: channel,
      );
    } catch (_) {
      final fallbackRepo = MockAdminNotificationsRepository();
      return await fallbackRepo.getDeliveries(
        status: status,
        channel: channel,
      );
    }
  }

  Future<void> retry(String deliveryId) async {
    try {
      final repo = ref.read(adminNotificationsRepositoryProvider);
      await repo.retryDelivery(deliveryId);
      ref.invalidateSelf();
      ref.invalidate(adminDeliveryStatsProvider);
    } catch (_) {
      final fallbackRepo = MockAdminNotificationsRepository();
      await fallbackRepo.retryDelivery(deliveryId);
      ref.invalidateSelf();
      ref.invalidate(adminDeliveryStatsProvider);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    ref.invalidate(adminDeliveryStatsProvider);
    await future;
  }
}

final adminDeliveriesProvider =
    AutoDisposeAsyncNotifierProvider<AdminDeliveriesNotifier, List<NotificationDeliveryModel>>(
        AdminDeliveriesNotifier.new);

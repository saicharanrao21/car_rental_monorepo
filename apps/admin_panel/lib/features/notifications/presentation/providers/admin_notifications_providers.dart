import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/admin_notifications_repository.dart';
import '../../data/mock_admin_notifications_repository.dart';

final adminNotificationsRepositoryProvider = Provider<AdminNotificationsRepository>((ref) {
  return MockAdminNotificationsRepository();
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

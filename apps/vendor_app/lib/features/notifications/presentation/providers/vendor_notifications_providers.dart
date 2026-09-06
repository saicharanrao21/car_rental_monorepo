import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/vendor_notifications_repository.dart';
import '../../data/api_vendor_notifications_repository.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';

final vendorNotificationsRepositoryProvider = Provider<VendorNotificationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiVendorNotificationsRepository(apiClient: apiClient);
});

class VendorNotificationsNotifier extends AutoDisposeAsyncNotifier<List<NotificationModel>> {
  @override
  Future<List<NotificationModel>> build() async {
    final session = ref.watch(vendorSessionProvider);
    final vendor = session.vendor;
    final vendorUserId = vendor?.id ?? 'vnd_active_01';

    final repo = ref.watch(vendorNotificationsRepositoryProvider);
    return repo.getNotifications(vendorUserId);
  }

  Future<void> markAllAsRead() async {
    final session = ref.read(vendorSessionProvider);
    final vendorUserId = session.vendor?.id ?? 'vnd_active_01';

    state = const AsyncValue.loading();
    try {
      final repo = ref.read(vendorNotificationsRepositoryProvider);
      await repo.markAllRead(vendorUserId);
      state = state.whenData((list) => list.map((n) => n.copyWith(isRead: true)).toList());
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final repo = ref.read(vendorNotificationsRepositoryProvider);
      await repo.markAsRead(id);
      state = state.whenData((list) => list.map((n) {
        if (n.id == id) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList());
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final vendorNotificationsProvider =
    AutoDisposeAsyncNotifierProvider<VendorNotificationsNotifier, List<NotificationModel>>(
        VendorNotificationsNotifier.new);

final vendorUnreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notificationsAsync = ref.watch(vendorNotificationsProvider);
  final list = notificationsAsync.valueOrNull ?? [];
  return list.where((n) => !n.isRead).length;
});

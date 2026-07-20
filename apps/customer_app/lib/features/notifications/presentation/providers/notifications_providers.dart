import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../data/api_notifications_repository.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/session_provider.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiNotificationsRepository(apiClient: apiClient);
});

class NotificationsListNotifier extends AutoDisposeAsyncNotifier<List<NotificationModel>> {
  @override
  Future<List<NotificationModel>> build() async {
    final session = ref.watch(sessionProvider);
    if (!session.isAuthenticated || session.user == null) {
      return [];
    }
    final repo = ref.watch(notificationsRepositoryProvider);
    return repo.getNotifications(session.user!.id);
  }

  Future<void> markAllAsRead() async {
    final session = ref.read(sessionProvider);
    if (session.user == null) return;
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.markAllRead(session.user!.id);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final notificationsListProvider =
    AutoDisposeAsyncNotifierProvider<NotificationsListNotifier, List<NotificationModel>>(
        NotificationsListNotifier.new);

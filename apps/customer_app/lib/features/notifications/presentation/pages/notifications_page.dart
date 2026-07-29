import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/notifications_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsVal = ref.watch(notificationsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(notificationsListProvider.notifier).markAllAsRead();
            },
            child: const Text(
              'Mark all read',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: notificationsVal.when(
        loading: () => const AppLoader(),
        error: (err, stack) => ErrorStateWidget(
          message: 'Failed to load notifications: $err',
          onRetry: () => ref.read(notificationsListProvider.notifier).refresh(),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_off_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap(16),
                    const Text(
                      'No Notifications Yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      'Any trip updates or promotional offers will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsListProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Gap(12),
              itemBuilder: (context, index) {
                final item = list[index];
                return AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Unread Dot
                      if (!item.isRead)
                        Container(
                          margin: const EdgeInsets.only(top: 4, right: 12),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        )
                      else
                        const Gap(20),

                      // Notification Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 14,
                                color: item.isRead
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const Gap(4),
                            Text(
                              item.body,
                              style: TextStyle(
                                fontSize: 13,
                                color: item.isRead
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const Gap(8),
                            Text(
                              item.createdAt.toDDMMYYYY(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

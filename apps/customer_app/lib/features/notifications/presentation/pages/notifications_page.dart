import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/notifications_providers.dart';

enum NotificationFilterTab { all, operational, promotions }

final notificationFilterProvider = StateProvider.autoDispose<NotificationFilterTab>((ref) {
  return NotificationFilterTab.all;
});

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsVal = ref.watch(notificationsListProvider);
    final activeFilter = ref.watch(notificationFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            key: const Key('notification_mark_all_read'),
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
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(
                  context: context,
                  ref: ref,
                  label: 'All',
                  tab: NotificationFilterTab.all,
                  current: activeFilter,
                  keyStr: 'notifications_filter_all',
                ),
                const Gap(8),
                _buildFilterChip(
                  context: context,
                  ref: ref,
                  label: 'Operational',
                  tab: NotificationFilterTab.operational,
                  current: activeFilter,
                  keyStr: 'notifications_filter_operational',
                ),
                const Gap(8),
                _buildFilterChip(
                  context: context,
                  ref: ref,
                  label: 'Promotions',
                  tab: NotificationFilterTab.promotions,
                  current: activeFilter,
                  keyStr: 'notifications_filter_promotions',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: notificationsVal.when(
              loading: () => const AppLoader(),
              error: (err, stack) => ErrorStateWidget(
                message: 'Failed to load notifications: $err',
                onRetry: () => ref.read(notificationsListProvider.notifier).refresh(),
              ),
              data: (list) {
                final filtered = list.where((item) {
                  final cat = (item.category.isNotEmpty ? item.category : item.type).toUpperCase();
                  if (activeFilter == NotificationFilterTab.operational) {
                    return cat == 'BOOKING' ||
                        cat == 'PAYMENT' ||
                        cat == 'FULFILLMENT' ||
                        cat == 'REFUND' ||
                        cat == 'SECURITY';
                  } else if (activeFilter == NotificationFilterTab.promotions) {
                    return cat == 'PROMOTION' || cat == 'MARKETING';
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
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
                            'No Notifications Found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Gap(8),
                          Text(
                            activeFilter == NotificationFilterTab.all
                                ? 'Any trip updates or operational notifications will appear here.'
                                : 'No notifications match the selected filter.',
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
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Gap(12),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _NotificationCard(item: item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required NotificationFilterTab tab,
    required NotificationFilterTab current,
    required String keyStr,
  }) {
    final isSelected = tab == current;
    return FilterChip(
      key: Key(keyStr),
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
      ),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      onSelected: (_) {
        ref.read(notificationFilterProvider.notifier).state = tab;
      },
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final dynamic item;

  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = (item.category?.isNotEmpty == true ? item.category : item.type).toString().toUpperCase();
    final isHighPriority = item.priority == 'HIGH';

    return InkWell(
      key: Key('notification_item_${item.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (!item.isRead) {
          ref.read(notificationsListProvider.notifier).markAsRead(item.id);
        }
        _handleDeepLink(context);
      },
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Icon with Circle Background
            _buildCategoryIcon(category, isHighPriority),
            const Gap(12),

            // Notification Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Category Tag Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(category).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getCategoryColor(category),
                          ),
                        ),
                      ),
                      if (isHighPriority) ...[
                        const Gap(6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'URGENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  const Gap(6),

                  Text(
                    item.title.isNotEmpty ? item.title : 'Operational Alert',
                    style: TextStyle(
                      fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                      fontSize: 14,
                      color: item.isRead
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (item.body.isNotEmpty) ...[
                    const Gap(4),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: item.isRead
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                  const Gap(8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const Gap(4),
                      Text(
                        _formatDate(item.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),

                      if (item.entityId != null && item.entityId.isNotEmpty) ...[
                        const Spacer(),
                        const Row(
                          children: [
                            Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Gap(2),
                            Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
                          ],
                        ),
                      ],

                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }


  void _handleDeepLink(BuildContext context) {

    if (item.entityId != null && item.entityId.isNotEmpty) {
      if (item.entityType == 'BOOKING' || item.category == 'BOOKING' || item.category == 'FULFILLMENT') {
        context.push('/bookings/${item.entityId}');
        return;
      }
    }
    if (item.actionUrl != null && item.actionUrl.isNotEmpty) {
      String url = item.actionUrl;
      if (url.startsWith('/my-bookings/')) {
        url = url.replaceAll('/my-bookings/', '/bookings/');
      }
      context.push(url);
    }
  }

  Widget _buildCategoryIcon(String category, bool isHighPriority) {
    final color = isHighPriority ? Colors.redAccent : _getCategoryColor(category);
    IconData iconData = Icons.notifications_active_outlined;
    switch (category) {
      case 'BOOKING':
        iconData = Icons.directions_car_outlined;
        break;
      case 'PAYMENT':
        iconData = Icons.account_balance_wallet_outlined;
        break;
      case 'FULFILLMENT':
        iconData = Icons.local_shipping_outlined;
        break;
      case 'REFUND':
        iconData = Icons.currency_rupee_outlined;
        break;
      case 'SECURITY':
        iconData = Icons.shield_outlined;
        break;
      case 'PROMOTION':
        iconData = Icons.local_offer_outlined;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 20),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'BOOKING':
        return Colors.blue;
      case 'PAYMENT':
        return Colors.green;
      case 'FULFILLMENT':
        return Colors.purple;
      case 'REFUND':
        return Colors.teal;
      case 'SECURITY':
        return Colors.deepOrange;
      case 'PROMOTION':
        return Colors.amber.shade800;
      default:
        return AppColors.primary;
    }
  }
}

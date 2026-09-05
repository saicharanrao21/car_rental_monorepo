import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

import 'package:gap/gap.dart';

import 'package:models/models.dart';
import '../providers/vendor_notifications_providers.dart';

enum VendorNotificationFilter { all, operations, payouts, alerts }

final vendorNotificationFilterProvider = StateProvider.autoDispose<VendorNotificationFilter>((ref) {
  return VendorNotificationFilter.all;
});

class VendorNotificationsPage extends ConsumerWidget {
  const VendorNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsVal = ref.watch(vendorNotificationsProvider);
    final activeFilter = ref.watch(vendorNotificationFilterProvider);
    final unreadCount = ref.watch(vendorUnreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: DDSColors.bgCanvas,
      appBar: AppBar(
        backgroundColor: DDSColors.primaryNavy,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text(
              'Operational Alerts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (unreadCount > 0) ...[
              const Gap(8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: DDSColors.errorRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount NEW',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton.icon(
            key: const Key('vendor_mark_all_read'),
            icon: const Icon(Icons.done_all, size: 16, color: Colors.white),
            label: const Text(
              'Mark all read',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            onPressed: () {
              ref.read(vendorNotificationsProvider.notifier).markAllAsRead();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    context: context,
                    ref: ref,
                    label: 'All Alerts',
                    filter: VendorNotificationFilter.all,
                    current: activeFilter,
                    keyStr: 'vendor_filter_all',
                  ),
                  const Gap(8),
                  _buildFilterChip(
                    context: context,
                    ref: ref,
                    label: 'Operations & Fleet',
                    filter: VendorNotificationFilter.operations,
                    current: activeFilter,
                    keyStr: 'vendor_filter_operations',
                  ),
                  const Gap(8),
                  _buildFilterChip(
                    context: context,
                    ref: ref,
                    label: 'Payouts & Escrow',
                    filter: VendorNotificationFilter.payouts,
                    current: activeFilter,
                    keyStr: 'vendor_filter_payouts',
                  ),
                  const Gap(8),
                  _buildFilterChip(
                    context: context,
                    ref: ref,
                    label: 'Disputes & Security',
                    filter: VendorNotificationFilter.alerts,
                    current: activeFilter,
                    keyStr: 'vendor_filter_alerts',
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: DDSColors.borderLight),


          Expanded(
            child: notificationsVal.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: DDSColors.errorRed),
                      const Gap(12),
                      Text('Failed to load alerts: $err', textAlign: TextAlign.center),
                      const Gap(12),
                      ElevatedButton(
                        onPressed: () => ref.read(vendorNotificationsProvider.notifier).refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (list) {
                final filtered = list.where((item) {
                  final cat = (item.category.isNotEmpty ? item.category : item.type).toUpperCase();
                  if (activeFilter == VendorNotificationFilter.operations) {
                    return cat == 'BOOKING' || cat == 'FULFILLMENT';
                  } else if (activeFilter == VendorNotificationFilter.payouts) {
                    return cat == 'PAYMENT' || cat == 'PAYOUT';
                  } else if (activeFilter == VendorNotificationFilter.alerts) {
                    return cat == 'SECURITY' || cat == 'DISPUTE';
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => ref.read(vendorNotificationsProvider.notifier).refresh(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        height: 400,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_paused_outlined,
                              size: 56,
                              color: DDSColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            const Gap(16),
                            Text(
                              'No Alerts in This Category',
                              style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Gap(8),
                            Text(
                              'Operational, handover, and escrow notifications will appear here.',
                              textAlign: TextAlign.center,
                              style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(vendorNotificationsProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Gap(12),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _VendorNotificationCard(item: item);
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
    required VendorNotificationFilter filter,
    required VendorNotificationFilter current,
    required String keyStr,
  }) {
    final isSelected = filter == current;
    return FilterChip(
      key: Key(keyStr),
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? DDSColors.primaryBlue : DDSColors.textPrimary,
      ),
      selectedColor: DDSColors.primaryBlue.withValues(alpha: 0.12),
      checkmarkColor: DDSColors.primaryBlue,
      onSelected: (_) {
        ref.read(vendorNotificationFilterProvider.notifier).state = filter;
      },
    );
  }
}

class _VendorNotificationCard extends ConsumerWidget {
  final NotificationModel item;

  const _VendorNotificationCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = (item.category.isNotEmpty ? item.category : item.type).toUpperCase();
    final isUrgent = item.priority == 'HIGH';

    return InkWell(
      key: Key('vendor_notification_card_${item.id}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (!item.isRead) {
          ref.read(vendorNotificationsProvider.notifier).markAsRead(item.id);
        }
        _handleNavigation(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: !item.isRead
                ? DDSColors.primaryBlue.withValues(alpha: 0.5)
                : DDSColors.borderLight,

            width: !item.isRead ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circular Icon
            _buildCategoryIcon(category, isUrgent),
            const Gap(12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Badge
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
                      if (isUrgent) ...[
                        const Gap(6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: DDSColors.errorRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ACTION REQUIRED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: DDSColors.errorRed,
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
                            color: DDSColors.primaryBlue,
                          ),
                        ),
                    ],
                  ),
                  const Gap(6),

                  // Title
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                      fontSize: 14,
                      color: item.isRead ? DDSColors.textPrimary : Colors.black,
                    ),
                  ),
                  const Gap(4),

                  // Body
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: item.isRead ? DDSColors.textSecondary : DDSColors.textPrimary,
                    ),
                  ),
                  const Gap(8),

                  // Footer timestamp & action
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 12, color: DDSColors.textSecondary),
                      const Gap(4),
                      Text(
                        _formatDate(item.createdAt),
                        style: const TextStyle(fontSize: 11, color: DDSColors.textSecondary),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            _getActionLabel(category, item.eventType),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: DDSColors.primaryBlue,
                            ),
                          ),
                          const Gap(2),
                          const Icon(Icons.arrow_forward, size: 12, color: DDSColors.primaryBlue),
                        ],
                      ),
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

  String _getActionLabel(String category, String? eventType) {
    if (eventType == 'HANDOVER_READY') return 'Open Handover';
    if (eventType == 'RETURN_PENDING') return 'Start Return';
    if (eventType == 'SETTLEMENT_ELIGIBLE') return 'View Wallet';
    if (category == 'BOOKING') return 'View Booking';
    return 'View Details';
  }

  void _handleNavigation(BuildContext context) {
    if (item.actionUrl != null && item.actionUrl!.isNotEmpty) {
      context.push(item.actionUrl!);
      return;
    }
    if (item.entityId != null && item.entityId!.isNotEmpty) {
      if (item.category == 'BOOKING' || item.category == 'FULFILLMENT') {
        context.push('/bookings/${item.entityId}');
        return;
      }
    }
  }

  Widget _buildCategoryIcon(String category, bool isUrgent) {
    final color = isUrgent ? DDSColors.errorRed : _getCategoryColor(category);
    IconData icon = Icons.notifications_active;
    switch (category) {
      case 'BOOKING':
        icon = Icons.calendar_today_outlined;
        break;
      case 'FULFILLMENT':
        icon = Icons.key_outlined;
        break;
      case 'PAYMENT':
      case 'PAYOUT':
        icon = Icons.account_balance_wallet_outlined;
        break;
      case 'SECURITY':
      case 'DISPUTE':
        icon = Icons.warning_amber_rounded;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'BOOKING':
        return DDSColors.primaryBlue;
      case 'FULFILLMENT':
        return Colors.deepPurple;
      case 'PAYMENT':
      case 'PAYOUT':
        return DDSColors.successGreen;
      case 'SECURITY':
      case 'DISPUTE':
        return DDSColors.warningOrange;
      default:

        return DDSColors.primaryNavy;
    }
  }
}

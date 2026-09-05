import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../domain/repositories/admin_notifications_repository.dart';
import '../providers/admin_notifications_providers.dart';

class PushNotificationsPage extends ConsumerStatefulWidget {
  const PushNotificationsPage({super.key});

  @override
  ConsumerState<PushNotificationsPage> createState() => _PushNotificationsPageState();
}

class _PushNotificationsPageState extends ConsumerState<PushNotificationsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _phoneController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _phoneController = TextEditingController();

    _titleController.addListener(() {
      ref.read(notificationTitleProvider.notifier).state = _titleController.text;
    });
    _bodyController.addListener(() {
      ref.read(notificationBodyProvider.notifier).state = _bodyController.text;
    });
    _phoneController.addListener(() {
      ref.read(notificationPhoneProvider.notifier).state = _phoneController.text;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _titleController.clear();
    _bodyController.clear();
    _phoneController.clear();
    ref.read(notificationTargetProvider.notifier).state = 'All Users';
    ref.read(notificationCityProvider.notifier).state = 'Mumbai';
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
    });

    final targetType = ref.read(notificationTargetProvider);
    String target = targetType;
    if (targetType == 'Specific City') {
      target = 'City:${ref.read(notificationCityProvider)}';
    } else if (targetType == 'Specific User (Phone)') {
      target = 'Phone:${ref.read(notificationPhoneProvider)}';
    }

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(sentNotificationsProvider.notifier).sendNotification(
            target: target,
            title: title,
            body: body,
          );

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Push notification sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
      }
    } catch (err) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notification Operations & Control Tower',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Gap(4),
                        Text(
                          'Multi-channel dispatch, queue observability, provider telemetry, and dead-letter governance.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),
                  ElevatedButton.icon(

                    key: const Key('admin_notifications_refresh_btn'),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      ref.read(adminDeliveriesProvider.notifier).refresh();
                    },
                  ),
                ],
              ),
              const Gap(16),

              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.track_changes_rounded, size: 18),
                      text: 'Delivery Telemetry & Governance',
                    ),
                    Tab(
                      icon: Icon(Icons.campaign_outlined, size: 18),
                      text: 'Broadcast Composer',
                    ),
                  ],
                ),
              ),
              const Gap(16),

              // Tab Views
              Expanded(
                child: TabBarView(
                  children: [
                    _buildTelemetryAndGovernanceTab(context),
                    _buildBroadcastComposerTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 1: Delivery Telemetry & Governance ---
  Widget _buildTelemetryAndGovernanceTab(BuildContext context) {
    final statsAsync = ref.watch(adminDeliveryStatsProvider);
    final deliveriesAsync = ref.watch(adminDeliveriesProvider);
    final statusFilter = ref.watch(notificationDeliveryStatusFilterProvider);
    final channelFilter = ref.watch(notificationDeliveryChannelFilterProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI Cards Row
          statsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Stats error: $err'),
            data: (stats) {
              final total = stats['total'] ?? 0;
              final delivered = stats['delivered'] ?? 0;
              final failed = stats['failed'] ?? 0;
              final deadLetter = stats['deadLetter'] ?? 0;
              final successRate = (stats['successRate'] as num?)?.toDouble() ?? 0.0;

              return Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Total Dispatches',
                      value: '$total',
                      icon: Icons.all_inbox_rounded,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Delivered',
                      value: '$delivered',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Failed / Retrying',
                      value: '$failed',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Dead Letter',
                      value: '$deadLetter',
                      icon: Icons.cancel_outlined,
                      color: Colors.redAccent,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Success Rate',
                      value: '${successRate.toStringAsFixed(1)}%',
                      icon: Icons.analytics_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              );
            },
          ),
          const Gap(16),

          // Filters & Table Card
          AppCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filter Controls
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        'Operational Channel Deliveries',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Gap(24),

                      // Channel Dropdown
                      const Text('Channel: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const Gap(6),
                      DropdownButton<String>(
                        key: const Key('admin_filter_channel_dropdown'),
                        value: channelFilter,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Channels')),
                          DropdownMenuItem(value: 'PUSH', child: Text('Push (FCM)')),
                          DropdownMenuItem(value: 'SMS', child: Text('SMS (Twilio)')),
                          DropdownMenuItem(value: 'WHATSAPP', child: Text('WhatsApp')),
                          DropdownMenuItem(value: 'EMAIL', child: Text('Email (SMTP)')),
                          DropdownMenuItem(value: 'IN_APP', child: Text('In-App')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(notificationDeliveryChannelFilterProvider.notifier).state = val;
                          }
                        },
                      ),
                      const Gap(16),

                      // Status Dropdown
                      const Text('Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const Gap(6),
                      DropdownButton<String>(
                        key: const Key('admin_filter_status_dropdown'),
                        value: statusFilter,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'DELIVERED', child: Text('Delivered')),
                          DropdownMenuItem(value: 'FAILED', child: Text('Failed')),
                          DropdownMenuItem(value: 'DEAD_LETTER', child: Text('Dead Letter')),
                          DropdownMenuItem(value: 'QUEUED', child: Text('Queued')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(notificationDeliveryStatusFilterProvider.notifier).state = val;
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),


                // Deliveries List / Table
                deliveriesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load deliveries: $err', style: const TextStyle(color: Colors.red)),
                  ),
                  data: (deliveries) {
                    if (deliveries.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No delivery logs matching current filters.')),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: deliveries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = deliveries[index];
                        return _buildDeliveryRow(context, item);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryRow(BuildContext context, NotificationDeliveryModel item) {
    final statusColor = _getStatusColor(item.status);
    final channelIcon = _getChannelIcon(item.channel);
    final canRetry = item.status == 'FAILED' || item.status == 'DEAD_LETTER';

    return Padding(
      key: Key('delivery_row_${item.id}'),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel Avatar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(channelIcon, size: 20, color: Colors.blueAccent),
          ),
          const Gap(12),

          // Event, Title, Target
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.eventType ?? 'OPERATIONAL',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        item.notificationTitle ?? 'Notification',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const Gap(4),
                Text(
                  'Recipient: ${item.recipientName ?? "Customer"} (${item.recipientTarget ?? "N/A"})',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (item.lastError != null && item.lastError!.isNotEmpty) ...[
                  const Gap(4),
                  Text(
                    'Error: ${item.lastError}',
                    style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),

          // Provider & Reference
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Provider: ${item.provider ?? "N/A"}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Gap(2),
                Text(
                  'Ref: ${item.providerMessageId != null ? item.providerMessageId!.substring(0, item.providerMessageId!.length.clamp(0, 24)) : "None"}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(
                  'Attempts: ${item.attemptCount}/${item.maxRetries}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              item.status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Gap(16),

          // Retry Action Button
          if (canRetry)
            IconButton(
              key: Key('retry_btn_${item.id}'),
              icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
              tooltip: 'Retry Delivery Dispatch',
              onPressed: () {
                ref.read(adminDeliveriesProvider.notifier).retry(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Queued retry for delivery ${item.id}'),
                    backgroundColor: Colors.blueGrey,
                  ),
                );
              },
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),

    );
  }

  IconData _getChannelIcon(String channel) {
    switch (channel.toUpperCase()) {
      case 'PUSH':
        return Icons.notifications_active;
      case 'SMS':
        return Icons.sms_outlined;
      case 'WHATSAPP':
        return Icons.chat_bubble_outline;
      case 'EMAIL':
        return Icons.mail_outline;
      default:
        return Icons.phone_android;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
      case 'SENT':
        return Colors.green;
      case 'FAILED':
        return Colors.orange.shade800;
      case 'DEAD_LETTER':
        return Colors.red.shade700;
      case 'QUEUED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // --- TAB 2: Broadcast Composer ---
  Widget _buildBroadcastComposerTab(BuildContext context) {
    final targetType = ref.watch(notificationTargetProvider);
    final historyAsync = ref.watch(sentNotificationsProvider);

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Composer Form
          Expanded(
            flex: 5,
            child: Column(
              children: [
                AppCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Compose Broadcast',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Gap(16),

                        // Audience Selector
                        DropdownButtonFormField<String>(
                          initialValue: targetType,
                          decoration: const InputDecoration(
                            labelText: 'Target Audience',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All Users', child: Text('All Registered Users')),
                            DropdownMenuItem(value: 'All Vendors', child: Text('All Active Vendors')),
                            DropdownMenuItem(value: 'Specific City', child: Text('Users in Specific City')),
                            DropdownMenuItem(value: 'Specific User (Phone)', child: Text('Single User (Phone)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(notificationTargetProvider.notifier).state = val;
                            }
                          },
                        ),
                        const Gap(16),

                        if (targetType == 'Specific City') ...[
                          DropdownButtonFormField<String>(
                            initialValue: ref.watch(notificationCityProvider),
                            decoration: const InputDecoration(
                              labelText: 'Select City',
                              border: OutlineInputBorder(),
                            ),

                            items: const [
                              DropdownMenuItem(value: 'Mumbai', child: Text('Mumbai')),
                              DropdownMenuItem(value: 'Delhi NCR', child: Text('Delhi NCR')),
                              DropdownMenuItem(value: 'Bangalore', child: Text('Bangalore')),
                              DropdownMenuItem(value: 'Hyderabad', child: Text('Hyderabad')),
                              DropdownMenuItem(value: 'Goa', child: Text('Goa')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(notificationCityProvider.notifier).state = val;
                              }
                            },
                          ),
                          const Gap(16),
                        ],

                        if (targetType == 'Specific User (Phone)') ...[
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              hintText: 'e.g. 9876543210',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter a target phone number';
                              }
                              return null;
                            },
                          ),
                          const Gap(16),
                        ],

                        // Title Field
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Notification Title',
                            hintText: 'e.g., Weekend Flash Sale 🏎️',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a notification title';
                            }
                            return null;
                          },
                        ),
                        const Gap(16),

                        // Message Body
                        TextFormField(
                          controller: _bodyController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Message Body',
                            hintText: 'Enter your push notification payload text here...',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a message body';
                            }
                            return null;
                          },
                        ),
                        const Gap(20),

                        // Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: _isSending ? null : _clearForm,
                              child: const Text('Clear'),
                            ),
                            const Gap(12),
                            ElevatedButton.icon(
                              onPressed: _isSending ? null : _handleSend,
                              icon: _isSending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(_isSending ? 'Dispatching...' : 'Dispatch Push'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(24),
                _buildLivePreviewCard(context),
              ],
            ),
          ),
          const Gap(24),

          // Right: History Card
          Expanded(
            flex: 4,
            child: _buildHistoryCard(context, historyAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreviewCard(BuildContext context) {
    final title = ref.watch(notificationTitleProvider);
    final body = ref.watch(notificationBodyProvider);

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Device Preview',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const Gap(12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: Colors.blueAccent, size: 20),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title.isEmpty ? 'Notification Title' : title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text('now', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                        ],
                      ),
                      const Gap(4),
                      Text(
                        body.isEmpty ? 'Type message body in composer to preview live.' : body,
                        style: TextStyle(color: Colors.grey[300], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, AsyncValue<List<SentNotification>> historyAsync) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Broadcast History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Gap(16),
          SizedBox(
            height: 480,
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Failed to load history: $err')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No sent notifications found'));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.mark_email_read_outlined, size: 18, color: AppColors.primary),
                      ),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Gap(2),
                          Text(item.body, style: const TextStyle(fontSize: 12)),
                          const Gap(4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(item.target, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const Spacer(),
                              Text(DateFormat('dd MMM yyyy, hh:mm a').format(item.sentAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

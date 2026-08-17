import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../providers/whatsapp_providers.dart';

class AdminWhatsAppPage extends ConsumerStatefulWidget {
  const AdminWhatsAppPage({super.key});

  @override
  ConsumerState<AdminWhatsAppPage> createState() => _AdminWhatsAppPageState();
}

class _AdminWhatsAppPageState extends ConsumerState<AdminWhatsAppPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(whatsAppSummaryProvider);
    final messagesAsync = ref.watch(whatsAppMessagesProvider);
    final selectedStatus = ref.watch(whatsAppStatusFilterProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WhatsApp Business Communications',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const Gap(4),
                      Text(
                        'Monitor transactional notifications, delivery receipts, and template dispatch logs',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                AppButton(
                  text: 'Refresh Logs',
                  isFullWidth: false,
                  onPressed: () {
                    ref.invalidate(whatsAppSummaryProvider);
                    ref.invalidate(whatsAppMessagesProvider);
                  },
                ),
              ],
            ),
            const Gap(20),

            // Summary Metrics Row
            summaryAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: AppLoader()),
              ),
              error: (err, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: Text('Error loading summary: $err')),
                ),
              ),
              data: (summary) => _buildSummaryCards(context, summary),
            ),
            const Gap(20),

            // Filters Row
            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by phone number or booking ID...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        ref.read(whatsAppSearchQueryProvider.notifier).state = val.trim();
                      },
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const Gap(8),
                          ChoiceChip(
                            label: const Text('All'),
                            selected: selectedStatus == null,
                            onSelected: (val) {
                              if (val) ref.read(whatsAppStatusFilterProvider.notifier).state = null;
                            },
                          ),
                          const Gap(6),
                          ...WhatsAppMessageStatus.values.map((status) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(status.displayName),
                                selected: selectedStatus == status,
                                onSelected: (val) {
                                  ref.read(whatsAppStatusFilterProvider.notifier).state = val ? status : null;
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(20),

            // Messages Table
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => Center(child: Text('Error loading messages: $err')),
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(child: Text('No WhatsApp messages match the selected filters.'));
                  }

                  return AppCard(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return _buildMessageRow(context, msg);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, WhatsAppSummaryModel summary) {
    final cards = [
      _buildKpiCard('Total Messages', '${summary.totalMessages}', Colors.blue, Icons.chat_outlined),
      _buildKpiCard('Delivered', '${summary.deliveredCount}', Colors.green, Icons.done_all),
      _buildKpiCard('Read Receipts', '${summary.readCount}', Colors.indigo, Icons.mark_chat_read_outlined),
      _buildKpiCard('Failed', '${summary.failedCount}', Colors.red, Icons.error_outline),
      _buildKpiCard('Delivery Rate', '${summary.deliveryRatePercent.toStringAsFixed(1)}%', Colors.teal, Icons.trending_up),
    ];

    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: c,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, IconData icon) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Gap(6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(BuildContext context, WhatsAppMessageModel msg) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final timeStr = msg.sentAt != null ? dateFormat.format(msg.sentAt!) : dateFormat.format(msg.createdAt);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.chat, color: Colors.green, size: 22),
      ),
      title: Row(
        children: [
          Text(
            msg.phoneNumber,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const Gap(10),
          _buildStatusBadge(msg.status),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              msg.messageType.displayName,
              style: TextStyle(fontSize: 10, color: Colors.grey[800], fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Template: ${msg.templateName} • Ref: ${msg.bookingId ?? 'Direct'} • Time: $timeStr',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ),
      trailing: msg.status == WhatsAppMessageStatus.failed
          ? TextButton.icon(
              onPressed: () => _handleResend(msg.id),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Resend', style: TextStyle(fontSize: 12)),
            )
          : null,
    );
  }

  Widget _buildStatusBadge(WhatsAppMessageStatus status) {
    Color bg;
    Color fg = Colors.white;

    switch (status) {
      case WhatsAppMessageStatus.read:
        bg = Colors.indigo;
        break;
      case WhatsAppMessageStatus.delivered:
        bg = Colors.green;
        break;
      case WhatsAppMessageStatus.sent:
        bg = Colors.teal;
        break;
      case WhatsAppMessageStatus.failed:
        bg = Colors.red;
        break;
      case WhatsAppMessageStatus.queued:
        bg = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _handleResend(String id) async {
    try {
      final repo = ref.read(whatsAppRepositoryProvider);
      await repo.resendMessage(id);
      ref.invalidate(whatsAppSummaryProvider);
      ref.invalidate(whatsAppMessagesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp message queued for re-delivery.')),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend message: $err')),
        );
      }
    }
  }
}

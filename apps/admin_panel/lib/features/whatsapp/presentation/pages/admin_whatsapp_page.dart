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

  void _showComposeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _ComposeWhatsAppDialog(
        onSuccess: () {
          ref.invalidate(whatsAppSummaryProvider);
          ref.invalidate(whatsAppMessagesProvider);
        },
      ),
    );
  }

  void _showTemplateRegistryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _WhatsAppTemplateRegistryDialog(),
    );
  }

  void _showTimelineDialog(BuildContext context, String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => _WhatsAppTimelineDialog(messageId: messageId),
    );
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
                        'Monitor transactional notifications, manage templates, compose messages, and inspect delivery receipts',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                Wrap(
                  spacing: 12,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: const Text('Template Registry'),
                      onPressed: () => _showTemplateRegistryDialog(context),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                      onPressed: () {
                        ref.invalidate(whatsAppSummaryProvider);
                        ref.invalidate(whatsAppMessagesProvider);
                      },
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Compose Message'),
                      onPressed: () => _showComposeDialog(context),
                    ),
                  ],
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
                    return const Center(
                      child: Text('No WhatsApp messages found matching criteria.'),
                    );
                  }

                  return AppCard(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, index) => _buildMessageRow(context, messages[index]),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Messages',
                summary.totalMessages.toString(),
                Icons.mark_chat_unread_outlined,
                Colors.blue,
              ),
            ),
            const Gap(12),
            Expanded(
              child: _buildMetricCard(
                'Sent',
                summary.sentCount.toString(),
                Icons.send_outlined,
                Colors.teal,
              ),
            ),
            const Gap(12),
            Expanded(
              child: _buildMetricCard(
                'Delivered',
                summary.deliveredCount.toString(),
                Icons.done_all,
                Colors.green,
              ),
            ),
            const Gap(12),
            Expanded(
              child: _buildMetricCard(
                'Read Receipts',
                summary.readCount.toString(),
                Icons.visibility_outlined,
                Colors.indigo,
              ),
            ),
            const Gap(12),
            Expanded(
              child: _buildMetricCard(
                'Failed',
                summary.failedCount.toString(),
                Icons.error_outline,
                Colors.red,
              ),
            ),
            const Gap(12),
            Expanded(
              child: _buildMetricCard(
                'Delivery Rate',
                '${summary.deliveryRatePercent.toStringAsFixed(1)}%',
                Icons.analytics_outlined,
                Colors.amber[800]!,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
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
      onTap: () => _showTimelineDialog(context, msg.id),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.timeline, size: 18, color: Colors.blueGrey),
            tooltip: 'View Delivery Timeline',
            onPressed: () => _showTimelineDialog(context, msg.id),
          ),
          if (msg.status == WhatsAppMessageStatus.failed)
            TextButton.icon(
              onPressed: () => _handleResend(msg.id),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Resend', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
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

// ─── Manual Message Composer Modal ──────────────────────────────────────────

class _ComposeWhatsAppDialog extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const _ComposeWhatsAppDialog({required this.onSuccess});

  @override
  ConsumerState<_ComposeWhatsAppDialog> createState() => _ComposeWhatsAppDialogState();
}

class _ComposeWhatsAppDialogState extends ConsumerState<_ComposeWhatsAppDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _bookingIdController = TextEditingController();
  final Map<String, TextEditingController> _paramControllers = {};
  String? _selectedTemplate;
  bool _isSending = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _bookingIdController.dispose();
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateTemplate(String tplName, List<dynamic> requiredVars) {
    setState(() {
      _selectedTemplate = tplName;
      for (final c in _paramControllers.values) {
        c.dispose();
      }
      _paramControllers.clear();
      for (final v in requiredVars) {
        _paramControllers[v.toString()] = TextEditingController();
      }
    });
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTemplate == null) return;

    setState(() => _isSending = true);

    try {
      final variables = <String, dynamic>{};
      for (final entry in _paramControllers.entries) {
        variables[entry.key] = entry.value.text.trim();
      }

      final repo = ref.read(whatsAppRepositoryProvider);
      await repo.sendManualMessage(
        phoneNumber: _phoneController.text.trim(),
        templateName: _selectedTemplate!,
        variables: variables,
        bookingId: _bookingIdController.text.trim().isNotEmpty
            ? _bookingIdController.text.trim()
            : null,
      );

      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp template message dispatched successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to dispatch message: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(whatsAppTemplatesProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.send_to_mobile, color: Color(0xFF16A34A), size: 24),
                          Gap(10),
                          Text(
                            'Compose WhatsApp Message',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  AppTextField(
                    label: 'Recipient Phone Number (E.164 or 10-digit)',
                    controller: _phoneController,
                    hint: 'e.g. +919876543210 or 9876543210',
                    keyboardType: TextInputType.phone,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Phone is required' : null,
                  ),
                  const Gap(12),
                  AppTextField(
                    label: 'Associated Booking ID (Optional)',
                    controller: _bookingIdController,
                    hint: 'e.g. bkg-12345',
                  ),
                  const Gap(16),
                  const Text('Select Approved Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Gap(6),
                  templatesAsync.when(
                    loading: () => const Center(child: AppLoader()),
                    error: (err, _) => Text('Error loading templates: $err', style: const TextStyle(color: Colors.red)),
                    data: (templates) {
                      if (templates.isEmpty) {
                        return const Text('No templates registered.');
                      }

                      return DropdownButtonFormField<String>(
                        value: _selectedTemplate,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        hint: const Text('Choose a registered template...'),
                        items: templates.map((t) {
                          return DropdownMenuItem<String>(
                            value: t['name'].toString(),
                            child: Text('${t['name']} (${t['category']})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final tpl = templates.firstWhere((t) => t['name'] == val);
                            final reqVars = (tpl['requiredVariables'] as List<dynamic>?) ?? [];
                            _updateTemplate(val, reqVars);
                          }
                        },
                        validator: (val) => val == null ? 'Please select a template' : null,
                      );
                    },
                  ),
                  if (_paramControllers.isNotEmpty) ...[
                    const Gap(16),
                    const Text('Template Variables', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Gap(8),
                    ..._paramControllers.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppTextField(
                          label: entry.key,
                          controller: entry.value,
                          hint: 'Value for {{${entry.key}}}',
                          validator: (v) => v == null || v.trim().isEmpty ? '${entry.key} is required' : null,
                        ),
                      );
                    }),
                  ],
                  const Gap(20),
                  _isSending
                      ? const Center(child: AppLoader())
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.send, size: 18),
                          label: const Text('Send Message Now', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _send,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Template Registry Inspection Modal ──────────────────────────────────────

class _WhatsAppTemplateRegistryDialog extends ConsumerWidget {
  const _WhatsAppTemplateRegistryDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(whatsAppTemplatesProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified, color: Color(0xFF2563EB), size: 24),
                      Gap(10),
                      Text(
                        'Meta Approved WhatsApp Templates',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: templatesAsync.when(
                  loading: () => const Center(child: AppLoader()),
                  error: (err, _) => Center(child: Text('Error loading templates: $err')),
                  data: (templates) {
                    return ListView.separated(
                      itemCount: templates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final t = templates[idx];
                        final reqVars = (t['requiredVariables'] as List<dynamic>?) ?? [];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    t['name'].toString(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB)),
                                  ),
                                  const Gap(8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      t['status'].toString(),
                                      style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Gap(8),
                                  Text(
                                    '${t['category']} • ${t['language']}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                              const Gap(4),
                              Text(
                                t['description'].toString(),
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                              const Gap(6),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  t['bodySample'].toString(),
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87),
                                ),
                              ),
                              const Gap(4),
                              Text(
                                'Parameters: [${reqVars.join(', ')}]',
                                style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic),
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
        ),
      ),
    );
  }
}

// ─── Delivery Timeline Modal ────────────────────────────────────────────────

class _WhatsAppTimelineDialog extends ConsumerWidget {
  final String messageId;

  const _WhatsAppTimelineDialog({required this.messageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.timeline, color: Color(0xFF2563EB), size: 24),
                      Gap(10),
                      Text(
                        'Message Delivery Timeline',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: ref.read(whatsAppRepositoryProvider).getMessageTimeline(messageId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: AppLoader());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final data = snapshot.data ?? {};
                    final msg = data['message'] as Map<String, dynamic>? ?? {};
                    final timeline = (data['timeline'] as List<dynamic>?) ?? [];
                    final dateFormat = DateFormat('dd MMM yyyy, hh:mm:ss a');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Recipient: ${msg['phoneNumber']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Template: ${msg['templateName']} | Status: ${msg['status']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              if (msg['providerMessageId'] != null)
                                Text('Provider ID: ${msg['providerMessageId']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: timeline.length,
                            itemBuilder: (context, idx) {
                              final item = timeline[idx] as Map<String, dynamic>;
                              final event = item['event'].toString();
                              final time = item['timestamp'] != null
                                  ? dateFormat.format(DateTime.parse(item['timestamp'].toString()))
                                  : 'N/A';
                              final details = item['details']?.toString() ?? '';

                              Color iconColor = Colors.green;
                              IconData iconData = Icons.check_circle;
                              if (event == 'QUEUED') {
                                iconColor = Colors.grey;
                                iconData = Icons.schedule;
                              } else if (event == 'SENT') {
                                iconColor = Colors.teal;
                                iconData = Icons.send;
                              } else if (event == 'FAILED') {
                                iconColor = Colors.red;
                                iconData = Icons.error;
                              } else if (event == 'READ') {
                                iconColor = Colors.indigo;
                                iconData = Icons.visibility;
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Icon(iconData, color: iconColor, size: 20),
                                      if (idx < timeline.length - 1)
                                        Container(
                                          width: 2,
                                          height: 36,
                                          color: Colors.grey[300],
                                        ),
                                    ],
                                  ),
                                  const Gap(12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(event, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: iconColor)),
                                            Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                        Text(details, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                        const Gap(12),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

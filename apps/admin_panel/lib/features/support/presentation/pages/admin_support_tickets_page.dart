import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:dio/dio.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';

final adminSupportTicketsProvider =
    FutureProvider.family.autoDispose<List<SupportTicketModel>, String?>((ref, statusFilter) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get(
    '/admin/support/tickets',
    queryParameters: statusFilter != null && statusFilter != 'ALL' ? {'status': statusFilter} : null,
  );
  final raw = response.data;
  final List list = raw is Map ? (raw['tickets'] as List? ?? []) : (raw is List ? raw : []);
  return list.map((e) => SupportTicketModel.fromJson(e as Map<String, dynamic>)).toList();
});

class AdminSupportTicketsPage extends ConsumerStatefulWidget {
  const AdminSupportTicketsPage({super.key});

  @override
  ConsumerState<AdminSupportTicketsPage> createState() => _AdminSupportTicketsPageState();
}

class _AdminSupportTicketsPageState extends ConsumerState<AdminSupportTicketsPage> {
  String _selectedStatus = 'ALL';

  void _openTicketDetailDialog(SupportTicketModel ticket) {
    showDialog(
      context: context,
      builder: (ctx) => _TicketDetailDialog(
        ticketId: ticket.id,
        onUpdated: () => ref.invalidate(adminSupportTicketsProvider(_selectedStatus)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(adminSupportTicketsProvider(_selectedStatus));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer Support Tickets',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Gap(4),
                    Text('Manage customer support requests, staff assignments and SLA resolution.',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  onPressed: () => ref.invalidate(adminSupportTicketsProvider(_selectedStatus)),
                ),
              ],
            ),
            const Gap(20),

            // Status Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('ALL', 'All Tickets'),
                  _filterChip('OPEN', 'Open'),
                  _filterChip('ASSIGNED', 'Assigned'),
                  _filterChip('IN_PROGRESS', 'In Progress'),
                  _filterChip('WAITING_FOR_CUSTOMER', 'Waiting on Customer'),
                  _filterChip('RESOLVED', 'Resolved'),
                  _filterChip('CLOSED', 'Closed'),
                ],
              ),
            ),
            const Gap(16),

            // Tickets Data Table / List
            Expanded(
              child: ticketsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error loading tickets: $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.support_agent_outlined, size: 64, color: Colors.grey.shade400),
                          const Gap(12),
                          const Text('No tickets found for this filter.',
                              style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: ListView.separated(
                      itemCount: tickets.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final t = tickets[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: _getPriorityColor(t.priority).withValues(alpha: 0.15),
                            child: Icon(Icons.confirmation_number_outlined,
                                color: _getPriorityColor(t.priority), size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(t.ticketNumber,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const Gap(8),
                              _buildStatusBadge(t.status),
                              const Gap(8),
                              _buildPriorityBadge(t.priority),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Gap(4),
                              Text(t.subject,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const Gap(2),
                              Text(
                                'Category: ${t.category.label} | Customer: ${t.customerName ?? t.customerId}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade800,
                              elevation: 0,
                            ),
                            onPressed: () => _openTicketDetailDialog(t),
                            child: const Text('View & Reply', style: TextStyle(fontSize: 12)),
                          ),
                        );
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

  Widget _filterChip(String statusKey, String label) {
    final isSelected = _selectedStatus == statusKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12)),
        selected: isSelected,
        selectedColor: Colors.blue.shade700,
        checkmarkColor: Colors.white,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedStatus = statusKey;
            });
          }
        },
      ),
    );
  }

  Color _getPriorityColor(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.URGENT:
        return Colors.red;
      case TicketPriority.HIGH:
        return Colors.orange;
      case TicketPriority.NORMAL:
        return Colors.blue;
      case TicketPriority.LOW:
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge(TicketStatus status) {
    Color color;
    switch (status) {
      case TicketStatus.OPEN:
        color = Colors.blue;
        break;
      case TicketStatus.ASSIGNED:
        color = Colors.indigo;
        break;
      case TicketStatus.IN_PROGRESS:
        color = Colors.purple;
        break;
      case TicketStatus.WAITING_FOR_CUSTOMER:
      case TicketStatus.WAITING_FOR_VENDOR:
        color = Colors.amber.shade800;
        break;
      case TicketStatus.RESOLVED:
      case TicketStatus.CLOSED:
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(status.label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPriorityBadge(TicketPriority priority) {
    final color = _getPriorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(priority.name,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _TicketDetailDialog extends ConsumerStatefulWidget {
  final String ticketId;
  final VoidCallback onUpdated;

  const _TicketDetailDialog({required this.ticketId, required this.onUpdated});

  @override
  ConsumerState<_TicketDetailDialog> createState() => _TicketDetailDialogState();
}

class _TicketDetailDialogState extends ConsumerState<_TicketDetailDialog> {
  final _replyController = TextEditingController();
  bool _isInternal = false;
  bool _isSending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final msg = _replyController.text.trim();
    if (msg.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.post(
        '/support/tickets/${widget.ticketId}/reply',
        data: {
          'message': msg,
          'isInternal': _isInternal,
        },
      );
      _replyController.clear();
      widget.onUpdated();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error replying: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _updateStatus(TicketStatus newStatus) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.patch(
        '/admin/support/tickets/${widget.ticketId}/status',
        data: {'status': newStatus.name},
      );
      widget.onUpdated();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = ref.watch(apiClientProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 650,
        padding: const EdgeInsets.all(24),
        child: FutureBuilder(
          future: apiClient.dio.get('/support/tickets/${widget.ticketId}'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading ticket: ${snapshot.error}'));
            }

            final res = snapshot.data as Response;
            final ticket =
                SupportTicketModel.fromJson(res.data as Map<String, dynamic>);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ticket #${ticket.ticketNumber}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(ticket.subject,
                            style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                    Row(
                      children: [
                        DropdownButton<TicketStatus>(
                          value: ticket.status,
                          items: TicketStatus.values.map((s) {
                            return DropdownMenuItem(value: s, child: Text(s.label));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) _updateStatus(val);
                          },
                        ),
                        const Gap(8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Description Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Original Customer Description:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const Gap(4),
                      Text(ticket.description, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const Gap(16),

                // Message Thread
                Expanded(
                  child: ListView.builder(
                    itemCount: ticket.messages.length,
                    itemBuilder: (context, index) {
                      final msg = ticket.messages[index];
                      final isStaff = msg.senderRole == 'ADMIN' || msg.senderRole == 'SUPPORT_AGENT';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: msg.isInternal
                              ? Colors.amber.shade50
                              : (isStaff ? Colors.blue.shade50 : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: msg.isInternal
                                ? Colors.amber.shade300
                                : (isStaff ? Colors.blue.shade200 : Colors.grey.shade300),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${msg.senderName ?? msg.senderRole} (${msg.senderRole})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: msg.isInternal ? Colors.amber.shade900 : Colors.black87,
                                  ),
                                ),
                                if (msg.isInternal)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('🔒 Internal Staff Note',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const Gap(6),
                            Text(msg.message, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 24),

                // Reply Composer
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        decoration: InputDecoration(
                          hintText: _isInternal
                              ? 'Type an internal staff note (hidden from customer)...'
                              : 'Type reply to customer...',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const Gap(12),
                    FilterChip(
                      label: const Text('Internal Note', style: TextStyle(fontSize: 12)),
                      selected: _isInternal,
                      selectedColor: Colors.amber.shade200,
                      onSelected: (val) => setState(() => _isInternal = val),
                    ),
                    const Gap(12),
                    ElevatedButton.icon(
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, size: 16),
                      label: const Text('Send'),
                      onPressed: _isSending ? null : _sendReply,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

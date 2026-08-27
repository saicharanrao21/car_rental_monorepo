import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import '../providers/support_providers.dart';

class TicketDetailPage extends ConsumerStatefulWidget {
  final String ticketId;

  const TicketDetailPage({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends ConsumerState<TicketDetailPage> {
  final _replyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.replyTicket(
        ticketId: widget.ticketId,
        message: text,
      );
      _replyController.clear();
      ref.invalidate(supportTicketDetailProvider(widget.ticketId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending reply: $e'), backgroundColor: Colors.red),
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

  Future<void> _closeTicket() async {
    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.closeTicket(widget.ticketId);
      ref.invalidate(supportTicketDetailProvider(widget.ticketId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket closed.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error closing ticket: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reopenTicket() async {
    final reasonController = TextEditingController();
    final shouldReopen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen Ticket'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Why do you need to reopen this ticket?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );

    if (shouldReopen == true && reasonController.text.trim().isNotEmpty) {
      try {
        final repo = ref.read(supportRepositoryProvider);
        await repo.reopenTicket(
          ticketId: widget.ticketId,
          reason: reasonController.text.trim(),
        );
        ref.invalidate(supportTicketDetailProvider(widget.ticketId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket reopened.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reopening ticket: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(supportTicketDetailProvider(widget.ticketId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Discussion'),
      ),
      body: ticketAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const Gap(12),
              Text('Error: $err'),
              const Gap(12),
              ElevatedButton(
                onPressed: () => ref.invalidate(supportTicketDetailProvider(widget.ticketId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (ticket) {
          final isClosed = ticket.status == TicketStatus.CLOSED;
          final isResolved = ticket.status == TicketStatus.RESOLVED;

          return Column(
            children: [
              // Ticket Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ticket.ticketNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(ticket.status.label, style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Gap(6),
                    Text(
                      ticket.subject,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Gap(6),
                    Row(
                      children: [
                        Text(
                          'Category: ${ticket.category.label}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Spacer(),
                        if (isResolved)
                          OutlinedButton(
                            onPressed: _closeTicket,
                            child: const Text('Close Ticket', style: TextStyle(fontSize: 12)),
                          )
                        else if (isClosed)
                          OutlinedButton(
                            onPressed: _reopenTicket,
                            child: const Text('Reopen Ticket', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Conversation Messages Timeline
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ticket.messages.length,
                  itemBuilder: (context, index) {
                    final msg = ticket.messages[index];
                    final isCust = msg.senderRole == 'CUSTOMER';

                    return Align(
                      alignment: isCust ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        decoration: BoxDecoration(
                          color: isCust ? AppColors.primary : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isCust ? 'You' : (msg.senderName ?? 'Support Agent'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isCust ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                const Gap(8),
                                Text(
                                  '${msg.createdAt.hour}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isCust ? Colors.white60 : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                            const Gap(4),
                            Text(
                              msg.message,
                              style: TextStyle(
                                fontSize: 13,
                                color: isCust ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Reply Composer
              if (!isClosed)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          decoration: const InputDecoration(
                            hintText: 'Type your message...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const Gap(8),
                      IconButton.filled(
                        icon: _isSending
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send),
                        onPressed: _isSending ? null : _sendReply,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  width: double.infinity,
                  child: const Text(
                    'This ticket is closed. Tap Reopen above if you need further assistance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

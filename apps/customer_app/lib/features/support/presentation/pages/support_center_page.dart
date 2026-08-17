import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import '../providers/support_providers.dart';
import 'create_ticket_page.dart';
import 'ticket_detail_page.dart';

class SupportCenterPage extends ConsumerStatefulWidget {
  const SupportCenterPage({super.key});

  @override
  ConsumerState<SupportCenterPage> createState() => _SupportCenterPageState();
}

class _SupportCenterPageState extends ConsumerState<SupportCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  final List<(String, String, String)> _faqs = const [
    ('Booking', 'How do I cancel my booking?', 'You can cancel any upcoming booking directly from My Bookings. Simply tap the booking card, click "Cancel Booking", select your reason, and confirm.'),
    ('Booking', 'Can I extend my ongoing trip?', 'Yes! You can request a 1-tap trip extension right from your active booking page up to 2 hours before scheduled return.'),
    ('Payment', 'When is the Security Deposit refunded?', 'Security deposits are automatically processed within 24 to 48 hours post-trip inspection and returned directly to your original payment method.'),
    ('Payment', 'How does GST tax invoicing work?', 'Every confirmed booking generates an authoritative GST tax invoice itemizing base rent, convenience fee, GST (18%), and delivery add-ons.'),
    ('Vehicle', 'What documents do I need to present?', 'You must present an original Driving Licence (DL) and an Aadhaar/Govt ID card matching your verified profile during vehicle key handover.'),
    ('Emergency', 'What if my car breaks down on the road?', 'Tap the red "Emergency Assistance (SOS)" button inside your active booking page. Our 24/7 roadside assistance dispatch will coordinate roadside technicians or a flatbed tow immediately.'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support Center'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.help_outline), text: 'FAQs & Help'),
            Tab(icon: Icon(Icons.confirmation_number_outlined), text: 'My Tickets'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Raise Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const CreateTicketPage()),
          );
          if (created == true) {
            ref.invalidate(mySupportTicketsProvider);
            _tabController.animateTo(1);
          }
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFaqTab(),
          _buildTicketsTab(),
        ],
      ),
    );
  }

  Widget _buildFaqTab() {
    final filteredFaqs = _faqs.where((f) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return f.$1.toLowerCase().contains(q) ||
          f.$2.toLowerCase().contains(q) ||
          f.$3.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Direct Support Contact Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.headset_mic, color: AppColors.primary, size: 28),
                ),
                const Gap(16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DriveGo 24/7 Helpline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Gap(4),
                      Text('support@drivego.in • 1800-200-3000', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),

          // Search Field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search help topics & questions...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
          const Gap(16),

          const Text('Frequently Asked Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Gap(12),

          if (filteredFaqs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No FAQs match your search.')),
            )
          else
            ...filteredFaqs.map((faq) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: ExpansionTile(
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        faq.$1,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    title: Text(faq.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedAlignment: Alignment.topLeft,
                    children: [
                      Text(faq.$3, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
                    ],
                  ),
                ),
              );
            }),
          const Gap(80), // Fab clearance
        ],
      ),
    );
  }

  Widget _buildTicketsTab() {
    final ticketsAsync = ref.watch(mySupportTicketsProvider);

    return ticketsAsync.when(
      loading: () => const Center(child: AppLoader()),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const Gap(12),
            Text('Failed to load tickets: $err'),
            const Gap(12),
            ElevatedButton(
              onPressed: () => ref.invalidate(mySupportTicketsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (tickets) {
        if (tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey.shade400),
                const Gap(16),
                const Text('No Support Tickets Raised', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Gap(8),
                const Text('Need assistance with a booking or payment? Tap Raise Ticket below.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(mySupportTicketsProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TicketDetailPage(ticketId: ticket.id),
                      ),
                    ).then((_) => ref.invalidate(mySupportTicketsProvider));
                  },
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
                          _buildStatusBadge(ticket.status),
                        ],
                      ),
                      const Gap(8),
                      Text(
                        ticket.subject,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const Gap(4),
                      Text(
                        ticket.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const Gap(12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(ticket.category.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                          ),
                          const Spacer(),
                          Text(
                            '${ticket.createdAt.day}/${ticket.createdAt.month}/${ticket.createdAt.year}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const Gap(8),
                          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(TicketStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case TicketStatus.OPEN:
        bg = Colors.blue.withOpacity(0.12);
        fg = Colors.blue;
        break;
      case TicketStatus.ASSIGNED:
      case TicketStatus.IN_PROGRESS:
        bg = Colors.orange.withOpacity(0.12);
        fg = Colors.orange;
        break;
      case TicketStatus.WAITING_FOR_CUSTOMER:
        bg = Colors.purple.withOpacity(0.12);
        fg = Colors.purple;
        break;
      case TicketStatus.WAITING_FOR_VENDOR:
        bg = Colors.amber.withOpacity(0.12);
        fg = Colors.amber.shade900;
        break;
      case TicketStatus.RESOLVED:
        bg = Colors.green.withOpacity(0.12);
        fg = Colors.green;
        break;
      case TicketStatus.CLOSED:
        bg = Colors.grey.withOpacity(0.12);
        fg = Colors.grey.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

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
        title: Text(
          'Help & Support Center',
          style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: DDSColors.primaryBlue,
          labelColor: DDSColors.primaryBlue,
          unselectedLabelColor: DDSColors.textMuted,
          labelStyle: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.help_outline), text: 'FAQs & Help'),
            Tab(icon: Icon(Icons.confirmation_number_outlined), text: 'My Tickets'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: DDSColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Raise Ticket', style: DDSTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.all(DDSSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Direct Support Contact Card
          Container(
            padding: const EdgeInsets.all(DDSSpacing.md),
            decoration: BoxDecoration(
              color: DDSColors.surfaceCard,
              borderRadius: DDSRadius.largeBorderRadius,
              border: Border.all(color: DDSColors.borderLight),
              boxShadow: DDSElevation.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DDSSpacing.sm),
                  decoration: BoxDecoration(
                    color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.headset_mic, color: DDSColors.primaryBlue, size: 28),
                ),
                const Gap(DDSSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DriveGo 24/7 Helpline', style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 15, color: DDSColors.textPrimary)),
                      const Gap(4),
                      Text('support@drivego.in • 1800-200-3000', style: DDSTypography.bodyMedium.copyWith(fontSize: 13, color: DDSColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(DDSSpacing.md),

          // Search Field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search help topics & questions...',
              hintStyle: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted),
              prefixIcon: const Icon(Icons.search, color: DDSColors.primaryBlue),
              border: OutlineInputBorder(borderRadius: DDSRadius.mediumBorderRadius),
              filled: true,
              fillColor: DDSColors.surfaceCard,
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
          const Gap(DDSSpacing.md),

          Text('Frequently Asked Questions', style: DDSTypography.titleMedium.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: DDSColors.textPrimary)),
          const Gap(DDSSpacing.sm),

          if (filteredFaqs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('No FAQs match your search.', style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted))),
            )
          else
            ...filteredFaqs.map((faq) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: DDSColors.surfaceCard,
                    borderRadius: DDSRadius.mediumBorderRadius,
                    border: Border.all(color: DDSColors.borderLight),
                    boxShadow: DDSElevation.cardShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ExpansionTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DDSColors.primaryBlue.withValues(alpha: 0.08),
                          borderRadius: DDSRadius.smallBorderRadius,
                        ),
                        child: Text(
                          faq.$1,
                          style: DDSTypography.labelSmall.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: DDSColors.primaryBlue),
                        ),
                      ),
                      title: Text(faq.$2, style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 14, color: DDSColors.textPrimary)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedAlignment: Alignment.topLeft,
                      children: [
                        Text(faq.$3, style: DDSTypography.bodyMedium.copyWith(fontSize: 13, color: DDSColors.textSecondary, height: 1.4)),
                      ],
                    ),
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
            const Icon(Icons.error_outline, size: 48, color: DDSColors.errorRed),
            const Gap(12),
            Text('Failed to load tickets: $err', style: DDSTypography.bodyMedium.copyWith(color: DDSColors.errorRed)),
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
                const Icon(Icons.confirmation_number_outlined, size: 64, color: DDSColors.textMuted),
                const Gap(16),
                Text('No Support Tickets Raised', style: DDSTypography.titleMedium.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: DDSColors.textPrimary)),
                const Gap(8),
                Text('Need assistance with a booking or payment? Tap Raise Ticket below.', textAlign: TextAlign.center, style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary, fontSize: 13)),
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
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TicketDetailPage(ticketId: ticket.id),
                      ),
                    ).then((_) => ref.invalidate(mySupportTicketsProvider));
                  },
                  borderRadius: DDSRadius.mediumBorderRadius,
                  child: Container(
                    padding: const EdgeInsets.all(DDSSpacing.md),
                    decoration: BoxDecoration(
                      color: DDSColors.surfaceCard,
                      borderRadius: DDSRadius.mediumBorderRadius,
                      border: Border.all(color: DDSColors.borderLight),
                      boxShadow: DDSElevation.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ticket.ticketNumber,
                              style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 13, color: DDSColors.primaryBlue),
                            ),
                            _buildStatusBadge(ticket.status),
                          ],
                        ),
                        const Gap(8),
                        Text(
                          ticket.subject,
                          style: DDSTypography.titleMedium.copyWith(fontSize: 15, fontWeight: FontWeight.bold, color: DDSColors.textPrimary),
                        ),
                        const Gap(4),
                        Text(
                          ticket.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DDSTypography.bodyMedium.copyWith(fontSize: 13, color: DDSColors.textSecondary),
                        ),
                        const Gap(12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: DDSColors.infoBlueBg,
                                borderRadius: DDSRadius.smallBorderRadius,
                              ),
                              child: Text(ticket.category.label, style: DDSTypography.labelSmall.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: DDSColors.primaryBlue)),
                            ),
                            const Spacer(),
                            Text(
                              '${ticket.createdAt.day}/${ticket.createdAt.month}/${ticket.createdAt.year}',
                              style: DDSTypography.labelSmall.copyWith(fontSize: 11, color: DDSColors.textMuted),
                            ),
                            const Gap(8),
                            const Icon(Icons.arrow_forward_ios, size: 12, color: DDSColors.textMuted),
                          ],
                        ),
                      ],
                    ),
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
        bg = DDSColors.infoBlueBg;
        fg = DDSColors.primaryBlue;
        break;
      case TicketStatus.ASSIGNED:
      case TicketStatus.IN_PROGRESS:
        bg = DDSColors.warningOrangeBg;
        fg = DDSColors.warningOrange;
        break;
      case TicketStatus.WAITING_FOR_CUSTOMER:
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        break;
      case TicketStatus.WAITING_FOR_VENDOR:
        bg = DDSColors.warningOrangeBg;
        fg = DDSColors.warningOrange;
        break;
      case TicketStatus.RESOLVED:
        bg = DDSColors.successGreenBg;
        fg = DDSColors.successGreen;
        break;
      case TicketStatus.CLOSED:
        bg = DDSColors.surfaceCard;
        fg = DDSColors.textMuted;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: DDSRadius.smallBorderRadius),
      child: Text(status.label, style: DDSTypography.labelSmall.copyWith(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

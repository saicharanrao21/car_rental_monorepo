import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../providers/admin_disputes_providers.dart';

class AdminDisputesPage extends ConsumerStatefulWidget {
  const AdminDisputesPage({super.key});

  @override
  ConsumerState<AdminDisputesPage> createState() => _AdminDisputesPageState();
}

class _AdminDisputesPageState extends ConsumerState<AdminDisputesPage> {
  void _showDetailPanel(BuildContext context, String disputeId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close details',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(anim1),
            child: Material(
              color: Colors.white,
              elevation: 16,
              child: SizedBox(
                width: 540,
                height: double.infinity,
                child: _DisputeDetailPanel(disputeId: disputeId),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final disputesAsync = ref.watch(adminDisputesProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dispute Resolution Center',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Gap(4),
                    Text(
                      'Review customer & vendor claims, evidence, booking context, and issue resolutions.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(adminDisputesProvider),
                  tooltip: 'Refresh Disputes',
                ),
              ],
            ),
            const Gap(20),

            // Filter Pills Bar
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Text('Status Filter:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Gap(16),
                    _buildFilterPill('ALL', 'All Disputes'),
                    const Gap(8),
                    _buildFilterPill('OPEN', 'Open Claims'),
                    const Gap(8),
                    _buildFilterPill('UNDER_REVIEW', 'Under Review'),
                    const Gap(8),
                    _buildFilterPill('RESOLVED', 'Resolved'),
                    const Gap(8),
                    _buildFilterPill('REJECTED', 'Rejected'),
                  ],
                ),
              ),
            ),
            const Gap(24),

            // Table List
            Expanded(
              child: disputesAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Failed to load disputes: $err',
                  onRetry: () => ref.invalidate(adminDisputesProvider),
                ),
                data: (disputes) {
                  if (disputes.isEmpty) {
                    return const Center(
                      child: EmptyStateWidget(
                        icon: Icons.gavel_outlined,
                        title: 'No Disputes Found',
                        subtitle: 'There are no active disputes matching the selected status.',
                      ),
                    );
                  }

                  return AppCard(
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                        columns: const [
                          DataColumn(label: Text('Booking ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Raised By', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Reason Claimed', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Evidence Attached', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Date Raised', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: disputes.map((d) {
                          final isCustomer = d.raisedByRole.toUpperCase() == 'CUSTOMER';
                          final reasonTruncated = d.reason.length > 38 ? '${d.reason.substring(0, 38)}...' : d.reason;

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  '#${d.bookingId.length > 8 ? d.bookingId.substring(d.bookingId.length - 8).toUpperCase() : d.bookingId}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              ),
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(d.raisedByName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(
                                      isCustomer ? 'Customer' : 'Vendor Partner',
                                      style: TextStyle(fontSize: 11, color: isCustomer ? Colors.blue[700] : Colors.purple[700]),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text(reasonTruncated, style: const TextStyle(fontSize: 13))),
                              DataCell(
                                Row(
                                  children: [
                                    const Icon(Icons.attach_file, size: 14, color: Colors.grey),
                                    const Gap(4),
                                    Text('${d.evidence.length} file(s)', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              DataCell(Text(DateFormat('dd MMM yyyy, HH:mm').format(d.createdAt), style: const TextStyle(fontSize: 12))),
                              DataCell(StatusBadge(status: d.status.toLowerCase())),
                              DataCell(
                                OutlinedButton.icon(
                                  onPressed: () => _showDetailPanel(context, d.id),
                                  icon: const Icon(Icons.open_in_new, size: 14),
                                  label: const Text('Review', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
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

  Widget _buildFilterPill(String statusKey, String label) {
    final selectedStatus = ref.watch(disputeStatusFilterProvider);
    final isSelected = selectedStatus == statusKey;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          ref.read(disputeStatusFilterProvider.notifier).state = statusKey;
        }
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}

// ─── Dispute Side Detail Panel ───
class _DisputeDetailPanel extends ConsumerStatefulWidget {
  final String disputeId;

  const _DisputeDetailPanel({required this.disputeId});

  @override
  ConsumerState<_DisputeDetailPanel> createState() => _DisputeDetailPanelState();
}

class _DisputeDetailPanelState extends ConsumerState<_DisputeDetailPanel> {
  final _resolutionNoteCtrl = TextEditingController();

  @override
  void dispose() {
    _resolutionNoteCtrl.dispose();
    super.dispose();
  }

  void _showActionDialog({
    required BuildContext context,
    required String actionTitle,
    required String targetStatus,
    required bool requiresNote,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(actionTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to mark this dispute as $targetStatus?'),
            if (requiresNote) ...[
              const Gap(16),
              AppTextField(
                label: 'Resolution / Rejection Note',
                hint: 'Provide explanation for customer and vendor...',
                controller: _resolutionNoteCtrl,
                maxLines: 3,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(adminDisputesControllerProvider.notifier).updateDisputeStatus(
                id: widget.disputeId,
                status: targetStatus,
                resolutionNote: _resolutionNoteCtrl.text.trim().isEmpty ? null : _resolutionNoteCtrl.text.trim(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Dispute status updated to $targetStatus')),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(disputeDetailProvider(widget.disputeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispute Claim Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, _) => Center(child: Text('Failed to load dispute details: $err')),
        data: (d) {
          final isCustomer = d.raisedByRole.toUpperCase() == 'CUSTOMER';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Header Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Booking #${d.bookingId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                StatusBadge(status: d.status.toLowerCase()),
                              ],
                            ),
                            const Gap(8),
                            Row(
                              children: [
                                Icon(isCustomer ? Icons.person : Icons.storefront, size: 16, color: Colors.grey[700]),
                                const Gap(6),
                                Text(
                                  'Claim raised by ${d.raisedByName} (${isCustomer ? 'Customer' : 'Vendor Partner'})',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const Gap(4),
                            Text('Filed on: ${DateFormat('dd MMM yyyy, hh:mm a').format(d.createdAt)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      const Gap(20),

                      // Reason Details Card
                      const SectionHeader(title: 'Dispute Reason & Claim Details'),
                      const Gap(10),
                      AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            d.reason,
                            style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                          ),
                        ),
                      ),
                      const Gap(20),

                      // Attached Evidence Gallery
                      SectionHeader(title: 'Attached Evidence (${d.evidence.length})'),
                      const Gap(10),
                      if (d.evidence.isEmpty)
                        const AppCard(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No evidence files uploaded for this claim.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: d.evidence.length,
                          separatorBuilder: (context, index) => const Gap(10),
                          itemBuilder: (context, index) {
                            final ev = d.evidence[index];
                            final isImage = ev.fileType.toLowerCase().contains('image') ||
                                ev.fileUrl.endsWith('.jpg') ||
                                ev.fileUrl.endsWith('.png') ||
                                ev.fileUrl.endsWith('.jpeg');

                            return AppCard(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(isImage ? Icons.image : Icons.insert_drive_file, color: Colors.blue, size: 20),
                                        const Gap(10),
                                        Expanded(
                                          child: Text(
                                            'Evidence #${index + 1} (${ev.fileType})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isImage) ...[
                                      const Gap(10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          ev.fileUrl,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, err, stack) => Container(
                                            height: 80,
                                            color: Colors.grey[100],
                                            child: const Center(child: Text('Preview unavailable', style: TextStyle(color: Colors.grey, fontSize: 12))),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      const Gap(8),
                                      SelectableText(ev.fileUrl, style: const TextStyle(fontSize: 12, color: Colors.blue)),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const Gap(20),

                      // Resolution Note (If resolved/rejected)
                      if (d.resolutionNote != null && d.resolutionNote!.isNotEmpty) ...[
                        const SectionHeader(title: 'Admin Resolution Note'),
                        const Gap(10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Text(
                            d.resolutionNote!,
                            style: TextStyle(fontSize: 13, color: Colors.green[900]),
                          ),
                        ),
                        const Gap(20),
                      ],
                    ],
                  ),
                ),
              ),

              // Action Buttons Bottom Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (d.status.toUpperCase() != 'UNDER_REVIEW')
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _showActionDialog(
                                  context: context,
                                  actionTitle: 'Move to Under Review',
                                  targetStatus: 'UNDER_REVIEW',
                                  requiresNote: false,
                                );
                              },
                              icon: const Icon(Icons.search, size: 16),
                              label: const Text('Under Review'),
                            ),
                          ),
                        if (d.status.toUpperCase() != 'UNDER_REVIEW') const Gap(10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showActionDialog(
                                context: context,
                                actionTitle: 'Resolve Dispute',
                                targetStatus: 'RESOLVED',
                                requiresNote: true,
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Resolve Dispute'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _showActionDialog(
                                context: context,
                                actionTitle: 'Reject Claim',
                                targetStatus: 'REJECTED',
                                requiresNote: true,
                              );
                            },
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Reject Claim'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red[700],
                              side: BorderSide(color: Colors.red[300]!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

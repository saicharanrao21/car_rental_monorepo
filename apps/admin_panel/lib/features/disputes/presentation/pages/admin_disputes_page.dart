import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:models/models.dart';
import '../providers/admin_disputes_providers.dart';

class AdminDisputesPage extends ConsumerStatefulWidget {
  const AdminDisputesPage({super.key});

  @override
  ConsumerState<AdminDisputesPage> createState() => _AdminDisputesPageState();
}

class _AdminDisputesPageState extends ConsumerState<AdminDisputesPage> {
  int _activeSection = 0; // 0: Booking Disputes, 1: Vehicle Damage Claims

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

  void _showDamageClaimPanel(BuildContext context, DamageClaimModel claim) {
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
                width: 560,
                height: double.infinity,
                child: _DamageClaimDetailPanel(claim: claim),
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
    final damageClaimsAsync = ref.watch(adminDamageClaimsProvider);

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
                      'Dispute & Claims Resolution Center',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Gap(4),
                    Text(
                      'Review customer & vendor claims, vehicle damage evidence, and adjudicate deposit settlements.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref.invalidate(adminDisputesProvider);
                    ref.invalidate(adminDamageClaimsProvider);
                  },
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const Gap(16),

            // Section Tabs: Booking Disputes vs Vehicle Damage Claims
            Row(
              children: [
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gavel_outlined, size: 16),
                      Gap(8),
                      Text('Booking Disputes'),
                    ],
                  ),
                  selected: _activeSection == 0,
                  onSelected: (val) {
                    if (val) setState(() => _activeSection = 0);
                  },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _activeSection == 0 ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(12),
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.car_crash_outlined, size: 16),
                      Gap(8),
                      Text('Vehicle Damage Claims'),
                    ],
                  ),
                  selected: _activeSection == 1,
                  onSelected: (val) {
                    if (val) setState(() => _activeSection = 1);
                  },
                  selectedColor: Colors.red[700],
                  labelStyle: TextStyle(
                    color: _activeSection == 1 ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Gap(16),

            // Filter Pills Bar
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Text('Status Filter:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Gap(16),
                    if (_activeSection == 0) ...[
                      _buildFilterPill('ALL', 'All Disputes'),
                      const Gap(8),
                      _buildFilterPill('OPEN', 'Open Claims'),
                      const Gap(8),
                      _buildFilterPill('UNDER_REVIEW', 'Under Review'),
                      const Gap(8),
                      _buildFilterPill('RESOLVED', 'Resolved'),
                      const Gap(8),
                      _buildFilterPill('REJECTED', 'Rejected'),
                    ] else ...[
                      _buildDamageClaimFilterPill('ALL', 'All Claims'),
                      const Gap(8),
                      _buildDamageClaimFilterPill('SUBMITTED', 'Submitted'),
                      const Gap(8),
                      _buildDamageClaimFilterPill('UNDER_REVIEW', 'Under Review'),
                      const Gap(8),
                      _buildDamageClaimFilterPill('APPROVED', 'Approved'),
                      const Gap(8),
                      _buildDamageClaimFilterPill('PARTIALLY_APPROVED', 'Partially Approved'),
                      const Gap(8),
                      _buildDamageClaimFilterPill('REJECTED', 'Rejected'),
                    ],
                  ],
                ),
              ),
            // Table List
            Expanded(
              child: _activeSection == 0
                  ? _buildDisputesTable(disputesAsync)
                  : _buildDamageClaimsTable(damageClaimsAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisputesTable(AsyncValue<List<DisputeModel>> disputesAsync) {
    return disputesAsync.when(
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
    );
  }

  Widget _buildDamageClaimsTable(AsyncValue<List<DamageClaimModel>> claimsAsync) {
    return claimsAsync.when(
      loading: () => const Center(child: AppLoader()),
      error: (err, _) => ErrorStateWidget(
        message: 'Failed to load damage claims: $err',
        onRetry: () => ref.invalidate(adminDamageClaimsProvider),
      ),
      data: (claims) {
        if (claims.isEmpty) {
          return const Center(
            child: EmptyStateWidget(
              icon: Icons.car_crash_outlined,
              title: 'No Damage Claims Found',
              subtitle: 'There are no active vehicle damage claims matching the selected status.',
            ),
          );
        }

        return AppCard(
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
              columns: const [
                DataColumn(label: Text('Claim ID', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Booking ID', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Claimed Repair', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Approved Deduction', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Evidence Photos', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Date Filed', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: claims.map((c) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        '#${c.id.length > 8 ? c.id.substring(0, 8).toUpperCase() : c.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(
                      Text(
                        '#${c.bookingId.length > 8 ? c.bookingId.substring(c.bookingId.length - 8).toUpperCase() : c.bookingId}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                    DataCell(
                      PriceTag(
                        amount: c.claimedAmount,
                        amountStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                      ),
                    ),
                    DataCell(
                      c.approvedAmount != null
                          ? PriceTag(
                              amount: c.approvedAmount!,
                              amountStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                            )
                          : const Text('—', style: TextStyle(color: Colors.grey)),
                    ),
                    DataCell(
                      Row(
                        children: [
                          const Icon(Icons.photo_library_outlined, size: 14, color: Colors.grey),
                          const Gap(4),
                          Text('${c.damagePhotos.length} photo(s)', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    DataCell(Text(DateFormat('dd MMM yyyy, HH:mm').format(c.createdAt), style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _claimStatusBg(c.status),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          c.status.name,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _claimStatusFg(c.status)),
                        ),
                      ),
                    ),
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () => _showDamageClaimPanel(context, c),
                        icon: const Icon(Icons.gavel, size: 14),
                        label: const Text('Adjudicate', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Color _claimStatusBg(DamageClaimStatus status) {
    switch (status) {
      case DamageClaimStatus.SUBMITTED:
        return Colors.amber.withValues(alpha: 0.15);
      case DamageClaimStatus.UNDER_REVIEW:
        return Colors.blue.withValues(alpha: 0.15);
      case DamageClaimStatus.APPROVED:
        return Colors.green.withValues(alpha: 0.15);
      case DamageClaimStatus.PARTIALLY_APPROVED:
        return Colors.orange.withValues(alpha: 0.15);
      case DamageClaimStatus.REJECTED:
        return Colors.red.withValues(alpha: 0.15);
      case DamageClaimStatus.SETTLED:
        return Colors.purple.withValues(alpha: 0.15);
    }
  }

  Color _claimStatusFg(DamageClaimStatus status) {
    switch (status) {
      case DamageClaimStatus.SUBMITTED:
        return Colors.amber[900]!;
      case DamageClaimStatus.UNDER_REVIEW:
        return Colors.blue[900]!;
      case DamageClaimStatus.APPROVED:
        return Colors.green[900]!;
      case DamageClaimStatus.PARTIALLY_APPROVED:
        return Colors.orange[900]!;
      case DamageClaimStatus.REJECTED:
        return Colors.red[900]!;
      case DamageClaimStatus.SETTLED:
        return Colors.purple[900]!;
    }
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

  Widget _buildDamageClaimFilterPill(String statusKey, String label) {
    final selectedStatus = ref.watch(damageClaimStatusFilterProvider);
    final isSelected = selectedStatus == statusKey;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          ref.read(damageClaimStatusFilterProvider.notifier).state = statusKey;
        }
      },
      selectedColor: Colors.red[700],
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

// ─── Vehicle Damage Claim Side Detail & Adjudication Panel ───
class _DamageClaimDetailPanel extends ConsumerStatefulWidget {
  final DamageClaimModel claim;

  const _DamageClaimDetailPanel({required this.claim});

  @override
  ConsumerState<_DamageClaimDetailPanel> createState() => _DamageClaimDetailPanelState();
}

class _DamageClaimDetailPanelState extends ConsumerState<_DamageClaimDetailPanel> {
  final _adminNotesCtrl = TextEditingController();
  final _approvedAmountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _approvedAmountCtrl.text = widget.claim.claimedAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _adminNotesCtrl.dispose();
    _approvedAmountCtrl.dispose();
    super.dispose();
  }

  void _showAdjudicateDialog({
    required BuildContext context,
    required String title,
    required String decision,
    required bool requiresAmount,
  }) {
    _adminNotesCtrl.clear();
    if (requiresAmount && _approvedAmountCtrl.text.isEmpty) {
      _approvedAmountCtrl.text = widget.claim.claimedAmount.toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (requiresAmount) ...[
                    AppTextField(
                      label: 'Approved Deduction Amount (₹)',
                      controller: _approvedAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      hint: 'Capped at claimed ₹${widget.claim.claimedAmount.toStringAsFixed(0)}',
                    ),
                    const Gap(12),
                  ],
                  AppTextField(
                    label: 'Mandatory Admin Justification Notes',
                    controller: _adminNotesCtrl,
                    maxLines: 3,
                    hint: 'Detail verification findings from pre/post-trip photos...',
                  ),
                  const Gap(12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: decision == 'REJECTED' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: decision == 'REJECTED' ? Colors.green : Colors.orange),
                    ),
                    child: Text(
                      decision == 'REJECTED'
                          ? 'Rejecting this claim will immediately trigger a full security deposit refund back to the customer.'
                          : 'Approving this deduction will deduct the approved amount from customer security deposit and credit the vendor payout ledger.',
                      style: TextStyle(
                        fontSize: 12,
                        color: decision == 'REJECTED' ? Colors.green[900] : Colors.orange[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final notes = _adminNotesCtrl.text.trim();
                  if (notes.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please provide administrative justification notes')),
                    );
                    return;
                  }

                  double? amount;
                  if (requiresAmount) {
                    amount = double.tryParse(_approvedAmountCtrl.text.trim());
                    if (amount == null || amount <= 0 || amount > widget.claim.claimedAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Enter a valid amount between ₹1 and ₹${widget.claim.claimedAmount}')),
                      );
                      return;
                    }
                  }

                  Navigator.pop(ctx);

                  final success = await ref.read(adminDisputesControllerProvider.notifier).adjudicateClaim(
                    claimId: widget.claim.id,
                    decision: decision,
                    approvedAmount: amount,
                    adminNotes: notes,
                  );

                  if (context.mounted) {
                    if (success) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green[800],
                          content: Text('Claim $decision successfully adjudicated and deposit settled.'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to adjudicate claim. Check backend logs.')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: decision == 'REJECTED' ? Colors.red[700] : Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                child: Text('Confirm $decision'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.claim;
    final isFinalized = c.status == DamageClaimStatus.SETTLED || c.status == DamageClaimStatus.REJECTED;

    return Scaffold(
      appBar: AppBar(
        title: Text('Damage Claim #${c.id.length > 8 ? c.id.substring(0, 8).toUpperCase() : c.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
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
                            Text(
                              'Booking #${c.bookingId}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                c.status.name,
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const Gap(8),
                        Text(
                          'Claimed Repair Amount: ${IndianCurrencyFormatter.format(c.claimedAmount, showDecimals: false)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        if (c.approvedAmount != null) ...[
                          const Gap(4),
                          Text(
                            'Approved Deduction: ${IndianCurrencyFormatter.format(c.approvedAmount!, showDecimals: false)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                        const Gap(4),
                        Text(
                          'Filed on: ${DateFormat('dd MMM yyyy, hh:mm a').format(c.createdAt)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const Gap(20),

                  // Damage Description
                  const SectionHeader(title: 'Damage Description & Details'),
                  const Gap(10),
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        c.description,
                        style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                      ),
                    ),
                  ),
                  const Gap(20),

                  // Evidence Photos
                  SectionHeader(title: 'Photographic Evidence (${c.damagePhotos.length})'),
                  const Gap(10),
                  if (c.damagePhotos.isEmpty)
                    const AppCard(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No evidence photos attached.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: c.damagePhotos.length,
                      separatorBuilder: (context, index) => const Gap(10),
                      itemBuilder: (context, index) {
                        final photoUrl = c.damagePhotos[index];
                        return AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.photo_camera_outlined, color: Colors.red, size: 18),
                                    const Gap(8),
                                    Text('Damage Photo #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                const Gap(10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    photoUrl,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, err, stack) => Container(
                                      height: 100,
                                      color: Colors.grey[100],
                                      child: const Center(child: Text('Image Preview Unavailable', style: TextStyle(color: Colors.grey, fontSize: 12))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const Gap(20),

                  // Customer Dispute (if any)
                  if (c.customerDispute != null && c.customerDispute!.isNotEmpty) ...[
                    const SectionHeader(title: 'Customer Dispute Statement'),
                    const Gap(10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[300]!),
                      ),
                      child: Text(
                        c.customerDispute!,
                        style: TextStyle(fontSize: 13, color: Colors.amber[900]),
                      ),
                    ),
                    const Gap(20),
                  ],

                  // Admin Resolution Note (if any)
                  if (c.adminNotes != null && c.adminNotes!.isNotEmpty) ...[
                    const SectionHeader(title: 'Admin Resolution & Settlement Note'),
                    const Gap(10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Text(
                        c.adminNotes!,
                        style: TextStyle(fontSize: 13, color: Colors.green[900]),
                      ),
                    ),
                    const Gap(20),
                  ],
                ],
              ),
            ),
          ),

          // Adjudication Bottom Actions (if not finalized)
          if (!isFinalized)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showAdjudicateDialog(
                          context: context,
                          title: 'Approve Damage Claim',
                          decision: 'APPROVED',
                          requiresAmount: true,
                        );
                      },
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Approve Claim'),
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
                        _showAdjudicateDialog(
                          context: context,
                          title: 'Partially Approve Claim',
                          decision: 'PARTIALLY_APPROVED',
                          requiresAmount: true,
                        );
                      },
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Partial Approve'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange[800],
                        side: BorderSide(color: Colors.orange[400]!),
                      ),
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showAdjudicateDialog(
                          context: context,
                          title: 'Reject Damage Claim',
                          decision: 'REJECTED',
                          requiresAmount: false,
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
            ),
        ],
      ),
    );
  }
}

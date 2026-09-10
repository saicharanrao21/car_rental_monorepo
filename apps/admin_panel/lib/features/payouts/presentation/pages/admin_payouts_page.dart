import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/api_providers.dart';

class AdminPayoutsPage extends ConsumerStatefulWidget {
  const AdminPayoutsPage({super.key});

  @override
  ConsumerState<AdminPayoutsPage> createState() => _AdminPayoutsPageState();
}

class _AdminPayoutsPageState extends ConsumerState<AdminPayoutsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> _payouts = [];
  Map<String, dynamic>? _financialSummary;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  String? _statusFilter;

  final List<String> _tabs = [
    'ALL',
    'PENDING',
    'APPROVED',
    'PAID',
    'REJECTED',
    'FAILED',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final selected = _tabs[_tabController.index];
      setState(() {
        _statusFilter = selected == 'ALL' ? null : selected;
        _currentPage = 1;
      });
      _fetchPayouts();
    });
    _fetchSummary();
    _fetchPayouts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSummary() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.get('/admin/finance/summary');
      if (mounted && res.data is Map) {
        setState(() {
          _financialSummary = res.data as Map<String, dynamic>;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchPayouts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final queryParams = <String, dynamic>{
        'page': _currentPage,
        'limit': 15,
      };
      if (_statusFilter != null) {
        queryParams['status'] = _statusFilter;
      }

      final res = await apiClient.dio.get(
        '/admin/payouts',
        queryParameters: queryParams,
      );

      if (mounted) {
        final data = res.data is Map ? res.data as Map<String, dynamic> : {};
        setState(() {
          _payouts = (data['data'] as List<dynamic>?) ?? [];
          _totalPages = (data['totalPages'] as int?) ?? 1;
          _totalCount = (data['total'] as int?) ?? 0;
          _isLoading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load payouts: $err';
        });
      }
    }
  }

  Future<void> _approvePayout(String payoutId) async {
    final notesController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Payout Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to approve this vendor payout for execution?',
            ),
            const Gap(12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Approval Notes (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve Payout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.post(
        '/admin/payouts/$payoutId/approve',
        data: {'adminNotes': notesController.text.trim()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout approved successfully.')),
        );
        _fetchPayouts();
        _fetchSummary();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectPayout(String payoutId) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payout Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a mandatory reason for rejecting this payout:'),
            const Gap(12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject Payout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.post(
        '/admin/payouts/$payoutId/reject',
        data: {'reason': reasonController.text.trim()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout rejected.')),
        );
        _fetchPayouts();
        _fetchSummary();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejection failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _executePayout(String payoutId, double amount) async {
    final utrController = TextEditingController();
    final notesController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Execute Settlement (₹${amount.toStringAsFixed(2)})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter external bank transfer UTR or payment reference ID. This will trigger the immutable general ledger journal settlement.',
            ),
            const Gap(12),
            TextField(
              controller: utrController,
              decoration: const InputDecoration(
                labelText: 'Bank Reference / UTR Number',
                hintText: 'e.g. UTR1234567890 or leave blank for auto',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(8),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Settlement Notes (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Execution'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final utr = utrController.text.trim();
      final notes = notesController.text.trim();

      await apiClient.dio.post(
        '/admin/payouts/$payoutId/execute',
        data: {
          if (utr.isNotEmpty) 'providerTransferId': utr,
          if (notes.isNotEmpty) 'adminNotes': notes,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout executed and ledger settled.')),
        );
        _fetchPayouts();
        _fetchSummary();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Execution failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _inspectPayout(Map<String, dynamic> payout) async {
    final vendorId = payout['vendorId']?.toString() ?? '';
    Map<String, dynamic>? earnings;

    if (vendorId.isNotEmpty) {
      try {
        final apiClient = ref.read(apiClientProvider);
        final res = await apiClient.dio.get('/vendors/me/earnings/summary');
        if (res.data is Map) earnings = res.data as Map<String, dynamic>;
      } catch (_) {}
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payout #${payout['payoutNumber'] ?? payout['id']}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Vendor: ${payout['vendor']?['businessName'] ?? payout['vendorId']}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
                _buildStatusChip(payout['status']?.toString() ?? 'PENDING'),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: ListView(
                children: [
                  _buildDetailRow('Amount', '₹${payout['amount']}'),
                  _buildDetailRow('Status', payout['status']?.toString() ?? '-'),
                  _buildDetailRow('Payout Number', payout['payoutNumber']?.toString() ?? '-'),
                  _buildDetailRow('Provider Transfer ID', payout['providerTransferId']?.toString() ?? 'None (Pending)'),
                  _buildDetailRow('Requested Date', payout['createdAt'] != null ? DateFormat.yMMMd().add_jm().format(DateTime.parse(payout['createdAt'])) : '-'),
                  _buildDetailRow('Paid Date', payout['paidAt'] != null ? DateFormat.yMMMd().add_jm().format(DateTime.parse(payout['paidAt'])) : '-'),
                  _buildDetailRow('Admin Notes', payout['notes']?.toString() ?? '-'),
                  if (payout['providerFailureReason'] != null)
                    _buildDetailRow('Failure Reason', payout['providerFailureReason'], isError: true),
                  const Gap(16),
                  if (earnings != null) ...[
                    const Text('Vendor Financial Position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Gap(8),
                    _buildDetailRow('Available Balance', '₹${earnings['availableBalance']}'),
                    _buildDetailRow('Ledger Payable Balance', '₹${earnings['ledgerPayableBalance'] ?? earnings['availableBalance']}'),
                    _buildDetailRow('Held in Escrow', '₹${earnings['heldEarnings']}'),
                    _buildDetailRow('Total Paid Payouts', '₹${earnings['totalPaid']}'),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                if (payout['status'] == 'PENDING') ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _rejectPayout(payout['id']);
                      },
                      child: const Text('Reject'),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _approvePayout(payout['id']);
                      },
                      child: const Text('Approve'),
                    ),
                  ),
                ] else if (payout['status'] == 'APPROVED') ...[
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Execute Settlement'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final amt = double.tryParse(payout['amount'].toString()) ?? 0.0;
                        _executePayout(payout['id'], amt);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isError ? Colors.red : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'PAID':
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green[800]!;
        break;
      case 'APPROVED':
        bg = Colors.blue.withValues(alpha: 0.12);
        fg = Colors.blue[800]!;
        break;
      case 'PENDING':
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber[900]!;
        break;
      case 'REJECTED':
      case 'FAILED':
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red[800]!;
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.12);
        fg = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Vendor Payouts & General Ledger Settlement'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchSummary();
              _fetchPayouts();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Financial Overview Summary
          if (_financialSummary != null) _buildSummaryCards(),

          // Main Data Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                            const Gap(12),
                            ElevatedButton(onPressed: _fetchPayouts, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _payouts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payments_outlined, size: 48, color: Colors.grey[400]),
                                const Gap(8),
                                Text('No payouts found for $_statusFilter filter.', style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _payouts.length,
                            separatorBuilder: (_, __) => const Gap(8),
                            itemBuilder: (ctx, idx) {
                              final p = _payouts[idx] as Map<String, dynamic>;
                              final amt = double.tryParse(p['amount'].toString()) ?? 0.0;
                              final status = p['status']?.toString() ?? 'PENDING';
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.grey[200]!),
                                ),
                                child: ListTile(
                                  onTap: () => _inspectPayout(p),
                                  title: Row(
                                    children: [
                                      Text(
                                        '#${p['payoutNumber'] ?? p['id']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const Gap(8),
                                      _buildStatusChip(status),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Vendor: ${p['vendor']?['businessName'] ?? p['vendorId']}'
                                    ' • Requested: ${p['createdAt'] != null ? DateFormat.yMMMd().format(DateTime.parse(p['createdAt'])) : '-'}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '₹${amt.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const Gap(12),
                                      if (status == 'PENDING')
                                        FilledButton.tonal(
                                          onPressed: () => _approvePayout(p['id']),
                                          child: const Text('Approve'),
                                        )
                                      else if (status == 'APPROVED')
                                        FilledButton(
                                          onPressed: () => _executePayout(p['id'], amt),
                                          child: const Text('Execute'),
                                        )
                                      else
                                        const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),

          // Pagination Controls
          if (_totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total: $_totalCount payouts'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentPage > 1
                            ? () {
                                setState(() => _currentPage--);
                                _fetchPayouts();
                              }
                            : null,
                      ),
                      Text('$_currentPage / $_totalPages'),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _currentPage < _totalPages
                            ? () {
                                setState(() => _currentPage++);
                                _fetchPayouts();
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final s = _financialSummary!;
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          _buildStatCard('Pending Payouts', '₹${s['vendorPayoutsPending'] ?? 0}', Colors.amber[800]!),
          const Gap(12),
          _buildStatCard('Settled Payouts', '₹${s['vendorPayoutsPaid'] ?? 0}', Colors.green[700]!),
          const Gap(12),
          _buildStatCard('Platform Revenue', '₹${s['platformCommissions'] ?? 0}', Colors.blue[700]!),
          const Gap(12),
          _buildStatCard('Escrow Deposits', '₹${s['securityDepositsHeld'] ?? 0}', Colors.purple[700]!),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 11)),
            const Gap(4),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

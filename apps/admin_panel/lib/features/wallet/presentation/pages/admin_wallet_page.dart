import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/api_providers.dart';
import '../../../../core/widgets/admin_detail_drawer.dart';

class AdminWalletPage extends ConsumerStatefulWidget {
  const AdminWalletPage({super.key});

  @override
  ConsumerState<AdminWalletPage> createState() => _AdminWalletPageState();
}

class _AdminWalletPageState extends ConsumerState<AdminWalletPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _walletData;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchWallet(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);

      // Check if query is directly a user ID or lookup via users search
      String targetUserId = cleanQuery;
      if (!cleanQuery.startsWith('cuid_') && cleanQuery.length < 20) {
        final usersRes = await apiClient.dio.get('/users?search=$cleanQuery&limit=1');
        final data = usersRes.data is Map ? usersRes.data as Map<String, dynamic> : <String, dynamic>{};
        final items = data['items'] as List<dynamic>?;
        if (items == null || items.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No customer or vendor found matching "$cleanQuery".';
          });
          return;
        }
        targetUserId = items[0]['id'].toString();
      }

      final res = await apiClient.dio.get('/wallet/admin/user/$targetUserId');
      setState(() {
        _walletData = res.data is Map ? res.data as Map<String, dynamic> : null;
        _isLoading = false;
      });
    } catch (err) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load wallet: $err';
      });
    }
  }

  Future<void> _runReconciliation(String walletId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.get('/wallet/admin/$walletId/reconcile');
      if (!mounted) return;

      final data = res.data is Map ? res.data as Map<String, dynamic> : <String, dynamic>{};
      final isHealthy = data['healthy'] == true;
      final discrepancy = data['discrepancy'] ?? 0;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isHealthy ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                color: isHealthy ? Colors.green : Colors.red,
              ),
              const Gap(8),
              Text(isHealthy ? 'Wallet Reconciled Cleanly' : 'Discrepancy Detected'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cached Available: ₹${data['cachedAvailable'] ?? 0}'),
              Text('Computed Ledger Balance: ₹${data['computedLedgerBalance'] ?? 0}'),
              Text('Discrepancy: ₹$discrepancy'),
              const Gap(12),
              Text(
                isHealthy
                    ? 'All ledger credit and debit entries match cached balances.'
                    : 'A financial discrepancy was detected between ledger logs and cached balance.',
                style: TextStyle(
                  fontSize: 13,
                  color: isHealthy ? Colors.green.shade800 : Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reconciliation failed: $err'), backgroundColor: Colors.red),
      );
    }
  }

  void _openAdjustmentDrawer() {
    if (_walletData == null) return;
    final wallet = _walletData!['wallet'] as Map<String, dynamic>;
    final user = _walletData!['user'] as Map<String, dynamic>;

    String direction = 'CREDIT';
    String bucket = 'REAL_MONEY';
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;

    AdminDetailDrawer.show(
      context: context,
      title: 'Manual Wallet Adjustment',
      subtitle: 'Perform auditable credit or debit for ${user['name'] ?? user['phone']}',
      width: 480,
      child: StatefulBuilder(
        builder: (ctx, setDrawerState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Adjustment Direction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Gap(8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'CREDIT',
                  label: Text('Credit (+)'),
                  icon: Icon(Icons.add_circle_outline, color: Colors.green),
                ),
                ButtonSegment(
                  value: 'DEBIT',
                  label: Text('Debit (-)'),
                  icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                ),
              ],
              selected: {direction},
              onSelectionChanged: (newSet) {
                setDrawerState(() => direction = newSet.first);
              },
            ),
            const Gap(16),
            if (direction == 'CREDIT') ...[
              const Text('Target Bucket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Gap(8),
              DropdownButtonFormField<String>(
                initialValue: bucket,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'REAL_MONEY', child: Text('Real Money Balance (Deposit)')),
                  DropdownMenuItem(value: 'PROMOTIONAL', child: Text('Promotional Balance (Non-withdrawable)')),
                  DropdownMenuItem(value: 'REFUND_CREDIT', child: Text('Refund Credit Balance')),
                ],
                onChanged: (val) {
                  if (val != null) setDrawerState(() => bucket = val);
                },
              ),
              const Gap(16),
            ],
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹) *',
                hintText: 'e.g. 500',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
            const Gap(16),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mandatory Adjustment Reason *',
                hintText: 'Explain the business justification (e.g. CS goodwill compensation ticket #1024)',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: direction == 'CREDIT' ? Colors.green.shade700 : Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final amountVal = double.tryParse(amountCtrl.text.trim());
                      final reasonVal = reasonCtrl.text.trim();

                      if (amountVal == null || amountVal <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid positive amount.')),
                        );
                        return;
                      }

                      if (reasonVal.length < 5) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please provide a detailed reason (at least 5 characters).')),
                        );
                        return;
                      }

                      setDrawerState(() => isSubmitting = true);
                      try {
                        final apiClient = ref.read(apiClientProvider);
                        await apiClient.dio.post('/wallet/admin/adjust', data: {
                          'walletId': wallet['id'],
                          'amount': amountVal,
                          'direction': direction,
                          'bucket': bucket,
                          'reason': reasonVal,
                          'clientNonce': 'adm_${DateTime.now().millisecondsSinceEpoch}',
                        });

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Wallet ${direction.toLowerCase()}ed by ₹$amountVal successfully.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _fetchWallet(user['id']);
                      } catch (err) {
                        if (ctx.mounted) {
                          setDrawerState(() => isSubmitting = false);
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Adjustment failed: $err'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Confirm & Apply $direction'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet Master Control & Ledger Audit',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Gap(4),
                    Text(
                      'Search customer or vendor wallets, inspect immutable ledger balances, and perform governed adjustments.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                if (_walletData != null)
                  ElevatedButton.icon(
                    onPressed: () => _fetchWallet(_walletData!['user']['id']),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
              ],
            ),
            const Gap(24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF94A3B8)),
                  const Gap(12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: _fetchWallet,
                      decoration: const InputDecoration(
                        hintText: 'Search user by User ID, phone number, or email...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _fetchWallet(_searchController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Lookup Wallet'),
                  ),
                ],
              ),
            ),
            const Gap(24),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                    const Gap(12),
                    Expanded(
                      child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFF991B1B))),
                    ),
                  ],
                ),
              ),
            if (_walletData == null && !_isLoading && _errorMessage == null)
              Container(
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade300),
                    const Gap(16),
                    const Text(
                      'No Wallet Selected',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const Gap(6),
                    const Text(
                      'Enter a user ID, customer phone, or vendor email in the search bar above to audit ledger entries and balance breakdown.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            if (_walletData != null) ...[
              _buildUserAndWalletSummary(context),
              const Gap(24),
              _buildBalanceCards(),
              const Gap(24),
              _buildLedgerSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserAndWalletSummary(BuildContext context) {
    final wallet = _walletData!['wallet'] as Map<String, dynamic>;
    final user = _walletData!['user'] as Map<String, dynamic>;
    final status = wallet['status']?.toString() ?? 'ACTIVE';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  (user['name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ),
              const Gap(16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user['name'] ?? 'Unknown User',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const Gap(8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user['role'] ?? 'CUSTOMER',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                      const Gap(8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: status == 'ACTIVE'
                              ? const Color(0xFFECFDF5)
                              : status == 'FROZEN'
                                  ? const Color(0xFFFFFBEB)
                                  : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: status == 'ACTIVE'
                                ? const Color(0xFF059669)
                                : status == 'FROZEN'
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(4),
                  Text(
                    'ID: ${user['id']}  •  Phone: ${user['phone']}  •  Email: ${user['email'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _runReconciliation(wallet['id']),
                icon: const Icon(Icons.fact_check_outlined, size: 16),
                label: const Text('Reconcile Ledger'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              const Gap(12),
              ElevatedButton.icon(
                onPressed: _openAdjustmentDrawer,
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Manual Adjustment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCards() {
    final wallet = _walletData!['wallet'] as Map<String, dynamic>;
    final available = double.tryParse(wallet['availableBalance']?.toString() ?? '0') ?? 0;
    final real = double.tryParse(wallet['realBalance']?.toString() ?? '0') ?? 0;
    final promo = double.tryParse(wallet['promoBalance']?.toString() ?? '0') ?? 0;
    final locked = double.tryParse(wallet['lockedBalance']?.toString() ?? '0') ?? 0;

    return Row(
      children: [
        Expanded(
          child: _balanceTile(
            title: 'Available Balance',
            amount: available,
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF2563EB),
            bg: const Color(0xFFEFF6FF),
          ),
        ),
        const Gap(16),
        Expanded(
          child: _balanceTile(
            title: 'Real Money Balance',
            amount: real,
            icon: Icons.payments_outlined,
            color: const Color(0xFF059669),
            bg: const Color(0xFFECFDF5),
          ),
        ),
        const Gap(16),
        Expanded(
          child: _balanceTile(
            title: 'Promotional Credit',
            amount: promo,
            icon: Icons.card_giftcard_rounded,
            color: const Color(0xFF7C3AED),
            bg: const Color(0xFFF5F3FF),
          ),
        ),
        const Gap(16),
        Expanded(
          child: _balanceTile(
            title: 'Locked / Held',
            amount: locked,
            icon: Icons.lock_outline_rounded,
            color: const Color(0xFFD97706),
            bg: const Color(0xFFFFFBEB),
          ),
        ),
      ],
    );
  }

  Widget _balanceTile({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const Gap(16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              const Gap(4),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerSection() {
    final entries = (_walletData!['recentLedger'] as List<dynamic>?) ?? [];
    final df = DateFormat('dd MMM yyyy, HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Authoritative Immutable Ledger',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Showing ${entries.length} recent events',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No ledger entries recorded yet for this wallet.', style: TextStyle(color: Color(0xFF64748B))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final entry = entries[idx] as Map<String, dynamic>;
                final direction = entry['direction']?.toString() ?? 'CREDIT';
                final isCredit = direction == 'CREDIT';
                final amount = double.tryParse(entry['amount']?.toString() ?? '0') ?? 0;
                final balanceBefore = double.tryParse(entry['balanceBefore']?.toString() ?? '0') ?? 0;
                final balanceAfter = double.tryParse(entry['balanceAfter']?.toString() ?? '0') ?? 0;
                final createdAt = DateTime.tryParse(entry['createdAt']?.toString() ?? '') ?? DateTime.now();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCredit ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          size: 18,
                        ),
                      ),
                      const Gap(16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry['description'] ?? entry['type'] ?? 'Transaction',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            const Gap(2),
                            Text(
                              '${df.format(createdAt)}  •  ${entry['type']}  •  Bucket: ${entry['bucket']}',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                          const Gap(2),
                          Text(
                            'Bal: ₹${balanceBefore.toStringAsFixed(0)} → ₹${balanceAfter.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

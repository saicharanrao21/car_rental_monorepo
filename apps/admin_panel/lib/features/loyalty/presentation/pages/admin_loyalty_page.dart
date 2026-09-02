import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:gap/gap.dart';
import '../../../../core/widgets/admin_detail_drawer.dart';
import '../../../../core/widgets/admin_data_grid.dart';
import '../providers/admin_loyalty_providers.dart';

class AdminLoyaltyManagementPage extends ConsumerStatefulWidget {
  const AdminLoyaltyManagementPage({super.key});

  @override
  ConsumerState<AdminLoyaltyManagementPage> createState() =>
      _AdminLoyaltyManagementPageState();
}

class _AdminLoyaltyManagementPageState
    extends ConsumerState<AdminLoyaltyManagementPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(adminLoyaltySummaryProvider);
    final accountsAsync = ref.watch(adminLoyaltyAccountsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            summaryAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text('Failed to load loyalty summary: $err',
                    style: TextStyle(color: Colors.red.shade800)),
              ),
              data: (summary) => _buildSummaryCards(context, summary),
            ),
            const SizedBox(height: 28),
            _buildAccountsSection(context, accountsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Loyalty & Rewards Program',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage customer loyalty tiers, points ledger, and platform rewards liability',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () {
            ref.invalidate(adminLoyaltySummaryProvider);
            ref.invalidate(adminLoyaltyAccountsProvider);
          },
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, LoyaltySummaryModel summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;
            return isNarrow
                ? Column(
                    children: [
                      _buildMetricCard('Total Members', summary.totalAccounts.toString(), Icons.people_alt_outlined, const Color(0xFF3B82F6)),
                      const SizedBox(height: 12),
                      _buildMetricCard('Points Issued', summary.totalLifetimePoints.toString(), Icons.stars_outlined, const Color(0xFF10B981)),
                      const SizedBox(height: 12),
                      _buildMetricCard('Points Redeemed', summary.totalPointsRedeemed.toString(), Icons.redeem_outlined, const Color(0xFF8B5CF6)),
                      const SizedBox(height: 12),
                      _buildMetricCard('Reward Liability', '₹${summary.outstandingLiabilityInr}', Icons.account_balance_wallet_outlined, const Color(0xFFF59E0B)),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _buildMetricCard('Total Members', summary.totalAccounts.toString(), Icons.people_alt_outlined, const Color(0xFF3B82F6))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMetricCard('Points Issued', summary.totalLifetimePoints.toString(), Icons.stars_outlined, const Color(0xFF10B981))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMetricCard('Points Redeemed', summary.totalPointsRedeemed.toString(), Icons.redeem_outlined, const Color(0xFF8B5CF6))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMetricCard('Reward Liability', '₹${summary.outstandingLiabilityInr}', Icons.account_balance_wallet_outlined, const Color(0xFFF59E0B))),
                    ],
                  );
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'Tier Distribution',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: summary.tierBreakdown.map((tier) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    _buildTierBadge(tier.code),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${tier.accountCount} Members', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${tier.multiplier}x multiplier', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsSection(BuildContext context, AsyncValue<Map<String, dynamic>> accountsAsync) {
    final selectedTier = ref.watch(adminLoyaltyTierFilterProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const Text(
                'Member Accounts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 40,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search customer...',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (val) {
                        ref.read(adminLoyaltySearchQueryProvider.notifier).state = val;
                      },
                    ),
                  ),
                  DropdownButton<LoyaltyTierCode?>(
                    value: selectedTier,
                    hint: const Text('All Tiers', style: TextStyle(fontSize: 13)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Tiers')),
                      ...LoyaltyTierCode.values.map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.displayName)),
                      ),
                    ],
                    onChanged: (val) {
                      ref.read(adminLoyaltyTierFilterProvider.notifier).state = val;
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          accountsAsync.when(
            loading: () => const AdminTableSkeleton(),
            error: (err, _) => AdminErrorState(
              message: 'Failed to load accounts: $err',
              onRetry: () => ref.invalidate(adminLoyaltyAccountsProvider),
            ),
            data: (data) {
              final accountsList = data['accounts'] as List<dynamic>? ?? [];
              return AdminDataGrid<dynamic>(
                items: accountsList,
                emptyTitle: 'No Loyalty Accounts',
                emptyMessage: 'No loyalty accounts found matching search criteria.',
                emptyIcon: Icons.stars_outlined,
                columns: [
                  AdminDataColumn(
                    title: 'CUSTOMER',
                    builder: (acc) {
                      final accMap = acc as Map<String, dynamic>;
                      final userName = accMap['userName'] as String? ?? 'N/A';
                      final userPhone = accMap['userPhone'] as String? ?? '';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(userPhone, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      );
                    },
                  ),
                  AdminDataColumn(
                    title: 'TIER',
                    builder: (acc) {
                      final accMap = acc as Map<String, dynamic>;
                      final tierCode = LoyaltyTierCode.fromString(accMap['tierCode'] as String?);
                      return _buildTierBadge(tierCode);
                    },
                  ),
                  AdminDataColumn(
                    title: 'AVAILABLE POINTS',
                    numeric: true,
                    builder: (acc) {
                      final accMap = acc as Map<String, dynamic>;
                      final pointsBalance = accMap['pointsBalance'] as int? ?? 0;
                      return Text('$pointsBalance pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)));
                    },
                  ),
                  AdminDataColumn(
                    title: 'LIFETIME POINTS',
                    numeric: true,
                    builder: (acc) {
                      final accMap = acc as Map<String, dynamic>;
                      final lifetimePoints = accMap['lifetimePoints'] as int? ?? 0;
                      return Text('$lifetimePoints pts');
                    },
                  ),
                  AdminDataColumn(
                    title: 'WALLET EQUIV.',
                    numeric: true,
                    builder: (acc) {
                      final accMap = acc as Map<String, dynamic>;
                      final walletEquiv = accMap['walletEquivalent'] as int? ?? 0;
                      return Text('₹$walletEquiv', style: const TextStyle(fontWeight: FontWeight.w600));
                    },
                  ),
                  AdminDataColumn(
                    title: 'ACTIONS',
                    builder: (acc) {
                      final accMap = acc as Map<String, dynamic>;
                      final userId = accMap['userId'] as String;
                      final userName = accMap['userName'] as String? ?? 'N/A';
                      final pointsBalance = accMap['pointsBalance'] as int? ?? 0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.tune, size: 18, color: Color(0xFF3B82F6)),
                            tooltip: 'Adjust Points',
                            onPressed: () => _showAdjustPointsDialog(context, userId, userName, pointsBalance),
                          ),
                          IconButton(
                            icon: const Icon(Icons.history, size: 18, color: Colors.blueGrey),
                            tooltip: 'View Transaction History',
                            onPressed: () => _showTransactionHistoryDialog(context, userId, userName),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                mobileCardBuilder: (ctx, acc) {
                  final accMap = acc as Map<String, dynamic>;
                  final userName = accMap['userName'] as String? ?? 'N/A';
                  final tierCode = LoyaltyTierCode.fromString(accMap['tierCode'] as String?);
                  final pointsBalance = accMap['pointsBalance'] as int? ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const Gap(4),
                            _buildTierBadge(tierCode),
                          ],
                        ),
                        Text('$pointsBalance pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 14)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTierBadge(LoyaltyTierCode code) {
    Color bg;
    Color fg;
    switch (code) {
      case LoyaltyTierCode.bronze:
        bg = const Color(0xFFCD7F32).withValues(alpha: 0.15);
        fg = const Color(0xFF8B4513);
        break;
      case LoyaltyTierCode.silver:
        bg = const Color(0xFF718096).withValues(alpha: 0.15);
        fg = const Color(0xFF2D3748);
        break;
      case LoyaltyTierCode.gold:
        bg = const Color(0xFFD4AF37).withValues(alpha: 0.15);
        fg = const Color(0xFFB8860B);
        break;
      case LoyaltyTierCode.platinum:
        bg = const Color(0xFF6C5CE7).withValues(alpha: 0.15);
        fg = const Color(0xFF6C5CE7);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code.displayName.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
      ),
    );
  }

  void _showAdjustPointsDialog(BuildContext context, String userId, String userName, int currentBalance) {
    final pointsCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    AdminDetailDrawer.show(
      context: context,
      title: 'Adjust Points',
      subtitle: userName,
      width: 480,
      child: StatefulBuilder(
        builder: (context, setModalState) => Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Current Available Balance: $currentBalance pts', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const Gap(16),
              TextFormField(
                controller: pointsCtrl,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: const InputDecoration(
                  labelText: 'Points Delta (+credit or -debit)',
                  hintText: 'e.g. 250 or -100',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter points amount';
                  final parsed = int.tryParse(val);
                  if (parsed == null || parsed == 0) return 'Enter non-zero integer';
                  return null;
                },
              ),
              const Gap(12),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason for Adjustment (Audit Required)',
                  hintText: 'e.g. Good will compensation for ticket #1234',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) return 'Reason must be at least 5 chars';
                  return null;
                },
              ),
              const Gap(24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (formKey.currentState?.validate() ?? false) {
                          setModalState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final points = int.parse(pointsCtrl.text.trim());
                            final reason = reasonCtrl.text.trim();
                            final repo = ref.read(adminLoyaltyRepositoryProvider);
                            await repo.adjustPoints(
                              userId: userId,
                              points: points,
                              reason: reason,
                              idempotencyKey: 'admin_adj_${userId}_${DateTime.now().millisecondsSinceEpoch}',
                            );
                            ref.invalidate(adminLoyaltySummaryProvider);
                            ref.invalidate(adminLoyaltyAccountsProvider);
                            if (context.mounted) Navigator.pop(context);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Points adjusted successfully!'), backgroundColor: Color(0xFF10B981)),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Adjustment failed: $e'), backgroundColor: Colors.red),
                            );
                          } finally {
                            setModalState(() => isSaving = false);
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Apply Adjustment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionHistoryDialog(BuildContext context, String userId, String userName) {
    AdminDetailDrawer.show(
      context: context,
      title: 'Transaction History',
      subtitle: userName,
      width: 480,
      child: FutureBuilder<List<LoyaltyTransactionModel>>(
        future: ref.read(adminLoyaltyRepositoryProvider).getAccountTransactions(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading history: ${snapshot.error}'));
          }
          final txs = snapshot.data ?? [];
          if (txs.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No transactions recorded.'),
            ));
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: txs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tx = txs[index];
              final isCredit = tx.type.isCredit;
              final color = isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: color,
                  size: 20,
                ),
                title: Text(tx.type.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(tx.description, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${isCredit ? '+' : '-'}${tx.points} pts', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                    Text('Bal: ${tx.balanceAfter}', style: const TextStyle(fontSize: 10, color: Colors.black38)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

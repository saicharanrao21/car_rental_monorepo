import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../providers/loyalty_providers.dart';

class LoyaltyPage extends ConsumerStatefulWidget {
  const LoyaltyPage({super.key});

  @override
  ConsumerState<LoyaltyPage> createState() => _LoyaltyPageState();
}

class _LoyaltyPageState extends ConsumerState<LoyaltyPage> {
  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(loyaltyAccountProvider);
    final transactionsAsync = ref.watch(loyaltyTransactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'DriveGo Rewards Club',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(loyaltyAccountProvider);
              ref.invalidate(loyaltyTransactionsProvider);
            },
          ),
        ],
      ),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Failed to load rewards account: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(loyaltyAccountProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (account) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(loyaltyAccountProvider);
              ref.invalidate(loyaltyTransactionsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTierHeroCard(context, account),
                  const SizedBox(height: 16),
                  _buildPointsRedemptionCard(context, account),
                  const SizedBox(height: 20),
                  _buildEarningRulesCard(context, account),
                  const SizedBox(height: 24),
                  const Text(
                    'Points History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  transactionsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Failed to load transactions: $err'),
                    ),
                    data: (transactions) {
                      if (transactions.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.stars_outlined, size: 48, color: Colors.black26),
                              SizedBox(height: 8),
                              Text(
                                'No loyalty points earned yet',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Complete your first rental to earn reward points!',
                                style: TextStyle(fontSize: 12, color: Colors.black38),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          return _buildTransactionTile(tx);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTierHeroCard(BuildContext context, LoyaltyAccountModel account) {
    final colors = _getTierGradient(account.tierCode);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${account.tierName.toUpperCase()} MEMBER',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '${account.pointsMultiplier}x Points Multiplier',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${account.lifetimePoints} Lifetime Pts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (account.nextTier != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Next Tier: ${account.nextTier!.name}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${account.nextTier!.pointsToNextTier} pts needed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (account.nextTier!.progressPercent / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 8,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '★ Highest Platinum Tier Achieved — Enjoy 2.00x Points!',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPointsRedemptionCard(BuildContext context, LoyaltyAccountModel account) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Points Balance',
                    style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${account.pointsBalance}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Points',
                        style: TextStyle(fontSize: 14, color: Colors.black45, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Wallet Value',
                      style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${account.walletEquivalent}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Conversion Rate: 2 Points = ₹1',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Directly credited to DriveGo Promotional Wallet',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: account.pointsBalance >= 2
                    ? () => _showRedemptionDialog(context, account)
                    : null,
                icon: const Icon(Icons.account_balance_wallet, size: 16),
                label: const Text('Redeem'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningRulesCard(BuildContext context, LoyaltyAccountModel account) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.all(Radius.circular(16)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Text(
                'How to Earn Loyalty Points',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Earn 1 base point per ₹10 of eligible rental Base Fare upon trip completion.\n'
            '• Multipliers apply automatically based on your Lifetime Tier.\n'
            '• Redeeming points never reduces your tier or lifetime rank.',
            style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(LoyaltyTransactionModel tx) {
    final isCredit = tx.type.isCredit;
    final color = isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.type.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.description,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${tx.points} pts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bal: ${tx.balanceAfter}',
                style: const TextStyle(fontSize: 10, color: Colors.black38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRedemptionDialog(BuildContext context, LoyaltyAccountModel account) {
    int redeemPoints = account.pointsBalance >= 500 ? 500 : (account.pointsBalance - (account.pointsBalance % 2));
    final maxPoints = account.pointsBalance - (account.pointsBalance % 2);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final walletCredit = (redeemPoints / 2).floor();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Redeem for Wallet Credit'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Points: ${account.pointsBalance} (Max: $maxPoints pts)',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Points to Redeem:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('$redeemPoints pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Promotional Wallet Credit:', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                      Text('₹$walletCredit', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (maxPoints >= 100)
                        ChoiceChip(
                          label: const Text('100 pts (₹50)'),
                          selected: redeemPoints == 100,
                          onSelected: (val) {
                            if (val) setDialogState(() => redeemPoints = 100);
                          },
                        ),
                      if (maxPoints >= 500)
                        ChoiceChip(
                          label: const Text('500 pts (₹250)'),
                          selected: redeemPoints == 500,
                          onSelected: (val) {
                            if (val) setDialogState(() => redeemPoints = 500);
                          },
                        ),
                      if (maxPoints >= 1000)
                        ChoiceChip(
                          label: const Text('1000 pts (₹500)'),
                          selected: redeemPoints == 1000,
                          onSelected: (val) {
                            if (val) setDialogState(() => redeemPoints = 1000);
                          },
                        ),
                      ChoiceChip(
                        label: const Text('Max'),
                        selected: redeemPoints == maxPoints,
                        onSelected: (val) {
                          if (val) setDialogState(() => redeemPoints = maxPoints);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: redeemPoints >= 2 && redeemPoints <= maxPoints
                      ? () async {
                          Navigator.pop(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final repo = ref.read(loyaltyRepositoryProvider);
                            await repo.redeemPointsToWallet(redeemPoints);
                            ref.invalidate(loyaltyAccountProvider);
                            ref.invalidate(loyaltyTransactionsProvider);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Successfully redeemed $redeemPoints points for ₹$walletCredit Wallet Credit!'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Redemption failed: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      : null,
                  child: Text('Redeem ₹$walletCredit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Color> _getTierGradient(LoyaltyTierCode code) {
    switch (code) {
      case LoyaltyTierCode.bronze:
        return const [Color(0xFF8B4513), Color(0xFFCD7F32)];
      case LoyaltyTierCode.silver:
        return const [Color(0xFF4A5568), Color(0xFF718096)];
      case LoyaltyTierCode.gold:
        return const [Color(0xFFB8860B), Color(0xFFE5C07B)];
      case LoyaltyTierCode.platinum:
        return const [Color(0xFF4A00E0), Color(0xFF8E2DE2)];
    }
  }
}

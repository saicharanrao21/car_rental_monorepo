import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'DriveGo Rewards Club',
          style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: DDSColors.primaryBlue),
            tooltip: 'Refresh Rewards',
            onPressed: () {
              ref.invalidate(loyaltyAccountProvider);
              ref.invalidate(loyaltyTransactionsProvider);
            },
          ),
        ],
      ),
      body: accountAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(DDSSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: DDSColors.errorRed),
                const Gap(DDSSpacing.sm),
                Text(
                  'Failed to load rewards account: $err',
                  textAlign: TextAlign.center,
                  style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary),
                ),
                const Gap(DDSSpacing.md),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: DDSColors.infoBlueBg,
                    foregroundColor: DDSColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: DDSRadius.mediumBorderRadius),
                  ),
                  onPressed: () => ref.invalidate(loyaltyAccountProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
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
              padding: const EdgeInsets.all(DDSSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTierHeroCard(context, account),
                  const Gap(DDSSpacing.md),
                  _buildPointsRedemptionCard(context, account),
                  const Gap(DDSSpacing.md),
                  _buildEarningRulesCard(context, account),
                  const Gap(DDSSpacing.lg),
                  Text(
                    'Points History',
                    style: DDSTypography.titleMedium.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: DDSColors.textPrimary,
                    ),
                  ),
                  const Gap(DDSSpacing.sm),
                  transactionsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Failed to load transactions: $err', style: DDSTypography.bodyMedium.copyWith(color: DDSColors.errorRed)),
                    ),
                    data: (transactions) {
                      if (transactions.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(DDSSpacing.xl),
                          decoration: BoxDecoration(
                            color: DDSColors.surfaceCard,
                            borderRadius: DDSRadius.largeBorderRadius,
                            border: Border.all(color: DDSColors.borderLight),
                            boxShadow: DDSElevation.cardShadow,
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.stars_outlined, size: 48, color: DDSColors.textMuted),
                              const Gap(8),
                              Text(
                                'No loyalty points earned yet',
                                style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: DDSColors.textPrimary),
                              ),
                              const Gap(4),
                              Text(
                                'Complete your first rental to earn reward points!',
                                style: DDSTypography.bodyMedium.copyWith(fontSize: 12, color: DDSColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => const Gap(8),
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          return _buildTransactionTile(tx);
                        },
                      );
                    },
                  ),
                  const Gap(40),
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
        borderRadius: DDSRadius.largeBorderRadius,
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(DDSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${account.tierName.toUpperCase()} MEMBER',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DDSTypography.titleMedium.copyWith(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '${account.pointsMultiplier}x Points Multiplier',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DDSTypography.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: DDSRadius.mediumBorderRadius,
                ),
                child: Text(
                  '${account.lifetimePoints} Lifetime Pts',
                  style: DDSTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Gap(24),
          if (account.nextTier != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Next Tier: ${account.nextTier!.name}',
                    style: DDSTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${account.nextTier!.pointsToNextTier} pts needed',
                  style: DDSTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Gap(8),
            ClipRRect(
              borderRadius: DDSRadius.smallBorderRadius,
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
                borderRadius: DDSRadius.smallBorderRadius,
              ),
              child: Text(
                '★ Highest Platinum Tier Achieved — Enjoy 2.00x Points!',
                style: DDSTypography.labelSmall.copyWith(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(DDSSpacing.lg),
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.largeBorderRadius,
        border: Border.all(color: DDSColors.borderLight),
        boxShadow: DDSElevation.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Points Balance',
                      style: DDSTypography.bodyMedium.copyWith(fontSize: 13, color: DDSColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const Gap(4),
                    Text(
                      '${account.pointsBalance} Pts',
                      style: DDSTypography.displayLarge.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: DDSColors.successGreenBg,
                  borderRadius: DDSRadius.mediumBorderRadius,
                  border: Border.all(color: DDSColors.successGreen.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Wallet Value',
                      style: DDSTypography.labelSmall.copyWith(fontSize: 10, color: DDSColors.successGreen, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${account.walletEquivalent}',
                      style: DDSTypography.titleMedium.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: DDSColors.successGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(DDSSpacing.md),
          const Divider(height: 1, color: DDSColors.borderLight),
          const Gap(DDSSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conversion Rate: 2 Points = ₹1',
                      style: DDSTypography.bodyMedium.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: DDSColors.textPrimary),
                    ),
                    const Gap(2),
                    Text(
                      'Directly credited to DriveGo Promotional Wallet',
                      style: DDSTypography.bodyMedium.copyWith(fontSize: 11, color: DDSColors.textMuted),
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
                  backgroundColor: DDSColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: DDSRadius.mediumBorderRadius),
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
      padding: const EdgeInsets.all(DDSSpacing.md),
      decoration: BoxDecoration(
        color: DDSColors.infoBlueBg,
        borderRadius: DDSRadius.largeBorderRadius,
        border: Border.all(color: DDSColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: DDSColors.primaryBlue),
              const Gap(8),
              Expanded(
                child: Text(
                  'How to Earn Loyalty Points',
                  style: DDSTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.bold, color: DDSColors.primaryBlue),
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            '• Earn 1 base point per ₹10 of eligible rental Base Fare upon trip completion.\n'
            '• Multipliers apply automatically based on your Lifetime Tier.\n'
            '• Redeeming points never reduces your tier or lifetime rank.',
            style: DDSTypography.bodyMedium.copyWith(fontSize: 12, color: DDSColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(LoyaltyTransactionModel tx) {
    final isCredit = tx.type.isCredit;
    final color = isCredit ? DDSColors.successGreen : DDSColors.errorRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DDSSpacing.md, vertical: DDSSpacing.sm),
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.mediumBorderRadius,
        border: Border.all(color: DDSColors.borderLight),
        boxShadow: DDSElevation.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DDSSpacing.xs),
            decoration: BoxDecoration(
              color: isCredit ? DDSColors.successGreenBg : DDSColors.errorRedBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: color,
              size: 20,
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.type.displayName,
                  style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 13, color: DDSColors.textPrimary),
                ),
                const Gap(2),
                Text(
                  tx.description,
                  style: DDSTypography.bodyMedium.copyWith(fontSize: 11, color: DDSColors.textSecondary),
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
                style: DDSTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
              const Gap(2),
              Text(
                'Bal: ${tx.balanceAfter}',
                style: DDSTypography.labelSmall.copyWith(fontSize: 10, color: DDSColors.textMuted),
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
              shape: RoundedRectangleBorder(borderRadius: DDSRadius.largeBorderRadius),
              title: Text('Redeem for Wallet Credit', style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Points: ${account.pointsBalance} (Max: $maxPoints pts)',
                    style: DDSTypography.bodyMedium.copyWith(fontSize: 13, color: DDSColors.textSecondary),
                  ),
                  const Gap(16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Points to Redeem:', style: DDSTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      Text('$redeemPoints pts', style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const Gap(4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Promotional Wallet Credit:', style: DDSTypography.bodyMedium.copyWith(color: DDSColors.successGreen, fontWeight: FontWeight.w600)),
                      Text('₹$walletCredit', style: DDSTypography.titleLarge.copyWith(color: DDSColors.successGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  const Gap(16),
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
                  child: Text('Cancel', style: DDSTypography.labelLarge.copyWith(color: DDSColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DDSColors.successGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: DDSRadius.smallBorderRadius),
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
                                backgroundColor: DDSColors.successGreen,
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Redemption failed: $e'),
                                backgroundColor: DDSColors.errorRed,
                              ),
                            );
                          }
                        }
                      : null,
                  child: Text('Redeem ₹$walletCredit', style: DDSTypography.labelLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/referral_providers.dart';

class ReferralPage extends ConsumerStatefulWidget {
  const ReferralPage({super.key});

  @override
  ConsumerState<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends ConsumerState<ReferralPage> {
  final _codeController = TextEditingController();
  bool _isApplying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showApplyCodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: DDSRadius.largeBorderRadius),
          title: Text('Enter Referral Code', style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the referral code shared by your friend to unlock ₹250 off on your first booking of ₹1,000 or more.',
                style: DDSTypography.bodyMedium.copyWith(fontSize: 13, color: DDSColors.textSecondary),
              ),
              const Gap(16),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'e.g. DGALICE1',
                  prefixIcon: const Icon(Icons.confirmation_number_outlined, color: DDSColors.primaryBlue),
                  border: OutlineInputBorder(borderRadius: DDSRadius.mediumBorderRadius),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: DDSTypography.labelLarge.copyWith(color: DDSColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: _isApplying
                  ? null
                  : () async {
                      final code = _codeController.text.trim().toUpperCase();
                      if (code.isEmpty) return;

                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(ctx);

                      setDialogState(() => _isApplying = true);
                      try {
                        final repo = ref.read(referralRepositoryProvider);
                        final res = await repo.applyReferralCode(code);
                        navigator.pop();
                        _codeController.clear();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(res['message'] as String? ?? 'Referral code applied!'),
                            backgroundColor: DDSColors.successGreen,
                          ),
                        );
                        ref.invalidate(refereeEligibilityProvider);
                      } catch (err) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to apply code: $err'),
                            backgroundColor: DDSColors.errorRed,
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setDialogState(() => _isApplying = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: DDSColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: DDSRadius.smallBorderRadius),
              ),
              child: _isApplying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Apply Code', style: DDSTypography.labelLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final codeAsync = ref.watch(myReferralCodeProvider);
    final historyAsync = ref.watch(referralHistoryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Refer & Earn',
          style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, color: DDSColors.textPrimary),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: DDSColors.primaryBlue),
            tooltip: 'Refresh Referral',
            onPressed: () {
              ref.invalidate(myReferralCodeProvider);
              ref.invalidate(referralHistoryProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myReferralCodeProvider);
          ref.invalidate(referralHistoryProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(DDSSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DDSSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: DDSRadius.largeBorderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A00E0).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.card_giftcard, color: Colors.white, size: 28),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            'Invite Friends, Earn ₹250',
                            style: DDSTypography.headlineMedium.copyWith(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    Text(
                      'Give ₹250 off their first qualifying drive, get ₹250 DriveGo Wallet credit when they complete their first trip.',
                      style: DDSTypography.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.4),
                    ),
                    const Gap(20),

                    // Referral Code Box
                    codeAsync.when(
                      data: (data) {
                        final code = data['referralCode'] as String? ?? '---';
                        final shareUrl = data['shareUrl'] as String? ?? 'https://drivego.in/invite?code=$code';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: DDSSpacing.md, vertical: DDSSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: DDSRadius.mediumBorderRadius,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'YOUR REFERRAL CODE',
                                      style: DDSTypography.labelSmall.copyWith(
                                        color: DDSColors.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const Gap(2),
                                    Text(
                                      code,
                                      style: DDSTypography.titleLarge.copyWith(
                                        color: DDSColors.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy, color: DDSColors.primaryBlue),
                                    tooltip: 'Copy Code',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: code));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Referral code copied to clipboard!'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share, color: DDSColors.primaryBlue),
                                    tooltip: 'Share Invite',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(
                                        text: 'Join DriveGo and get ₹250 off your first rental booking with my code $code! 🚗💨\n$shareUrl',
                                      ));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Referral invite link copied to clipboard!'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      error: (err, _) => Text(
                        'Failed to load code: $err',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              const Gap(16),

              // Apply Code CTA Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: DDSSpacing.md, vertical: DDSSpacing.sm),
                decoration: BoxDecoration(
                  color: DDSColors.surfaceCard,
                  borderRadius: DDSRadius.largeBorderRadius,
                  border: Border.all(color: DDSColors.borderLight),
                  boxShadow: DDSElevation.cardShadow,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.redeem, color: DDSColors.successGreen),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        'Have a friend\'s referral code?',
                        style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 13, color: DDSColors.textPrimary),
                      ),
                    ),
                    TextButton(
                      onPressed: _showApplyCodeDialog,
                      child: Text('Apply Code', style: DDSTypography.labelLarge.copyWith(fontWeight: FontWeight.bold, color: DDSColors.primaryBlue)),
                    ),
                  ],
                ),
              ),

              const Gap(20),

              // Performance Summary Stats
              historyAsync.when(
                data: (data) {
                  final summary = data['summary'] as Map<String, dynamic>? ?? {};
                  final totalInvited = summary['totalInvited'] ?? 0;
                  final totalRegistered = summary['totalRegistered'] ?? 0;
                  final totalCompleted = summary['totalCompleted'] ?? 0;
                  final totalEarnings = (summary['totalEarnings'] as num?)?.toDouble() ?? 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Referral Stats',
                        style: DDSTypography.titleMedium.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: DDSColors.textPrimary),
                      ),
                      const Gap(12),
                      Row(
                        children: [
                          _buildStatCard(
                            'Invited',
                            totalInvited.toString(),
                            Icons.people_outline,
                            DDSColors.primaryBlue,
                          ),
                          const Gap(8),
                          _buildStatCard(
                            'Registered',
                            totalRegistered.toString(),
                            Icons.how_to_reg_outlined,
                            DDSColors.warningOrange,
                          ),
                        ],
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          _buildStatCard(
                            'Trips Done',
                            totalCompleted.toString(),
                            Icons.check_circle_outline,
                            DDSColors.successGreen,
                          ),
                          const Gap(8),
                          _buildStatCard(
                            'Rewards Earned',
                            '₹${totalEarnings.toStringAsFixed(0)}',
                            Icons.account_balance_wallet_outlined,
                            Colors.purple.shade700,
                          ),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
              ),

              const Gap(24),

              // How it Works Stepper
              Text(
                'How It Works',
                style: DDSTypography.titleMedium.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: DDSColors.textPrimary),
              ),
              const Gap(12),
              _buildStepTile(
                1,
                'Share your code',
                'Send your unique referral code or link to your friends.',
              ),
              _buildStepTile(
                2,
                'Friend gets ₹250 off',
                'Your friend enters your code and gets ₹250 off on their first booking of ₹1,000 or more.',
              ),
              _buildStepTile(
                3,
                'You get ₹250 wallet cash',
                'Once your friend successfully completes their first trip, ₹250 is instantly credited to your DriveGo Wallet.',
              ),

              const Gap(24),

              // Referred Friends List
              historyAsync.when(
                data: (data) {
                  final list = data['referrals'] as List<dynamic>? ?? [];
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No referrals yet. Share your code to start earning!',
                          style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted),
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Referred Friends',
                        style: DDSTypography.titleMedium.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: DDSColors.textPrimary),
                      ),
                      const Gap(12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Gap(8),
                        itemBuilder: (context, index) {
                          final item = list[index] as Map<String, dynamic>;
                          final name = item['refereeName'] as String? ?? 'User';
                          final phone = item['refereePhone'] as String? ?? '';
                          final status = item['status'] as String? ?? 'REGISTERED';
                          final reward = (item['rewardAmount'] as num?)?.toDouble() ?? 250.0;

                          return Container(
                            decoration: BoxDecoration(
                              color: DDSColors.surfaceCard,
                              borderRadius: DDSRadius.mediumBorderRadius,
                              border: Border.all(color: DDSColors.borderLight),
                              boxShadow: DDSElevation.cardShadow,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: DDSColors.primaryBlue.withValues(alpha: 0.1),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: DDSTypography.titleMedium.copyWith(
                                      color: DDSColors.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(name, style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.w600, color: DDSColors.textPrimary)),
                                subtitle: Text(phone, style: DDSTypography.bodyMedium.copyWith(fontSize: 12, color: DDSColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: _buildStatusChip(status, reward),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Failed to load history: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(DDSSpacing.sm),
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
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Gap(8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DDSTypography.titleMedium.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: DDSColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DDSTypography.labelSmall.copyWith(fontSize: 10, color: DDSColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTile(int step, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: DDSColors.primaryBlue,
            child: Text(
              '$step',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 13, color: DDSColors.textPrimary)),
                const Gap(2),
                Text(subtitle, style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, double reward) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'REWARDED':
        bg = DDSColors.successGreenBg;
        fg = DDSColors.successGreen;
        label = '+₹${reward.toStringAsFixed(0)} Earned';
        break;
      case 'QUALIFIED':
        bg = DDSColors.warningOrangeBg;
        fg = DDSColors.warningOrange;
        label = 'Trip Completed';
        break;
      case 'REGISTERED':
        bg = DDSColors.infoBlueBg;
        fg = DDSColors.primaryBlue;
        label = 'Signed Up';
        break;
      case 'FRAUD_BLOCKED':
        bg = DDSColors.errorRedBg;
        fg = DDSColors.errorRed;
        label = 'Blocked';
        break;
      default:
        bg = DDSColors.surfaceCard;
        fg = DDSColors.textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DDSRadius.smallBorderRadius,
      ),
      child: Text(
        label,
        style: DDSTypography.labelSmall.copyWith(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

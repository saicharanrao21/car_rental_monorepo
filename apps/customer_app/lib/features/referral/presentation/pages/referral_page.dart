import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Enter Referral Code', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the referral code shared by your friend to unlock ₹250 off on your first booking of ₹1,000 or more.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'e.g. DGALICE1',
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
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
                            backgroundColor: Colors.green,
                          ),
                        );
                        ref.invalidate(refereeEligibilityProvider);
                      } catch (err) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to apply code: $err'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setDialogState(() => _isApplying = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isApplying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Apply Code'),
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
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          'Refer & Earn',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.card_giftcard, color: Colors.white, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Invite Friends, Earn ₹250',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Give ₹250 off their first qualifying drive, get ₹250 DriveGo Wallet credit when they complete their first trip.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    // Referral Code Box
                    codeAsync.when(
                      data: (data) {
                        final code = data['referralCode'] as String? ?? '---';
                        final shareUrl = data['shareUrl'] as String? ?? 'https://drivego.in/invite?code=$code';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'YOUR REFERRAL CODE',
                                    style: TextStyle(
                                      color: Colors.black45,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    code,
                                    style: const TextStyle(
                                      color: Color(0xFF2D3436),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy, color: Color(0xFF6C5CE7)),
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
                                    icon: const Icon(Icons.share, color: Color(0xFF6C5CE7)),
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

              const SizedBox(height: 16),

              // Apply Code CTA Banner
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.redeem, color: Color(0xFF00B894)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Have a friend\'s referral code?',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: _showApplyCodeDialog,
                        child: const Text('Apply Code'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

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
                      const Text(
                        'Your Referral Stats',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatCard(
                            'Invited',
                            totalInvited.toString(),
                            Icons.people_outline,
                            const Color(0xFF0984E3),
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            'Registered',
                            totalRegistered.toString(),
                            Icons.how_to_reg_outlined,
                            const Color(0xFFE17055),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatCard(
                            'Trips Done',
                            totalCompleted.toString(),
                            Icons.check_circle_outline,
                            const Color(0xFF00B894),
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            'Rewards Earned',
                            '₹${totalEarnings.toStringAsFixed(0)}',
                            Icons.account_balance_wallet_outlined,
                            const Color(0xFF6C5CE7),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // How it Works Stepper
              const Text(
                'How It Works',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
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

              const SizedBox(height: 24),

              // Referred Friends List
              historyAsync.when(
                data: (data) {
                  final list = data['referrals'] as List<dynamic>? ?? [];
                  if (list.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No referrals yet. Share your code to start earning!',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Referred Friends',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = list[index] as Map<String, dynamic>;
                          final name = item['refereeName'] as String? ?? 'User';
                          final phone = item['refereePhone'] as String? ?? '';
                          final status = item['status'] as String? ?? 'REGISTERED';
                          final reward = (item['rewardAmount'] as num?)?.toDouble() ?? 250.0;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: Color(0xFF6C5CE7),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(phone, style: const TextStyle(fontSize: 12)),
                              trailing: _buildStatusChip(status, reward),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
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
            backgroundColor: const Color(0xFF6C5CE7),
            child: Text(
              '$step',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.3)),
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
        bg = const Color(0xFFE8F8F5);
        fg = const Color(0xFF00B894);
        label = '+₹${reward.toStringAsFixed(0)} Earned';
        break;
      case 'QUALIFIED':
        bg = const Color(0xFFFEF9E7);
        fg = const Color(0xFFF39C12);
        label = 'Trip Completed';
        break;
      case 'REGISTERED':
        bg = const Color(0xFFEBF5FB);
        fg = const Color(0xFF3498DB);
        label = 'Signed Up';
        break;
      case 'FRAUD_BLOCKED':
        bg = const Color(0xFFFDEDEC);
        fg = const Color(0xFFE74C3C);
        label = 'Blocked';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

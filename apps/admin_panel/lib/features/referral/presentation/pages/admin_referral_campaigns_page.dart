import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:gap/gap.dart';
import '../../../../core/widgets/admin_detail_drawer.dart';
import '../providers/admin_referral_providers.dart';

class AdminReferralCampaignsPage extends ConsumerStatefulWidget {
  const AdminReferralCampaignsPage({super.key});

  @override
  ConsumerState<AdminReferralCampaignsPage> createState() =>
      _AdminReferralCampaignsPageState();
}

class _AdminReferralCampaignsPageState
    extends ConsumerState<AdminReferralCampaignsPage> {
  void _showCreateCampaignDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final referrerRewardCtrl = TextEditingController(text: '250');
    final refereeRewardCtrl = TextEditingController(text: '250');
    final minBookingCtrl = TextEditingController(text: '1000');
    final cityCtrl = TextEditingController();
    final maxReferralsCtrl = TextEditingController(text: '20');
    bool isSaving = false;

    AdminDetailDrawer.show(
      context: context,
      title: 'Create Referral Campaign',
      subtitle: 'Configure reward structures and redemption caps',
      width: 480,
      child: StatefulBuilder(
        builder: (context, setModalState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Campaign Name *',
                hintText: 'e.g. Bangalore Launch Promo',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Campaign Code *',
                hintText: 'e.g. BLR2026',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: referrerRewardCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Referrer Reward (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: TextField(
                    controller: refereeRewardCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Referee Discount (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minBookingCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min Booking Fare (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: TextField(
                    controller: maxReferralsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Referrals / User',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const Gap(12),
            TextField(
              controller: cityCtrl,
              decoration: const InputDecoration(
                labelText: 'Target City (Optional)',
                hintText: 'Leave empty for Global',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(24),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final code = codeCtrl.text.trim().toUpperCase();
                      final referrerReward =
                          double.tryParse(referrerRewardCtrl.text.trim()) ?? 250.0;
                      final refereeReward =
                          double.tryParse(refereeRewardCtrl.text.trim()) ?? 250.0;
                      final minBooking =
                          double.tryParse(minBookingCtrl.text.trim()) ?? 1000.0;
                      final maxRef =
                          int.tryParse(maxReferralsCtrl.text.trim()) ?? 20;
                      final city = cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim();

                      if (name.isEmpty || code.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Campaign name and code are required.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      setModalState(() => isSaving = true);

                      try {
                        final repo = ref.read(adminReferralRepositoryProvider);
                        await repo.createCampaign({
                          'name': name,
                          'code': code,
                          'referrerRewardAmount': referrerReward,
                          'refereeRewardAmount': refereeReward,
                          'minBookingAmount': minBooking,
                          'maxReferralsPerUser': maxRef,
                          if (city != null) 'city': city,
                          'isActive': true,
                        });
                        if (context.mounted) Navigator.of(context).pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Referral campaign created successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        ref.invalidate(adminReferralCampaignsProvider);
                      } catch (err) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to create campaign: $err'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setModalState(() => isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Campaign'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(adminReferralCampaignsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Referral Campaign Management',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminReferralCampaignsProvider),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: _showCreateCampaignDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Campaign'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: campaignsAsync.when(
        data: (campaigns) {
          if (campaigns.isEmpty) {
            return const Center(
              child: Text(
                'No referral campaigns found. Create a new campaign to begin.',
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: campaigns.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = campaigns[index];
              return _buildCampaignCard(item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Failed to load campaigns: $err',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildCampaignCard(ReferralCampaignModel campaign) {
    final stats = campaign.stats ?? {};
    final total = stats['total'] ?? 0;
    final registered = stats['registered'] ?? 0;
    final qualified = stats['qualified'] ?? 0;
    final rewarded = stats['rewarded'] ?? 0;
    final cancelled = stats['cancelled'] ?? 0;
    final fraudBlocked = stats['fraudBlocked'] ?? 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          campaign.code,
                          style: const TextStyle(
                            color: Color(0xFF6C5CE7),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          campaign.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: campaign.isActive
                            ? const Color(0xFFE8F8F5)
                            : const Color(0xFFFDEDEC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        campaign.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: campaign.isActive
                              ? const Color(0xFF00B894)
                              : const Color(0xFFE74C3C),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: campaign.isActive,
                      activeTrackColor: const Color(0xFF6C5CE7),
                      onChanged: (val) async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final repo = ref.read(adminReferralRepositoryProvider);
                          await repo.toggleCampaign(campaign.id);
                          ref.invalidate(adminReferralCampaignsProvider);
                        } catch (err) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to update status: $err'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _buildParamChip('Referrer Reward', '₹${campaign.referrerRewardAmount.toStringAsFixed(0)}'),
                _buildParamChip('Referee Discount', '₹${campaign.refereeRewardAmount.toStringAsFixed(0)}'),
                _buildParamChip('Min Booking Amount', '₹${campaign.minBookingAmount.toStringAsFixed(0)}'),
                _buildParamChip('City', campaign.city ?? 'Global (All Cities)'),
                _buildParamChip('Max Referrals/User', '${campaign.maxReferralsPerUser}'),
              ],
            ),
            const Divider(height: 32),
            const Text(
              'Campaign Performance Stats',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetricBox('Total', total.toString(), Colors.blueGrey),
                  const SizedBox(width: 8),
                  _buildMetricBox('Registered', registered.toString(), Colors.blue),
                  const SizedBox(width: 8),
                  _buildMetricBox('Qualified', qualified.toString(), Colors.amber.shade800),
                  const SizedBox(width: 8),
                  _buildMetricBox('Rewarded', rewarded.toString(), Colors.green),
                  const SizedBox(width: 8),
                  _buildMetricBox('Cancelled', cancelled.toString(), Colors.orange),
                  const SizedBox(width: 8),
                  _buildMetricBox('Fraud Blocked', fraudBlocked.toString(), Colors.red),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParamChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMetricBox(String label, String count, Color color) {
    return SizedBox(
      width: 105,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

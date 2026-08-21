import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../../loyalty/presentation/providers/loyalty_providers.dart';
import '../../../referral/presentation/providers/referral_providers.dart';
import '../../../wishlist/wishlist_providers.dart';
import 'kyc_upload_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  void _showEditProfileBottomSheet(
    BuildContext context,
    WidgetRef ref,
    String currentName,
    String? currentEmail,
  ) {
    final nameCtrl = TextEditingController(text: currentName);
    final emailCtrl = TextEditingController(text: currentEmail ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(modalContext).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(modalContext).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Gap(16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Profile',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const Gap(16),
                    AppTextField(
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      controller: nameCtrl,
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                    ),
                    const Gap(16),
                    AppTextField(
                      label: 'Email Address',
                      hint: 'Enter your email address',
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const Gap(24),
                    AppButton(
                      text: isSubmitting ? 'Saving...' : 'Save Changes',
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (formKey.currentState!.validate()) {
                                setModalState(() => isSubmitting = true);
                                try {
                                  await ref.read(sessionProvider.notifier).updateProfile(
                                        name: nameCtrl.text.trim(),
                                        email: emailCtrl.text.trim(),
                                      );
                                  if (context.mounted) {
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Profile updated successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (modalContext.mounted) {
                                    setModalState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error updating profile: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out from DriveGo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(sessionProvider.notifier).logout();
              context.go('/auth/phone');
            },
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car_filled, size: 48, color: AppColors.primary),
              ),
              const Gap(16),
              const Text(
                'DriveGo Self-Drive & Chauffeur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const Gap(6),
              Text(
                'Version 1.0.0 (Release Candidate)',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const Gap(16),
              const Text(
                'High-performance car rental platform with instant booking, zero security deposit, doorstep delivery, and 24/7 roadside assistance.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const Gap(20),
              const Divider(height: 1),
              const Gap(12),
              Text(
                '© 2026 DriveGo Technologies Inc.\nAll rights reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyRoadsideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency, color: Colors.red, size: 24),
            ),
            const Gap(12),
            const Expanded(
              child: Text(
                'Emergency Roadside SOS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DriveGo Roadside Assistance provides real-time emergency dispatch for on-trip breakdowns, towing, flat tires, and accidents.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const Gap(16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gps_fixed, color: AppColors.primary, size: 20),
                  Gap(10),
                  Expanded(
                    child: Text(
                      'For active trips, open your booking to dispatch technicians directly to your live GPS coordinates.',
                      style: TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.support_agent, color: AppColors.primary, size: 20),
                  Gap(10),
                  Expanded(
                    child: Text(
                      'For urgent account or trip support, raise an emergency ticket in the Help & Support Center.',
                      style: TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/support');
            },
            child: const Text('Support Center'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/bookings');
            },
            child: const Text('My Bookings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle_outlined, size: 64, color: Colors.grey),
              const Gap(16),
              const Text('Not signed in', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Gap(12),
              FilledButton(
                onPressed: () => context.go('/auth/phone'),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    final kycAsync = ref.watch(kycStatusProvider);
    final walletAsync = ref.watch(customerWalletProvider);
    final loyaltyAsync = ref.watch(loyaltyAccountProvider);
    final referralAsync = ref.watch(myReferralCodeProvider);
    final wishlistedIds = ref.watch(wishlistIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditProfileBottomSheet(context, ref, user.name, user.email),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Modern Profile Hero Card ──────────────────────────────
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      _getInitials(user.name),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Gap(4),
                        Row(
                          children: [
                            Icon(Icons.phone_android, size: 14, color: cs.onSurfaceVariant),
                            const Gap(4),
                            Text(
                              user.phone,
                              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                        if (user.email != null && user.email!.isNotEmpty) ...[
                          const Gap(2),
                          Row(
                            children: [
                              Icon(Icons.email_outlined, size: 14, color: cs.onSurfaceVariant),
                              const Gap(4),
                              Expanded(
                                child: Text(
                                  user.email!,
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Gap(8),
                        // Real KYC Status Badge
                        kycAsync.when(
                          data: (kycData) {
                            final status = (kycData['status'] as String? ?? 'NONE').toUpperCase();
                            return _buildKycBadge(context, status);
                          },
                          loading: () => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Checking KYC...', style: TextStyle(fontSize: 10)),
                          ),
                          error: (_, __) => _buildKycErrorBadge(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),

            // ── Quick Stats & Rewards Bar ──────────────────────────────
            Row(
              children: [
                // Wallet Stat
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/wallet'),
                    borderRadius: BorderRadius.circular(12),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Column(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.primary),
                          const Gap(4),
                          walletAsync.when(
                            data: (w) => Text(
                              '₹${w.availableBalance.toInt()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            loading: () => const Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                            error: (_, __) => Text(
                              'Unavailable',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.error),
                            ),
                          ),
                          const Gap(2),
                          Text('Wallet', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap(10),
                // Loyalty Stat
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/loyalty'),
                    borderRadius: BorderRadius.circular(12),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Column(
                        children: [
                          const Icon(Icons.stars_outlined, size: 20, color: Colors.amber),
                          const Gap(4),
                          loyaltyAsync.when(
                            data: (l) => Text(
                              '${l.pointsBalance} pts',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            loading: () => const Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                            error: (_, __) => Text(
                              'Unavailable',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.error),
                            ),
                          ),
                          const Gap(2),
                          Text('Club Rewards', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap(10),
                // Referral Stat
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/referral'),
                    borderRadius: BorderRadius.circular(12),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Column(
                        children: [
                          const Icon(Icons.card_giftcard_outlined, size: 20, color: Colors.purple),
                          const Gap(4),
                          referralAsync.when(
                            data: (_) => const Text('₹250 Off', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            loading: () => const Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                            error: (_, __) => Text(
                              'Unavailable',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.error),
                            ),
                          ),
                          const Gap(2),
                          Text('Refer & Earn', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Gap(24),

            // ── Account & Documents Section ───────────────────────────
            _sectionHeader(context, 'Account & Verification'),
            const Gap(8),
            _menuTile(
              context,
              icon: Icons.badge_outlined,
              title: 'Driving Licence (KYC)',
              subtitle: kycAsync.when(
                data: (d) => _getKycSubtitle(d['status'] as String? ?? 'NONE'),
                loading: () => 'Checking status...',
                error: (_, __) => 'Status unavailable',
              ),
              trailingBadge: kycAsync.when(
                data: (d) => (d['status'] == 'VERIFIED')
                    ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                    : null,
                loading: () => null,
                error: (_, __) => null,
              ),
              onTap: () => context.push('/kyc'),
            ),
            _menuTile(
              context,
              icon: Icons.account_balance_wallet_outlined,
              title: 'DriveGo Wallet & Credits',
              subtitle: 'Manage balance, refunds and transactions',
              onTap: () => context.push('/wallet'),
            ),
            _menuTile(
              context,
              icon: Icons.person_outline,
              title: 'Personal Details',
              subtitle: 'Edit name, email and contact preferences',
              onTap: () => _showEditProfileBottomSheet(context, ref, user.name, user.email),
            ),
            const Gap(20),

            // ── Activity & Benefits Section ─────────────────────────────
            _sectionHeader(context, 'Activity & Benefits'),
            const Gap(8),
            _menuTile(
              context,
              icon: Icons.favorite_border,
              title: 'Saved Cars (Wishlist)',
              subtitle: '${wishlistedIds.length} cars saved',
              onTap: () => context.push('/wishlist'),
            ),
            _menuTile(
              context,
              icon: Icons.stars_outlined,
              title: 'DriveGo Rewards Club',
              subtitle: 'Tier benefits, points and perks',
              onTap: () => context.push('/loyalty'),
            ),
            _menuTile(
              context,
              icon: Icons.card_giftcard_outlined,
              title: 'Refer & Earn',
              subtitle: 'Earn ₹250 for every friend who books',
              onTap: () => context.push('/referral'),
            ),
            _menuTile(
              context,
              icon: Icons.notifications_none_outlined,
              title: 'Notifications',
              subtitle: 'Trip alerts, offers and updates',
              onTap: () => context.push('/notifications'),
            ),
            const Gap(20),

            // ── Support & Info Section ────────────────────────────────
            _sectionHeader(context, 'Support & Info'),
            const Gap(8),
            _menuTile(
              context,
              icon: Icons.help_outline,
              title: 'Help & Support Center',
              subtitle: 'FAQs, ticket history and live resolution',
              onTap: () => context.push('/support'),
            ),
            _menuTile(
              context,
              icon: Icons.emergency_outlined,
              iconColor: Colors.red[700],
              title: 'Emergency Roadside SOS',
              subtitle: '24/7 breakdown & towing assistance',
              onTap: () => _showEmergencyRoadsideDialog(context),
            ),
            _menuTile(
              context,
              icon: Icons.info_outline,
              title: 'About DriveGo',
              subtitle: 'Version 1.0.0, Terms & Privacy',
              onTap: () => _showAboutDialog(context),
            ),
            const Gap(28),

            // ── Sign Out Button ───────────────────────────────────────
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showLogoutDialog(context, ref),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: Colors.red.shade300),
                foregroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    Widget? trailingBadge,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingBadge != null) trailingBadge,
              const Gap(4),
              Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildKycBadge(BuildContext context, String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'VERIFIED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Verified Driver';
        icon = Icons.verified;
        break;
      case 'PENDING':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        label = 'KYC Under Review';
        icon = Icons.schedule;
        break;
      case 'REJECTED':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'KYC Rejected';
        icon = Icons.cancel_outlined;
        break;
      case 'EXPIRED':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        label = 'Licence Expired';
        icon = Icons.warning_amber_rounded;
        break;
      default:
        bg = AppColors.primary.withValues(alpha: 0.1);
        fg = AppColors.primary;
        label = 'Verify Driving Licence';
        icon = Icons.badge_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const Gap(4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildKycErrorBadge(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.error.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 12, color: cs.error),
          const Gap(4),
          Text(
            'Status Unavailable',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.error),
          ),
        ],
      ),
    );
  }

  String _getKycSubtitle(String status) {
    switch (status.toUpperCase()) {
      case 'VERIFIED':
        return 'Driving licence verified';
      case 'PENDING':
        return 'Verification under review';
      case 'REJECTED':
        return 'Document rejected - resubmit';
      case 'EXPIRED':
        return 'Licence expired - update details';
      default:
        return 'Upload licence for quick bookings';
    }
  }
}

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
                left: DDSSpacing.lg,
                right: DDSSpacing.lg,
                top: DDSSpacing.lg,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + DDSSpacing.xl,
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
                          color: DDSColors.borderMedium,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Gap(DDSSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Profile',
                          style: DDSTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: DDSColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: DDSColors.textSecondary),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const Gap(DDSSpacing.md),
                    AppTextField(
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      controller: nameCtrl,
                      prefixIcon: const Icon(Icons.person_outline, color: DDSColors.primaryBlue),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                    ),
                    const Gap(DDSSpacing.md),
                    AppTextField(
                      label: 'Email Address',
                      hint: 'Enter your email address',
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, color: DDSColors.primaryBlue),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const Gap(DDSSpacing.xl),
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
                                        backgroundColor: DDSColors.successGreen,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (modalContext.mounted) {
                                    setModalState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error updating profile: $e'),
                                        backgroundColor: DDSColors.errorRed,
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
        shape: RoundedRectangleBorder(borderRadius: DDSRadius.largeBorderRadius),
        title: Text('Logout', style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to sign out from DriveGo?',
          style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: DDSTypography.labelLarge.copyWith(color: DDSColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DDSColors.errorRed,
              shape: RoundedRectangleBorder(borderRadius: DDSRadius.mediumBorderRadius),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(sessionProvider.notifier).logout();
              context.go('/auth/phone');
            },
            child: Text('Logout', style: DDSTypography.labelLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DDSRadius.largeBorderRadius),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: DDSSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(DDSSpacing.md),
                decoration: BoxDecoration(
                  color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car_filled, size: 48, color: DDSColors.primaryBlue),
              ),
              const Gap(DDSSpacing.md),
              Text(
                'DriveGo Self-Drive & Chauffeur',
                style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const Gap(6),
              Text(
                'Version 1.0.0 (Release Candidate)',
                style: DDSTypography.bodyMedium.copyWith(fontSize: 12, color: DDSColors.textMuted),
              ),
              const Gap(DDSSpacing.md),
              Text(
                'High-performance car rental platform with instant booking, zero security deposit, doorstep delivery, and 24/7 roadside assistance.',
                textAlign: TextAlign.center,
                style: DDSTypography.bodyMedium.copyWith(fontSize: 13, height: 1.4, color: DDSColors.textSecondary),
              ),
              const Gap(DDSSpacing.lg),
              const Divider(height: 1, color: DDSColors.borderLight),
              const Gap(DDSSpacing.sm),
              Text(
                '© 2026 DriveGo Technologies Inc.\nAll rights reserved.',
                textAlign: TextAlign.center,
                style: DDSTypography.labelSmall.copyWith(fontSize: 11, color: DDSColors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close', style: DDSTypography.labelLarge.copyWith(fontWeight: FontWeight.bold, color: DDSColors.primaryBlue)),
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
        shape: RoundedRectangleBorder(borderRadius: DDSRadius.largeBorderRadius),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DDSSpacing.xs),
              decoration: BoxDecoration(
                color: DDSColors.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency, color: DDSColors.errorRed, size: 24),
            ),
            const Gap(DDSSpacing.sm),
            Expanded(
              child: Text(
                'Emergency Roadside SOS',
                style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DriveGo Roadside Assistance provides real-time emergency dispatch for on-trip breakdowns, towing, flat tires, and accidents.',
              style: DDSTypography.bodyMedium.copyWith(fontSize: 13, height: 1.4, color: DDSColors.textSecondary),
            ),
            const Gap(DDSSpacing.md),
            Container(
              padding: const EdgeInsets.all(DDSSpacing.sm),
              decoration: BoxDecoration(
                color: DDSColors.surfaceCard,
                borderRadius: DDSRadius.mediumBorderRadius,
                border: Border.all(color: DDSColors.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, color: DDSColors.primaryBlue, size: 20),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      'For active trips, open your booking to dispatch technicians directly to your live GPS coordinates.',
                      style: DDSTypography.bodyMedium.copyWith(fontSize: 12, height: 1.3, color: DDSColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(DDSSpacing.sm),
            Container(
              padding: const EdgeInsets.all(DDSSpacing.sm),
              decoration: BoxDecoration(
                color: DDSColors.surfaceCard,
                borderRadius: DDSRadius.mediumBorderRadius,
                border: Border.all(color: DDSColors.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent, color: DDSColors.primaryBlue, size: 20),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      'For urgent account or trip support, raise an emergency ticket in the Help & Support Center.',
                      style: DDSTypography.bodyMedium.copyWith(fontSize: 12, height: 1.3, color: DDSColors.textPrimary),
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
            child: Text('Close', style: DDSTypography.labelLarge.copyWith(color: DDSColors.textSecondary)),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: DDSColors.infoBlueBg,
              foregroundColor: DDSColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: DDSRadius.mediumBorderRadius),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/support');
            },
            child: const Text('Support Center'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DDSColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: DDSRadius.mediumBorderRadius),
            ),
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
              const Icon(Icons.account_circle_outlined, size: 64, color: DDSColors.textMuted),
              const Gap(DDSSpacing.md),
              Text(
                'Not signed in',
                style: DDSTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold, color: DDSColors.textPrimary),
              ),
              const Gap(DDSSpacing.sm),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: DDSColors.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: DDSRadius.mediumBorderRadius),
                ),
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
        title: Text(
          'My Profile',
          style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.w700, color: DDSColors.textPrimary),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: DDSColors.primaryBlue),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditProfileBottomSheet(context, ref, user.name, user.email),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: DDSSpacing.md, vertical: DDSSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Modern Profile Hero Card ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(DDSSpacing.md),
              decoration: BoxDecoration(
                color: DDSColors.surfaceCard,
                borderRadius: DDSRadius.largeBorderRadius,
                border: Border.all(color: DDSColors.borderLight),
                boxShadow: DDSElevation.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: DDSColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(user.name),
                        style: DDSTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const Gap(DDSSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: DDSTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: DDSColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Gap(4),
                        Row(
                          children: [
                            const Icon(Icons.phone_android, size: 14, color: DDSColors.textSecondary),
                            const Gap(4),
                            Text(
                              user.phone,
                              style: DDSTypography.bodyMedium.copyWith(fontSize: 13, color: DDSColors.textSecondary),
                            ),
                          ],
                        ),
                        if (user.email != null && user.email!.isNotEmpty) ...[
                          const Gap(2),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 14, color: DDSColors.textSecondary),
                              const Gap(4),
                              Expanded(
                                child: Text(
                                  user.email!,
                                  style: DDSTypography.bodyMedium.copyWith(fontSize: 12, color: DDSColors.textSecondary),
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
                              color: DDSColors.surfaceCard,
                              borderRadius: DDSRadius.smallBorderRadius,
                              border: Border.all(color: DDSColors.borderLight),
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
            const Gap(DDSSpacing.md),

            // ── Account Health & Readiness Card ───────────────────────
            kycAsync.when(
              data: (kycData) {
                final status = (kycData['status'] as String? ?? 'NONE').toUpperCase();
                final isVerified = status == 'VERIFIED';
                final isPending = status == 'PENDING';
                final isRejected = status == 'REJECTED';

                return Container(
                  padding: const EdgeInsets.all(DDSSpacing.md),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? DDSColors.successGreenBg
                        : isPending
                            ? DDSColors.warningOrangeBg
                            : DDSColors.infoBlueBg,
                    borderRadius: DDSRadius.largeBorderRadius,
                    border: Border.all(
                      color: isVerified
                          ? DDSColors.successGreen.withValues(alpha: 0.3)
                          : isPending
                              ? DDSColors.warningOrange.withValues(alpha: 0.3)
                              : DDSColors.primaryBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isVerified
                            ? Icons.verified_user
                            : isPending
                                ? Icons.hourglass_top
                                : Icons.shield_outlined,
                        color: isVerified
                            ? DDSColors.successGreen
                            : isPending
                                ? DDSColors.warningOrange
                                : DDSColors.primaryBlue,
                        size: 24,
                      ),
                      const Gap(DDSSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isVerified
                                  ? 'Account Status: Fully Verified'
                                  : isPending
                                      ? 'Account Status: Verification Pending'
                                      : isRejected
                                          ? 'Account Status: Action Required'
                                          : 'Account Status: Verification Required',
                              style: DDSTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isVerified
                                    ? DDSColors.successGreen
                                    : isPending
                                        ? DDSColors.warningOrange
                                        : DDSColors.primaryBlue,
                              ),
                            ),
                            const Gap(2),
                            Text(
                              isVerified
                                  ? 'Your driving licence is authenticated. You can rent any vehicle instantly.'
                                  : isPending
                                      ? 'Documents are under administrative review. Approval usually takes under 30 mins.'
                                      : isRejected
                                          ? 'Your licence submission was rejected. Tap to view reason and retry.'
                                          : 'Upload your Driving Licence to unlock instant booking without trip delays.',
                              style: DDSTypography.bodyMedium.copyWith(
                                fontSize: 11,
                                color: DDSColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isVerified)
                        ElevatedButton(
                          onPressed: () => context.push('/kyc'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPending ? DDSColors.warningOrange : DDSColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: DDSRadius.smallBorderRadius),
                          ),
                          child: Text(
                            isPending ? 'View' : 'Verify',
                            style: DDSTypography.labelSmall.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const Gap(DDSSpacing.md),

            // ── Quick Stats & Rewards Bar ──────────────────────────────
            Row(
              children: [
                // Wallet Stat
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/wallet'),
                    borderRadius: DDSRadius.mediumBorderRadius,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: DDSSpacing.sm, horizontal: DDSSpacing.xs),
                      decoration: BoxDecoration(
                        color: DDSColors.surfaceCard,
                        borderRadius: DDSRadius.mediumBorderRadius,
                        border: Border.all(color: DDSColors.borderLight),
                        boxShadow: DDSElevation.cardShadow,
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, size: 20, color: DDSColors.primaryBlue),
                          const Gap(4),
                          walletAsync.when(
                            data: (w) => Text(
                              '₹${w.availableBalance.toInt()}',
                              style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            loading: () => const Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                            error: (_, __) => Text(
                              'Unavailable',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.error),
                            ),
                          ),
                          const Gap(2),
                          Text('Wallet', style: DDSTypography.labelSmall.copyWith(fontSize: 11, color: DDSColors.textMuted)),
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
                    borderRadius: DDSRadius.mediumBorderRadius,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: DDSSpacing.sm, horizontal: DDSSpacing.xs),
                      decoration: BoxDecoration(
                        color: DDSColors.surfaceCard,
                        borderRadius: DDSRadius.mediumBorderRadius,
                        border: Border.all(color: DDSColors.borderLight),
                        boxShadow: DDSElevation.cardShadow,
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.stars_outlined, size: 20, color: DDSColors.accentAmber),
                          const Gap(4),
                          loyaltyAsync.when(
                            data: (l) => Text(
                              '${l.pointsBalance} pts',
                              style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            loading: () => const Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                            error: (_, __) => Text(
                              'Unavailable',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.error),
                            ),
                          ),
                          const Gap(2),
                          Text('Club Rewards', style: DDSTypography.labelSmall.copyWith(fontSize: 11, color: DDSColors.textMuted)),
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
                    borderRadius: DDSRadius.mediumBorderRadius,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: DDSSpacing.sm, horizontal: DDSSpacing.xs),
                      decoration: BoxDecoration(
                        color: DDSColors.surfaceCard,
                        borderRadius: DDSRadius.mediumBorderRadius,
                        border: Border.all(color: DDSColors.borderLight),
                        boxShadow: DDSElevation.cardShadow,
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.card_giftcard_outlined, size: 20, color: Colors.purple),
                          const Gap(4),
                          referralAsync.when(
                            data: (_) => Text('₹250 Off', style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
                            loading: () => const Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                            error: (_, __) => Text(
                              'Unavailable',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.error),
                            ),
                          ),
                          const Gap(2),
                          Text('Refer & Earn', style: DDSTypography.labelSmall.copyWith(fontSize: 11, color: DDSColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Gap(DDSSpacing.lg),

            // ── Account & Verification Section ───────────────────────────
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
                    ? const Icon(Icons.check_circle, color: DDSColors.successGreen, size: 18)
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
            const Gap(DDSSpacing.md),

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
            const Gap(DDSSpacing.md),

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
              iconColor: DDSColors.errorRed,
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
            const Gap(DDSSpacing.xl),

            // ── Sign Out Button ───────────────────────────────────────
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, size: 18),
              label: Text('Sign Out', style: DDSTypography.labelLarge.copyWith(fontWeight: FontWeight.bold, color: DDSColors.errorRed)),
              onPressed: () => _showLogoutDialog(context, ref),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: DDSColors.errorRed.withValues(alpha: 0.4)),
                foregroundColor: DDSColors.errorRed,
                shape: RoundedRectangleBorder(borderRadius: DDSRadius.mediumBorderRadius),
              ),
            ),
            const Gap(DDSSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: DDSTypography.titleMedium.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: DDSColors.textSecondary,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: DDSColors.surfaceCard,
          borderRadius: DDSRadius.mediumBorderRadius,
          border: Border.all(color: DDSColors.borderLight),
          boxShadow: DDSElevation.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: DDSSpacing.md, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(DDSSpacing.xs),
              decoration: BoxDecoration(
                color: (iconColor ?? DDSColors.primaryBlue).withValues(alpha: 0.1),
                borderRadius: DDSRadius.smallBorderRadius,
              ),
              child: Icon(icon, color: iconColor ?? DDSColors.primaryBlue, size: 20),
            ),
            title: Text(
              title,
              style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 14, color: DDSColors.textPrimary),
            ),
            subtitle: subtitle != null
                ? Text(
                    subtitle,
                    style: DDSTypography.bodyMedium.copyWith(fontSize: 12, color: DDSColors.textMuted),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailingBadge != null) trailingBadge,
                const Gap(4),
                const Icon(Icons.chevron_right, size: 20, color: DDSColors.textMuted),
              ],
            ),
            onTap: onTap,
          ),
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
        bg = DDSColors.successGreenBg;
        fg = DDSColors.successGreen;
        label = 'Verified Driver';
        icon = Icons.verified;
        break;
      case 'PENDING':
        bg = DDSColors.warningOrangeBg;
        fg = DDSColors.warningOrange;
        label = 'KYC Under Review';
        icon = Icons.schedule;
        break;
      case 'REJECTED':
        bg = DDSColors.errorRedBg;
        fg = DDSColors.errorRed;
        label = 'KYC Rejected';
        icon = Icons.cancel_outlined;
        break;
      case 'EXPIRED':
        bg = DDSColors.warningOrangeBg;
        fg = DDSColors.warningOrange;
        label = 'Licence Expired';
        icon = Icons.warning_amber_rounded;
        break;
      default:
        bg = DDSColors.infoBlueBg;
        fg = DDSColors.primaryBlue;
        label = 'Verify Driving Licence';
        icon = Icons.badge_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DDSRadius.smallBorderRadius,
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const Gap(4),
          Text(
            label,
            style: DDSTypography.labelSmall.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
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
        borderRadius: DDSRadius.smallBorderRadius,
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

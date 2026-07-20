import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/session_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  // Initials from full name helper
  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  void _showEditProfileBottomSheet(BuildContext context, WidgetRef ref, String currentName, String? currentEmail) {
    final nameCtrl = TextEditingController(text: currentName);
    final emailCtrl = TextEditingController(text: currentEmail ?? '');
    final formKey = GlobalKey<FormState>();

    AppBottomSheet.show(
      context,
      title: 'Edit Profile',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Name',
                hint: 'Enter your name',
                controller: nameCtrl,
                prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const Gap(16),
              AppTextField(
                label: 'Email',
                hint: 'Enter your email',
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email address';
                  return null;
                },
              ),
              const Gap(24),
              AppButton(
                text: 'Save Changes',
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      await ref.read(sessionProvider.notifier).updateProfile(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
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
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out from the application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(sessionProvider.notifier).logout();
              context.go('/auth/phone');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not Authenticated')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar + Name Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      _getInitials(user.name),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Gap(16),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    user.phone,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (user.email != null && user.email!.isNotEmpty) ...[
                    const Gap(2),
                    Text(
                      user.email!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(32),

            // Profile Section List
            const Text(
              'Account',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const Gap(10),

            _menuTile(
              context,
              icon: Icons.person_outline,
              title: 'Edit Profile',
              onTap: () => _showEditProfileBottomSheet(context, ref, user.name, user.email),
            ),
            _menuTile(
              context,
              icon: Icons.location_on_outlined,
              title: 'Saved Addresses',
              onTap: () {
                _navigateToSubpage(
                  context,
                  title: 'Saved Addresses',
                  child: const _SavedAddressesSection(),
                );
              },
            ),
            _menuTile(
              context,
              icon: Icons.account_balance_wallet_outlined,
              title: 'Wallet & Credits',
              onTap: () {
                _navigateToSubpage(
                  context,
                  title: 'Wallet & Credits',
                  child: const _WalletSection(),
                );
              },
            ),

            const Gap(20),
            const Text(
              'Support & Info',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const Gap(10),

            _menuTile(
              context,
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                _navigateToSubpage(
                  context,
                  title: 'Help & Support',
                  child: const _HelpSupportSection(),
                );
              },
            ),
            _menuTile(
              context,
              icon: Icons.info_outline,
              title: 'About App',
              onTap: () {
                _navigateToSubpage(
                  context,
                  title: 'About App',
                  child: const _AboutSection(),
                );
              },
            ),

            const Gap(32),

            // Logout Button
            OutlinedButton(
              onPressed: () => _showLogoutDialog(context, ref),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: Colors.red),
                foregroundColor: Colors.red,
              ),
              child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
        ),
      ),
    );
  }

  void _navigateToSubpage(BuildContext context, {required String title, required Widget child}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: child,
        ),
      ),
    );
  }
}

// ── Saved Addresses Section ──────────────────────────────────────────────────
class _SavedAddressesSection extends StatelessWidget {
  const _SavedAddressesSection();

  @override
  Widget build(BuildContext context) {
    const addresses = [
      ('Home', '123, Sunrise Apartments, Bandra West, Mumbai, 400050'),
      ('Office', '5th Floor, Alpha Tech Park, BKC, Mumbai, 400051'),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final (label, details) = addresses[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  label == 'Home' ? Icons.home_outlined : Icons.work_outline,
                  color: AppColors.primary,
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const Gap(4),
                      Text(details, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Wallet Section ───────────────────────────────────────────────────────────
class _WalletSection extends StatelessWidget {
  const _WalletSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Gap(24),
          const Icon(
            Icons.account_balance_wallet,
            size: 80,
            color: AppColors.primary,
          ),
          const Gap(24),
          const Text(
            'Wallet Balance',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const Gap(8),
          const Text(
            '₹0',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Gap(32),
          Text(
            'Add money, view transaction history and more features are coming soon.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ── Help & Support FAQ Section ───────────────────────────────────────────────
class _HelpSupportSection extends StatelessWidget {
  const _HelpSupportSection();

  @override
  Widget build(BuildContext context) {
    const faqs = [
      ('How do I cancel my booking?', 'You can cancel any upcoming booking directly from the My Bookings list. Simply tap on the booking card, click "Cancel Booking", select your reason, and confirm.'),
      ('Are there any cancellation charges?', 'Cancellations made more than 24 hours before the trip start time are completely free. Inside 24 hours, a standard platform processing fee may apply.'),
      ('How is the fare calculated?', 'Fares include the package base rate per day, distance packages, platform fee, and GST. Tolls, parking, and fuel are to be settled directly as per trip type rules.'),
      ('How do I contact the vendor?', 'Once your booking is confirmed, the vendor will contact you directly to coordinate car dropoff and key handover. Support contact options are also visible on the booking details page.'),
      ('What documents do I need to present?', 'You must present a valid original Driving License (DL) and an Aadhaar/Govt ID card matching the booking name to the vendor during delivery.'),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: faqs.length,
      itemBuilder: (context, index) {
        final (q, a) = faqs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              title: Text(
                q,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              childrenPadding: const EdgeInsets.all(16),
              expandedAlignment: Alignment.topLeft,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── About App Section ────────────────────────────────────────────────────────
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Gap(24),
          // App Logo Placeholder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.directions_car_filled,
              size: 72,
              color: AppColors.primary,
            ),
          ),
          const Gap(24),
          const Text(
            'Car Rental Customer App',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          Text(
            'Version 1.0.0 (MVP)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const Gap(24),
          const Text(
            'Seamlessly search, compare, and book self-drive and chauffeur-driven cars. Powered by our high-performance Flutter melos monorepo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const Spacer(),
          Text(
            '© 2026 Antigravity Inc. All rights reserved.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
            ),
          ),
          const Gap(12),
        ],
      ),
    );
  }
}

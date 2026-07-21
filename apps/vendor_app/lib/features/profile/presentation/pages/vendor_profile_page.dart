import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../providers/profile_providers.dart';
import '../../domain/repositories/vendor_profile_repository.dart';

class VendorProfilePage extends ConsumerStatefulWidget {
  const VendorProfilePage({super.key});

  @override
  ConsumerState<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends ConsumerState<VendorProfilePage> {
  bool _editMode = false;
  bool _isSaving = false;

  late TextEditingController _businessNameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _panCtrl;
  String? _selectedCity;

  static const _cities = [
    'Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai',
    'Pune', 'Kolkata', 'Ahmedabad', 'Jaipur', 'Surat',
  ];

  static const _faqItems = [
    (
      'When will I receive my payout?',
      'Payouts are processed weekly every Wednesday. You will receive the net amount (total fare minus platform fee and GST) directly to your registered bank account.'
    ),
    (
      'How is platform commission calculated?',
      'Platform commission is typically 10% of the total fare. For luxury vehicles it is 12%, and for outstation trips it may be 8%. You can see the exact deduction on every completed booking.'
    ),
    (
      'Can I re-upload my documents?',
      'Yes. To re-upload RC Book, Trade License, or Insurance, please contact support at support@carrental.in or use the in-app chat. Document verification takes 1–2 business days.'
    ),
    (
      'How do I add a new car to my fleet?',
      'Go to the Fleet tab and tap the "+" button. Fill in the car details, add photos, set pricing, and submit. The car will be live after a quick review (usually within 24 hours).'
    ),
    (
      'How do I raise a dispute on a booking?',
      'On the Booking Detail page, scroll to the bottom and tap "Raise Dispute". Describe the issue and submit. Our support team will respond within 48 hours.'
    ),
  ];

  @override
  void initState() {
    super.initState();
    final vendor = ref.read(vendorSessionProvider).vendor;
    _businessNameCtrl = TextEditingController(text: vendor?.businessName ?? '');
    _ownerNameCtrl = TextEditingController(text: vendor?.ownerName ?? '');
    _phoneCtrl = TextEditingController(text: vendor?.phone ?? '');
    _emailCtrl = TextEditingController(text: vendor?.email ?? '');
    _gstCtrl = TextEditingController(text: vendor?.gstNumber ?? '');
    _panCtrl = TextEditingController(text: vendor?.panNumber ?? '');
    _selectedCity = vendor?.city;
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vendor = ref.read(vendorSessionProvider).vendor;
    if (vendor == null) return;

    setState(() => _isSaving = true);
    final updated = vendor.copyWith(
      businessName: _businessNameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
      panNumber: _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
      city: _selectedCity ?? vendor.city,
    );

    final updatedVendor = await ref.read(vendorProfileRepositoryProvider).updateBusinessProfile(updated);
    ref.read(vendorSessionProvider.notifier).authenticate(updatedVendor);

    if (mounted) {
      setState(() {
        _isSaving = false;
        _editMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(vendorSessionProvider.notifier).logout();
              context.go('/auth/phone');
            },
            child: Text('Logout', style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendor = ref.watch(vendorSessionProvider).vendor;
    if (vendor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    // Masked bank account
    final bank = vendor.bankDetails ?? '';
    final maskedBank = bank.length > 4
        ? '•••• ${bank.substring(bank.length - 4)}'
        : bank.isEmpty
            ? 'Not provided'
            : bank;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Profile & Settings'),
            actions: [
              if (!_editMode)
                TextButton.icon(
                  onPressed: () => setState(() => _editMode = true),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
              if (_editMode)
                TextButton.icon(
                  onPressed: () => setState(() => _editMode = false),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel'),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Avatar + business name hero ──────────────────────────
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          vendor.businessName.isNotEmpty ? vendor.businessName[0].toUpperCase() : 'V',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      const Gap(10),
                      Text(vendor.businessName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Gap(4),
                      StatusBadge(status: vendor.verificationStatus),
                    ],
                  ),
                ),
                const Gap(28),

                // ─── Business Profile ──────────────────────────────────────
                const SectionHeader(title: 'Business Profile'),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _editMode
                            ? AppTextField(
                                label: 'Business / Fleet Name',
                                controller: _businessNameCtrl,
                              )
                            : _InfoRow(label: 'Business Name', value: vendor.businessName),
                        const Divider(height: 24),
                        _editMode
                            ? AppTextField(
                                label: 'Owner Full Name',
                                controller: _ownerNameCtrl,
                              )
                            : _InfoRow(label: 'Owner Name', value: vendor.ownerName),
                        const Divider(height: 24),
                        _editMode
                            ? AppDropdown<String>(
                                label: 'City',
                                value: _selectedCity,
                                items: _cities
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedCity = v),
                              )
                            : _InfoRow(label: 'City', value: vendor.city),
                        const Divider(height: 24),
                        _editMode
                            ? AppTextField(
                                label: 'GST Number',
                                controller: _gstCtrl,
                              )
                            : _InfoRow(label: 'GST Number', value: vendor.gstNumber ?? 'Not provided'),
                        const Divider(height: 24),
                        _editMode
                            ? AppTextField(
                                label: 'PAN Number',
                                controller: _panCtrl,
                              )
                            : _InfoRow(label: 'PAN Number', value: vendor.panNumber ?? 'Not provided'),
                      ],
                    ),
                  ),
                ),
                const Gap(20),

                // ─── Contact Details ───────────────────────────────────────
                const SectionHeader(title: 'Contact Details'),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _editMode
                            ? AppTextField(label: 'Phone', controller: _phoneCtrl, keyboardType: TextInputType.phone)
                            : _InfoRow(label: 'Phone', value: vendor.phone.isEmpty ? 'Not provided' : vendor.phone),
                        const Divider(height: 24),
                        _editMode
                            ? AppTextField(label: 'Email', controller: _emailCtrl, keyboardType: TextInputType.emailAddress)
                            : _InfoRow(label: 'Email', value: vendor.email ?? 'Not provided'),
                      ],
                    ),
                  ),
                ),
                const Gap(20),

                // ─── Save button (edit mode) ───────────────────────────────
                if (_editMode) ...[
                  AppButton(
                    text: 'Save Changes',
                    onPressed: _isSaving ? null : _save,
                    isLoading: _isSaving,
                  ),
                  const Gap(20),
                ],

                // ─── Bank Details (view-only) ──────────────────────────────
                const SectionHeader(title: 'Bank Details'),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InfoRow(label: 'Account', value: maskedBank),
                        const Gap(12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                              const Gap(8),
                              const Expanded(
                                child: Text(
                                  'Contact support to update bank details.',
                                  style: TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(20),

                // ─── Documents Status ──────────────────────────────────────
                const SectionHeader(title: 'Documents'),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DocRow(
                          label: 'RC Book',
                          status: vendor.verificationStatus == 'verified' ? 'verified' : 'pending',
                        ),
                        const Divider(height: 24),
                        _DocRow(
                          label: 'Trade License',
                          status: vendor.verificationStatus == 'verified' ? 'verified' : 'pending',
                        ),
                        const Divider(height: 24),
                        _DocRow(
                          label: 'Insurance Certificate',
                          status: vendor.verificationStatus == 'verified' ? 'verified' : 'pending',
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(28),

                // ─── Help & Support (FAQ) ──────────────────────────────────
                const SectionHeader(title: 'Help & Support'),
                const Gap(12),
                AppCard(
                  child: Column(
                    children: _faqItems.map((item) {
                      return ExpansionTile(
                        title: Text(
                          item.$1,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              item.$2,
                              style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const Gap(28),

                // ─── Logout ────────────────────────────────────────────────
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
                const Gap(40),
              ],
            ),
          ),
        ),
        if (_isSaving)
          Container(
            color: Colors.black12,
            child: const Center(child: AppLoader()),
          ),
      ],
    );
  }
}

// ─── Helper widgets ─────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  final String label;
  final String status;
  const _DocRow({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.description_outlined, size: 18, color: Colors.grey),
            const Gap(10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ],
        ),
        StatusBadge(status: status),
      ],
    );
  }
}

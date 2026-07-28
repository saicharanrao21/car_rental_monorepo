import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../../../../core/providers/api_providers.dart';
import '../providers/profile_providers.dart';
import '../../domain/repositories/vendor_profile_repository.dart';
import '../../domain/document_expiry_utils.dart';
import '../../domain/vendor_document_model.dart';
import '../providers/documents_provider.dart';
import '../../../fleet/presentation/providers/fleet_providers.dart';

class VendorProfilePage extends ConsumerStatefulWidget {
  const VendorProfilePage({super.key});

  @override
  ConsumerState<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends ConsumerState<VendorProfilePage> {
  bool _editMode = false;
  bool _isSaving = false;
  bool _isLocating = false;

  late TextEditingController _businessNameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _panCtrl;
  late TextEditingController _localityCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
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
      'Yes. You can upload or update documents below including Trade License, RC Book, and Insurance with expiry dates.'
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
    _localityCtrl = TextEditingController(text: vendor?.locality ?? '');
    _latCtrl = TextEditingController(text: vendor?.latitude != null ? vendor!.latitude.toString() : '');
    _lngCtrl = TextEditingController(text: vendor?.longitude != null ? vendor!.longitude.toString() : '');
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
    _localityCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled on your device.')),
          );
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied.')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current GPS position captured successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
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
      locality: _localityCtrl.text.trim().isEmpty ? null : _localityCtrl.text.trim(),
      latitude: double.tryParse(_latCtrl.text.trim()),
      longitude: double.tryParse(_lngCtrl.text.trim()),
    );

    try {
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
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
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

  void _showUploadDocumentDialog() {
    String docType = 'TRADE_LICENSE';
    DateTime? selectedExpiryDate;
    final fileUrlCtrl = TextEditingController(text: 'https://storage.drivego.in/docs/${DateTime.now().millisecondsSinceEpoch}.pdf');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Upload Document'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Document Type', border: OutlineInputBorder()),
                  value: docType,
                  items: const [
                    DropdownMenuItem(value: 'TRADE_LICENSE', child: Text('Trade License (Vendor Level)')),
                    DropdownMenuItem(value: 'RC_BOOK', child: Text('RC Book')),
                    DropdownMenuItem(value: 'INSURANCE', child: Text('Insurance Policy')),
                  ],
                  onChanged: (v) => setDialogState(() => docType = v!),
                ),
                const Gap(16),
                AppTextField(
                  label: 'Document File URL / Path',
                  controller: fileUrlCtrl,
                ),
                const Gap(16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedExpiryDate == null
                            ? 'No Expiry Date Set'
                            : 'Expiry: ${DateFormat('dd MMM yyyy').format(selectedExpiryDate!)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: selectedExpiryDate != null ? Colors.black87 : Colors.grey[600],
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedExpiryDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: const Text('Select Date'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final apiClient = ref.read(apiClientProvider);
                try {
                  await apiClient.dio.post('/vendors/me/documents', data: {
                    'type': docType,
                    'fileUrl': fileUrlCtrl.text.trim(),
                    if (selectedExpiryDate != null)
                      'expiresAt': selectedExpiryDate!.toUtc().toIso8601String(),
                  });
                  ref.invalidate(vendorDocumentsProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Document uploaded successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to upload document: $e')),
                    );
                  }
                }
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendor = ref.watch(vendorSessionProvider).vendor;
    final docsAsync = ref.watch(vendorDocumentsProvider);

    if (vendor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Not logged in')),
      );
    }

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
                // Avatar + business name
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

                // Business Profile
                const SectionHeader(title: 'Business Profile & Location'),
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
                                label: 'Locality / Area',
                                hint: 'e.g. Andheri East, Koramangala',
                                controller: _localityCtrl,
                              )
                            : _InfoRow(label: 'Locality', value: vendor.locality ?? 'Not set'),
                        const Divider(height: 24),
                        if (_editMode) ...[
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'Latitude',
                                  hint: '19.0760',
                                  controller: _latCtrl,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const Gap(12),
                              Expanded(
                                child: AppTextField(
                                  label: 'Longitude',
                                  hint: '72.8777',
                                  controller: _lngCtrl,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const Gap(12),
                          OutlinedButton.icon(
                            onPressed: _isLocating ? null : _getCurrentLocation,
                            icon: _isLocating
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.my_location, size: 18),
                            label: const Text('Use my current location'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ] else ...[
                          _InfoRow(
                            label: 'GPS Location',
                            value: (vendor.latitude != null && vendor.longitude != null)
                                ? '${vendor.latitude!.toStringAsFixed(4)}, ${vendor.longitude!.toStringAsFixed(4)}'
                                : 'Not set',
                          ),
                        ],
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

                // Contact Details
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

                // Save button (edit mode)
                if (_editMode) ...[
                  AppButton(
                    text: 'Save Changes',
                    onPressed: _isSaving ? null : _save,
                    isLoading: _isSaving,
                  ),
                  const Gap(20),
                ],

                // Bank Details
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

                // Documents Status & Management
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SectionHeader(title: 'Documents'),
                    TextButton.icon(
                      onPressed: _showUploadDocumentDialog,
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Upload Doc'),
                    ),
                  ],
                ),
                const Gap(8),
                docsAsync.when(
                  loading: () => const AppCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: AppLoader()),
                    ),
                  ),
                  error: (err, _) => AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Failed to load documents: $err'),
                    ),
                  ),
                  data: (docs) {
                    if (docs.isEmpty) {
                      return AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text('No uploaded documents yet.', style: TextStyle(color: Colors.grey)),
                              const Gap(12),
                              ElevatedButton.icon(
                                onPressed: _showUploadDocumentDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Upload First Document'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: docs.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final doc = entry.value;
                            final expiry = checkDocumentExpiry(doc.expiresAt);

                            return Column(
                              children: [
                                if (idx > 0) const Divider(height: 24),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.description_outlined, size: 20, color: Colors.grey),
                                    const Gap(10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doc.type.replaceAll('_', ' '),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          if (doc.expiresAt != null)
                                            Text(
                                              'Expires: ${DateFormat('dd MMM yyyy').format(doc.expiresAt!)}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        StatusBadge(status: doc.status.toLowerCase()),
                                        if (expiry != null) ...[
                                          const Gap(4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: expiry.isExpired ? Colors.red[100] : Colors.amber[100],
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: expiry.isExpired ? Colors.red : Colors.amber[800]!,
                                              ),
                                            ),
                                            child: Text(
                                              expiry.badgeText,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: expiry.isExpired ? Colors.red[900] : Colors.amber[900],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
                const Gap(28),

                // Help & Support
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

                // Logout
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

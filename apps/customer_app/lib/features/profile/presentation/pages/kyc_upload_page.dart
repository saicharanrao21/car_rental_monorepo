import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/api_providers.dart';

final kycStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/kyc/status');
  return response.data as Map<String, dynamic>;
});

class KycUploadPage extends ConsumerStatefulWidget {
  const KycUploadPage({super.key});

  @override
  ConsumerState<KycUploadPage> createState() => _KycUploadPageState();
}

class _KycUploadPageState extends ConsumerState<KycUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _dlCtrl = TextEditingController();
  final _frontUrlCtrl = TextEditingController();
  final _backUrlCtrl = TextEditingController();
  DateTime? _expiryDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _dlCtrl.dispose();
    _frontUrlCtrl.dispose();
    _backUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitKyc() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select licence expiry date'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.post('/kyc/submit', data: {
        'licenceNumber': _dlCtrl.text.trim(),
        'expiryDate': _expiryDate!.toIso8601String(),
        'licenceFrontUrl': _frontUrlCtrl.text.trim(),
        'licenceBackUrl': _backUrlCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC documents submitted successfully! Admin review pending.'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(kycStatusProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting KYC: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycAsync = ref.watch(kycStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Driving Licence (KYC)')),
      body: kycAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Failed to load KYC status: $err')),
        data: (data) {
          final status = data['status'] as String? ?? 'NONE';
          final kyc = data['kyc'] as Map<String, dynamic>?;

          if (kyc != null && _dlCtrl.text.isEmpty) {
            _dlCtrl.text = kyc['licenceNumber'] ?? '';
            _frontUrlCtrl.text = kyc['licenceFrontUrl'] ?? '';
            _backUrlCtrl.text = kyc['licenceBackUrl'] ?? '';
            if (kyc['expiryDate'] != null) {
              _expiryDate = DateTime.tryParse(kyc['expiryDate']);
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusBanner(context, status, kyc),
                const Gap(24),
                if (status == 'NONE' || status == 'REJECTED' || status == 'EXPIRED' || status == 'PENDING') ...[
                  Text(
                    status == 'PENDING' ? 'Update KYC Submission' : 'Submit Driving Licence Verification',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Gap(16),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: 'Driving Licence Number',
                          hint: 'e.g. DL1420110012345',
                          controller: _dlCtrl,
                          prefixIcon: Icon(Icons.badge_outlined, color: Theme.of(context).primaryColor),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Licence number required' : null,
                        ),
                        const Gap(16),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setState(() => _expiryDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Licence Expiry Date',
                              prefixIcon: Icon(Icons.calendar_today_outlined, color: Theme.of(context).primaryColor),
                              border: const OutlineInputBorder(),
                            ),
                            child: Text(
                              _expiryDate != null
                                  ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                                  : 'Select Expiry Date',
                              style: TextStyle(
                                color: _expiryDate != null
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const Gap(16),
                        AppTextField(
                          label: 'Front Licence Image URL',
                          hint: 'https://storage.drivego.in/dl_front.jpg',
                          controller: _frontUrlCtrl,
                          prefixIcon: Icon(Icons.image_outlined, color: Theme.of(context).primaryColor),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Front image URL required' : null,
                        ),
                        const Gap(16),
                        AppTextField(
                          label: 'Back Licence Image URL',
                          hint: 'https://storage.drivego.in/dl_back.jpg',
                          controller: _backUrlCtrl,
                          prefixIcon: Icon(Icons.image_outlined, color: Theme.of(context).primaryColor),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Back image URL required' : null,
                        ),
                        const Gap(24),
                        AppButton(
                          text: _isSubmitting ? 'Submitting...' : 'Submit Verification',
                          onPressed: _isSubmitting ? null : _submitKyc,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, String status, Map<String, dynamic>? kyc) {
    Color color;
    IconData icon;
    String title;
    String description;

    switch (status) {
      case 'VERIFIED':
        color = Colors.green;
        icon = Icons.verified;
        title = 'Identity Verified';
        description = 'Your driving licence has been verified. You are eligible for all vehicle rentals!';
        break;
      case 'PENDING':
        color = Colors.orange;
        icon = Icons.hourglass_top;
        title = 'Verification Pending';
        description = 'Your KYC documents are under review by our verification team.';
        break;
      case 'REJECTED':
        color = Colors.red;
        icon = Icons.error_outline;
        title = 'Verification Rejected';
        final reason = kyc?['rejectionReason'] as String? ?? 'Documents did not meet criteria';
        description = 'Reason: $reason. Please re-submit valid licence documents.';
        break;
      case 'EXPIRED':
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        title = 'Licence Expired';
        description = 'Your driving licence on record has expired. Please upload updated licence.';
        break;
      default:
        color = Theme.of(context).primaryColor;
        icon = Icons.info_outline;
        title = 'Verification Required';
        description = 'Upload your Driving Licence to complete account KYC for hassle-free trip handovers.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                const Gap(4),
                Text(description, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

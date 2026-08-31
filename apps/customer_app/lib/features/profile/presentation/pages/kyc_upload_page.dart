import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
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

  String _maskLicenceNumber(String raw) {
    if (raw.length <= 4) return raw;
    final last4 = raw.substring(raw.length - 4);
    final prefix = raw.length > 6 ? raw.substring(0, 2) : '';
    return '$prefix••••••••$last4';
  }

  Future<void> _submitKyc() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select licence expiry date'),
          backgroundColor: DDSColors.errorRed,
        ),
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
            backgroundColor: DDSColors.successGreen,
          ),
        );
        ref.invalidate(kycStatusProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting KYC: $e'),
            backgroundColor: DDSColors.errorRed,
          ),
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
      appBar: AppBar(
        title: Text(
          'Driving Licence (KYC)',
          style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: kycAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(DDSSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: DDSColors.errorRed),
                const Gap(DDSSpacing.sm),
                Text(
                  'Failed to load KYC status: $err',
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
                  onPressed: () => ref.invalidate(kycStatusProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
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
            padding: const EdgeInsets.all(DDSSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusBanner(context, status, kyc),
                const Gap(DDSSpacing.lg),
                if (status == 'NONE' || status == 'REJECTED' || status == 'EXPIRED' || status == 'PENDING') ...[
                  Text(
                    status == 'PENDING' ? 'Update KYC Submission' : 'Submit Driving Licence Verification',
                    style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: DDSColors.textPrimary),
                  ),
                  const Gap(4),
                  Text(
                    'As per Indian transport regulations, valid Driving Licence verification is required prior to vehicle delivery.',
                    style: DDSTypography.bodyMedium.copyWith(fontSize: 12, color: DDSColors.textSecondary),
                  ),
                  const Gap(DDSSpacing.md),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: 'Driving Licence Number',
                          hint: 'e.g. DL1420110012345',
                          controller: _dlCtrl,
                          prefixIcon: const Icon(Icons.badge_outlined, color: DDSColors.primaryBlue),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Licence number required' : null,
                        ),
                        const Gap(DDSSpacing.md),
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
                          borderRadius: DDSRadius.mediumBorderRadius,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Licence Expiry Date',
                              prefixIcon: const Icon(Icons.calendar_today_outlined, color: DDSColors.primaryBlue),
                              border: OutlineInputBorder(borderRadius: DDSRadius.mediumBorderRadius),
                            ),
                            child: Text(
                              _expiryDate != null
                                  ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                                  : 'Select Expiry Date',
                              style: DDSTypography.bodyMedium.copyWith(
                                color: _expiryDate != null
                                    ? DDSColors.textPrimary
                                    : DDSColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                        const Gap(DDSSpacing.md),
                        AppTextField(
                          label: 'Front Licence Image URL',
                          hint: 'https://storage.drivego.in/dl_front.jpg',
                          controller: _frontUrlCtrl,
                          prefixIcon: const Icon(Icons.image_outlined, color: DDSColors.primaryBlue),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Front image URL required' : null,
                        ),
                        const Gap(DDSSpacing.md),
                        AppTextField(
                          label: 'Back Licence Image URL',
                          hint: 'https://storage.drivego.in/dl_back.jpg',
                          controller: _backUrlCtrl,
                          prefixIcon: const Icon(Icons.image_outlined, color: DDSColors.primaryBlue),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Back image URL required' : null,
                        ),
                        const Gap(DDSSpacing.xl),
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
    Color bg;
    Color border;
    Color fg;
    IconData icon;
    String title;
    String description;

    switch (status) {
      case 'VERIFIED':
        bg = DDSColors.successGreenBg;
        border = DDSColors.successGreen.withValues(alpha: 0.3);
        fg = DDSColors.successGreen;
        icon = Icons.verified;
        title = 'Identity Verified';
        final maskedDl = kyc?['licenceNumber'] != null ? _maskLicenceNumber(kyc!['licenceNumber']) : '';
        description = 'Your driving licence ($maskedDl) has been verified. You are eligible for all vehicle rentals!';
        break;
      case 'PENDING':
        bg = DDSColors.warningOrangeBg;
        border = DDSColors.warningOrange.withValues(alpha: 0.3);
        fg = DDSColors.warningOrange;
        icon = Icons.hourglass_top;
        title = 'Verification Pending';
        description = 'Your KYC documents are under review by our verification team.';
        break;
      case 'REJECTED':
        bg = DDSColors.errorRedBg;
        border = DDSColors.errorRed.withValues(alpha: 0.3);
        fg = DDSColors.errorRed;
        icon = Icons.error_outline;
        title = 'Verification Rejected';
        final reason = kyc?['rejectionReason'] as String? ?? 'Documents did not meet criteria';
        description = 'Reason: $reason. Please re-submit valid licence documents.';
        break;
      case 'EXPIRED':
        bg = DDSColors.errorRedBg;
        border = DDSColors.errorRed.withValues(alpha: 0.3);
        fg = DDSColors.errorRed;
        icon = Icons.warning_amber_rounded;
        title = 'Licence Expired';
        description = 'Your driving licence on record has expired. Please upload updated licence.';
        break;
      default:
        bg = DDSColors.infoBlueBg;
        border = DDSColors.primaryBlue.withValues(alpha: 0.3);
        fg = DDSColors.primaryBlue;
        icon = Icons.info_outline;
        title = 'Verification Required';
        description = 'Upload your Driving Licence to complete account KYC for hassle-free trip handovers.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(DDSSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DDSRadius.largeBorderRadius,
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 28),
          const Gap(DDSSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 16, color: fg)),
                const Gap(4),
                Text(description, style: DDSTypography.bodyMedium.copyWith(fontSize: 13, color: DDSColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';
import '../../../profile/presentation/pages/kyc_upload_page.dart';

class BookingCustomerForm extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;

  const BookingCustomerForm({
    super.key,
    required this.formKey,
  });

  @override
  ConsumerState<BookingCustomerForm> createState() =>
      _BookingCustomerFormState();
}

class _BookingCustomerFormState extends ConsumerState<BookingCustomerForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider);
    _nameCtrl = TextEditingController(text: draft.contactName);
    _phoneCtrl = TextEditingController(text: draft.contactPhone);
    _nameCtrl.addListener(() {
      ref.read(bookingDraftProvider.notifier).update(
            (d) => d.copyWith(contactName: _nameCtrl.text),
          );
    });
    _phoneCtrl.addListener(() {
      ref.read(bookingDraftProvider.notifier).update(
            (d) => d.copyWith(contactPhone: _phoneCtrl.text),
          );
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kycAsync = ref.watch(kycStatusProvider);

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Contact Details Card ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(DDSSpacing.md),
            decoration: BoxDecoration(
              color: DDSColors.surfaceCard,
              borderRadius: DDSRadius.largeBorderRadius,
              border: const Border.fromBorderSide(
                BorderSide(color: DDSColors.borderLight),
              ),
              boxShadow: DDSElevation.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: DDSColors.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: DDSColors.primaryBlue,
                        size: 18,
                      ),
                    ),
                    const Gap(DDSSpacing.xs),
                    Text(
                      'Primary Driver Details',
                      style: DDSTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DDSColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Text(
                  'Trip confirmation and vehicle handover verification are issued to this driver.',
                  style: DDSTypography.bodyMedium.copyWith(
                    color: DDSColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const Gap(DDSSpacing.md),

                // Name field
                AppTextField(
                  label: 'Full Name (as on Driving Licence)',
                  hint: 'Enter your full legal name',
                  controller: _nameCtrl,
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                    color: DDSColors.primaryBlue,
                    size: 20,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const Gap(DDSSpacing.md),

                // Phone field
                AppTextField(
                  label: 'Mobile Number',
                  hint: '10-digit mobile number',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    color: DDSColors.primaryBlue,
                    size: 20,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Mobile number is required';
                    }
                    if (v.trim().length < 10) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const Gap(DDSSpacing.md),

          // ── KYC Status Card ───────────────────────────────────────
          kycAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => _buildKycCard(status: 'NOT_SUBMITTED'),
            data: (data) {
              final status = (data['status'] as String?)?.toUpperCase() ?? 'NOT_SUBMITTED';
              return _buildKycCard(status: status);
            },
          ),
          const Gap(DDSSpacing.md),

          // ── Handover Requirement Notice ───────────────────────────
          Container(
            padding: const EdgeInsets.all(DDSSpacing.md),
            decoration: BoxDecoration(
              color: DDSColors.infoBlueBg,
              borderRadius: DDSRadius.largeBorderRadius,
              border: Border.all(
                color: DDSColors.primaryBlue.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: DDSColors.primaryBlue,
                  size: 20,
                ),
                const Gap(DDSSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Document Inspection at Handover',
                        style: DDSTypography.titleMedium.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: DDSColors.primaryBlue,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        'Please carry your original physical Driving Licence and Aadhaar/Passport during vehicle pickup.',
                        style: DDSTypography.bodyMedium.copyWith(
                          fontSize: 11,
                          color: DDSColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKycCard({required String status}) {
    Color badgeBg;
    Color badgeFg;
    String badgeText;
    IconData icon;
    String description;
    bool showAction = false;

    switch (status) {
      case 'APPROVED':
        badgeBg = DDSColors.successGreenBg;
        badgeFg = DDSColors.successGreen;
        badgeText = 'VERIFIED';
        icon = Icons.check_circle_outline;
        description = 'Driving licence verified. Ready for seamless vehicle handover.';
        break;
      case 'PENDING':
        badgeBg = DDSColors.warningOrangeBg;
        badgeFg = DDSColors.warningOrange;
        badgeText = 'UNDER REVIEW';
        icon = Icons.hourglass_top_outlined;
        description = 'Documents uploaded and currently under verification by operations team.';
        break;
      case 'REJECTED':
        badgeBg = DDSColors.errorRedBg;
        badgeFg = DDSColors.errorRed;
        badgeText = 'ACTION REQUIRED';
        icon = Icons.error_outline;
        description = 'Document verification failed. Please re-upload clear photos of your Driving Licence.';
        showAction = true;
        break;
      default:
        badgeBg = DDSColors.warningOrangeBg;
        badgeFg = DDSColors.warningOrange;
        badgeText = 'PENDING UPLOAD';
        icon = Icons.info_outline;
        description = 'Upload your Driving Licence now to expedite vehicle pickup.';
        showAction = true;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(DDSSpacing.md),
      decoration: BoxDecoration(
        color: DDSColors.surfaceCard,
        borderRadius: DDSRadius.largeBorderRadius,
        border: const Border.fromBorderSide(
          BorderSide(color: DDSColors.borderLight),
        ),
        boxShadow: DDSElevation.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: badgeFg),
                  const Gap(DDSSpacing.xs),
                  Text(
                    'Driver KYC Status',
                    style: DDSTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: DDSColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: DDSRadius.smallBorderRadius,
                ),
                child: Text(
                  badgeText,
                  style: DDSTypography.labelSmall.copyWith(
                    color: badgeFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Gap(DDSSpacing.xs),
          Text(
            description,
            style: DDSTypography.bodyMedium.copyWith(
              color: DDSColors.textMuted,
              fontSize: 12,
            ),
          ),
          if (showAction) ...[
            const Gap(DDSSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.push('/kyc/upload'),
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Upload Driving Licence'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: DDSRadius.mediumBorderRadius,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

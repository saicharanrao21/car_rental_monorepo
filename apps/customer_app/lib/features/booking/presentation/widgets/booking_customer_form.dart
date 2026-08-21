import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';

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
    final cs = Theme.of(context).colorScheme;

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Contact Details Card ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const Gap(10),
                    Text(
                      'Primary Contact Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Text(
                  'Trip confirmation and driver handover details will be sent here.',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Gap(16),

                // Name field
                AppTextField(
                  label: 'Full Name',
                  hint: 'Enter your full name as on ID',
                  controller: _nameCtrl,
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const Gap(14),

                // Phone field
                AppTextField(
                  label: 'Mobile Number',
                  hint: '10-digit mobile number',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    color: AppColors.primary,
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
          const Gap(14),

          // ── KYC & License Notice ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: Colors.blueAccent,
                  size: 20,
                ),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Document Verification at Handover',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        'Please carry your original Driving Licence and Aadhaar/Passport during vehicle handover.',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
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
}

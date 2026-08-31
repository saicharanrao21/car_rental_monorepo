import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'booking_customer_form.dart';

class ContactConfirmStep extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const ContactConfirmStep({
    super.key,
    required this.formKey,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(DDSSpacing.md, DDSSpacing.md, DDSSpacing.md, DDSSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Confirm your contact details. The host and driver will coordinate vehicle handover with you.',
            style: DDSTypography.bodyMedium.copyWith(
              color: DDSColors.textSecondary,
              height: 1.4,
              fontSize: 12,
            ),
          ),
          const Gap(DDSSpacing.md),

          BookingCustomerForm(formKey: formKey),
        ],
      ),
    );
  }
}

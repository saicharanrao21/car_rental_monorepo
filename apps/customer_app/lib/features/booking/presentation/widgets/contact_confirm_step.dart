import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Confirm your contact details. The host and driver will coordinate vehicle handover with you.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const Gap(16),

          BookingCustomerForm(formKey: formKey),
        ],
      ),
    );
  }
}

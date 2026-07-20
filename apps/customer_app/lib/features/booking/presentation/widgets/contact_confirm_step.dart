import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/booking_flow_providers.dart';

class ContactConfirmStep extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;

  const ContactConfirmStep({super.key, required this.onBack, required this.onNext});

  @override
  ConsumerState<ContactConfirmStep> createState() => _ContactConfirmStepState();
}

class _ContactConfirmStepState extends ConsumerState<ContactConfirmStep> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider);
    _nameCtrl = TextEditingController(text: draft.contactName);
    _phoneCtrl = TextEditingController(text: draft.contactPhone);
    _nameCtrl.addListener(() {
      ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(contactName: _nameCtrl.text));
    });
    _phoneCtrl.addListener(() {
      ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(contactPhone: _phoneCtrl.text));
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
    final draft = ref.watch(bookingDraftProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Confirm your contact details. The vendor will reach you at the number below.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Gap(20),

            AppTextField(
              label: 'Full Name',
              hint: 'Enter your name',
              controller: _nameCtrl,
              prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const Gap(16),

            AppTextField(
              label: 'Mobile Number',
              hint: '10-digit mobile number',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone is required';
                if (v.trim().length < 10) return 'Enter a valid 10-digit number';
                return null;
              },
            ),
            const Gap(20),

            // Fare summary reminder
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Payable',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  PriceTag(
                    amount: draft.totalFare,
                    amountStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const Gap(24),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text('Back', style: TextStyle(color: AppColors.primary)),
                ),
              ),
              const Gap(12),
              Expanded(
                child: AppButton(
                  text: 'Next: Payment',
                  onPressed: () {
                    if (_formKey.currentState!.validate()) widget.onNext();
                  },
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

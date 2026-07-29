import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import '../providers/auth_providers.dart';

class PhoneEntryPage extends ConsumerStatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  ConsumerState<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends ConsumerState<PhoneEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController(text: '9876543210');
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _errorMessage = null;
    });

    final phone = _phoneController.text.trim();
    final success = await ref.read(authControllerProvider.notifier).sendOtp(phone);

    if (success && mounted) {
      context.go('/auth/otp?phone=$phone');
    } else if (mounted) {
      final authState = ref.read(authControllerProvider);
      setState(() {
        _errorMessage = authState.error?.toString() ?? 'Failed to send OTP. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Verify Phone',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(8),
                Text(
                  'Enter your 10-digit mobile number to proceed.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(32),
                AppTextField(
                  label: 'Phone Number',
                  hint: '98765 43210',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone number is required';
                    }
                    if (value.replaceAll(RegExp(r'\D'), '').length != 10) {
                      return 'Enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const Gap(16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ],
                const Spacer(),
                AppButton(
                  text: 'Send OTP',
                  onPressed: isLoading ? null : _submit,
                  isLoading: isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

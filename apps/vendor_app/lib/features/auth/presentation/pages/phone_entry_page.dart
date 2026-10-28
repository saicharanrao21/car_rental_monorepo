import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/vendor_auth_providers.dart';

class PhoneEntryPage extends ConsumerStatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  ConsumerState<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends ConsumerState<PhoneEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
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
    final success = await ref.read(vendorAuthControllerProvider.notifier).sendOtp(phone);

    if (success && mounted) {
      context.go('/auth/otp?phone=$phone');
    } else if (mounted) {
      final authState = ref.read(vendorAuthControllerProvider);
      setState(() {
        _errorMessage = authState.error?.toString() ?? 'Failed to send OTP. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(vendorAuthControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: DDSColors.bgCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: DDSColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Partner Brand Header
                const Center(
                  child: DriveGoBrandMark(
                    size: 64,
                    isVendor: true,
                    showWordmark: true,
                  ),
                ),
                const Gap(32),

                Text(
                  'Partner Verification',
                  style: DDSTypography.headlineLarge.copyWith(
                    color: DDSColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(8),
                Text(
                  'Enter your 10-digit mobile number to access your fleet operations dashboard or register a new business.',
                  style: DDSTypography.bodyMedium.copyWith(
                    color: DDSColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(32),

                DriveGoCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business Mobile Number',
                        style: DDSTypography.labelLarge.copyWith(
                          color: DDSColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(10),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: DDSTypography.bodyLarge.copyWith(
                          color: DDSColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: '98765 43210',
                          hintStyle: DDSTypography.bodyLarge.copyWith(
                            color: DDSColors.textMuted,
                          ),
                          filled: true,
                          fillColor: DDSColors.surfaceSubtle,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          prefixIcon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: DDSColors.borderLight, width: 1.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  '+91',
                                  style: DDSTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: DDSColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: DDSRadius.mediumBorderRadius,
                            borderSide: const BorderSide(color: DDSColors.borderMedium),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: DDSRadius.mediumBorderRadius,
                            borderSide: const BorderSide(color: DDSColors.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: DDSRadius.mediumBorderRadius,
                            borderSide: const BorderSide(color: DDSColors.primaryBlue, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: DDSRadius.mediumBorderRadius,
                            borderSide: const BorderSide(color: DDSColors.errorRed),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Mobile number is required';
                          }
                          final digits = value.replaceAll(RegExp(r'\D'), '');
                          if (digits.length != 10) {
                            return 'Enter a valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const Gap(12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: DDSColors.errorRedBg,
                            borderRadius: DDSRadius.smallBorderRadius,
                            border: Border.all(color: DDSColors.errorRed.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: DDSColors.errorRed, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: DDSTypography.bodySmall.copyWith(
                                    color: DDSColors.errorRed,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Gap(24),
                      DriveGoButton(
                        text: 'Send OTP Verification',
                        onPressed: isLoading ? null : _submit,
                        isLoading: isLoading,
                        size: DriveGoButtonSize.large,
                      ),
                    ],
                  ),
                ),
                const Gap(32),

                // Partner Help / Trust Note
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_outlined, size: 18, color: DDSColors.accentTeal),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Dedicated to registered fleet owners and car hosts',
                          style: DDSTypography.bodySmall.copyWith(
                            color: DDSColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

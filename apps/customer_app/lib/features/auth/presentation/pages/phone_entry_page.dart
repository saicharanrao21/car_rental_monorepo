import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../providers/auth_providers.dart';

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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _errorMessage = null;
    });
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) return;
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        setState(() {
          _errorMessage = 'Failed to obtain Google ID token.';
        });
        return;
      }
      final user = await ref.read(authControllerProvider.notifier).signInWithGoogle(idToken);
      if (user != null && mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        _showProviderUnavailableDialog(
          providerName: 'Google Sign-In',
          technicalDetail: e.toString(),
        );
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _errorMessage = null;
    });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null) {
        setState(() {
          _errorMessage = 'Failed to obtain Apple identity token.';
        });
        return;
      }
      final fullName = [credential.givenName, credential.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      final user = await ref.read(authControllerProvider.notifier).signInWithApple(
        identityToken,
        fullName: fullName.isNotEmpty ? fullName : null,
      );
      if (user != null && mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        _showProviderUnavailableDialog(
          providerName: 'Apple Sign-In',
          technicalDetail: e.toString(),
        );
      }
    }
  }

  void _showProviderUnavailableDialog({
    required String providerName,
    required String technicalDetail,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DDSColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: DDSRadius.largeBorderRadius),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: DDSColors.primaryBlue),
            const SizedBox(width: 10),
            Text(
              '$providerName Setup',
              style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$providerName requires production Google Play Services credentials configured for this device environment.',
              style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'For developer verification and testing, please sign in securely with your 10-digit mobile number and OTP.',
              style: DDSTypography.bodySmall.copyWith(color: DDSColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Understood',
              style: DDSTypography.labelLarge.copyWith(color: DDSColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: DDSColors.bgCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header
                const Center(
                  child: DriveGoBrandMark(
                    size: 64,
                    showWordmark: true,
                  ),
                ),
                const Gap(32),

                // Welcome Headings
                Text(
                  'Welcome to DriveGo',
                  style: DDSTypography.headlineLarge.copyWith(
                    color: DDSColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(8),
                Text(
                  'Enter your 10-digit mobile number to verify your identity and start exploring premium rentals.',
                  style: DDSTypography.bodyMedium.copyWith(
                    color: DDSColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(32),

                // Phone Input Card
                DriveGoCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mobile Number',
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
                            return 'Phone number is required';
                          }
                          final digits = value.replaceAll(RegExp(r'\D'), '');
                          if (digits.length != 10) {
                            return 'Please enter a valid 10-digit mobile number';
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
                      const Gap(20),
                      DriveGoButton(
                        text: 'Continue with Phone',
                        onPressed: isLoading ? null : _submit,
                        isLoading: isLoading,
                        size: DriveGoButtonSize.large,
                      ),
                    ],
                  ),
                ),
                const Gap(24),

                // Social Auth Divider
                Row(
                  children: [
                    const Expanded(child: Divider(color: DDSColors.borderLight, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR CONTINUE WITH',
                        style: DDSTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: DDSColors.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: DDSColors.borderLight, thickness: 1)),
                  ],
                ),
                const Gap(20),

                // Platform Social Buttons
                SocialAuthButton.google(
                  onPressed: isLoading ? null : _signInWithGoogle,
                  isLoading: false,
                ),
                const Gap(12),
                SocialAuthButton.apple(
                  onPressed: isLoading ? null : _signInWithApple,
                  isLoading: false,
                ),
                const Gap(32),

                // Legal Disclaimers
                Center(
                  child: Text.rich(
                    TextSpan(
                      text: 'By continuing, you agree to our ',
                      style: DDSTypography.bodySmall.copyWith(color: DDSColors.textSecondary),
                      children: [
                        TextSpan(
                          text: 'Terms of Service',
                          style: DDSTypography.bodySmall.copyWith(
                            color: DDSColors.primaryBlue,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: DDSTypography.bodySmall.copyWith(
                            color: DDSColors.primaryBlue,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
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

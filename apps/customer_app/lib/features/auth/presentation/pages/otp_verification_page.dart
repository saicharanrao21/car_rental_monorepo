import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/auth_providers.dart';

class OtpVerificationPage extends ConsumerStatefulWidget {
  final String phone;

  const OtpVerificationPage({super.key, required this.phone});

  @override
  ConsumerState<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  final TextEditingController _otpController = TextEditingController();

  int _cooldownSeconds = 30;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 30;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _verify() async {
    setState(() {
      _errorMessage = null;
    });

    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits of the OTP';
      });
      return;
    }

    try {
      final user = await ref.read(authControllerProvider.notifier).verifyOtp(widget.phone, otp);
      if (mounted) {
        if (user != null) {
          context.go('/home');
        } else {
          context.go('/auth/register?phone=${widget.phone}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _errorMessage = null;
    });
    final success = await ref.read(authControllerProvider.notifier).sendOtp(widget.phone);
    if (success) {
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'OTP resent successfully.',
              style: DDSTypography.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: DDSColors.primaryNavy,
          ),
        );
      }
    } else {
      if (mounted) {
        final authState = ref.read(authControllerProvider);
        setState(() {
          _errorMessage = authState.error?.toString() ?? 'Failed to resend OTP.';
        });
      }
    }
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
        iconTheme: const IconThemeData(color: DDSColors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Verify Phone',
                style: DDSTypography.headlineLarge.copyWith(
                  color: DDSColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(8),
              Text(
                'Enter the 6-digit verification code sent to +91 ${widget.phone}.',
                style: DDSTypography.bodyLarge.copyWith(
                  color: DDSColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const Gap(32),

              DriveGoCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: DDSTypography.displayLarge.copyWith(
                        color: DDSColors.textPrimary,
                        letterSpacing: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: '• • • • • •',
                        hintStyle: DDSTypography.displayLarge.copyWith(
                          color: DDSColors.textMuted,
                          letterSpacing: 12,
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: DDSColors.surfaceSubtle,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: DDSRadius.mediumBorderRadius,
                          borderSide: const BorderSide(color: DDSColors.borderMedium),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: DDSRadius.mediumBorderRadius,
                          borderSide: const BorderSide(color: DDSColors.primaryBlue, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.trim().length == 6) {
                          _verify();
                        }
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const Gap(16),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive code? ",
                          style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textSecondary),
                        ),
                        _cooldownSeconds > 0
                            ? Text(
                                'Resend in ${_cooldownSeconds}s',
                                style: DDSTypography.bodyMedium.copyWith(
                                  color: DDSColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : TextButton(
                                onPressed: isLoading ? null : _resend,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  tapTargetSize: MaterialTapTargetSize.padded,
                                ),
                                child: Text(
                                  'Resend OTP',
                                  style: DDSTypography.labelLarge.copyWith(
                                    color: DDSColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),
              DriveGoButton(
                text: 'Verify & Continue',
                onPressed: isLoading ? null : _verify,
                isLoading: isLoading,
                size: DriveGoButtonSize.large,
              ),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }
}

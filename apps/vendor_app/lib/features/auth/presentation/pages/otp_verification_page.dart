import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/vendor_auth_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../../../registration/presentation/providers/registration_providers.dart';

class OtpVerificationPage extends ConsumerStatefulWidget {
  final String phone;

  const OtpVerificationPage({super.key, required this.phone});

  @override
  ConsumerState<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

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
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
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

    final otp = _controllers.map((c) => c.text.trim()).join();
    if (otp.length < 6) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits of the OTP';
      });
      return;
    }

    try {
      final vendor = await ref.read(vendorAuthControllerProvider.notifier).verifyOtp(widget.phone, otp);
      if (mounted) {
        if (vendor != null) {
          final status = ref.read(vendorApprovalStatusProvider);
          if (status == VendorApprovalStatus.verified) {
            context.go('/dashboard');
          } else {
            context.go('/registration/pending');
          }
        } else {
          ref.read(registrationPhoneProvider.notifier).state = widget.phone;
          ref.read(vendorRegistrationDraftProvider.notifier).updateField(phone: widget.phone);
          context.go('/registration');
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll('Exception: ', '');
        if (e is DioException) {
          final resData = e.response?.data;
          if (resData is Map && resData['message'] != null) {
            final m = resData['message'];
            msg = m is List ? m.join(', ') : m.toString();
          } else {
            msg = e.message ?? 'Verification failed';
          }
        }
        setState(() {
          _errorMessage = msg;
        });
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _errorMessage = null;
    });
    final success = await ref.read(vendorAuthControllerProvider.notifier).sendOtp(widget.phone);
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
        final authState = ref.read(vendorAuthControllerProvider);
        setState(() {
          _errorMessage = authState.error?.toString() ?? 'Failed to resend OTP.';
        });
      }
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Partner Verification',
                style: DDSTypography.headlineLarge.copyWith(
                  color: DDSColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(8),
              Text(
                'Enter the 6-digit authentication code sent to +91 ${widget.phone}.',
                style: DDSTypography.bodyLarge.copyWith(
                  color: DDSColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const Gap(32),

              DriveGoCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 44,
                          height: 56,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: DDSTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DDSColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: DDSColors.surfaceSubtle,
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius: DDSRadius.smallBorderRadius,
                                borderSide: const BorderSide(color: DDSColors.borderMedium),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: DDSRadius.smallBorderRadius,
                                borderSide: const BorderSide(color: DDSColors.borderLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: DDSRadius.smallBorderRadius,
                                borderSide: const BorderSide(color: DDSColors.primaryBlue, width: 2),
                              ),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                if (index < 5) {
                                  _focusNodes[index + 1].requestFocus();
                                } else {
                                  _focusNodes[index].unfocus();
                                }
                              } else {
                                if (index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                              }
                            },
                          ),
                        );
                      }),
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
                text: 'Verify & Proceed',
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

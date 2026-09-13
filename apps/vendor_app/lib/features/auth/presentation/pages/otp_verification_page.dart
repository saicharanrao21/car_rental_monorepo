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
      final vendor = await ref.read(vendorAuthControllerProvider.notifier).verifyOtp(widget.phone, otp);
      if (mounted) {
        if (vendor != null) {
          // If the vendor is verified, go to dashboard. Otherwise, go to pending approval
          final status = ref.read(vendorApprovalStatusProvider);
          if (status == VendorApprovalStatus.verified) {
            context.go('/dashboard');
          } else {
            context.go('/registration/pending');
          }
        } else {
          // New vendor: prefill registration phone number draft state and navigate to stepper
          ref.read(registrationPhoneProvider.notifier).state = widget.phone;
          // Pre-populate Step 1 phone field
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
          const SnackBar(content: Text('OTP resent successfully.')),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(8),
              Text(
                'Enter the 6-digit code sent to +91 ${widget.phone}.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const Gap(32),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: 'Enter 6-digit OTP',
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
              const Gap(24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the OTP? ",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  _cooldownSeconds > 0
                      ? Text(
                          'Resend in ${_cooldownSeconds}s',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : TextButton(
                          onPressed: isLoading ? null : _resend,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Resend OTP',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ],
              ),
              const Spacer(),
              AppButton(
                text: 'Verify & Proceed',
                onPressed: isLoading ? null : _verify,
                isLoading: isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

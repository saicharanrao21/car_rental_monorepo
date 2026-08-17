import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/registration_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';

class RegistrationStepperPage extends ConsumerStatefulWidget {
  const RegistrationStepperPage({super.key});

  @override
  ConsumerState<RegistrationStepperPage> createState() => _RegistrationStepperPageState();
}

class _RegistrationStepperPageState extends ConsumerState<RegistrationStepperPage> {
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();
  final _formKey4 = GlobalKey<FormState>();

  // Form controllers
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;

  late TextEditingController _businessNameCtrl;
  late TextEditingController _yearsCtrl;

  late TextEditingController _gstCtrl;
  late TextEditingController _panCtrl;

  late TextEditingController _bankAccountCtrl;
  late TextEditingController _bankIfscCtrl;
  late TextEditingController _bankHolderCtrl;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(vendorRegistrationDraftProvider);

    _ownerNameCtrl = TextEditingController(text: draft.ownerName);
    _phoneCtrl = TextEditingController(text: draft.phone.isEmpty
        ? (ref.read(registrationPhoneProvider) ?? '')
        : draft.phone);
    _emailCtrl = TextEditingController(text: draft.email);

    _businessNameCtrl = TextEditingController(text: draft.businessName);
    _yearsCtrl = TextEditingController(
        text: draft.yearsInOperation > 0 ? draft.yearsInOperation.toString() : '');

    _gstCtrl = TextEditingController(text: draft.gstNumber);
    _panCtrl = TextEditingController(text: draft.panNumber);

    _bankAccountCtrl = TextEditingController(text: draft.bankAccountNumber);
    _bankIfscCtrl = TextEditingController(text: draft.bankIfsc);
    _bankHolderCtrl = TextEditingController(text: draft.bankHolderName);
  }

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _businessNameCtrl.dispose();
    _yearsCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _bankAccountCtrl.dispose();
    _bankIfscCtrl.dispose();
    _bankHolderCtrl.dispose();
    super.dispose();
  }

  void _saveDraft() {
    ref.read(vendorRegistrationDraftProvider.notifier).updateField(
          ownerName: _ownerNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          businessName: _businessNameCtrl.text.trim(),
          yearsInOperation: int.tryParse(_yearsCtrl.text.trim()) ?? 0,
          gstNumber: _gstCtrl.text.trim(),
          panNumber: _panCtrl.text.trim(),
          bankAccountNumber: _bankAccountCtrl.text.trim(),
          bankIfsc: _bankIfscCtrl.text.trim(),
          bankHolderName: _bankHolderCtrl.text.trim(),
        );
  }

  void _nextStep(int currentStep) {
    _saveDraft();

    // Validate the current step
    bool isValid = false;
    if (currentStep == 0) {
      isValid = _formKey1.currentState?.validate() ?? false;
    } else if (currentStep == 1) {
      isValid = _formKey2.currentState?.validate() ?? false;
    } else if (currentStep == 2) {
      isValid = _formKey3.currentState?.validate() ?? false;
    } else if (currentStep == 3) {
      isValid = _formKey4.currentState?.validate() ?? false;
    } else if (currentStep == 4) {
      // Step 5: check if Trade License is uploaded
      final draft = ref.read(vendorRegistrationDraftProvider);
      if (draft.tradeLicensePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload your business Trade License to proceed')),
        );
        return;
      }
      isValid = true;
    }

    if (isValid) {
      ref.read(registrationStepProvider.notifier).next();
    }
  }

  Future<void> _submitApplication() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final draft = ref.read(vendorRegistrationDraftProvider);
      final vendor = await ref.read(vendorRegistrationRepositoryProvider).registerVendor(draft);

      if (mounted) {
        ref.read(vendorSessionProvider.notifier).authenticate(vendor);
        context.go('/registration/pending');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _simulateUpload(String docType) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            Gap(20),
            Text('Selecting and processing file…'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    Navigator.of(context).pop(); // Dismiss loading

    final fakePath = '/simulated_uploads/${docType.toLowerCase().replaceAll(' ', '_')}_doc.pdf';
    ref.read(vendorRegistrationDraftProvider.notifier).updateField(
          rcBookPath: docType == 'RC Book' ? fakePath : null,
          tradeLicensePath: docType == 'Trade License' ? fakePath : null,
          insurancePath: docType == 'Insurance' ? fakePath : null,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$docType uploaded successfully (Simulated)')),
    );
  }

  Widget _buildStepProgress(int currentStep) {
    final titles = [
      'Personal',
      'Business',
      'GST/Legal',
      'Bank',
      'Docs',
      'Review',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              final isCompleted = index < currentStep;
              final isCurrent = index == currentStep;
              return Column(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isCompleted
                        ? Colors.green
                        : isCurrent
                            ? AppColors.primary
                            : Colors.grey[300],
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCurrent || isCompleted ? Colors.white : Colors.grey[600],
                            ),
                          ),
                  ),
                  const Gap(4),
                  Text(
                    titles[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? AppColors.primary : Colors.grey[500],
                    ),
                  ),
                ],
              );
            }),
          ),
          const Gap(12),
          LinearProgressIndicator(
            value: (currentStep + 1) / 6,
            backgroundColor: Colors.grey[200],
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildStepForm(int step, VendorRegistrationDraft draft) {
    switch (step) {
      case 0:
        return Form(
          key: _formKey1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Personal Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Gap(16),
              AppTextField(
                label: 'Owner Full Name',
                hint: 'Amit Shah',
                controller: _ownerNameCtrl,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Owner name is required' : null,
              ),
              const Gap(16),
              AppTextField(
                label: 'Phone Number',
                hint: '98765 43210',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  if (value.replaceAll(RegExp(r'\D'), '').length != 10) {
                    return 'Enter a valid 10-digit phone number';
                  }
                  return null;
                },
              ),
              const Gap(16),
              AppTextField(
                label: 'Email Address',
                hint: 'amit.shah@example.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
            ],
          ),
        );
      case 1:
        return Form(
          key: _formKey2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Business Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Gap(16),
              AppTextField(
                label: 'Business / Fleet Name',
                hint: 'Mumbai Car Rentals',
                controller: _businessNameCtrl,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Business name is required' : null,
              ),
              const Gap(16),
              AppDropdown<String>(
                label: 'Operating City',
                value: draft.city,
                items: AppConstants.indianCities
                    .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(vendorRegistrationDraftProvider.notifier).updateField(city: value);
                  }
                },
                validator: (value) => value == null ? 'Please select a city' : null,
              ),
              const Gap(16),
              AppTextField(
                label: 'Years in Operation',
                hint: 'e.g. 5',
                controller: _yearsCtrl,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Years in operation is required';
                  }
                  final years = int.tryParse(value.trim());
                  if (years == null || years < 0) {
                    return 'Enter a valid positive number';
                  }
                  return null;
                },
              ),
              const Gap(16),
              const Text(
                'Business Type',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(vendorRegistrationDraftProvider.notifier).updateField(businessType: 'Individual Owner');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: draft.businessType == 'Individual Owner' ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                          border: Border.all(
                            color: draft.businessType == 'Individual Owner' ? AppColors.primary : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Individual',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: draft.businessType == 'Individual Owner' ? AppColors.primary : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(vendorRegistrationDraftProvider.notifier).updateField(businessType: 'Consultancy');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: draft.businessType == 'Consultancy' ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                          border: Border.all(
                            color: draft.businessType == 'Consultancy' ? AppColors.primary : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Consultancy',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: draft.businessType == 'Consultancy' ? AppColors.primary : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case 2:
        return Form(
          key: _formKey3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'GST & Legal Info',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Gap(16),
              AppTextField(
                label: 'GST Number',
                hint: '27AAAAA1111A1Z1',
                controller: _gstCtrl,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'GST number is required';
                  }
                  if (value.trim().length != 15) {
                    return 'GST number must be exactly 15 characters';
                  }
                  return null;
                },
              ),
              const Gap(16),
              AppTextField(
                label: 'PAN Card Number',
                hint: 'ABCDE1234F',
                controller: _panCtrl,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'PAN number is required';
                  }
                  if (value.trim().length != 10) {
                    return 'PAN number must be exactly 10 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        );
      case 3:
        return Form(
          key: _formKey4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bank Account Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Gap(16),
              AppTextField(
                label: 'Bank Account Number',
                hint: '50100234567890',
                controller: _bankAccountCtrl,
                keyboardType: TextInputType.number,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Account number is required' : null,
              ),
              const Gap(16),
              AppTextField(
                label: 'IFSC Code',
                hint: 'HDFC0001234',
                controller: _bankIfscCtrl,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'IFSC code is required';
                  }
                  if (value.trim().length != 11) {
                    return 'IFSC code must be exactly 11 characters';
                  }
                  return null;
                },
              ),
              const Gap(16),
              AppTextField(
                label: 'Account Holder Name',
                hint: 'Amit Shah',
                controller: _bankHolderCtrl,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Account holder name is required' : null,
              ),
            ],
          ),
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Business License Upload',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Gap(8),
            Text(
              'Please provide a clear scan of your business Trade License.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const Gap(16),
            _buildDocUploadCard('Trade License', draft.tradeLicensePath),
          ],
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Review & Submit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _buildReviewSection('Personal Details', [
              _buildReviewRow('Owner Name', draft.ownerName),
              _buildReviewRow('Phone', draft.phone),
              _buildReviewRow('Email', draft.email),
            ]),
            const Gap(16),
            _buildReviewSection('Business Details', [
              _buildReviewRow('Fleet Name', draft.businessName),
              _buildReviewRow('Operating City', draft.city),
              _buildReviewRow('Years in Operation', '${draft.yearsInOperation} years'),
              _buildReviewRow('Business Type', draft.businessType),
            ]),
            const Gap(16),
            _buildReviewSection('Legal Info', [
              _buildReviewRow('GST Number', draft.gstNumber),
              _buildReviewRow('PAN Number', draft.panNumber),
            ]),
            const Gap(16),
            _buildReviewSection('Bank Details', [
              _buildReviewRow('Holder Name', draft.bankHolderName),
              _buildReviewRow('Account #', draft.bankAccountNumber),
              _buildReviewRow('IFSC Code', draft.bankIfsc),
            ]),
            const Gap(16),
            _buildReviewSection('Business License', [
              _buildReviewRow('Trade License', draft.tradeLicensePath != null ? 'Uploaded ✓' : 'Missing ✗', isSuccess: draft.tradeLicensePath != null),
            ]),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildDocUploadCard(String label, String? filePath) {
    final hasFile = filePath != null;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              hasFile ? Icons.check_circle : Icons.upload_file,
              color: hasFile ? Colors.green : AppColors.primary,
              size: 32,
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Gap(4),
                  Text(
                    hasFile
                        ? 'file_scanned_doc.pdf (Green check indicates mock verification)'
                        : 'Tap to upload scanned document',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasFile ? Colors.green[700] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _simulateUpload(label),
              child: Text(hasFile ? 'Re-upload' : 'Choose'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(String sectionTitle, List<Widget> children) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sectionTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, {bool? isSuccess}) {
    Color? valueColor;
    if (isSuccess != null) {
      valueColor = isSuccess ? Colors.green : Colors.red;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(registrationStepProvider);
    final draft = ref.watch(vendorRegistrationDraftProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentStep > 0) {
          _saveDraft();
          ref.read(registrationStepProvider.notifier).back();
        } else {
          context.go('/auth/phone');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Partner Registration'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (currentStep > 0) {
                _saveDraft();
                ref.read(registrationStepProvider.notifier).back();
              } else {
                context.go('/auth/phone');
              }
            },
          ),
        ),
        body: Column(
          children: [
            _buildStepProgress(currentStep),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: _buildStepForm(currentStep, draft),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (currentStep > 0) ...[
                    Expanded(
                      child: AppButton(
                        text: 'Back',
                        backgroundColor: Colors.white,
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                _saveDraft();
                                ref.read(registrationStepProvider.notifier).back();
                              },
                      ),
                    ),
                    const Gap(16),
                  ],
                  Expanded(
                    flex: 2,
                    child: currentStep == 5
                        ? AppButton(
                            text: 'Submit Application',
                            onPressed: _isSubmitting ? null : _submitApplication,
                            isLoading: _isSubmitting,
                          )
                        : AppButton(
                            text: 'Next',
                            onPressed: () => _nextStep(currentStep),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

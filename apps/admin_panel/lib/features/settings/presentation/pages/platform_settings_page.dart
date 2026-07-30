import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import '../../domain/repositories/platform_settings_repository.dart';
import '../providers/settings_providers.dart';
// TODO: re-enable for v2 dark mode — theme_provider import removed
// import '../../../../core/providers/theme_provider.dart';

class PlatformSettingsPage extends ConsumerStatefulWidget {
  const PlatformSettingsPage({super.key});

  @override
  ConsumerState<PlatformSettingsPage> createState() => _PlatformSettingsPageState();
}

class _PlatformSettingsPageState extends ConsumerState<PlatformSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _initialized = false;
  bool _isSaving = false;

  late final TextEditingController _nameController;
  late final TextEditingController _gstController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  String? _logoUrl;

  void _initControllers(PlatformSettings settings) {
    if (_initialized) return;
    _nameController = TextEditingController(text: settings.platformName);
    _gstController = TextEditingController(text: settings.gstNumber);
    _emailController = TextEditingController(text: settings.supportEmail);
    _phoneController = TextEditingController(text: settings.supportPhone);
    _logoUrl = settings.logoUrl;
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _nameController.dispose();
      _gstController.dispose();
      _emailController.dispose();
      _phoneController.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave(PlatformSettings currentSettings) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final updated = currentSettings.copyWith(
      platformName: _nameController.text.trim(),
      gstNumber: _gstController.text.trim().toUpperCase(),
      supportEmail: _emailController.text.trim(),
      supportPhone: _phoneController.text.trim(),
      logoUrl: _logoUrl,
    );

    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(platformSettingsProvider.notifier).updateSettings(updated);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(platformSettingsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Gap(4),
                Text(
                  'Configure drivego platform core configurations and customer support channels.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const Gap(24),
            Expanded(
              child: settingsAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading platform settings',
                  onRetry: () => ref.invalidate(platformSettingsProvider),
                ),
                data: (settings) {
                  _initControllers(settings);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form Card
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(
                          child: AppCard(
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Platform Profile & Parameters',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const Gap(24),

                                  // Logo upload slot
                                  const Text(
                                    'Platform Logo',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const Gap(8),
                                  _buildLogoSlot(),
                                  const Gap(20),

                                  // Name
                                  AppTextField(
                                    label: 'Platform Name',
                                    controller: _nameController,
                                    hint: 'e.g. DriveGo Rent',
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Platform name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const Gap(16),

                                  // GSTIN
                                  AppTextField(
                                    label: 'GSTIN (Tax Identification Number)',
                                    controller: _gstController,
                                    hint: 'e.g. 27AAAAA1111A1Z1',
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'GST Number is required';
                                      }
                                      final cleaned = val.trim().toUpperCase();
                                      if (cleaned.length != 15) {
                                        return 'GSTIN must be exactly 15 characters';
                                      }
                                      final gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
                                      if (!gstRegex.hasMatch(cleaned)) {
                                        return 'Enter a valid Indian GSTIN format';
                                      }
                                      return null;
                                    },
                                  ),
                                  const Gap(16),

                                  // Support Email
                                  AppTextField(
                                    label: 'Customer Support Email',
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    hint: 'support@drivego.com',
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Support email is required';
                                      }
                                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                      if (!emailRegex.hasMatch(val.trim())) {
                                        return 'Enter a valid email address';
                                      }
                                      return null;
                                    },
                                  ),
                                  const Gap(16),

                                  // Support Phone
                                  AppTextField(
                                    label: 'Customer Support Helpline',
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    hint: '+91 98765 43210',
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Support phone is required';
                                      }
                                      final phoneRegex = RegExp(r'^\+91\s?\d{10}$|^\+91-\d{10}$|^\d{10}$');
                                      if (!phoneRegex.hasMatch(val.trim())) {
                                        return 'Enter phone in valid +91XXXXXXXXXX format';
                                      }
                                      return null;
                                    },
                                  ),
                                  const Gap(24),

                                  // Save changes button
                                  _isSaving
                                      ? const Center(child: AppLoader())
                                      : AppButton(
                                          text: 'Save Platform Settings',
                                          onPressed: () => _handleSave(settings),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Gap(24),

                      // Sidebar Info Cards
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildAppInfoCard(settings),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSlot() {
    return InkWell(
      onTap: () {
        setState(() {
          _logoUrl = 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=120&q=80';
        });
      },
      child: Container(
        height: 100,
        width: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: _logoUrl != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _logoUrl!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 24, color: Colors.grey),
                  Gap(4),
                  Text('Upload Logo', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
      ),
    );
  }

  Widget _buildAppInfoCard(PlatformSettings settings) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application Registry',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const Gap(16),
          _buildInfoRow('App Environment', 'Development / Sandbox'),
          const Divider(),
          _buildInfoRow('Engine Version', 'Flutter SDK 3.x'),
          const Divider(),
          _buildInfoRow('Bundle Identifier', 'com.drivego.admin'),
          const Divider(),
          _buildInfoRow('App Build Version', settings.appVersion),
        ],
      ),
    );
  }

  // TODO: re-enable for v2 dark mode — theme toggle removed for v1 (light-only)
  // Widget _buildThemeCard(BuildContext context) { ... }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

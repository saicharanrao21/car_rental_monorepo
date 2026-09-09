import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../data/models/marketplace_provider_model.dart';
import '../providers/integration_marketplace_provider.dart';

class ConfigureProviderDialog extends ConsumerStatefulWidget {
  final MarketplaceProviderModel provider;

  const ConfigureProviderDialog({super.key, required this.provider});

  @override
  ConsumerState<ConfigureProviderDialog> createState() => _ConfigureProviderDialogState();
}

class _ConfigureProviderDialogState extends ConsumerState<ConfigureProviderDialog> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;
  late Map<String, bool> _obscureMap;
  late String _selectedEnvironment;
  late int _priority;
  bool _isSaving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _obscureMap = {};
    _selectedEnvironment = widget.provider.activeEnvironment;
    _priority = widget.provider.priority;

    for (final field in widget.provider.credentialSchema) {
      final maskedVal = widget.provider.maskedCredentials[field.key]?.toString() ?? '';
      _controllers[field.key] = TextEditingController(text: maskedVal);
      _obscureMap[field.key] = field.isSecret;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _validationError = null;
    });

    final credentialsToSubmit = <String, String>{};
    for (final field in widget.provider.credentialSchema) {
      final val = _controllers[field.key]?.text.trim() ?? '';
      // If it contains mask bullets '••••' and is unchanged, do not re-encrypt the mask
      if (val.isNotEmpty && !val.contains('••••')) {
        credentialsToSubmit[field.key] = val;
      }
    }

    final success = await ref
        .read(marketplaceNotifierProvider.notifier)
        .saveProviderConfiguration(
          category: widget.provider.category,
          providerId: widget.provider.providerId,
          isEnabled: widget.provider.isEnabled,
          priority: _priority,
          credentials: credentialsToSubmit.isNotEmpty ? credentialsToSubmit : null,
          settings: {
            ...widget.provider.effectiveSettings,
            'environment': _selectedEnvironment,
          },
        );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.provider.name} settings saved successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        final err = ref.read(marketplaceNotifierProvider).errorMessage;
        setState(() => _validationError = err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.settings_suggest_rounded, color: theme.colorScheme.primary),
                  ),
                  const Gap(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configure ${widget.provider.name}',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Category: ${widget.provider.category} • Vault: AES-256-GCM',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Gap(16),
              const Divider(height: 1),
              const Gap(16),

              // Environment & Priority Row
              Row(
                children: [
                  // Environment selector
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Target Environment', style: theme.textTheme.labelMedium),
                        const Gap(6),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'SANDBOX',
                              label: Text('Sandbox'),
                              icon: Icon(Icons.science_outlined, size: 16),
                            ),
                            ButtonSegment(
                              value: 'LIVE',
                              label: Text('Live'),
                              icon: Icon(Icons.verified_outlined, size: 16),
                            ),
                          ],
                          selected: {_selectedEnvironment},
                          onSelectionChanged: (val) {
                            setState(() => _selectedEnvironment = val.first);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),
                  // Priority
                  SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Routing Priority', style: theme.textTheme.labelMedium),
                        const Gap(6),
                        DropdownButtonFormField<int>(
                          value: _priority,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: [1, 2, 3, 4, 5, 10]
                              .map((p) => DropdownMenuItem(value: p, child: Text('Priority $p')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _priority = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(20),

              // Dynamic Credential Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Text(
                        'Credential Vault Specification',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const Gap(6),
                      Text(
                        'All API credentials are encrypted with AES-256-GCM via SecretVaultService before persisting. Plaintext credentials are never logged or exposed.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const Gap(16),

                      if (_validationError != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFEF4444), size: 18),
                              const Gap(8),
                              Expanded(
                                child: Text(
                                  _validationError!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      ...widget.provider.credentialSchema.map((field) {
                        final isSecret = field.isSecret;
                        final isObscured = _obscureMap[field.key] ?? false;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    field.label,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (field.required)
                                    const Text(' *', style: TextStyle(color: Colors.red)),
                                  if (field.environmentScoped) ...[
                                    const Gap(6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'ENV SCOPED',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const Gap(4),
                              Text(
                                field.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                              ),
                              const Gap(6),
                              TextFormField(
                                controller: _controllers[field.key],
                                obscureText: isSecret && isObscured,
                                decoration: InputDecoration(
                                  hintText: field.placeholder ?? 'Enter ${field.label}',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  suffixIcon: isSecret
                                      ? IconButton(
                                          icon: Icon(
                                            isObscured
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureMap[field.key] = !isObscured;
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                validator: (val) {
                                  if (field.required) {
                                    if (val == null || val.trim().isEmpty) {
                                      return '${field.label} is required';
                                    }
                                  }
                                  if (val != null &&
                                      val.isNotEmpty &&
                                      field.validationRegex != null) {
                                    final regex = RegExp(field.validationRegex!);
                                    if (!regex.hasMatch(val) && !val.contains('••••')) {
                                      return 'Invalid format for ${field.label}';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),
              const Gap(16),

              // Dialog Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Gap(12),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_isSaving ? 'Encrypting & Saving...' : 'Save & Encrypt'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

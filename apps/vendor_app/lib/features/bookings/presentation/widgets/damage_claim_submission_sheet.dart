import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import '../providers/vendor_bookings_providers.dart';

class DamageClaimSubmissionSheet extends ConsumerStatefulWidget {
  final String bookingId;
  final VoidCallback onSubmitted;

  const DamageClaimSubmissionSheet({
    super.key,
    required this.bookingId,
    required this.onSubmitted,
  });

  @override
  ConsumerState<DamageClaimSubmissionSheet> createState() => _DamageClaimSubmissionSheetState();
}

class _DamageClaimSubmissionSheetState extends ConsumerState<DamageClaimSubmissionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _vendorNotesCtrl = TextEditingController();
  final _photoUrlCtrl = TextEditingController();

  final List<String> _damagePhotos = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    _vendorNotesCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  void _addPhotoDialog() {
    _photoUrlCtrl.text = 'damage-claim/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Damage Evidence Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Storage Key / Photo Path',
              controller: _photoUrlCtrl,
              hint: 'e.g. damage-claim/rear_bumper_scratch.jpg',
            ),
            const Gap(8),
            Text(
              'Uploads directly to Cloudflare R2 storage.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final key = _photoUrlCtrl.text.trim();
              if (key.isNotEmpty) {
                setState(() {
                  _damagePhotos.add(key);
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add Photo'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_damagePhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach at least one photographic evidence of damage')),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claimed amount must be greater than zero')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await ref.read(vendorBookingsProvider.notifier).submitDamageClaim(
      widget.bookingId,
      claimedAmount: amount,
      description: _descriptionCtrl.text.trim(),
      damagePhotos: _damagePhotos,
      vendorNotes: _vendorNotesCtrl.text.trim().isNotEmpty ? _vendorNotesCtrl.text.trim() : null,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        Navigator.pop(context);
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green[800],
            content: const Text('Damage claim submitted successfully! Admin will review against pre-trip inspection.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit damage claim. A claim may already exist for this booking.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Gap(16),

              // Title
              Row(
                children: [
                  const Icon(Icons.report_problem_outlined, color: Colors.red, size: 24),
                  const Gap(10),
                  const Expanded(
                    child: Text(
                      'Report Post-Trip Vehicle Damage',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Gap(6),
              Text(
                'Submit repair cost estimate and photographic evidence. Claims are adjudicated against pre-trip and post-trip inspection photos.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const Gap(20),

              // Estimated Repair Amount
              AppTextField(
                label: 'Estimated Repair Cost (₹)',
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                hint: 'e.g. 3500',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter the estimated repair cost';
                  }
                  final numVal = double.tryParse(val.trim());
                  if (numVal == null || numVal <= 0) {
                    return 'Enter a valid amount greater than 0';
                  }
                  return null;
                },
              ),
              const Gap(16),

              // Description
              AppTextField(
                label: 'Damage Description & Incident Details',
                controller: _descriptionCtrl,
                maxLines: 3,
                hint: 'Describe where the damage occurred, affected parts, and incident context...',
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'Please provide a detailed description (min 10 chars)';
                  }
                  return null;
                },
              ),
              const Gap(16),

              // Damage Photos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Damage Evidence Photos (${_damagePhotos.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  TextButton.icon(
                    onPressed: _addPhotoDialog,
                    icon: const Icon(Icons.add_a_photo, size: 16),
                    label: const Text('Add Photo'),
                  ),
                ],
              ),
              const Gap(8),

              if (_damagePhotos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400], size: 36),
                        const Gap(8),
                        Text(
                          'No damage photos attached yet.\nPhotographic proof is mandatory for claim approval.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _damagePhotos.map((photo) {
                    return Chip(
                      avatar: const Icon(Icons.photo, size: 16),
                      label: Text(
                        photo.split('/').last,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () {
                        setState(() {
                          _damagePhotos.remove(photo);
                        });
                      },
                    );
                  }).toList(),
                ),
              const Gap(16),

              // Optional Vendor Notes
              AppTextField(
                label: 'Internal Vendor Notes (Optional)',
                controller: _vendorNotesCtrl,
                maxLines: 2,
                hint: 'Any additional notes for the DriveGo dispute resolution team...',
              ),
              const Gap(24),

              // Submit Button
              AppButton(
                text: _isSubmitting ? 'Submitting Claim...' : 'Submit Damage Claim',
                backgroundColor: Colors.red[700],
                onPressed: _isSubmitting ? null : _submit,
              ),
              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import '../providers/vendor_bookings_providers.dart';

class HandoverInspectionSheet extends ConsumerStatefulWidget {
  final String bookingId;
  final String type; // 'PRE_TRIP' or 'POST_TRIP'
  final double? minOdometer;
  final VoidCallback onSaved;

  const HandoverInspectionSheet({
    super.key,
    required this.bookingId,
    required this.type,
    this.minOdometer,
    required this.onSaved,
  });

  @override
  ConsumerState<HandoverInspectionSheet> createState() => _HandoverInspectionSheetState();
}

class _HandoverInspectionSheetState extends ConsumerState<HandoverInspectionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _odometerCtrl;
  final _notesCtrl = TextEditingController();
  final _photoUrlCtrl = TextEditingController();

  double _fuelPercent = 100.0;
  final List<String> _damagePhotos = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final initialOdo = widget.minOdometer != null ? widget.minOdometer!.toStringAsFixed(1) : '';
    _odometerCtrl = TextEditingController(text: initialOdo);
  }

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _notesCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  Color _getFuelColor(double percent) {
    if (percent < 25) return Colors.red;
    if (percent < 50) return Colors.amber.shade700;
    return Colors.green;
  }

  void _addPhotoDialog() {
    _photoUrlCtrl.text = 'inspection-photo/simulated_${DateTime.now().millisecondsSinceEpoch}.jpg';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Inspection Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Storage Key / Photo Path',
              controller: _photoUrlCtrl,
              hint: 'e.g. inspection-photo/front_bumper.jpg',
            ),
            const Gap(12),
            Text(
              'Photos are uploaded to private encrypted bucket with signed URL verification.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
              final text = _photoUrlCtrl.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  _damagePhotos.add(text);
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final odometerVal = double.tryParse(_odometerCtrl.text.trim());
    if (odometerVal == null || odometerVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid odometer reading')),
      );
      return;
    }

    if (widget.minOdometer != null && odometerVal < widget.minOdometer!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Post-trip odometer ($odometerVal km) cannot be less than pre-trip reading (${widget.minOdometer} km)',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await ref.read(vendorBookingsProvider.notifier).submitInspection(
      widget.bookingId,
      type: widget.type,
      odometer: odometerVal,
      fuelPercent: _fuelPercent.toInt(),
      conditionNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      damagePhotos: _damagePhotos,
      finalize: true,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.type == 'PRE_TRIP' ? 'Pre-Trip' : 'Post-Trip'} inspection recorded and finalized successfully!',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save vehicle inspection. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPreTrip = widget.type == 'PRE_TRIP';
    final title = isPreTrip ? 'Pre-Trip Inspection' : 'Post-Trip Inspection';
    final subtitle = isPreTrip
        ? 'Record vehicle condition and odometer prior to customer handover.'
        : 'Record vehicle condition and odometer upon customer vehicle return.';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isPreTrip ? Colors.blue[50] : Colors.purple[50],
                    child: Icon(
                      isPreTrip ? Icons.car_rental : Icons.fact_check_outlined,
                      color: isPreTrip ? Colors.blue[800] : Colors.purple[800],
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Gap(2),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Odometer Field
              Text(
                isPreTrip ? 'Starting Odometer (km)' : 'Return Odometer (km)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Gap(8),
              AppTextField(
                label: 'Odometer Reading (km)',
                controller: _odometerCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                hint: widget.minOdometer != null
                    ? 'Min: ${widget.minOdometer} km'
                    : 'e.g. 24500.5',
              ),
              if (widget.minOdometer != null) ...[
                const Gap(4),
                Text(
                  'Must be >= Pre-Trip reading (${widget.minOdometer} km)',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
              const Gap(16),

              // Fuel Percentage Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Fuel Level',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getFuelColor(_fuelPercent).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_fuelPercent.toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _getFuelColor(_fuelPercent),
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _getFuelColor(_fuelPercent),
                  thumbColor: _getFuelColor(_fuelPercent),
                ),
                child: Slider(
                  value: _fuelPercent,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (v) => setState(() => _fuelPercent = v),
                ),
              ),
              const Gap(12),

              // Condition Notes
              const Text(
                'Vehicle Condition / Existing Scratches',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Gap(8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Clean interior, minor scratch on rear bumper, spare tire verified.',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const Gap(16),

              // Damage Photos Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Inspection Photos',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  TextButton.icon(
                    onPressed: _addPhotoDialog,
                    icon: const Icon(Icons.add_photo_alternate, size: 18),
                    label: const Text('Add Photo'),
                  ),
                ],
              ),
              if (_damagePhotos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Center(
                    child: Text(
                      'No damage photos added (Optional)',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _damagePhotos.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final photoKey = entry.value;
                    return Chip(
                      avatar: const Icon(Icons.photo, size: 16),
                      label: Text(
                        photoKey.length > 20 ? '...${photoKey.substring(photoKey.length - 18)}' : photoKey,
                        style: const TextStyle(fontSize: 11),
                      ),
                      onDeleted: () => setState(() => _damagePhotos.removeAt(idx)),
                    );
                  }).toList(),
                ),
              const Gap(24),

              // Submit Button
              AppButton(
                text: _isSubmitting ? 'Finalizing Inspection...' : 'Finalize & Save Inspection',
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

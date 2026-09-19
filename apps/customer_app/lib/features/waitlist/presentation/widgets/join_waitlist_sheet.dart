import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class JoinWaitlistSheet extends ConsumerStatefulWidget {
  final String? carId;
  final String? carModelName;
  final String? initialCity;
  final Future<void> Function({
    required String city,
    required DateTime startDate,
    required DateTime endDate,
    String? carCategory,
    String? notes,
  })? onSubmit;

  const JoinWaitlistSheet({
    super.key,
    this.carId,
    this.carModelName,
    this.initialCity,
    this.onSubmit,
  });

  @override
  ConsumerState<JoinWaitlistSheet> createState() => _JoinWaitlistSheetState();
}

class _JoinWaitlistSheetState extends ConsumerState<JoinWaitlistSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cityController;
  final TextEditingController _notesController = TextEditingController();

  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  String _selectedCategory = 'SUV';
  bool _isSubmitting = false;
  bool _isSuccess = false;

  final List<String> _categories = ['ALL', 'HATCHBACK', 'SEDAN', 'SUV', 'LUXURY'];

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(text: widget.initialCity ?? 'Bangalore');
  }

  @override
  void dispose() {
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleDatePick({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 2));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (widget.onSubmit != null) {
        await widget.onSubmit!(
          city: _cityController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          carCategory: _selectedCategory == 'ALL' ? null : _selectedCategory,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      }
      if (mounted) {
        setState(() {
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join waitlist: $e')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');

    if (_isSuccess) {
      return Container(
        key: const Key('waitlist_success_banner'),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
            ),
            const Gap(16),
            Text(
              'You are on the Waitlist!',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(8),
            Text(
              'We will notify you immediately via SMS & Push notification when a ${widget.carModelName ?? _selectedCategory} becomes available in ${_cityController.text}.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('waitlist_done_button'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.carModelName != null
                        ? 'Waitlist for ${widget.carModelName}'
                        : 'Join Vehicle Waitlist',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Gap(12),
              Text(
                'High demand! Tell us your preferred dates and we will auto-reserve a vehicle matching your requirements.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const Gap(16),
              TextFormField(
                key: const Key('waitlist_city_field'),
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City *',
                  prefixIcon: Icon(Icons.location_city_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter a city' : null,
              ),
              const Gap(16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('waitlist_start_date_btn'),
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text('From: ${dateFormat.format(_startDate)}'),
                      onPressed: () => _handleDatePick(isStart: true),
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('waitlist_end_date_btn'),
                      icon: const Icon(Icons.event_rounded, size: 16),
                      label: Text('To: ${dateFormat.format(_endDate)}'),
                      onPressed: () => _handleDatePick(isStart: false),
                    ),
                  ),
                ],
              ),
              const Gap(16),
              DropdownButtonFormField<String>(
                key: const Key('waitlist_category_dropdown'),
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Category',
                  prefixIcon: Icon(Icons.directions_car_rounded),
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const Gap(16),
              TextFormField(
                key: const Key('waitlist_notes_field'),
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Special Requests / Notes (Optional)',
                  hintText: 'e.g. Automatic transmission, baby seat preferred',
                  border: OutlineInputBorder(),
                ),
              ),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: const Key('waitlist_submit_button'),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Join Waitlist', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

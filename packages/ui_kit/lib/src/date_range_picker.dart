import 'package:flutter/material.dart';
import 'package:core/core.dart';

class AppDateRangePicker extends StatefulWidget {
  final String label;
  final String? hint;
  final DateTimeRange? initialDateRange;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTimeRange?> onDateRangeSelected;

  const AppDateRangePicker({
    super.key,
    required this.label,
    this.hint,
    this.initialDateRange,
    this.firstDate,
    this.lastDate,
    required this.onDateRangeSelected,
  });

  @override
  State<AppDateRangePicker> createState() => _AppDateRangePickerState();
}

class _AppDateRangePickerState extends State<AppDateRangePicker> {
  DateTimeRange? _selectedRange;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.initialDateRange;
    _controller = TextEditingController(text: _formatRange(_selectedRange));
  }

  @override
  void didUpdateWidget(covariant AppDateRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDateRange != oldWidget.initialDateRange) {
      setState(() {
        _selectedRange = widget.initialDateRange;
        _controller.text = _formatRange(_selectedRange);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatRange(DateTimeRange? range) {
    if (range == null) return '';
    return '${range.start.toDDMMYYYY()} - ${range.end.toDDMMYYYY()}';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedRange,
      firstDate: widget.firstDate ?? today.subtract(const Duration(days: 1)),
      lastDate: widget.lastDate ?? today.add(const Duration(days: 365)),
      locale: const Locale('en', 'IN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _selectedRange = pickedRange;
        _controller.text = _formatRange(pickedRange);
      });
      widget.onDateRangeSelected(pickedRange);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          readOnly: true,
          onTap: _pickDateRange,
          decoration: InputDecoration(
            hintText: widget.hint ?? 'Select date range',
            suffixIcon: const Icon(Icons.calendar_today, color: AppColors.primary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

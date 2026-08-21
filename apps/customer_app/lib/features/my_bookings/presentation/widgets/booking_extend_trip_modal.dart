import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import '../providers/my_bookings_providers.dart';
import '../../domain/repositories/my_bookings_repository.dart';

class BookingExtendTripModal extends ConsumerStatefulWidget {
  final CustomerBookingItem item;

  const BookingExtendTripModal({
    super.key,
    required this.item,
  });

  static Future<bool?> show(BuildContext context, {required CustomerBookingItem item}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingExtendTripModal(item: item),
    );
  }

  @override
  ConsumerState<BookingExtendTripModal> createState() => _BookingExtendTripModalState();
}

class _BookingExtendTripModalState extends ConsumerState<BookingExtendTripModal> {
  int _extraDays = 1;
  late DateTime _selectedEndDate;
  TripExtensionQuoteModel? _quote;
  bool _isLoadingQuote = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedEndDate = widget.item.booking.endDate.add(Duration(days: _extraDays));
    _fetchQuote();
  }

  Future<void> _fetchQuote() async {
    setState(() {
      _isLoadingQuote = true;
      _errorMessage = null;
      _quote = null;
    });

    try {
      final repo = ref.read(myBookingsRepositoryProvider);
      final quote = await repo.getTripExtensionQuote(
        widget.item.booking.id,
        _selectedEndDate.toUtc().toIso8601String(),
      );
      if (mounted) {
        setState(() {
          _quote = quote;
          _isLoadingQuote = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingQuote = false;
          _errorMessage = 'Unable to fetch extension quote from server: $e';
        });
      }
    }
  }

  Future<void> _submitExtension() async {
    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(myBookingsRepositoryProvider);
      await repo.requestTripExtension(
        widget.item.booking.id,
        _selectedEndDate.toUtc().toIso8601String(),
      );
      ref.invalidate(myBookingsListProvider);
      ref.invalidate(enrichedBookingDetailProvider(widget.item.booking.id));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.item.booking;
    final dateFormat = DateFormat('EEE, dd MMM yyyy • hh:mm a');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.more_time_rounded, color: AppColors.primary, size: 24),
                  Gap(10),
                  Text(
                    'Extend Your Trip',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Gap(12),
          Text(
            'Current Scheduled Return: ${dateFormat.format(booking.endDate)}',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const Gap(16),

          const Text(
            'Select Additional Days',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const Gap(10),
          Row(
            children: [1, 2, 3, 5].map((days) {
              final isSelected = _extraDays == days;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isSelected ? AppColors.primary : Colors.white,
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : Colors.grey[300]!,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _extraDays = days;
                              _selectedEndDate = booking.endDate.add(Duration(days: days));
                            });
                            _fetchQuote();
                          },
                    child: Text(
                      '+$days Day${days > 1 ? "s" : ""}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Gap(16),

          // Price Calculation Card
          if (_isLoadingQuote)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: AppLoader()),
            )
          else if (_quote != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Return Schedule', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const Gap(4),
                  Text(
                    dateFormat.format(_quote!.requestedEndDate),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const Divider(height: 20),
                  _row('Additional Duration', '+${_quote!.additionalDays} Day${_quote!.additionalDays > 1 ? "s" : ""} (${_quote!.additionalHours} hours)'),
                  _row('Additional Base Fare', IndianCurrencyFormatter.format(_quote!.additionalBaseFare, showDecimals: false)),
                  _row('GST (18%)', IndianCurrencyFormatter.format(_quote!.gstAmount, showDecimals: false)),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Extension Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        IndianCurrencyFormatter.format(_quote!.totalAdditionalFare, showDecimals: false),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(20),
            AppButton(
              text: 'Confirm Extension (${IndianCurrencyFormatter.format(_quote!.totalAdditionalFare, showDecimals: false)})',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submitExtension,
            ),
          ] else if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 28, color: Colors.red),
                  const Gap(8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                  const Gap(12),
                  OutlinedButton(
                    onPressed: _fetchQuote,
                    child: const Text('Retry Quote'),
                  ),
                ],
              ),
            ),
          ],

          const Gap(8),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

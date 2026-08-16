import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/api_providers.dart';

final carAvailabilityCalendarProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, (String, String)>((ref, arg) async {
  final (carId, month) = arg;
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/cars/$carId/availability-calendar', queryParameters: {'month': month});
  return response.data as Map<String, dynamic>;
});

class AvailabilityCalendarWidget extends ConsumerStatefulWidget {
  final String carId;

  const AvailabilityCalendarWidget({super.key, required this.carId});

  @override
  ConsumerState<AvailabilityCalendarWidget> createState() => _AvailabilityCalendarWidgetState();
}

class _AvailabilityCalendarWidgetState extends ConsumerState<AvailabilityCalendarWidget> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthStr = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
    final calAsync = ref.watch(carAvailabilityCalendarProvider((widget.carId, monthStr)));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _prevMonth,
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextMonth,
              ),
            ],
          ),
          const Gap(12),
          calAsync.when(
            loading: () => const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading availability: $err', style: const TextStyle(color: Colors.red)),
            ),
            data: (data) {
              final calendarList = (data['calendar'] as List<dynamic>? ?? []);
              final Map<String, String> statusMap = {};
              for (var item in calendarList) {
                if (item is Map<String, dynamic>) {
                  statusMap[item['date'] as String] = item['status'] as String;
                }
              }

              final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
              final firstWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday;

              return Column(
                children: [
                  Row(
                    children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
                      return Expanded(
                        child: Center(
                          child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                        ),
                      );
                    }).toList(),
                  ),
                  const Gap(8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: (firstWeekday - 1) + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < firstWeekday - 1) {
                        return const SizedBox.shrink();
                      }
                      final dayNumber = index - (firstWeekday - 2);
                      final dateStr = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${dayNumber.toString().padLeft(2, '0')}';
                      final status = statusMap[dateStr] ?? 'AVAILABLE';

                      Color cellColor;
                      Color textColor;
                      if (status == 'BOOKED') {
                        cellColor = Colors.red.withValues(alpha: 0.15);
                        textColor = Colors.red[800]!;
                      } else if (status == 'BLOCKED') {
                        cellColor = Colors.grey.withValues(alpha: 0.2);
                        textColor = Colors.grey[700]!;
                      } else {
                        cellColor = Colors.green.withValues(alpha: 0.15);
                        textColor = Colors.green[800]!;
                      }

                      return Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: cellColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '$dayNumber',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                          ),
                        ),
                      );
                    },
                  ),
                  const Gap(16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegendItem(Colors.green, 'Available'),
                      _buildLegendItem(Colors.red, 'Booked'),
                      _buildLegendItem(Colors.grey, 'Blocked'),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), border: Border.all(color: color), borderRadius: BorderRadius.circular(2)),
        ),
        const Gap(4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

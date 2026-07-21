import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/earnings_repository.dart';

class ApiEarningsRepository implements EarningsRepository {
  final ApiClient apiClient;

  ApiEarningsRepository({required this.apiClient});

  @override
  Future<EarningsSummary> getSummary(String vendorId) async {
    final response = await apiClient.dio.get('/vendors/me/earnings/summary');
    final data = response.data as Map<String, dynamic>;

    final double thisMonth = double.tryParse(data['thisMonthEarnings']?.toString() ?? '0') ?? 0.0;
    final double lastMonth = double.tryParse(data['lastMonthEarnings']?.toString() ?? '0') ?? 0.0;
    final double totalLifetime = double.tryParse(data['totalEarnings']?.toString() ?? '0') ?? 0.0;

    return EarningsSummary(
      thisMonth: thisMonth,
      lastMonth: lastMonth,
      totalLifetime: totalLifetime,
    );
  }

  @override
  Future<List<EarningsModel>> getDailyEarnings(String vendorId, {int days = 30}) async {
    final response = await apiClient.dio.get(
      '/vendors/me/earnings/daily',
      queryParameters: {'days': days},
    );

    final List<dynamic> list = response.data is List ? response.data : [];
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final dateStr = map['date']?.toString() ?? '';
      final amount = double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0;

      return EarningsModel(
        vendorId: vendorId,
        date: DateTime.tryParse(dateStr) ?? DateTime.now(),
        grossAmount: amount,
        platformFee: 0,
        gstAmount: 0,
        netAmount: amount,
      );
    }).toList();
  }

  @override
  Future<List<PayoutRecord>> getPayoutHistory(String vendorId) async {
    final response = await apiClient.dio.get('/vendors/me/payouts');
    final List<dynamic> list = response.data is List
        ? response.data
        : (response.data['data'] is List ? response.data['data'] : []);

    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final dateStr = map['paidAt'] ?? map['createdAt'] ?? '';
      final amount = double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0;

      return PayoutRecord(
        date: DateTime.tryParse(dateStr.toString()) ?? DateTime.now(),
        amount: amount,
      );
    }).toList();
  }

  Map<String, dynamic> _normalizeBookingJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);

    final rawTripType = copy['tripType'] as String?;
    if (rawTripType != null) {
      if (rawTripType == 'LOCAL') {
        copy['tripType'] = 'Local';
      } else if (rawTripType == 'OUTSTATION') {
        copy['tripType'] = 'Outstation';
      } else if (rawTripType == 'AIRPORT_TRANSFER') {
        copy['tripType'] = 'Airport Transfer';
      } else if (rawTripType == 'SELF_DRIVE') {
        copy['tripType'] = 'Self-Drive';
      }
    }

    final rawStatus = copy['status'] as String?;
    if (rawStatus != null) {
      copy['status'] = rawStatus.toLowerCase();
    }

    for (final field in ['totalFare', 'platformFee', 'gstAmount', 'netToVendor']) {
      if (copy[field] != null) {
        copy[field] = double.tryParse(copy[field].toString()) ?? 0.0;
      }
    }

    return copy;
  }

  @override
  Future<List<BookingModel>> getCompletedBookings(String vendorId) async {
    final response = await apiClient.dio.get(
      '/vendors/me/bookings',
      queryParameters: {'status': 'COMPLETED'},
    );

    final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? []);
    return data.map((json) {
      final normalized = _normalizeBookingJson(Map<String, dynamic>.from(json));
      return BookingModel.fromJson(normalized);
    }).toList();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_providers.dart';

class AdminCampaignsNotifier extends AutoDisposeAsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _fetchCampaigns();
  }

  Future<List<Map<String, dynamic>>> _fetchCampaigns() async {
    final client = ref.read(apiClientProvider);
    final res = await client.dio.get('/growth/campaigns');
    if (res.data != null && res.data is Map && res.data['campaigns'] is List) {
      final list = res.data['campaigns'] as List;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final budget = double.tryParse(map['budget']?.toString() ?? '0') ?? 0.0;
        final spent = double.tryParse(map['spentBudget']?.toString() ?? map['spent']?.toString() ?? '0') ?? 0.0;
        final redemptions = (map['redemptionCount'] ?? map['redemptions'] ?? 0) as int;
        final maxRedemptions = map['maxRedemptions'] != null ? (map['maxRedemptions'] as num).toInt() : null;
        final isActive = map['isActive'] == true;

        DateTime? start;
        if (map['startDate'] != null) {
          start = DateTime.tryParse(map['startDate'].toString());
        }
        DateTime? end;
        if (map['endDate'] != null) {
          end = DateTime.tryParse(map['endDate'].toString());
        }

        String status = 'ACTIVE';
        final now = DateTime.now();
        if (!isActive) {
          status = 'PAUSED';
        } else if (start != null && now.isBefore(start)) {
          status = 'SCHEDULED';
        } else if (end != null && now.isAfter(end)) {
          status = 'EXPIRED';
        } else if ((budget > 0 && spent >= budget) || (maxRedemptions != null && redemptions >= maxRedemptions)) {
          status = 'EXHAUSTED';
        }

        return {
          'id': map['id']?.toString() ?? 'cmp_${DateTime.now().millisecondsSinceEpoch}',
          'code': map['code']?.toString() ?? '',
          'name': map['name']?.toString() ?? '',
          'type': map['type']?.toString() ?? 'GENERAL',
          'city': map['city']?.toString() ?? 'ALL',
          'carCategory': map['carCategory']?.toString() ?? 'ANY',
          'discountType': map['discountType']?.toString() ?? 'PERCENTAGE',
          'discountValue': double.tryParse(map['discountValue']?.toString() ?? '0') ?? 0.0,
          'maxDiscountAmount': double.tryParse(map['maxDiscountAmount']?.toString() ?? '0'),
          'minBookingAmount': double.tryParse(map['minBookingAmount']?.toString() ?? '0'),
          'budget': budget,
          'spent': spent,
          'redemptions': redemptions,
          'maxRedemptions': maxRedemptions ?? 0,
          'startDate': start ?? now,
          'endDate': end ?? now.add(const Duration(days: 30)),
          'status': status,
          'channels': ['PUSH', 'WHATSAPP', 'BANNER'],
          'audience': map['audience']?.toString() ?? 'All Customers',
          'attributedGmv': double.tryParse(map['attributedGmv']?.toString() ?? '0') ?? 0.0,
          'isDemo': false,
        };
      }).toList();
    }
    return [];
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchCampaigns());
  }

  Future<void> createCampaign(Map<String, dynamic> data) async {
    final client = ref.read(apiClientProvider);
    await client.dio.post('/growth/campaigns', data: data);
    await refresh();
  }

  Future<void> toggleCampaign(String id, bool isActive) async {
    final client = ref.read(apiClientProvider);
    await client.dio.patch('/growth/campaigns/$id', data: {'isActive': isActive});
    await refresh();
  }
}

final adminCampaignsProvider =
    AutoDisposeAsyncNotifierProvider<AdminCampaignsNotifier, List<Map<String, dynamic>>>(
  () => AdminCampaignsNotifier(),
);

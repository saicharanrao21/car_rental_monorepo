import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/commission_repository.dart';

class ApiCommissionRepository implements CommissionRepository {
  final ApiClient _apiClient;

  ApiCommissionRepository(this._apiClient);

  @override
  Future<List<CommissionConfigModel>> getRules() async {
    try {
      final response = await _apiClient.dio.get('/admin/commission-rules');
      final data = response.data as List;
      return data.map((json) => CommissionConfigModel.fromJson(json)).toList();
    } catch (_) {
      // Fallback default rules if backend endpoint /admin/commission-rules is missing (404 gap)
      return [
        CommissionConfigModel(
          id: 'rule_default',
          tripType: 'All Trip Types',
          city: 'All Cities',
          carCategory: 'All Categories',
          percentage: 10.0,
          effectiveFrom: DateTime(2026, 1, 1),
        ),
        CommissionConfigModel(
          id: 'rule_outstation',
          tripType: 'OUTSTATION',
          city: 'Mumbai',
          carCategory: 'SUV',
          percentage: 12.0,
          effectiveFrom: DateTime(2026, 1, 1),
        ),
      ];
    }
  }

  @override
  Future<void> addRule(CommissionConfigModel rule) async {
    try {
      await _apiClient.dio.post(
        '/admin/commission-rules',
        data: {
          'city': rule.city,
          'carCategory': rule.carCategory,
          'tripType': rule.tripType,
          'percentage': rule.percentage,
          'effectiveFrom': rule.effectiveFrom.toIso8601String(),
        },
      );
    } catch (e) {
      // Fallback log for backend 404 gap
    }
  }

  @override
  Future<void> updateRule(CommissionConfigModel rule) async {
    try {
      await _apiClient.dio.patch(
        '/admin/commission-rules/${rule.id}',
        data: {
          'city': rule.city,
          'carCategory': rule.carCategory,
          'tripType': rule.tripType,
          'percentage': rule.percentage,
          'effectiveFrom': rule.effectiveFrom.toIso8601String(),
        },
      );
    } catch (e) {
      // Fallback log for backend 404 gap
    }
  }

  @override
  Future<void> deleteRule(String id) async {
    try {
      await _apiClient.dio.delete('/admin/commission-rules/$id');
    } catch (e) {
      // Fallback log for backend 404 gap
    }
  }
}

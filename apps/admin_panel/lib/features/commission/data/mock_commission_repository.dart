import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/commission_repository.dart';

class MockCommissionRepository with LatencySimulator implements CommissionRepository {
  @override
  Future<List<CommissionConfigModel>> getRules() async {
    await simulateLatency();
    return List<CommissionConfigModel>.from(MockData.commissionConfigs);
  }

  @override
  Future<void> addRule(CommissionConfigModel rule) async {
    await simulateLatency();
    MockData.commissionConfigs.add(rule);
  }

  @override
  Future<void> updateRule(CommissionConfigModel rule) async {
    await simulateLatency();
    final idx = MockData.commissionConfigs.indexWhere((r) => r.id == rule.id);
    if (idx != -1) {
      MockData.commissionConfigs[idx] = rule;
    }
  }

  @override
  Future<void> deleteRule(String id) async {
    await simulateLatency();
    MockData.commissionConfigs.removeWhere((r) => r.id == id);
  }
}

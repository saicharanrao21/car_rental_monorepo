import 'package:models/models.dart';

abstract class CommissionRepository {
  Future<List<CommissionConfigModel>> getRules();
  Future<void> addRule(CommissionConfigModel rule);
  Future<void> updateRule(CommissionConfigModel rule);
  Future<void> deleteRule(String id);
}

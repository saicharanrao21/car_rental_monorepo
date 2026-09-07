import '../models/system_config_detail.dart';
import '../models/config_audit_item.dart';

class ConcurrencyConflictException implements Exception {
  final String key;
  final int expectedVersion;
  final int? currentServerVersion;
  final dynamic serverValue;
  final String message;

  const ConcurrencyConflictException({
    required this.key,
    required this.expectedVersion,
    this.currentServerVersion,
    this.serverValue,
    required this.message,
  });

  @override
  String toString() => message;
}

class BatchConfigItem {
  final String key;
  final dynamic value;
  final int? expectedVersion;

  const BatchConfigItem({
    required this.key,
    required this.value,
    this.expectedVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
    };
  }
}

abstract class BusinessRulesRepository {
  Future<List<SystemConfigDetail>> getAllConfigs();
  Future<SystemConfigDetail> getConfigDetail(String key);
  Future<List<ConfigAuditItem>> getAuditHistory(String key, {int limit = 50});
  Future<void> updateConfig({
    required String key,
    required dynamic value,
    int? expectedVersion,
    String? reason,
  });
  Future<void> batchUpdateConfigs({
    required List<BatchConfigItem> items,
    String? reason,
  });
}

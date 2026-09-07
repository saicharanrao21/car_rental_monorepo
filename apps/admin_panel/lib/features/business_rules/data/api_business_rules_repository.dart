import 'package:core/core.dart';
import 'package:dio/dio.dart';
import '../domain/models/system_config_detail.dart';
import '../domain/models/config_audit_item.dart';
import '../domain/repositories/business_rules_repository.dart';

class ApiBusinessRulesRepository implements BusinessRulesRepository {
  final ApiClient _apiClient;

  ApiBusinessRulesRepository(this._apiClient);

  @override
  Future<List<SystemConfigDetail>> getAllConfigs() async {
    try {
      final response = await _apiClient.dio.get('/config/admin/detailed');
      final data = response.data;
      if (data is List) {
        return data
            .map((item) => SystemConfigDetail.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to fetch platform business rules');
    }
  }

  @override
  Future<SystemConfigDetail> getConfigDetail(String key) async {
    try {
      final response = await _apiClient.dio.get('/config/admin/detailed/$key');
      return SystemConfigDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to fetch configuration for [$key]');
    }
  }

  @override
  Future<List<ConfigAuditItem>> getAuditHistory(String key, {int limit = 50}) async {
    try {
      final response = await _apiClient.dio.get(
        '/config/admin/$key/audit-history',
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      if (data is List) {
        return data
            .map((item) => ConfigAuditItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to fetch audit trail for [$key]');
    }
  }

  @override
  Future<void> updateConfig({
    required String key,
    required dynamic value,
    int? expectedVersion,
    String? reason,
  }) async {
    try {
      final payload = {
        'value': value,
        if (expectedVersion != null) 'expectedVersion': expectedVersion,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      };

      await _apiClient.dio.put(
        '/config/admin/$key',
        data: payload,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        final message = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Configuration was modified by another administrator (version mismatch).';

        // Try to fetch current server version to populate conflict details
        int? currentServerVersion;
        dynamic serverVal;
        try {
          final current = await getConfigDetail(key);
          currentServerVersion = current.version;
          serverVal = current.effectiveValue;
        } catch (_) {}

        throw ConcurrencyConflictException(
          key: key,
          expectedVersion: expectedVersion ?? 1,
          currentServerVersion: currentServerVersion,
          serverValue: serverVal,
          message: message,
        );
      }
      throw _handleDioError(e, 'Failed to update configuration [$key]');
    }
  }

  @override
  Future<void> batchUpdateConfigs({
    required List<BatchConfigItem> items,
    String? reason,
  }) async {
    try {
      await _apiClient.dio.put(
        '/config/admin/batch',
        data: {
          'configs': items.map((i) => i.toJson()).toList(),
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        final message = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'One or more configurations were modified by another administrator.';
        throw ConcurrencyConflictException(
          key: 'batch',
          expectedVersion: 0,
          message: message,
        );
      }
      throw _handleDioError(e, 'Failed to execute batch configuration update');
    }
  }

  Exception _handleDioError(DioException e, String fallbackMsg) {
    if (e.response != null) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;
      String? serverMsg;
      if (data is Map && data['message'] != null) {
        serverMsg = data['message'].toString();
      } else if (data is String) {
        serverMsg = data;
      }

      if (statusCode == 400) {
        return Exception(serverMsg ?? 'Invalid configuration payload.');
      } else if (statusCode == 401) {
        return Exception('Session expired or unauthorized. Please re-login.');
      } else if (statusCode == 403) {
        return Exception('Access Denied: You do not have permission to modify platform configurations.');
      } else if (statusCode == 404) {
        return Exception(serverMsg ?? 'Configuration key not found.');
      } else if (statusCode == 500) {
        return Exception('Internal server error occurred while processing configuration.');
      }
      return Exception(serverMsg ?? '$fallbackMsg (HTTP $statusCode)');
    }
    return Exception('$fallbackMsg: ${e.message}');
  }
}

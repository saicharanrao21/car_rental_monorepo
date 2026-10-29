import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_providers.dart';
import '../models/marketplace_provider_model.dart';

final adminIntegrationsRepositoryProvider = Provider<AdminIntegrationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminIntegrationsRepository(apiClient);
});

class AdminIntegrationsRepository {
  final ApiClient _apiClient;

  AdminIntegrationsRepository(this._apiClient);

  Future<List<MarketplaceProviderModel>> fetchMarketplace({
    String? category,
    String? environment,
    String? search,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (category != null && category.isNotEmpty && category != 'ALL') {
        query['category'] = category;
      }
      if (environment != null && environment.isNotEmpty) {
        query['environment'] = environment;
      }
      if (search != null && search.isNotEmpty) {
        query['search'] = search;
      }

      final response = await _apiClient.dio.get(
        '/admin/integrations/marketplace',
        queryParameters: query,
      );

      final data = response.data;
      if (data is List) {
        return data
            .map((item) => MarketplaceProviderModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to fetch integration marketplace');
    }
  }

  Future<void> updateProviderConfig(
    String category,
    String providerId, {
    bool? isEnabled,
    int? priority,
    Map<String, String>? credentials,
    Map<String, dynamic>? settings,
  }) async {
    try {
      await _apiClient.dio.put(
        '/admin/integrations/providers/$category/$providerId/config',
        data: {
          if (isEnabled != null) 'isEnabled': isEnabled,
          if (priority != null) 'priority': priority,
          if (credentials != null) 'credentials': credentials,
          if (settings != null) 'settings': settings,
        },
      );
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to update configuration for $providerId');
    }
  }

  Future<void> toggleProvider(
    String category,
    String providerId,
    bool enabled,
  ) async {
    try {
      await _apiClient.dio.post(
        '/admin/integrations/providers/$category/$providerId/toggle',
        data: {'enabled': enabled},
      );
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to toggle status for $providerId');
    }
  }

  Future<void> setActiveProvider(
    String category,
    String providerId,
  ) async {
    try {
      await _apiClient.dio.post(
        '/admin/integrations/providers/$category/$providerId/set-active',
        data: {},
      );
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to set $providerId as active provider');
    }
  }

  Future<Map<String, dynamic>> testConnection(
    String category,
    String providerId, {
    Map<String, String>? credentials,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/admin/integrations/providers/$category/$providerId/test',
        data: {
          if (credentials != null) 'credentials': credentials,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to test connection to $providerId');
    }
  }

  Future<Map<String, dynamic>> validateCredentials(
    String category,
    String providerId,
    Map<String, dynamic> credentials, {
    String? environment,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/admin/integrations/catalog/$category/$providerId/validate',
        data: {
          'credentials': credentials,
          if (environment != null) 'environment': environment,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e, 'Credential validation failed for $providerId');
    }
  }

  Future<void> updateActivationState(
    String category,
    String providerId,
    String activationState,
  ) async {
    try {
      await _apiClient.dio.put(
        '/admin/integrations/catalog/$category/$providerId/activation',
        data: {'activationState': activationState},
      );
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to update activation state for $providerId');
    }
  }

  // ==========================================
  // EVENT & NOTIFICATION RULES APIS
  // ==========================================

  Future<List<Map<String, dynamic>>> getNotificationRules() async {
    try {
      final response = await _apiClient.dio.get('/admin/integrations/notification-rules');
      final data = response.data;
      if (data is List) {
        return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to fetch notification rules');
    }
  }

  Future<Map<String, dynamic>> upsertNotificationRule(Map<String, dynamic> rule) async {
    try {
      final response = await _apiClient.dio.post(
        '/admin/integrations/notification-rules',
        data: rule,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to save notification rule');
    }
  }

  Future<Map<String, dynamic>> toggleNotificationRule(String id, bool isEnabled) async {
    try {
      final response = await _apiClient.dio.patch(
        '/admin/integrations/notification-rules/$id/toggle',
        data: {'isEnabled': isEnabled},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to toggle notification rule');
    }
  }

  Future<Map<String, dynamic>> simulateNotificationRule(
    String eventType, {
    String? recipientRole,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/admin/integrations/notification-rules/simulate',
        data: {
          'eventType': eventType,
          if (recipientRole != null) 'recipientRole': recipientRole,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to simulate notification rule');
    }
  }

  // ==========================================
  // RUNTIME & CIRCUIT BREAKER APIS
  // ==========================================

  Future<Map<String, dynamic>> fetchRuntimeOverview() async {
    try {
      final response = await _apiClient.dio.get('/admin/integrations/runtime/overview');
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {};
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to fetch runtime overview');
    }
  }

  Future<Map<String, String>> fetchCircuitStates() async {
    try {
      final response = await _apiClient.dio.get('/admin/integrations/runtime/circuits');
      if (response.data is Map) {
        return (response.data as Map).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
      return {};
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to fetch circuit states');
    }
  }

  Future<void> tripCircuit(String providerId, {String? reason}) async {
    try {
      await _apiClient.dio.post(
        '/admin/integrations/runtime/circuits/$providerId/trip',
        data: {'reason': reason ?? 'Manually tripped by Admin'},
      );
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to trip circuit for $providerId');
    }
  }

  Future<void> resetCircuit(String providerId) async {
    try {
      await _apiClient.dio.post(
        '/admin/integrations/runtime/circuits/$providerId/reset',
      );
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to reset circuit for $providerId');
    }
  }

  Future<Map<String, dynamic>> setSimulation(String providerId, String scenario) async {
    try {
      final response = await _apiClient.dio.post(
        '/admin/integrations/runtime/simulations/$providerId',
        data: {'scenario': scenario},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to configure simulation for $providerId');
    }
  }

  Future<void> clearSimulation(String providerId) async {
    try {
      await _apiClient.dio.delete(
        '/admin/integrations/runtime/simulations/$providerId',
      );
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to clear simulation for $providerId');
    }
  }

  String _handleDioError(DioException e, String fallback) {
    if (e.response?.data is Map && e.response?.data['message'] != null) {
      final msg = e.response?.data['message'];
      if (msg is List) return msg.join(', ');
      return msg.toString();
    }
    return e.message ?? fallback;
  }
}

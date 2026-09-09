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

  String _handleDioError(DioException e, String fallback) {
    if (e.response?.data is Map && e.response?.data['message'] != null) {
      final msg = e.response?.data['message'];
      if (msg is List) return msg.join(', ');
      return msg.toString();
    }
    return e.message ?? fallback;
  }
}

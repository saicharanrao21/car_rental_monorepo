import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/marketplace_provider_model.dart';
import '../../data/repositories/admin_integrations_repository.dart';

class MarketplaceState {
  final List<MarketplaceProviderModel> providers;
  final String selectedCategory;
  final String selectedEnvironment;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final Map<String, dynamic>? lastTestResult;
  final bool isTesting;

  const MarketplaceState({
    this.providers = const [],
    this.selectedCategory = 'ALL',
    this.selectedEnvironment = 'SANDBOX',
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.lastTestResult,
    this.isTesting = false,
  });

  MarketplaceState copyWith({
    List<MarketplaceProviderModel>? providers,
    String? selectedCategory,
    String? selectedEnvironment,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    Map<String, dynamic>? lastTestResult,
    bool? isTesting,
  }) {
    return MarketplaceState(
      providers: providers ?? this.providers,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedEnvironment: selectedEnvironment ?? this.selectedEnvironment,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
      lastTestResult: lastTestResult ?? this.lastTestResult,
      isTesting: isTesting ?? this.isTesting,
    );
  }

  List<MarketplaceProviderModel> get filteredProviders {
    return providers.where((p) {
      if (selectedCategory != 'ALL' && p.category != selectedCategory) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchesName = p.name.toLowerCase().contains(q);
        final matchesId = p.providerId.toLowerCase().contains(q);
        final matchesTagline = p.tagline.toLowerCase().contains(q);
        final matchesDesc = p.description.toLowerCase().contains(q);
        final matchesCaps = p.supportedCapabilities.any((c) => c.toLowerCase().contains(q));
        if (!matchesName && !matchesId && !matchesTagline && !matchesDesc && !matchesCaps) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  int get totalProvidersCount => providers.length;
  int get configuredCount => providers.where((p) => p.isConfigured).length;
  int get healthyCount => providers.where((p) => p.health.status == 'HEALTHY' || p.health.status == 'ACTIVE').length;
  int get activeGatewaysCount => providers.where((p) => p.isActive).length;
}

class MarketplaceNotifier extends StateNotifier<MarketplaceState> {
  final AdminIntegrationsRepository _repository;

  MarketplaceNotifier(this._repository) : super(const MarketplaceState()) {
    loadMarketplace();
  }

  Future<void> loadMarketplace() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.fetchMarketplace(
        category: state.selectedCategory != 'ALL' ? state.selectedCategory : null,
        environment: state.selectedEnvironment,
        search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
      );
      state = state.copyWith(
        providers: list,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setEnvironment(String environment) {
    state = state.copyWith(selectedEnvironment: environment);
    loadMarketplace();
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> toggleProvider(String category, String providerId, bool enabled) async {
    try {
      await _repository.toggleProvider(category, providerId, enabled);
      final updated = state.providers.map((p) {
        if (p.category == category && p.providerId == providerId) {
          return p.copyWith(isEnabled: enabled);
        }
        return p;
      }).toList();
      state = state.copyWith(
        providers: updated,
        successMessage: 'Provider ${enabled ? "enabled" : "disabled"} successfully',
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> setActiveProvider(String category, String providerId) async {
    try {
      await _repository.setActiveProvider(category, providerId);
      final updated = state.providers.map((p) {
        if (p.category == category) {
          return p.copyWith(isActive: p.providerId == providerId);
        }
        return p;
      }).toList();
      state = state.copyWith(
        providers: updated,
        successMessage: 'Active provider set to $providerId for $category',
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateActivationState(String category, String providerId, String activationState) async {
    try {
      await _repository.updateActivationState(category, providerId, activationState);
      final updated = state.providers.map((p) {
        if (p.category == category && p.providerId == providerId) {
          return p.copyWith(activationState: activationState);
        }
        return p;
      }).toList();
      state = state.copyWith(
        providers: updated,
        successMessage: 'Activation state updated to $activationState',
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>> testConnection(
    String category,
    String providerId, {
    Map<String, String>? credentials,
  }) async {
    state = state.copyWith(isTesting: true, errorMessage: null);
    try {
      final res = await _repository.testConnection(
        category,
        providerId,
        credentials: credentials,
      );
      state = state.copyWith(isTesting: false, lastTestResult: res);
      return res;
    } catch (e) {
      final fail = {
        'isHealthy': false,
        'latencyMs': 0,
        'errorMessage': e.toString(),
      };
      state = state.copyWith(isTesting: false, lastTestResult: fail);
      return fail;
    }
  }

  Future<bool> saveProviderConfiguration({
    required String category,
    required String providerId,
    bool? isEnabled,
    int? priority,
    Map<String, String>? credentials,
    Map<String, dynamic>? settings,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.updateProviderConfig(
        category,
        providerId,
        isEnabled: isEnabled,
        priority: priority,
        credentials: credentials,
        settings: settings,
      );
      await loadMarketplace();
      state = state.copyWith(
        successMessage: 'Configuration saved and encrypted successfully for $providerId',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final marketplaceNotifierProvider =
    StateNotifierProvider<MarketplaceNotifier, MarketplaceState>((ref) {
  final repo = ref.watch(adminIntegrationsRepositoryProvider);
  return MarketplaceNotifier(repo);
});

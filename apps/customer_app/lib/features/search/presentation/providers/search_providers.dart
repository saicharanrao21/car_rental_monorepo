import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/search_repository.dart';
import '../../data/api_search_repository.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/location_provider.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiSearchRepository(apiClient: apiClient);
});

final searchCityProvider = StateProvider.autoDispose<String>((ref) => 'Mumbai');
final searchTripTypeProvider = StateProvider.autoDispose<String?>((ref) => null);
final searchDatesProvider = StateProvider.autoDispose<DateTimeRange?>((ref) => null);
final searchPickupLocationProvider = StateProvider.autoDispose<String?>((ref) => null);
final searchDropLocationProvider = StateProvider.autoDispose<String?>((ref) => null);

final searchCarCategoryFilterProvider = StateProvider.autoDispose<String?>((ref) => null);
final searchACFilterProvider = StateProvider.autoDispose<bool?>((ref) => null);
final searchPriceRangeFilterProvider = StateProvider.autoDispose<RangeValues?>((ref) => null);
final searchRatingFilterProvider = StateProvider.autoDispose<double?>((ref) => null);

final sortByProvider = StateProvider.autoDispose<String>((ref) => 'Recommended');

class SearchResultsState {
  final List<CarModel> items;
  final bool hasMore;
  final bool isLoadingMore;

  SearchResultsState({
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
  });

  SearchResultsState copyWith({
    List<CarModel>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return SearchResultsState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class SearchResultsNotifier extends AutoDisposeAsyncNotifier<SearchResultsState> {
  List<CarModel> _allFilteredCars = [];
  int _currentPage = 1;
  static const _pageSize = 10;

  @override
  Future<SearchResultsState> build() async {
    final city = ref.watch(searchCityProvider);
    final tripType = ref.watch(searchTripTypeProvider);
    final dates = ref.watch(searchDatesProvider);
    final carType = ref.watch(searchCarCategoryFilterProvider);
    final isAC = ref.watch(searchACFilterProvider);
    final priceRange = ref.watch(searchPriceRangeFilterProvider);
    final minRating = ref.watch(searchRatingFilterProvider);
    final sortBy = ref.watch(sortByProvider);
    final location = ref.watch(userLocationProvider);

    if (tripType == null || tripType.isEmpty) {
      return SearchResultsState(
        items: [],
        hasMore: false,
        isLoadingMore: false,
      );
    }

    final repo = ref.watch(searchRepositoryProvider);

    final cars = await repo.searchCars(
      city: city,
      lat: location.latitude,
      lng: location.longitude,
      tripType: tripType,
      startDate: dates?.start,
      endDate: dates?.end,
      carType: carType,
      isAC: isAC,
      minPrice: priceRange?.start,
      maxPrice: priceRange?.end,
      minRating: minRating,
      sortBy: sortBy,
    );

    _allFilteredCars = cars;
    _currentPage = 1;

    final items = _allFilteredCars.take(_pageSize).toList();
    final hasMore = _allFilteredCars.length > _pageSize;

    return SearchResultsState(
      items: items,
      hasMore: hasMore,
      isLoadingMore: false,
    );
  }

  Future<void> loadMore() async {
    final currentState = state.valueOrNull;
    if (currentState == null || currentState.isLoadingMore || !currentState.hasMore) {
      return;
    }

    state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));

    await Future.delayed(const Duration(milliseconds: 600));

    _currentPage++;
    final nextLimit = _currentPage * _pageSize;
    final items = _allFilteredCars.take(nextLimit).toList();
    final hasMore = _allFilteredCars.length > nextLimit;

    state = AsyncValue.data(SearchResultsState(
      items: items,
      hasMore: hasMore,
      isLoadingMore: false,
    ));
  }
}

final searchResultsProvider = AutoDisposeAsyncNotifierProvider<SearchResultsNotifier, SearchResultsState>(() {
  return SearchResultsNotifier();
});

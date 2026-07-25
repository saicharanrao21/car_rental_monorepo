import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_providers.dart';

final selectedLocalityProvider = StateProvider<String?>((ref) => null);

class LocalityQuery {
  final String city;
  final String search;

  const LocalityQuery({required this.city, required this.search});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalityQuery &&
          runtimeType == other.runtimeType &&
          city == other.city &&
          search == other.search;

  @override
  int get hashCode => city.hashCode ^ search.hashCode;
}

final localitySuggestionsProvider = FutureProvider.family<List<String>, LocalityQuery>((ref, query) async {
  final apiClient = ref.watch(apiClientProvider);
  if (query.search.trim().isEmpty) {
    final response = await apiClient.dio.get('/localities', queryParameters: {'city': query.city});
    final list = response.data as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  }

  final response = await apiClient.dio.get('/localities', queryParameters: {
    'city': query.city,
    'search': query.search,
  });

  final list = response.data as List<dynamic>;
  return list.map((e) => e.toString()).toList();
});

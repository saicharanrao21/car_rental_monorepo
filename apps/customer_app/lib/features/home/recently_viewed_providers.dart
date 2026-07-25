import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import '../../core/providers/api_providers.dart';

final recentlyViewedCarsProvider = FutureProvider<List<CarModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.dio.get('/recently-viewed/me');
    final data = response.data as List<dynamic>;
    return data.map((json) => CarModel.fromJson(Map<String, dynamic>.from(json))).toList();
  } catch (e) {
    return [];
  }
});

Future<void> recordCarView(ApiClient apiClient, String carId) async {
  try {
    await apiClient.dio.post('/recently-viewed', data: {'carId': carId});
  } catch (e) {
    // Ignore errors for recording view
  }
}

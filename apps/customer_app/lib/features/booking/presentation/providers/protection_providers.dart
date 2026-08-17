import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';

final protectionPackagesProvider =
    FutureProvider.family.autoDispose<List<ProtectionPackageModel>, String?>((ref, city) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get(
    '/protection-packages',
    queryParameters: city != null ? {'city': city} : null,
  );
  final list = response.data as List<dynamic>;
  return list
      .map((e) => ProtectionPackageModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

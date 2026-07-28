import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../../domain/branch_model.dart';

final vendorBranchesProvider = FutureProvider.autoDispose<List<BranchModel>>((ref) async {
  final session = ref.watch(vendorSessionProvider);
  if (!session.isAuthenticated || session.vendor == null) {
    return [];
  }

  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/vendors/me/branches');
  final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? []);
  return data.map((item) => BranchModel.fromJson(Map<String, dynamic>.from(item))).toList();
});

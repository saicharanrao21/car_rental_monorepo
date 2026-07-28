import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../../domain/vendor_document_model.dart';

final vendorDocumentsProvider = FutureProvider.autoDispose<List<VendorDocumentModel>>((ref) async {
  final session = ref.watch(vendorSessionProvider);
  if (!session.isAuthenticated || session.vendor == null) {
    return [];
  }

  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/vendors/me/documents');
  final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? []);
  return data.map((item) => VendorDocumentModel.fromJson(Map<String, dynamic>.from(item))).toList();
});

/// Returns documents that are either expired or expiring within 30 days
final expiringDocumentsCountProvider = Provider.autoDispose<int>((ref) {
  final docsAsync = ref.watch(vendorDocumentsProvider);
  return docsAsync.when(
    data: (docs) {
      final now = DateTime.now();
      return docs.where((doc) {
        if (doc.expiresAt == null) return false;
        final diff = doc.expiresAt!.difference(now).inDays;
        return diff <= 30; // Expired (<0) or expiring soon (<=30)
      }).length;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});

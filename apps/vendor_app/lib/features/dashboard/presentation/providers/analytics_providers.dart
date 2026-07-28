import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../../domain/repositories/analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return ApiAnalyticsRepository(apiClient: ref.watch(apiClientProvider));
});

final vendorAnalyticsProvider = FutureProvider.autoDispose<VendorAnalyticsModel>((ref) async {
  final session = ref.watch(vendorSessionProvider);
  if (!session.isAuthenticated || session.vendor == null) {
    throw Exception('Vendor not logged in');
  }
  return ref.watch(analyticsRepositoryProvider).getVendorAnalytics();
});

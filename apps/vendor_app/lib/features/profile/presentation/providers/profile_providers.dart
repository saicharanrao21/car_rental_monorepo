import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_providers.dart';
import '../../domain/repositories/vendor_profile_repository.dart';
import '../../data/api_vendor_profile_repository.dart';

final vendorProfileRepositoryProvider = Provider<VendorProfileRepository>((ref) {
  return ApiVendorProfileRepository(apiClient: ref.watch(apiClientProvider));
});

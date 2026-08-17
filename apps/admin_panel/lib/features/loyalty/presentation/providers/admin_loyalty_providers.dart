import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';
import '../../data/admin_loyalty_repository.dart';
import '../../data/api_admin_loyalty_repository.dart';

final adminLoyaltyRepositoryProvider = Provider<AdminLoyaltyRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiAdminLoyaltyRepository(apiClient: apiClient);
});

final adminLoyaltySummaryProvider =
    FutureProvider.autoDispose<LoyaltySummaryModel>((ref) async {
  final repo = ref.watch(adminLoyaltyRepositoryProvider);
  return repo.getSummary();
});

final adminLoyaltySearchQueryProvider = StateProvider<String>((ref) => '');
final adminLoyaltyTierFilterProvider = StateProvider<LoyaltyTierCode?>((ref) => null);

final adminLoyaltyAccountsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(adminLoyaltyRepositoryProvider);
  final search = ref.watch(adminLoyaltySearchQueryProvider);
  final tierCode = ref.watch(adminLoyaltyTierFilterProvider);
  return repo.getAccounts(search: search, tierCode: tierCode);
});

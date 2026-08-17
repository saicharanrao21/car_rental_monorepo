import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';
import '../../data/api_loyalty_repository.dart';
import '../../data/loyalty_repository.dart';

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiLoyaltyRepository(apiClient);
});

final loyaltyAccountProvider =
    FutureProvider.autoDispose<LoyaltyAccountModel>((ref) async {
  final repo = ref.watch(loyaltyRepositoryProvider);
  return repo.getLoyaltyAccount();
});

final loyaltyTransactionsProvider =
    FutureProvider.autoDispose<List<LoyaltyTransactionModel>>((ref) async {
  final repo = ref.watch(loyaltyRepositoryProvider);
  return repo.getLoyaltyTransactions();
});

final loyaltyTiersProvider =
    FutureProvider.autoDispose<List<LoyaltyTierModel>>((ref) async {
  final repo = ref.watch(loyaltyRepositoryProvider);
  return repo.getLoyaltyTiers();
});

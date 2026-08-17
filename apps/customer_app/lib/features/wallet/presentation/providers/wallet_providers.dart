import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';
import '../../data/wallet_repository.dart';
import '../../data/api_wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiWalletRepository(apiClient: apiClient);
});

final customerWalletProvider =
    FutureProvider.autoDispose<WalletModel>((ref) async {
  final repo = ref.watch(walletRepositoryProvider);
  return repo.getWallet();
});

final customerWalletTransactionsProvider =
    FutureProvider.autoDispose<List<WalletLedgerEntryModel>>((ref) async {
  final repo = ref.watch(walletRepositoryProvider);
  return repo.getTransactions();
});

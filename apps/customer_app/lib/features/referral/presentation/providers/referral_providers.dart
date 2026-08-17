import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_providers.dart';
import '../../data/referral_repository.dart';
import '../../data/api_referral_repository.dart';

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiReferralRepository(apiClient: apiClient);
});

final myReferralCodeProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(referralRepositoryProvider);
  return repo.getMyReferralCode();
});

final referralHistoryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(referralRepositoryProvider);
  return repo.getReferralHistory();
});

final refereeEligibilityProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(referralRepositoryProvider);
  return repo.getRefereeEligibility();
});

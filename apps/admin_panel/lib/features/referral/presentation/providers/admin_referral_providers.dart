import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';
import '../../data/admin_referral_repository.dart';
import '../../data/api_admin_referral_repository.dart';

final adminReferralRepositoryProvider = Provider<AdminReferralRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiAdminReferralRepository(apiClient: apiClient);
});

final adminReferralCampaignsProvider =
    FutureProvider.autoDispose<List<ReferralCampaignModel>>((ref) async {
  final repo = ref.watch(adminReferralRepositoryProvider);
  return repo.getCampaigns();
});

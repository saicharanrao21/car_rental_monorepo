import 'package:core/core.dart';
import 'package:models/models.dart';
import 'admin_referral_repository.dart';

class ApiAdminReferralRepository implements AdminReferralRepository {
  final ApiClient apiClient;

  ApiAdminReferralRepository({required this.apiClient});

  @override
  Future<List<ReferralCampaignModel>> getCampaigns() async {
    final response = await apiClient.dio.get('/admin/referrals/campaigns');
    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => ReferralCampaignModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ReferralCampaignModel> createCampaign(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      '/admin/referrals/campaigns',
      data: data,
    );
    return ReferralCampaignModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReferralCampaignModel> updateCampaign(String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.patch(
      '/admin/referrals/campaigns/$id',
      data: data,
    );
    return ReferralCampaignModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReferralCampaignModel> toggleCampaign(String id) async {
    final response = await apiClient.dio.post(
      '/admin/referrals/campaigns/$id/toggle',
    );
    return ReferralCampaignModel.fromJson(response.data as Map<String, dynamic>);
  }
}

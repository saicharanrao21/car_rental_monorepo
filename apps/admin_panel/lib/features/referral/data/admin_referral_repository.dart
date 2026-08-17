import 'package:models/models.dart';

abstract class AdminReferralRepository {
  Future<List<ReferralCampaignModel>> getCampaigns();
  Future<ReferralCampaignModel> createCampaign(Map<String, dynamic> data);
  Future<ReferralCampaignModel> updateCampaign(String id, Map<String, dynamic> data);
  Future<ReferralCampaignModel> toggleCampaign(String id);
}

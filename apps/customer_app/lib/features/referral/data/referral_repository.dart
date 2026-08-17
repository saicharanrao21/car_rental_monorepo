abstract class ReferralRepository {
  Future<Map<String, dynamic>> getMyReferralCode();
  Future<Map<String, dynamic>> getReferralHistory();
  Future<Map<String, dynamic>> getRefereeEligibility();
  Future<Map<String, dynamic>> applyReferralCode(String code, {String? city});
}

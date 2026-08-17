import 'package:core/core.dart';
import 'referral_repository.dart';

class ApiReferralRepository implements ReferralRepository {
  final ApiClient apiClient;

  ApiReferralRepository({required this.apiClient});

  @override
  Future<Map<String, dynamic>> getMyReferralCode() async {
    final response = await apiClient.dio.get('/referrals/my-code');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getReferralHistory() async {
    final response = await apiClient.dio.get('/referrals/history');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getRefereeEligibility() async {
    final response = await apiClient.dio.get('/referrals/eligibility');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> applyReferralCode(String code, {String? city}) async {
    final response = await apiClient.dio.post(
      '/referrals/apply-code',
      data: {
        'referralCode': code,
        if (city != null) 'city': city,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}

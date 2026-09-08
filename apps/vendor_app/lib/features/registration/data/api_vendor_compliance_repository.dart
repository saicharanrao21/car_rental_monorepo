import 'package:core/core.dart';
import '../domain/models/vendor_compliance_models.dart';
import '../domain/repositories/vendor_compliance_repository.dart';

class ApiVendorComplianceRepository implements VendorComplianceRepository {
  final ApiClient apiClient;

  ApiVendorComplianceRepository({required this.apiClient});

  @override
  Future<VendorEligibilityModel> getEligibility({bool bypassCache = false}) async {
    final response = await apiClient.dio.get(
      '/vendors/me/onboarding/eligibility',
      queryParameters: bypassCache ? {'bypassCache': 'true'} : null,
    );
    return VendorEligibilityModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<VendorRequirementItemModel>> getRequirements() async {
    final response = await apiClient.dio.get('/vendors/me/onboarding/requirements');
    final list = response.data as List<dynamic>;
    return list.map((e) => VendorRequirementItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<VendorDepositSummaryModel> getDepositSummary() async {
    final response = await apiClient.dio.get('/vendors/me/onboarding/deposit');
    return VendorDepositSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> submitRequirement({
    required String requirementDefinitionId,
    String? documentUrl,
    Map<String, dynamic>? metadata,
  }) async {
    await apiClient.dio.post(
      '/vendors/me/onboarding/requirements/$requirementDefinitionId/submit',
      data: {
        if (documentUrl != null && documentUrl.isNotEmpty) 'documentUrl': documentUrl,
        if (metadata != null) 'submissionMetadata': metadata,
      },
    );
  }

  @override
  Future<void> recordDepositPayment({
    required double amount,
    required String paymentMethod,
    String? referenceTransactionId,
  }) async {
    await apiClient.dio.post(
      '/vendors/me/onboarding/deposit/payment',
      data: {
        'amount': amount,
        'paymentMethod': paymentMethod,
        if (referenceTransactionId != null && referenceTransactionId.isNotEmpty)
          'referenceTransactionId': referenceTransactionId,
      },
    );
  }
}

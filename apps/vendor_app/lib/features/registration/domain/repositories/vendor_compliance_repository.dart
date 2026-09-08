import '../models/vendor_compliance_models.dart';

abstract class VendorComplianceRepository {
  Future<VendorEligibilityModel> getEligibility({bool bypassCache = false});
  Future<List<VendorRequirementItemModel>> getRequirements();
  Future<VendorDepositSummaryModel> getDepositSummary();
  Future<void> submitRequirement({
    required String requirementDefinitionId,
    String? documentUrl,
    Map<String, dynamic>? metadata,
  });
  Future<void> recordDepositPayment({
    required double amount,
    required String paymentMethod,
    String? referenceTransactionId,
  });
}

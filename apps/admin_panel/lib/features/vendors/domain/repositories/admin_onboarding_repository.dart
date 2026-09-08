import '../models/vendor_onboarding_models.dart';

abstract interface class AdminOnboardingRepository {
  // Requirement Definitions
  Future<List<RequirementDefinitionModel>> getDefinitions({
    String? category,
    bool? isActive,
    String? scope,
  });

  Future<RequirementDefinitionModel> createDefinition(Map<String, dynamic> data);

  Future<RequirementDefinitionModel> updateDefinition(String id, Map<String, dynamic> data);

  Future<void> seedDefinitions();

  // Verification Approvals
  Future<List<PendingVerificationItemModel>> getPendingVerifications({
    String? category,
    String? vendorId,
  });

  Future<void> reviewRequirement(
    String vendorId,
    String reqId, {
    required String status,
    String? rejectionReason,
  });

  Future<void> waiveRequirement(
    String vendorId,
    String reqId, {
    required String reason,
  });

  // Security Deposits
  Future<List<VendorSecurityDepositModel>> listDeposits({
    String? status,
    String? search,
  });

  Future<VendorSecurityDepositModel> getDeposit(String vendorId);

  Future<List<VendorDepositLedgerEntryModel>> getDepositLedger(String vendorId);

  Future<void> recordPayment(
    String vendorId, {
    required double amount,
    required String paymentMethod,
    required String reference,
    String? reason,
  });

  Future<void> adjustDeposit(
    String vendorId, {
    required double amount,
    String? direction,
    required String reason,
    double? newRequiredAmount,
  });

  Future<void> holdDeposit(String vendorId, {String? reason});

  Future<void> releaseDeposit(
    String vendorId, {
    required String reference,
    required String reason,
  });

  Future<void> refundDeposit(
    String vendorId, {
    double? amount,
    required String reference,
    required String reason,
  });

  Future<void> forfeitDeposit(
    String vendorId, {
    double? amount,
    required String reference,
    required String reason,
  });
}

import 'package:core/core.dart';
import '../domain/models/vendor_onboarding_models.dart';
import '../domain/repositories/admin_onboarding_repository.dart';

class ApiAdminOnboardingRepository implements AdminOnboardingRepository {
  final ApiClient apiClient;

  ApiAdminOnboardingRepository({required this.apiClient});

  @override
  Future<List<RequirementDefinitionModel>> getDefinitions({
    String? category,
    bool? isActive,
    String? scope,
  }) async {
    final queryParams = <String, dynamic>{};
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (isActive != null) queryParams['isActive'] = isActive.toString();
    if (scope != null && scope.isNotEmpty) queryParams['scope'] = scope;

    final response = await apiClient.dio.get(
      '/admin/vendors/requirements/definitions',
      queryParameters: queryParams,
    );

    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => RequirementDefinitionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RequirementDefinitionModel> createDefinition(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      '/admin/vendors/requirements/definitions',
      data: data,
    );
    return RequirementDefinitionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<RequirementDefinitionModel> updateDefinition(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.dio.put(
      '/admin/vendors/requirements/definitions/$id',
      data: data,
    );
    return RequirementDefinitionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> seedDefinitions() async {
    await apiClient.dio.post('/admin/vendors/requirements/definitions/seed');
  }

  @override
  Future<List<PendingVerificationItemModel>> getPendingVerifications({
    String? category,
    String? vendorId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (vendorId != null && vendorId.isNotEmpty) queryParams['vendorId'] = vendorId;

    final response = await apiClient.dio.get(
      '/admin/vendors/onboarding/pending-verifications',
      queryParameters: queryParams,
    );

    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => PendingVerificationItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> reviewRequirement(
    String vendorId,
    String reqId, {
    required String status,
    String? rejectionReason,
  }) async {
    await apiClient.dio.post(
      '/admin/vendors/$vendorId/onboarding/requirements/$reqId/review',
      data: {
        'status': status,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      },
    );
  }

  @override
  Future<void> waiveRequirement(
    String vendorId,
    String reqId, {
    required String reason,
  }) async {
    await apiClient.dio.post(
      '/admin/vendors/$vendorId/onboarding/requirements/$reqId/waive',
      data: {'reason': reason},
    );
  }

  @override
  Future<List<VendorSecurityDepositModel>> listDeposits({
    String? status,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await apiClient.dio.get(
      '/admin/vendors/deposits',
      queryParameters: queryParams,
    );

    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => VendorSecurityDepositModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<VendorSecurityDepositModel> getDeposit(String vendorId) async {
    final response = await apiClient.dio.get('/admin/vendors/$vendorId/deposit');
    return VendorSecurityDepositModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<VendorDepositLedgerEntryModel>> getDepositLedger(String vendorId) async {
    final response = await apiClient.dio.get('/admin/vendors/$vendorId/deposit/ledger');
    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => VendorDepositLedgerEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> recordPayment(
    String vendorId, {
    required double amount,
    required String paymentMethod,
    required String reference,
    String? reason,
  }) async {
    await apiClient.dio.post(
      '/admin/vendors/$vendorId/deposit/record-payment',
      data: {
        'amount': amount,
        'paymentMethod': paymentMethod,
        'reference': reference,
        'idempotencyKey': 'admin_pay_${DateTime.now().millisecondsSinceEpoch}',
        if (reason != null) 'reason': reason,
      },
    );
  }

  @override
  Future<void> adjustDeposit(
    String vendorId, {
    required double amount,
    String? direction,
    required String reason,
    double? newRequiredAmount,
  }) async {
    await apiClient.dio.post(
      '/admin/vendors/$vendorId/deposit/adjust',
      data: {
        'amount': amount,
        if (direction != null) 'direction': direction,
        'reason': reason,
        if (newRequiredAmount != null) 'newRequiredAmount': newRequiredAmount,
        'idempotencyKey': 'admin_adj_${DateTime.now().millisecondsSinceEpoch}',
      },
    );
  }

  @override
  Future<void> holdDeposit(String vendorId, {String? reason}) async {
    await apiClient.dio.post(
      '/admin/vendors/$vendorId/deposit/hold',
      data: {
        if (reason != null) 'reason': reason,
      },
    );
  }

  @override
  Future<void> releaseDeposit(
    String vendorId, {
    required String reference,
    required String reason,
  }) async {
    await apiClient.dio.post(
      '/admin/vendors/$vendorId/deposit/release',
      data: {
        'reference': reference,
        'reason': reason,
        'idempotencyKey': 'admin_rel_${DateTime.now().millisecondsSinceEpoch}',
      },
    );
  }

  @override
  Future<void> refundDeposit(
    String vendorId, {
    double? amount,
    required String reference,
    required String reason,
  }) async {
    await apiClient.dio.post(
      '/admin/vendors/$vendorId/deposit/refund',
      data: {
        if (amount != null) 'amount': amount,
        'reference': reference,
        'reason': reason,
        'idempotencyKey': 'admin_ref_${DateTime.now().millisecondsSinceEpoch}',
      },
    );
  }

  @override
  Future<void> forfeitDeposit(
    String vendorId, {
    double? amount,
    required String reference,
    required String reason,
  }) async {
    await apiClient.dio.post(
      '/admin/vendors/$vendorId/deposit/forfeit',
      data: {
        if (amount != null) 'amount': amount,
        'reference': reference,
        'reason': reason,
        'idempotencyKey': 'admin_forf_${DateTime.now().millisecondsSinceEpoch}',
      },
    );
  }
}

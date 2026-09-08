class VendorEligibilityModel {
  final String vendorId;
  final bool isEligible;
  final List<String> blockers;
  final List<String> reasons;
  final bool requirementsSatisfied;
  final List<String> missingMandatoryRequirements;
  final String verificationStatus;
  final bool securityDepositSatisfied;
  final double depositRemaining;
  final bool serviceAreaEligible;
  final DateTime evaluatedAt;

  VendorEligibilityModel({
    required this.vendorId,
    required this.isEligible,
    required this.blockers,
    required this.reasons,
    required this.requirementsSatisfied,
    required this.missingMandatoryRequirements,
    required this.verificationStatus,
    required this.securityDepositSatisfied,
    required this.depositRemaining,
    required this.serviceAreaEligible,
    required this.evaluatedAt,
  });

  factory VendorEligibilityModel.fromJson(Map<String, dynamic> json) {
    final details = json['details'] as Map<String, dynamic>? ?? {};
    return VendorEligibilityModel(
      vendorId: json['vendorId']?.toString() ?? '',
      isEligible: json['isEligible'] == true,
      blockers: (json['blockers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      reasons: (json['reasons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      requirementsSatisfied: details['requirementsSatisfied'] == true,
      missingMandatoryRequirements: (details['missingMandatoryRequirements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      verificationStatus: details['verificationStatus']?.toString() ?? 'PENDING',
      securityDepositSatisfied: details['securityDepositSatisfied'] == true,
      depositRemaining: (details['depositRemaining'] as num?)?.toDouble() ?? 0.0,
      serviceAreaEligible: details['serviceAreaEligible'] == true,
      evaluatedAt: json['evaluatedAt'] != null
          ? DateTime.tryParse(json['evaluatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class VendorRequirementItemModel {
  final String definitionId;
  final String name;
  final String key;
  final String category;
  final String scope;
  final bool isRequired;
  final String? serviceAreaId;
  final String? serviceAreaName;
  final String state; // MISSING, PENDING, VERIFIED, REJECTED, EXPIRED, WAIVED
  final String? rejectionReason;
  final Map<String, dynamic>? submissionMetadata;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final DateTime? expiresAt;

  VendorRequirementItemModel({
    required this.definitionId,
    required this.name,
    required this.key,
    required this.category,
    required this.scope,
    required this.isRequired,
    this.serviceAreaId,
    this.serviceAreaName,
    required this.state,
    this.rejectionReason,
    this.submissionMetadata,
    this.submittedAt,
    this.verifiedAt,
    this.expiresAt,
  });

  factory VendorRequirementItemModel.fromJson(Map<String, dynamic> json) {
    return VendorRequirementItemModel(
      definitionId: json['definitionId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      category: json['category']?.toString() ?? 'DOCUMENT',
      scope: json['scope']?.toString() ?? 'GLOBAL',
      isRequired: json['isRequired'] == true,
      serviceAreaId: json['serviceAreaId']?.toString(),
      serviceAreaName: json['serviceAreaName']?.toString(),
      state: json['state']?.toString().toUpperCase() ?? 'MISSING',
      rejectionReason: json['rejectionReason']?.toString(),
      submissionMetadata: json['submissionMetadata'] is Map<String, dynamic>
          ? json['submissionMetadata'] as Map<String, dynamic>
          : null,
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'].toString())
          : null,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'].toString())
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
    );
  }
}

class VendorDepositSummaryModel {
  final String depositId;
  final String vendorId;
  final String status;
  final double requiredAmount;
  final double paidAmount;
  final double remainingAmount;
  final double availableBalance;
  final double heldBalance;
  final double refundedBalance;
  final double forfeitedBalance;
  final bool isFullyPaid;
  final double minInitialAmount;
  final bool allowPartialPayment;

  VendorDepositSummaryModel({
    required this.depositId,
    required this.vendorId,
    required this.status,
    required this.requiredAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.availableBalance,
    required this.heldBalance,
    required this.refundedBalance,
    required this.forfeitedBalance,
    required this.isFullyPaid,
    required this.minInitialAmount,
    required this.allowPartialPayment,
  });

  factory VendorDepositSummaryModel.fromJson(Map<String, dynamic> json) {
    return VendorDepositSummaryModel(
      depositId: json['depositId']?.toString() ?? '',
      vendorId: json['vendorId']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      requiredAmount: (json['requiredAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0.0,
      heldBalance: (json['heldBalance'] as num?)?.toDouble() ?? 0.0,
      refundedBalance: (json['refundedBalance'] as num?)?.toDouble() ?? 0.0,
      forfeitedBalance: (json['forfeitedBalance'] as num?)?.toDouble() ?? 0.0,
      isFullyPaid: json['isFullyPaid'] == true,
      minInitialAmount: (json['minInitialAmount'] as num?)?.toDouble() ?? 0.0,
      allowPartialPayment: json['allowPartialPayment'] != false,
    );
  }
}

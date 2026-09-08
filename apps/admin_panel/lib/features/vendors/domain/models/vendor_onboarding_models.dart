class RequirementDefinitionModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String category; // DOCUMENT, MONETARY, PHYSICAL_ASSET, VERIFICATION, OTHER
  final bool isRequired;
  final bool isActive;
  final int displayOrder;
  final String scope; // GLOBAL, VENDOR_SPECIFIC, VEHICLE_CATEGORY, SERVICE_AREA
  final String? targetScopeValue;
  final int version;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final Map<String, dynamic>? config;

  const RequirementDefinitionModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.category,
    required this.isRequired,
    required this.isActive,
    required this.displayOrder,
    required this.scope,
    this.targetScopeValue,
    required this.version,
    required this.effectiveFrom,
    this.effectiveTo,
    this.config,
  });

  factory RequirementDefinitionModel.fromJson(Map<String, dynamic> json) {
    return RequirementDefinitionModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? (json['title'] as String? ?? ''),
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'DOCUMENT',
      isRequired: json['isRequired'] as bool? ?? true,
      isActive: json['isActive'] as bool? ?? true,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      scope: json['scope'] as String? ?? 'GLOBAL',
      targetScopeValue: json['targetScopeValue'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      effectiveFrom: json['effectiveFrom'] != null
          ? DateTime.tryParse(json['effectiveFrom'].toString()) ?? DateTime.now()
          : DateTime.now(),
      effectiveTo: json['effectiveTo'] != null
          ? DateTime.tryParse(json['effectiveTo'].toString())
          : null,
      config: json['config'] is Map<String, dynamic>
          ? json['config'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        if (description != null) 'description': description,
        'category': category,
        'isRequired': isRequired,
        'isActive': isActive,
        'displayOrder': displayOrder,
        'scope': scope,
        if (targetScopeValue != null) 'targetScopeValue': targetScopeValue,
        'version': version,
        'effectiveFrom': effectiveFrom.toIso8601String(),
        if (effectiveTo != null) 'effectiveTo': effectiveTo!.toIso8601String(),
        if (config != null) 'config': config,
      };
}

class VendorSecurityDepositModel {
  final String id;
  final String vendorId;
  final double requiredAmount;
  final double paidAmount;
  final double remainingAmount;
  final String status; // REQUIRED, PENDING, PARTIALLY_PAID, PAID, HELD, RELEASED, REFUNDED, FORFEITED
  final String? requirementCode;
  final int? requirementVersion;
  final DateTime? heldAt;
  final DateTime? releasedAt;
  final DateTime? refundedAt;
  final DateTime? forfeitedAt;
  final String? forfeitedReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? vendorBusinessName;
  final String? vendorContactName;
  final String? vendorEmail;
  final String? vendorPhone;

  const VendorSecurityDepositModel({
    required this.id,
    required this.vendorId,
    required this.requiredAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.requirementCode,
    this.requirementVersion,
    this.heldAt,
    this.releasedAt,
    this.refundedAt,
    this.forfeitedAt,
    this.forfeitedReason,
    this.createdAt,
    this.updatedAt,
    this.vendorBusinessName,
    this.vendorContactName,
    this.vendorEmail,
    this.vendorPhone,
  });

  factory VendorSecurityDepositModel.fromJson(Map<String, dynamic> json) {
    final vendorMap = json['vendor'] is Map<String, dynamic> ? json['vendor'] as Map<String, dynamic> : null;
    final userMap = vendorMap != null && vendorMap['user'] is Map<String, dynamic>
        ? vendorMap['user'] as Map<String, dynamic>
        : null;

    return VendorSecurityDepositModel(
      id: json['id'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      requiredAmount: (json['requiredAmount'] as num?)?.toDouble() ??
          (json['amountRequired'] as num?)?.toDouble() ??
          0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ??
          (json['amountPaid'] as num?)?.toDouble() ??
          0.0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ??
          (json['amountRemaining'] as num?)?.toDouble() ??
          0.0,
      status: json['status'] as String? ?? 'REQUIRED',
      requirementCode: json['requirementCode'] as String?,
      requirementVersion: (json['requirementVersion'] as num?)?.toInt(),
      heldAt: json['heldAt'] != null ? DateTime.tryParse(json['heldAt'].toString()) : null,
      releasedAt: json['releasedAt'] != null ? DateTime.tryParse(json['releasedAt'].toString()) : null,
      refundedAt: json['refundedAt'] != null ? DateTime.tryParse(json['refundedAt'].toString()) : null,
      forfeitedAt: json['forfeitedAt'] != null ? DateTime.tryParse(json['forfeitedAt'].toString()) : null,
      forfeitedReason: json['forfeitedReason'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      vendorBusinessName: vendorMap != null ? vendorMap['businessName'] as String? : null,
      vendorContactName: userMap != null ? userMap['name'] as String? : null,
      vendorEmail: userMap != null ? userMap['email'] as String? : null,
      vendorPhone: userMap != null ? userMap['phone'] as String? : null,
    );
  }
}

class VendorDepositLedgerEntryModel {
  final String id;
  final String depositId;
  final double amount;
  final String direction; // CREDIT, DEBIT
  final double balanceBefore;
  final double balanceAfter;
  final String transactionType;
  final String paymentMethod;
  final String reference;
  final String? reason;
  final String? actorId;
  final String? actorRole;
  final DateTime createdAt;

  const VendorDepositLedgerEntryModel({
    required this.id,
    required this.depositId,
    required this.amount,
    required this.direction,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.transactionType,
    required this.paymentMethod,
    required this.reference,
    this.reason,
    this.actorId,
    this.actorRole,
    required this.createdAt,
  });

  factory VendorDepositLedgerEntryModel.fromJson(Map<String, dynamic> json) {
    return VendorDepositLedgerEntryModel(
      id: json['id'] as String? ?? '',
      depositId: json['depositId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      direction: json['direction'] as String? ?? 'CREDIT',
      balanceBefore: (json['balanceBefore'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
      transactionType: json['transactionType'] as String? ?? '',
      paymentMethod: json['paymentMethod'] as String? ?? 'ADMIN',
      reference: json['reference'] as String? ?? '',
      reason: json['reason'] as String?,
      actorId: json['actorId'] as String?,
      actorRole: json['actorRole'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class PendingVerificationItemModel {
  final String id;
  final String vendorId;
  final String vendorBusinessName;
  final String? vendorStatus;
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPhone;
  final String requirementId;
  final String requirementCode;
  final String requirementName;
  final String category;
  final String status;
  final String? documentId;
  final String? documentNumber;
  final DateTime? submittedAt;
  final String? rejectionReason;
  final Map<String, dynamic>? submissionData;

  const PendingVerificationItemModel({
    required this.id,
    required this.vendorId,
    required this.vendorBusinessName,
    this.vendorStatus,
    this.ownerName,
    this.ownerEmail,
    this.ownerPhone,
    required this.requirementId,
    required this.requirementCode,
    required this.requirementName,
    required this.category,
    required this.status,
    this.documentId,
    this.documentNumber,
    this.submittedAt,
    this.rejectionReason,
    this.submissionData,
  });

  factory PendingVerificationItemModel.fromJson(Map<String, dynamic> json) {
    final vendor = json['vendor'] is Map<String, dynamic> ? json['vendor'] as Map<String, dynamic> : {};
    final user = vendor['user'] is Map<String, dynamic> ? vendor['user'] as Map<String, dynamic> : {};
    final reqDef = json['requirementDefinition'] is Map<String, dynamic>
        ? json['requirementDefinition'] as Map<String, dynamic>
        : {};

    return PendingVerificationItemModel(
      id: json['id'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      vendorBusinessName: vendor['businessName'] as String? ?? (json['vendorBusinessName'] as String? ?? 'Partner'),
      vendorStatus: vendor['verificationStatus'] as String?,
      ownerName: user['name'] as String?,
      ownerEmail: user['email'] as String?,
      ownerPhone: user['phone'] as String?,
      requirementId: reqDef['id'] as String? ?? (json['requirementDefinitionId'] as String? ?? ''),
      requirementCode: reqDef['code'] as String? ?? (json['code'] as String? ?? ''),
      requirementName: reqDef['name'] as String? ?? (json['name'] as String? ?? 'Requirement'),
      category: reqDef['category'] as String? ?? (json['category'] as String? ?? 'DOCUMENT'),
      status: json['status'] as String? ?? 'PENDING',
      documentId: json['documentId'] as String?,
      documentNumber: json['documentNumber'] as String?,
      submittedAt: json['submittedAt'] != null ? DateTime.tryParse(json['submittedAt'].toString()) : null,
      rejectionReason: json['rejectionReason'] as String?,
      submissionData: json['submissionData'] is Map<String, dynamic>
          ? json['submissionData'] as Map<String, dynamic>
          : null,
    );
  }
}

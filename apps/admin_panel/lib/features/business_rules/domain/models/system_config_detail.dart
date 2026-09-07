class SystemConfigDetail {
  final String key;
  final dynamic effectiveValue;
  final String source; // 'DATABASE' | 'DEFAULT_FALLBACK'
  final bool isExplicitlyConfigured;
  final int version;
  final DateTime? updatedAt;
  final String? updatedBy;
  final String category;
  final String? description;
  final bool isPublic;

  const SystemConfigDetail({
    required this.key,
    required this.effectiveValue,
    required this.source,
    required this.isExplicitlyConfigured,
    required this.version,
    this.updatedAt,
    this.updatedBy,
    required this.category,
    this.description,
    required this.isPublic,
  });

  bool get isFallback => source == 'DEFAULT_FALLBACK';
  bool get isDatabase => source == 'DATABASE';

  String get humanReadableName {
    switch (key) {
      case 'pricing.tax':
        return 'Goods & Services Tax (GST)';
      case 'pricing.quote':
        return 'Booking Quote Validity Window';
      case 'pricing.duration_discounts':
        return 'Multi-Day Duration Discounts';
      case 'pricing.commission':
        return 'Platform Commission Fallback';
      case 'booking.cancellation_matrix':
        return 'Cancellation Fee Schedule & Tiers';
      case 'deposits.defaults':
        return 'Vehicle Category Deposit Defaults';
      case 'wallet.rules':
        return 'Digital Wallet & Deposit Rules';
      case 'booking.policies':
        return 'Operational Booking Policies & OTP';
      case 'search.ranking':
        return 'Marketplace Search Ranking Weights';
      case 'referral.rules':
        return 'Customer Referral Program Rewards';
      case 'platform.feature_flags':
        return 'Global Platform Dynamic Feature Flags';
      case 'payout.rules':
        return 'Vendor Payout Limits & Approval Rules';
      case 'reconciliation.rules':
        return 'Financial Gateway Reconciliation Rules';
      case 'support.sla':
        return 'Customer Support Target Response SLAs';
      case 'notification.orchestration':
        return 'Notification Delivery Channels & SLAs';
      case 'growth.campaigns':
        return 'Growth & Monetization Multipliers';
      case 'analytics.governance':
        return 'Analytics & Risk Alert Governance';
      default:
        return key.replaceAll('.', ' ').replaceAll('_', ' ').toUpperCase();
    }
  }

  String get domainGroup {
    if (key.startsWith('pricing.')) return 'PRICING';
    if (key.startsWith('booking.')) return 'BOOKING';
    if (key.startsWith('deposits.') || key.startsWith('payout.') || key.startsWith('reconciliation.')) {
      return 'FINANCE';
    }
    if (key.startsWith('growth.') || key.startsWith('referral.')) return 'GROWTH';
    if (key.startsWith('search.')) return 'SEARCH';
    if (key.startsWith('support.')) return 'SUPPORT';
    if (key.startsWith('notification.')) return 'NOTIFICATION';
    if (key.startsWith('wallet.')) return 'WALLET';
    if (key.startsWith('platform.')) return 'FEATURE_FLAGS';
    return category.toUpperCase();
  }

  factory SystemConfigDetail.fromJson(Map<String, dynamic> json) {
    return SystemConfigDetail(
      key: json['key'] as String? ?? '',
      effectiveValue: json['effectiveValue'],
      source: json['source'] as String? ?? 'DEFAULT_FALLBACK',
      isExplicitlyConfigured: json['isExplicitlyConfigured'] as bool? ?? false,
      version: (json['version'] as num?)?.toInt() ?? 1,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      updatedBy: json['updatedBy'] as String?,
      category: json['category'] as String? ?? 'GENERAL',
      description: json['description'] as String?,
      isPublic: json['isPublic'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'effectiveValue': effectiveValue,
      'source': source,
      'isExplicitlyConfigured': isExplicitlyConfigured,
      'version': version,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
      'category': category,
      'description': description,
      'isPublic': isPublic,
    };
  }

  SystemConfigDetail copyWith({
    String? key,
    dynamic effectiveValue,
    String? source,
    bool? isExplicitlyConfigured,
    int? version,
    DateTime? updatedAt,
    String? updatedBy,
    String? category,
    String? description,
    bool? isPublic,
  }) {
    return SystemConfigDetail(
      key: key ?? this.key,
      effectiveValue: effectiveValue ?? this.effectiveValue,
      source: source ?? this.source,
      isExplicitlyConfigured: isExplicitlyConfigured ?? this.isExplicitlyConfigured,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      category: category ?? this.category,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}

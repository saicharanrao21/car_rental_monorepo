class ProviderDocumentationModel {
  final String overview;
  final String docsUrl;
  final String setupGuide;
  final String? webhookGuide;
  final String? supportEmail;

  const ProviderDocumentationModel({
    required this.overview,
    required this.docsUrl,
    required this.setupGuide,
    this.webhookGuide,
    this.supportEmail,
  });

  factory ProviderDocumentationModel.fromJson(Map<String, dynamic> json) {
    return ProviderDocumentationModel(
      overview: json['overview']?.toString() ?? '',
      docsUrl: json['docsUrl']?.toString() ?? '',
      setupGuide: json['setupGuide']?.toString() ?? '',
      webhookGuide: json['webhookGuide']?.toString(),
      supportEmail: json['supportEmail']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'overview': overview,
        'docsUrl': docsUrl,
        'setupGuide': setupGuide,
        'webhookGuide': webhookGuide,
        'supportEmail': supportEmail,
      };
}

class CredentialFieldSchemaModel {
  final String key;
  final String label;
  final String type; // 'string' | 'password' | 'url' | 'textarea' | 'number' | 'boolean'
  final bool required;
  final bool isSecret;
  final String description;
  final String? placeholder;
  final String? validationRegex;
  final bool environmentScoped;
  final dynamic defaultValue;

  const CredentialFieldSchemaModel({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    required this.isSecret,
    required this.description,
    this.placeholder,
    this.validationRegex,
    this.environmentScoped = false,
    this.defaultValue,
  });

  factory CredentialFieldSchemaModel.fromJson(Map<String, dynamic> json) {
    return CredentialFieldSchemaModel(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: json['type']?.toString() ?? 'string',
      required: json['required'] == true,
      isSecret: json['isSecret'] == true,
      description: json['description']?.toString() ?? '',
      placeholder: json['placeholder']?.toString(),
      validationRegex: json['validationRegex']?.toString(),
      environmentScoped: json['environmentScoped'] == true,
      defaultValue: json['defaultValue'],
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'type': type,
        'required': required,
        'isSecret': isSecret,
        'description': description,
        'placeholder': placeholder,
        'validationRegex': validationRegex,
        'environmentScoped': environmentScoped,
        'defaultValue': defaultValue,
      };
}

class ProviderHealthModel {
  final String status; // 'HEALTHY' | 'DEGRADED' | 'DOWN' | 'UNKNOWN' | 'ACTIVE'
  final int latencyMs;
  final String? message;
  final DateTime? lastChecked;

  const ProviderHealthModel({
    required this.status,
    required this.latencyMs,
    this.message,
    this.lastChecked,
  });

  factory ProviderHealthModel.fromJson(Map<String, dynamic> json) {
    return ProviderHealthModel(
      status: json['status']?.toString() ?? 'UNKNOWN',
      latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
      message: json['message']?.toString(),
      lastChecked: json['lastChecked'] != null
          ? DateTime.tryParse(json['lastChecked'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'latencyMs': latencyMs,
        'message': message,
        'lastChecked': lastChecked?.toIso8601String(),
      };
}

class MarketplaceProviderModel {
  final String providerId;
  final String category;
  final String name;
  final String tagline;
  final String description;
  final String icon;
  final String websiteUrl;
  final ProviderDocumentationModel documentation;
  final String version;
  final String? apiVersion;
  final String author;
  final List<String> tags;
  final List<String> supportedEnvironments;
  final String defaultEnvironment;
  final List<CredentialFieldSchemaModel> credentialSchema;
  final List<String> supportedCapabilities;
  final List<String> supportedCurrencies;
  final List<String> supportedCountries;
  final List<String>? supportedWebhookEvents;
  final String? webhookSignatureHeader;
  final bool platformAvailability;
  final List<String> tenantTierAvailability;
  final String activationState; // 'ACTIVE', 'DRAFT', 'SUSPENDED', etc.
  final int priority;
  final String? fallbackProviderId;

  // Runtime / Configured State
  final bool isConfigured;
  final String activeEnvironment;
  final bool isActive;
  final bool isEnabled;
  final bool hasCredentials;
  final Map<String, dynamic> maskedCredentials;
  final Map<String, dynamic> effectiveSettings;
  final ProviderHealthModel health;
  final DateTime? lastHealthCheck;

  const MarketplaceProviderModel({
    required this.providerId,
    required this.category,
    required this.name,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.websiteUrl,
    required this.documentation,
    required this.version,
    this.apiVersion,
    required this.author,
    required this.tags,
    required this.supportedEnvironments,
    required this.defaultEnvironment,
    required this.credentialSchema,
    required this.supportedCapabilities,
    required this.supportedCurrencies,
    required this.supportedCountries,
    this.supportedWebhookEvents,
    this.webhookSignatureHeader,
    required this.platformAvailability,
    required this.tenantTierAvailability,
    required this.activationState,
    required this.priority,
    this.fallbackProviderId,
    required this.isConfigured,
    required this.activeEnvironment,
    required this.isActive,
    required this.isEnabled,
    required this.hasCredentials,
    required this.maskedCredentials,
    required this.effectiveSettings,
    required this.health,
    this.lastHealthCheck,
  });

  factory MarketplaceProviderModel.fromJson(Map<String, dynamic> json) {
    return MarketplaceProviderModel(
      providerId: json['providerId']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      tagline: json['tagline']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'extension',
      websiteUrl: json['websiteUrl']?.toString() ?? '',
      documentation: json['documentation'] is Map<String, dynamic>
          ? ProviderDocumentationModel.fromJson(json['documentation'] as Map<String, dynamic>)
          : const ProviderDocumentationModel(overview: '', docsUrl: '', setupGuide: ''),
      version: json['version']?.toString() ?? '1.0.0',
      apiVersion: json['apiVersion']?.toString(),
      author: json['author']?.toString() ?? 'DriveGo',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      supportedEnvironments:
          (json['supportedEnvironments'] as List?)?.map((e) => e.toString()).toList() ??
              ['SANDBOX', 'LIVE'],
      defaultEnvironment: json['defaultEnvironment']?.toString() ?? 'SANDBOX',
      credentialSchema: (json['credentialSchema'] as List?)
              ?.map((e) => CredentialFieldSchemaModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      supportedCapabilities:
          (json['supportedCapabilities'] as List?)?.map((e) => e.toString()).toList() ?? [],
      supportedCurrencies:
          (json['supportedCurrencies'] as List?)?.map((e) => e.toString()).toList() ?? ['INR'],
      supportedCountries:
          (json['supportedCountries'] as List?)?.map((e) => e.toString()).toList() ?? ['IN'],
      supportedWebhookEvents:
          (json['supportedWebhookEvents'] as List?)?.map((e) => e.toString()).toList(),
      webhookSignatureHeader: json['webhookSignatureHeader']?.toString(),
      platformAvailability: json['platformAvailability'] != false,
      tenantTierAvailability:
          (json['tenantTierAvailability'] as List?)?.map((e) => e.toString()).toList() ??
              ['ALL'],
      activationState: json['activationState']?.toString() ?? 'ACTIVE',
      priority: (json['priority'] as num?)?.toInt() ?? 10,
      fallbackProviderId: json['fallbackProviderId']?.toString(),
      isConfigured: json['isConfigured'] == true,
      activeEnvironment: json['activeEnvironment']?.toString() ?? 'SANDBOX',
      isActive: json['isActive'] == true,
      isEnabled: json['isEnabled'] != false,
      hasCredentials: json['hasCredentials'] == true,
      maskedCredentials: json['maskedCredentials'] is Map<String, dynamic>
          ? json['maskedCredentials'] as Map<String, dynamic>
          : {},
      effectiveSettings: json['effectiveSettings'] is Map<String, dynamic>
          ? json['effectiveSettings'] as Map<String, dynamic>
          : {},
      health: json['health'] is Map<String, dynamic>
          ? ProviderHealthModel.fromJson(json['health'] as Map<String, dynamic>)
          : const ProviderHealthModel(status: 'UNKNOWN', latencyMs: 0),
      lastHealthCheck: json['lastHealthCheck'] != null
          ? DateTime.tryParse(json['lastHealthCheck'].toString())
          : null,
    );
  }

  MarketplaceProviderModel copyWith({
    bool? isConfigured,
    String? activeEnvironment,
    bool? isActive,
    bool? isEnabled,
    bool? hasCredentials,
    Map<String, dynamic>? maskedCredentials,
    Map<String, dynamic>? effectiveSettings,
    ProviderHealthModel? health,
    String? activationState,
    int? priority,
  }) {
    return MarketplaceProviderModel(
      providerId: providerId,
      category: category,
      name: name,
      tagline: tagline,
      description: description,
      icon: icon,
      websiteUrl: websiteUrl,
      documentation: documentation,
      version: version,
      apiVersion: apiVersion,
      author: author,
      tags: tags,
      supportedEnvironments: supportedEnvironments,
      defaultEnvironment: defaultEnvironment,
      credentialSchema: credentialSchema,
      supportedCapabilities: supportedCapabilities,
      supportedCurrencies: supportedCurrencies,
      supportedCountries: supportedCountries,
      supportedWebhookEvents: supportedWebhookEvents,
      webhookSignatureHeader: webhookSignatureHeader,
      platformAvailability: platformAvailability,
      tenantTierAvailability: tenantTierAvailability,
      activationState: activationState ?? this.activationState,
      priority: priority ?? this.priority,
      fallbackProviderId: fallbackProviderId,
      isConfigured: isConfigured ?? this.isConfigured,
      activeEnvironment: activeEnvironment ?? this.activeEnvironment,
      isActive: isActive ?? this.isActive,
      isEnabled: isEnabled ?? this.isEnabled,
      hasCredentials: hasCredentials ?? this.hasCredentials,
      maskedCredentials: maskedCredentials ?? this.maskedCredentials,
      effectiveSettings: effectiveSettings ?? this.effectiveSettings,
      health: health ?? this.health,
      lastHealthCheck: lastHealthCheck,
    );
  }
}

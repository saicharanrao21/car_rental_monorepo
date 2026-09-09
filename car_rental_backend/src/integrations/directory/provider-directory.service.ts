import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { IntegrationCategory } from '../registry/provider.types';
import { ProviderEnvironment } from '../catalog/provider-catalog.types';
import {
  CertificationLevel,
  DirectoryFilterQuery,
  ProviderDirectoryMetadata,
  ProviderPricingType,
} from './provider-directory.types';

@Injectable()
export class ProviderDirectoryService {
  private readonly logger = new Logger(ProviderDirectoryService.name);

  // In-memory directory registry: providerId -> ProviderDirectoryMetadata
  private readonly directory = new Map<string, ProviderDirectoryMetadata>();

  constructor() {
    this.seedMasterDirectory();
  }

  /**
   * Register or update a provider in the enterprise directory.
   */
  public registerProvider(metadata: ProviderDirectoryMetadata): ProviderDirectoryMetadata {
    this.directory.set(metadata.providerId.toLowerCase(), metadata);
    this.logger.log(
      `[DIRECTORY_REGISTERED] Provider [${metadata.providerId}] (${metadata.displayName}) registered under [${metadata.category}].`,
    );
    return metadata;
  }

  /**
   * Retrieve single provider by ID.
   */
  public getProvider(providerId: string): ProviderDirectoryMetadata {
    const found = this.directory.get(providerId.toLowerCase());
    if (!found) {
      throw new NotFoundException(`Provider '${providerId}' not found in directory`);
    }
    return found;
  }

  /**
   * Check if a provider exists in directory.
   */
  public hasProvider(providerId: string): boolean {
    return this.directory.has(providerId.toLowerCase());
  }

  /**
   * Find all providers matching a given filter query.
   */
  public findProviders(filter?: DirectoryFilterQuery): ProviderDirectoryMetadata[] {
    let list = Array.from(this.directory.values());

    if (!filter) return list;

    if (filter.category) {
      list = list.filter((p) => p.category === filter.category);
    }
    if (filter.country) {
      const c = filter.country.toUpperCase();
      list = list.filter((p) => p.supportedCountries.includes(c) || p.supportedCountries.includes('GLOBAL'));
    }
    if (filter.currency) {
      const cur = filter.currency.toUpperCase();
      list = list.filter((p) => p.supportedCurrencies.includes(cur));
    }
    if (filter.environment) {
      list = list.filter((p) => p.environments.includes(filter.environment!));
    }
    if (filter.certificationLevel) {
      list = list.filter((p) => p.certificationLevel === filter.certificationLevel);
    }
    if (filter.pricingType) {
      list = list.filter((p) => p.pricing.type === filter.pricingType);
    }
    if (filter.status) {
      list = list.filter((p) => p.status === filter.status);
    }
    if (filter.capability) {
      const capNorm = filter.capability.toLowerCase();
      list = list.filter((p) => p.supportedCapabilities.some((c) => c.toLowerCase().includes(capNorm)));
    }
    if (filter.paymentMethod) {
      const pmNorm = filter.paymentMethod.toUpperCase();
      list = list.filter((p) => p.supportedPaymentMethods?.includes(pmNorm));
    }
    if (filter.search) {
      const query = filter.search.toLowerCase();
      list = list.filter(
        (p) =>
          p.displayName.toLowerCase().includes(query) ||
          p.providerId.toLowerCase().includes(query) ||
          p.description.toLowerCase().includes(query) ||
          p.subcategories.some((s) => s.toLowerCase().includes(query)),
      );
    }

    return list.sort((a, b) => b.priority - a.priority);
  }

  /**
   * Get all active providers for a specific category.
   */
  public getCategoryProviders(category: IntegrationCategory): ProviderDirectoryMetadata[] {
    return this.findProviders({ category, status: 'ACTIVE' });
  }

  /**
   * Returns seamlessly compatible fallback providers for a given provider.
   */
  public getCompatibleFallbacks(providerId: string): ProviderDirectoryMetadata[] {
    const primary = this.getProvider(providerId);
    return primary.fallbackCompatibility
      .map((id) => this.directory.get(id.toLowerCase()))
      .filter((p): p is ProviderDirectoryMetadata => !!p && p.status === 'ACTIVE');
  }

  /**
   * Seed standard DriveGo enterprise directory entries across India, regional, and global providers.
   */
  private seedMasterDirectory(): void {
    const defaultSla = {
      uptimeCommitmentPercent: 99.95,
      responseTimeCommitmentMs: 250,
      supportTier: 'PRIORITY_24X7' as const,
      refundSlaDays: 3,
    };

    const defaultLimits = {
      requestsPerSecond: 100,
      burstCapacity: 200,
      maxConcurrentRequests: 50,
    };

    // 1. Razorpay
    this.registerProvider({
      providerId: 'razorpay',
      displayName: 'Razorpay Enterprise',
      legalEntityName: 'Razorpay Software Private Limited',
      category: IntegrationCategory.PAYMENT,
      subcategories: ['UPI', 'CARDS', 'NETBANKING', 'AUTODEBIT_MANDATES', 'PAYOUTS'],
      description: 'Leading Indian payment gateway with UPI Intent, Tokenization, and Instant Refunds.',
      icon: 'https://cdn.drivego.in/icons/razorpay.svg',
      websiteUrl: 'https://razorpay.com',
      documentationUrl: 'https://razorpay.com/docs',
      supportedCountries: ['IN'],
      supportedCurrencies: ['INR', 'USD', 'EUR', 'GBP', 'SGD', 'AED'],
      supportedLanguages: ['en', 'hi'],
      supportedCapabilities: [
        'PAYMENT_CREATE_PAYMENT',
        'PAYMENT_CREATE_ORDER',
        'PAYMENT_AUTHORIZE',
        'PAYMENT_CAPTURE',
        'PAYMENT_REFUND',
        'PAYMENT_PARTIAL_REFUND',
        'PAYMENT_VERIFY',
        'PAYMENT_PAYOUT',
        'PAYMENT_TOKENIZATION',
        'PAYMENT_WEBHOOK',
      ],
      supportedPaymentMethods: ['UPI', 'CARD', 'NETBANKING', 'WALLET', 'EMI', 'BNPL'],
      supportedApis: ['REST', 'WEBHOOK'],
      environments: [ProviderEnvironment.SANDBOX, ProviderEnvironment.LIVE],
      defaultEnvironment: ProviderEnvironment.SANDBOX,
      webhookSupport: { supported: true, signatureHeader: 'x-razorpay-signature' },
      complianceCertifications: ['PCI_DSS_L1', 'ISO_27001', 'SOC2_TYPE2', 'RBI_COMPLIANT'],
      onboardingRequirements: ['KEY_ID', 'KEY_SECRET', 'MERCHANT_ACCOUNT_ID'],
      credentialSchema: [
        { key: 'keyId', label: 'Key ID', type: 'string', required: true, isSecret: false, description: 'API Key ID' },
        { key: 'keySecret', label: 'Key Secret', type: 'password', required: true, isSecret: true, description: 'API Secret' },
      ],
      pricing: { type: ProviderPricingType.TRANSACTIONAL, fixedFee: 0, percentageFee: 1.95, currency: 'INR' },
      sla: defaultSla,
      rateLimits: { requestsPerSecond: 250, burstCapacity: 500, maxConcurrentRequests: 100 },
      expectedLatencyP50Ms: 180,
      expectedLatencyP95Ms: 420,
      reliabilityScore: 0.998,
      priority: 95,
      status: 'ACTIVE',
      certificationLevel: CertificationLevel.ENTERPRISE_CERTIFIED,
      version: '2.4.0',
      apiVersion: 'v1',
      fallbackCompatibility: ['cashfree', 'phonepe', 'stripe'],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    // 2. Cashfree
    this.registerProvider({
      providerId: 'cashfree',
      displayName: 'Cashfree Payments',
      legalEntityName: 'Cashfree Payments India Private Limited',
      category: IntegrationCategory.PAYMENT,
      subcategories: ['PAYMENT_GATEWAY', 'PAYOUTS', 'VERIFICATION_SUITE', 'AUTO_COLLECT'],
      description: 'Full-stack Indian payment aggregator with high UPI success rates and instant vendor settlements.',
      icon: 'https://cdn.drivego.in/icons/cashfree.svg',
      websiteUrl: 'https://cashfree.com',
      documentationUrl: 'https://docs.cashfree.com',
      supportedCountries: ['IN'],
      supportedCurrencies: ['INR', 'USD'],
      supportedLanguages: ['en'],
      supportedCapabilities: [
        'PAYMENT_CREATE_PAYMENT',
        'PAYMENT_CREATE_ORDER',
        'PAYMENT_CAPTURE',
        'PAYMENT_REFUND',
        'PAYMENT_PARTIAL_REFUND',
        'PAYMENT_VERIFY',
        'PAYMENT_PAYOUT',
        'PAYMENT_WEBHOOK',
      ],
      supportedPaymentMethods: ['UPI', 'CARD', 'NETBANKING', 'WALLET', 'BNPL'],
      supportedApis: ['REST', 'WEBHOOK'],
      environments: [ProviderEnvironment.SANDBOX, ProviderEnvironment.LIVE],
      defaultEnvironment: ProviderEnvironment.SANDBOX,
      webhookSupport: { supported: true, signatureHeader: 'x-webhook-signature' },
      complianceCertifications: ['PCI_DSS_L1', 'ISO_27001', 'RBI_COMPLIANT'],
      onboardingRequirements: ['APP_ID', 'SECRET_KEY'],
      credentialSchema: [
        { key: 'appId', label: 'App ID', type: 'string', required: true, isSecret: false, description: 'Cashfree App ID' },
        { key: 'secretKey', label: 'Secret Key', type: 'password', required: true, isSecret: true, description: 'Cashfree Secret Key' },
      ],
      pricing: { type: ProviderPricingType.TRANSACTIONAL, fixedFee: 0, percentageFee: 1.85, currency: 'INR' },
      sla: defaultSla,
      rateLimits: defaultLimits,
      expectedLatencyP50Ms: 195,
      expectedLatencyP95Ms: 460,
      reliabilityScore: 0.995,
      priority: 90,
      status: 'ACTIVE',
      certificationLevel: CertificationLevel.ENTERPRISE_CERTIFIED,
      version: '2.1.0',
      apiVersion: '2023-08-01',
      fallbackCompatibility: ['razorpay', 'phonepe'],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    // 3. Stripe
    this.registerProvider({
      providerId: 'stripe',
      displayName: 'Stripe Global Payments',
      legalEntityName: 'Stripe, Inc.',
      category: IntegrationCategory.PAYMENT,
      subcategories: ['INTERNATIONAL_CARDS', 'MULTI_CURRENCY', 'RADAR_FRAUD', 'SUBSCRIPTIONS'],
      description: 'Global financial infrastructure for cross-border tourist bookings and multi-currency billing.',
      icon: 'https://cdn.drivego.in/icons/stripe.svg',
      websiteUrl: 'https://stripe.com',
      documentationUrl: 'https://stripe.com/docs',
      supportedCountries: ['GLOBAL', 'IN', 'US', 'GB', 'AE', 'SG', 'EU'],
      supportedCurrencies: ['USD', 'EUR', 'GBP', 'INR', 'AED', 'SGD', 'CAD', 'AUD'],
      supportedLanguages: ['en', 'fr', 'es', 'de', 'ja'],
      supportedCapabilities: [
        'PAYMENT_CREATE_PAYMENT',
        'PAYMENT_AUTHORIZE',
        'PAYMENT_CAPTURE',
        'PAYMENT_REFUND',
        'PAYMENT_PARTIAL_REFUND',
        'PAYMENT_TOKENIZATION',
        'PAYMENT_WEBHOOK',
      ],
      supportedPaymentMethods: ['CARD', 'APPLE_PAY', 'GOOGLE_PAY'],
      supportedApis: ['REST', 'WEBHOOK'],
      environments: [ProviderEnvironment.SANDBOX, ProviderEnvironment.LIVE],
      defaultEnvironment: ProviderEnvironment.SANDBOX,
      webhookSupport: { supported: true, signatureHeader: 'stripe-signature' },
      complianceCertifications: ['PCI_DSS_L1', 'SOC2_TYPE2', 'ISO_27001', 'GDPR'],
      onboardingRequirements: ['PUBLISHABLE_KEY', 'SECRET_KEY', 'WEBHOOK_SECRET'],
      credentialSchema: [
        { key: 'publishableKey', label: 'Publishable Key', type: 'string', required: true, isSecret: false, description: 'Stripe pk' },
        { key: 'secretKey', label: 'Secret Key', type: 'password', required: true, isSecret: true, description: 'Stripe sk' },
      ],
      pricing: { type: ProviderPricingType.TRANSACTIONAL, fixedFee: 30, percentageFee: 2.9, currency: 'USD' },
      sla: defaultSla,
      rateLimits: { requestsPerSecond: 500, burstCapacity: 1000, maxConcurrentRequests: 200 },
      expectedLatencyP50Ms: 220,
      expectedLatencyP95Ms: 500,
      reliabilityScore: 0.999,
      priority: 85,
      status: 'ACTIVE',
      certificationLevel: CertificationLevel.ENTERPRISE_CERTIFIED,
      version: '3.0.0',
      apiVersion: '2023-10-16',
      fallbackCompatibility: ['adyen', 'razorpay'],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    // 4. Meta WhatsApp Cloud API
    this.registerProvider({
      providerId: 'meta',
      displayName: 'Meta WhatsApp Cloud API',
      legalEntityName: 'Meta Platforms, Inc.',
      category: IntegrationCategory.MESSAGING_WHATSAPP,
      subcategories: ['BUSINESS_MESSAGING', 'TEMPLATES', 'OTP', 'RICH_MEDIA'],
      description: 'Official direct WhatsApp Cloud API with highest delivery throughput and global reliability.',
      icon: 'https://cdn.drivego.in/icons/meta-whatsapp.svg',
      websiteUrl: 'https://developers.facebook.com/docs/whatsapp',
      documentationUrl: 'https://developers.facebook.com/docs/whatsapp/cloud-api',
      supportedCountries: ['GLOBAL', 'IN'],
      supportedCurrencies: ['INR', 'USD'],
      supportedLanguages: ['en', 'hi', 'ar', 'es'],
      supportedCapabilities: [
        'WHATSAPP_SEND_TEXT',
        'WHATSAPP_SEND_TEMPLATE',
        'WHATSAPP_SEND_MEDIA',
        'WHATSAPP_OTP',
        'WHATSAPP_DELIVERY_STATUS',
        'WHATSAPP_WEBHOOK',
      ],
      supportedApis: ['REST', 'WEBHOOK'],
      environments: [ProviderEnvironment.SANDBOX, ProviderEnvironment.LIVE],
      defaultEnvironment: ProviderEnvironment.SANDBOX,
      webhookSupport: { supported: true, signatureHeader: 'x-hub-signature-256' },
      complianceCertifications: ['SOC2_TYPE2', 'ISO_27001', 'GDPR'],
      onboardingRequirements: ['PHONE_NUMBER_ID', 'WABA_ID', 'SYSTEM_USER_ACCESS_TOKEN'],
      credentialSchema: [
        { key: 'phoneNumberId', label: 'Phone Number ID', type: 'string', required: true, isSecret: false, description: 'WhatsApp Business Phone ID' },
        { key: 'accessToken', label: 'Access Token', type: 'password', required: true, isSecret: true, description: 'Meta System User Token' },
      ],
      pricing: { type: ProviderPricingType.TRANSACTIONAL, fixedFee: 0.45, percentageFee: 0, currency: 'INR' },
      sla: defaultSla,
      rateLimits: { requestsPerSecond: 80, burstCapacity: 150, maxConcurrentRequests: 50 },
      expectedLatencyP50Ms: 280,
      expectedLatencyP95Ms: 650,
      reliabilityScore: 0.996,
      priority: 95,
      status: 'ACTIVE',
      certificationLevel: CertificationLevel.ENTERPRISE_CERTIFIED,
      version: '2.0.0',
      apiVersion: 'v18.0',
      fallbackCompatibility: ['gupshup'],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    // 5. Gupshup WhatsApp & SMS
    this.registerProvider({
      providerId: 'gupshup',
      displayName: 'Gupshup Messaging Enterprise',
      legalEntityName: 'Gupshup Technology India Pvt Ltd',
      category: IntegrationCategory.MESSAGING_WHATSAPP,
      subcategories: ['WHATSAPP_BSP', 'SMS_GATEWAY', 'CONVERSATIONAL_AI'],
      description: 'Leading WhatsApp Business Solution Provider (BSP) with high Indian telecom operator redundancy.',
      icon: 'https://cdn.drivego.in/icons/gupshup.svg',
      websiteUrl: 'https://gupshup.io',
      documentationUrl: 'https://docs.gupshup.io',
      supportedCountries: ['IN', 'GLOBAL'],
      supportedCurrencies: ['INR', 'USD'],
      supportedLanguages: ['en', 'hi'],
      supportedCapabilities: [
        'WHATSAPP_SEND_TEXT',
        'WHATSAPP_SEND_TEMPLATE',
        'WHATSAPP_OTP',
        'WHATSAPP_DELIVERY_STATUS',
      ],
      supportedApis: ['REST', 'WEBHOOK'],
      environments: [ProviderEnvironment.SANDBOX, ProviderEnvironment.LIVE],
      defaultEnvironment: ProviderEnvironment.SANDBOX,
      webhookSupport: { supported: true },
      complianceCertifications: ['ISO_27001', 'SOC2_TYPE2'],
      onboardingRequirements: ['API_KEY', 'APP_NAME'],
      credentialSchema: [
        { key: 'apiKey', label: 'API Key', type: 'password', required: true, isSecret: true, description: 'Gupshup App Token' },
        { key: 'appName', label: 'App Name', type: 'string', required: true, isSecret: false, description: 'Gupshup App Name' },
      ],
      pricing: { type: ProviderPricingType.TRANSACTIONAL, fixedFee: 0.48, percentageFee: 0, currency: 'INR' },
      sla: defaultSla,
      rateLimits: defaultLimits,
      expectedLatencyP50Ms: 310,
      expectedLatencyP95Ms: 720,
      reliabilityScore: 0.992,
      priority: 88,
      status: 'ACTIVE',
      certificationLevel: CertificationLevel.ENTERPRISE_CERTIFIED,
      version: '1.8.0',
      fallbackCompatibility: ['meta'],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    // 6. Surepass KYC Verification
    this.registerProvider({
      providerId: 'surepass',
      displayName: 'Surepass Identity Verification',
      legalEntityName: 'Surepass Technologies Private Limited',
      category: IntegrationCategory.IDENTITY_VERIFICATION,
      subcategories: ['GOVERNMENT_APIS', 'DRIVING_LICENCE', 'PAN_VERIFY', 'AADHAAR_OKYC', 'VEHICLE_RC'],
      description: 'Instant government API verification engine for Indian DL, RC, PAN, GST, and Aadhaar.',
      icon: 'https://cdn.drivego.in/icons/surepass.svg',
      websiteUrl: 'https://surepass.io',
      documentationUrl: 'https://docs.surepass.io',
      supportedCountries: ['IN'],
      supportedCurrencies: ['INR'],
      supportedLanguages: ['en', 'hi'],
      supportedCapabilities: [
        'KYC_PAN_VERIFY',
        'KYC_DL_VERIFY',
        'KYC_AADHAAR_OKYC',
        'KYC_GST_VERIFY',
        'KYC_VEHICLE_RC_VERIFY',
        'KYC_DOCUMENT_OCR',
      ],
      supportedApis: ['REST'],
      environments: [ProviderEnvironment.SANDBOX, ProviderEnvironment.LIVE],
      defaultEnvironment: ProviderEnvironment.SANDBOX,
      webhookSupport: { supported: false },
      complianceCertifications: ['ISO_27001', 'SOC2_TYPE2', 'UIDAI_COMPLIANT'],
      onboardingRequirements: ['BEARER_TOKEN'],
      credentialSchema: [
        { key: 'token', label: 'Bearer Token', type: 'password', required: true, isSecret: true, description: 'Surepass API Token' },
      ],
      pricing: { type: ProviderPricingType.TRANSACTIONAL, fixedFee: 2.5, percentageFee: 0, currency: 'INR' },
      sla: defaultSla,
      rateLimits: defaultLimits,
      expectedLatencyP50Ms: 350,
      expectedLatencyP95Ms: 850,
      reliabilityScore: 0.991,
      priority: 95,
      status: 'ACTIVE',
      certificationLevel: CertificationLevel.ENTERPRISE_CERTIFIED,
      version: '1.4.0',
      fallbackCompatibility: ['hyperverge'],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    // 7. Google Maps Platform
    this.registerProvider({
      providerId: 'google',
      displayName: 'Google Maps Platform',
      legalEntityName: 'Google LLC',
      category: IntegrationCategory.MAPS,
      subcategories: ['GEOCODING', 'DIRECTIONS', 'DISTANCE_MATRIX', 'PLACES_AUTOCOMPLETE'],
      description: 'Gold standard global mapping, routing, traffic analysis, and geocoding platform.',
      icon: 'https://cdn.drivego.in/icons/google-maps.svg',
      websiteUrl: 'https://mapsplatform.google.com',
      documentationUrl: 'https://developers.google.com/maps',
      supportedCountries: ['GLOBAL', 'IN'],
      supportedCurrencies: ['INR', 'USD'],
      supportedLanguages: ['en', 'hi', 'ar', 'es'],
      supportedCapabilities: [
        'MAPS_GEOCODE',
        'MAPS_REVERSE_GEOCODE',
        'MAPS_DIRECTIONS_ROUTE',
        'MAPS_DISTANCE_MATRIX',
        'MAPS_PLACES_AUTOCOMPLETE',
        'MAPS_GEOFENCING',
      ],
      supportedApis: ['REST', 'SDK'],
      environments: [ProviderEnvironment.SANDBOX, ProviderEnvironment.LIVE],
      defaultEnvironment: ProviderEnvironment.SANDBOX,
      webhookSupport: { supported: false },
      complianceCertifications: ['ISO_27001', 'SOC2_TYPE2', 'GDPR'],
      onboardingRequirements: ['API_KEY'],
      credentialSchema: [
        { key: 'apiKey', label: 'Google Maps API Key', type: 'password', required: true, isSecret: true, description: 'GCP Maps Key' },
      ],
      pricing: { type: ProviderPricingType.TIERED, fixedFee: 0.4, percentageFee: 0, currency: 'INR' },
      sla: defaultSla,
      rateLimits: { requestsPerSecond: 1000, burstCapacity: 2000, maxConcurrentRequests: 300 },
      expectedLatencyP50Ms: 140,
      expectedLatencyP95Ms: 320,
      reliabilityScore: 0.999,
      priority: 95,
      status: 'ACTIVE',
      certificationLevel: CertificationLevel.ENTERPRISE_CERTIFIED,
      version: '3.1.0',
      fallbackCompatibility: ['mapbox'],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    // 8. Traccar Telematics & GPS
    this.registerProvider({
      providerId: 'traccar',
      displayName: 'Traccar Telematics Engine',
      legalEntityName: 'Traccar LLC',
      category: IntegrationCategory.VEHICLE_TRACKING,
      subcategories: ['GPS_TRACKING', 'REMOTE_IMMOBILIZATION', 'CANBUS_ODOMETER', 'GEOFENCE_ALERTS'],
      description: 'Enterprise IoT telematics protocol server supporting OBD-II dongles, Teltonika, Queclink, and AIS-140.',
      icon: 'https://cdn.drivego.in/icons/traccar.svg',
      websiteUrl: 'https://traccar.org',
      documentationUrl: 'https://www.traccar.org/api-documentation',
      supportedCountries: ['GLOBAL', 'IN'],
      supportedCurrencies: ['INR', 'USD'],
      supportedLanguages: ['en'],
      supportedCapabilities: [
        'TELEMATICS_LIVE_GPS',
        'TELEMATICS_INGEST',
        'TELEMATICS_IMMOBILIZE',
        'TELEMATICS_LOCK_UNLOCK',
        'TELEMATICS_ODOMETER_SYNC',
        'TELEMATICS_FUEL_EV_METRICS',
        'TELEMATICS_DIAGNOSTICS',
      ],
      supportedApis: ['REST', 'WEBHOOK'],
      environments: [ProviderEnvironment.SANDBOX, ProviderEnvironment.LIVE],
      defaultEnvironment: ProviderEnvironment.SANDBOX,
      webhookSupport: { supported: true },
      complianceCertifications: ['AIS_140_COMPLIANT', 'ISO_27001'],
      onboardingRequirements: ['SERVER_URL', 'API_KEY'],
      credentialSchema: [
        { key: 'serverUrl', label: 'Traccar Server URL', type: 'url', required: true, isSecret: false, description: 'Traccar host URL' },
        { key: 'apiKey', label: 'API Key', type: 'password', required: true, isSecret: true, description: 'Traccar User Token' },
      ],
      pricing: { type: ProviderPricingType.SUBSCRIPTION, fixedFee: 0, percentageFee: 0, monthlyPlatformFee: 150, currency: 'INR' },
      sla: defaultSla,
      rateLimits: defaultLimits,
      expectedLatencyP50Ms: 160,
      expectedLatencyP95Ms: 390,
      reliabilityScore: 0.994,
      priority: 90,
      status: 'ACTIVE',
      certificationLevel: CertificationLevel.ENTERPRISE_CERTIFIED,
      version: '5.8.0',
      fallbackCompatibility: ['mock_telematics'],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
  }
}

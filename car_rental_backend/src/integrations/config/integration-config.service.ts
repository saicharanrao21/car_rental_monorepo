import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SystemConfigService } from '../../config-engine/system-config.service';
import { SecretVaultService } from '../security/secret-vault.service';
import { IntegrationCategory, IntegrationContext } from '../registry/provider.types';
import {
  IntegrationProviderConfig,
  ResolvedProviderConfig,
  CategoryActiveProviderConfig,
} from './integration-config.types';

@Injectable()
export class IntegrationConfigService {
  private readonly logger = new Logger(IntegrationConfigService.name);

  // Default active providers per category if none explicitly set in DB
  private static readonly DEFAULT_ACTIVE_PROVIDERS: Record<IntegrationCategory, string> = {
    [IntegrationCategory.PAYMENT]: 'razorpay',
    [IntegrationCategory.MESSAGING_WHATSAPP]: 'meta',
    [IntegrationCategory.MESSAGING_SMS]: 'msg91',
    [IntegrationCategory.MESSAGING_EMAIL]: 'resend',
    [IntegrationCategory.MESSAGING_PUSH]: 'fcm',
    [IntegrationCategory.STORAGE]: 'r2',
    [IntegrationCategory.MAPS]: 'google',
    [IntegrationCategory.IDENTITY_VERIFICATION]: 'surepass',
    [IntegrationCategory.VEHICLE_TRACKING]: 'mock_telematics',
    [IntegrationCategory.ACCOUNTING]: 'mock_accounting',
  };

  constructor(
    private readonly systemConfigService: SystemConfigService,
    private readonly secretVault: SecretVaultService,
    private readonly configService: ConfigService,
  ) {}

  /**
   * Resolves the active provider ID for a category taking into account context (vendor/branch overrides).
   */
  async resolveActiveProviderId(
    category: IntegrationCategory,
    context?: IntegrationContext,
  ): Promise<string> {
    // 1. Check Branch Override
    if (context?.branchId) {
      const branchKey = `integrations.active.branch.${context.branchId}.${category}`;
      try {
        const branchActive = await this.systemConfigService.getConfig<string>(branchKey);
        if (branchActive) return branchActive;
      } catch (_) {}
    }

    // 2. Check Vendor Override
    if (context?.vendorId) {
      const vendorKey = `integrations.active.vendor.${context.vendorId}.${category}`;
      try {
        const vendorActive = await this.systemConfigService.getConfig<string>(vendorKey);
        if (vendorActive) return vendorActive;
      } catch (_) {}
    }

    // 3. Check Platform Level
    const platformKey = `integrations.active.${category}`;
    try {
      const platformActive = await this.systemConfigService.getConfig<CategoryActiveProviderConfig | string>(platformKey);
      if (typeof platformActive === 'string') return platformActive;
      if (platformActive?.activeProviderId) return platformActive.activeProviderId;
    } catch (_) {}

    // 4. Default Fallback
    return IntegrationConfigService.DEFAULT_ACTIVE_PROVIDERS[category] || 'mock';
  }

  /**
   * Resolves full configuration and decrypted credentials for a provider with hierarchy:
   * Branch -> Vendor -> Platform.
   */
  async resolveProviderConfig(
    category: IntegrationCategory,
    providerId: string,
    context?: IntegrationContext,
  ): Promise<ResolvedProviderConfig> {
    // Try resolving from DB at hierarchy levels:
    let rawConfig: IntegrationProviderConfig | null = null;
    let resolvedLevel: 'PLATFORM' | 'VENDOR' | 'BRANCH' = 'PLATFORM';
    let resolvedEntityId: string | undefined = undefined;

    // 1. Branch Level
    if (context?.branchId) {
      const key = `integrations.provider.branch.${context.branchId}.${category}.${providerId}`;
      try {
        rawConfig = await this.systemConfigService.getConfig<IntegrationProviderConfig>(key);
        if (rawConfig) {
          resolvedLevel = 'BRANCH';
          resolvedEntityId = context.branchId;
        }
      } catch (_) {}
    }

    // 2. Vendor Level
    if (!rawConfig && context?.vendorId) {
      const key = `integrations.provider.vendor.${context.vendorId}.${category}.${providerId}`;
      try {
        rawConfig = await this.systemConfigService.getConfig<IntegrationProviderConfig>(key);
        if (rawConfig) {
          resolvedLevel = 'VENDOR';
          resolvedEntityId = context.vendorId;
        }
      } catch (_) {}
    }

    // 3. Platform Level
    if (!rawConfig) {
      const key = `integrations.provider.${category}.${providerId}`;
      try {
        rawConfig = await this.systemConfigService.getConfig<IntegrationProviderConfig>(key);
        if (rawConfig) {
          resolvedLevel = 'PLATFORM';
        }
      } catch (_) {}
    }

    // 4. Fallback to environment variables if not yet configured in DB
    if (!rawConfig) {
      const envConfig = this.resolveConfigFromEnv(category, providerId);
      return {
        providerId,
        category,
        isEnabled: envConfig.isEnabled,
        credentials: envConfig.credentials,
        settings: envConfig.settings,
        resolvedLevel: 'PLATFORM',
      };
    }

    // Decrypt credentials for internal provider consumption
    const decryptedCredentials: Record<string, string> = {};
    if (rawConfig.credentials) {
      for (const [credKey, credVal] of Object.entries(rawConfig.credentials)) {
        decryptedCredentials[credKey] = this.secretVault.decrypt(credVal);
      }
    }

    return {
      providerId,
      category,
      isEnabled: rawConfig.isEnabled ?? true,
      credentials: decryptedCredentials,
      settings: rawConfig.settings || {},
      resolvedLevel,
      resolvedEntityId,
    };
  }

  /**
   * Sets or updates provider configuration in DB, encrypting credentials before persisting.
   */
  async setProviderConfig(
    category: IntegrationCategory,
    providerId: string,
    payload: {
      isEnabled?: boolean;
      priority?: number;
      credentials?: Record<string, string>;
      settings?: Record<string, any>;
    },
    userId?: string,
    context?: IntegrationContext,
  ): Promise<void> {
    let key = `integrations.provider.${category}.${providerId}`;
    if (context?.branchId) {
      key = `integrations.provider.branch.${context.branchId}.${category}.${providerId}`;
    } else if (context?.vendorId) {
      key = `integrations.provider.vendor.${context.vendorId}.${category}.${providerId}`;
    }

    // Encrypt any credentials provided
    const encryptedCredentials: Record<string, string> = {};
    if (payload.credentials) {
      for (const [k, v] of Object.entries(payload.credentials)) {
        encryptedCredentials[k] = this.secretVault.encrypt(v);
      }
    }

    // Fetch existing if present to merge
    let existing: IntegrationProviderConfig | null = null;
    try {
      existing = await this.systemConfigService.getConfig<IntegrationProviderConfig>(key);
    } catch (_) {}

    const updatedConfig: IntegrationProviderConfig = {
      providerId,
      category,
      isEnabled: payload.isEnabled ?? existing?.isEnabled ?? true,
      priority: payload.priority ?? existing?.priority ?? 1,
      credentials: {
        ...(existing?.credentials || {}),
        ...encryptedCredentials,
      },
      settings: {
        ...(existing?.settings || {}),
        ...(payload.settings || {}),
      },
      updatedAt: new Date(),
      updatedBy: userId || 'system',
    };

    await this.systemConfigService.setConfig(key, updatedConfig, userId, {
      reason: `Updated integration config for [${category}/${providerId}]`,
    });

    this.logger.log(`[INTEGRATION_CONFIG] Updated provider config for [${category}/${providerId}]`);
  }

  /**
   * Sets the active provider for a category at Platform or Vendor/Branch level.
   */
  async setActiveProvider(
    category: IntegrationCategory,
    providerId: string,
    userId?: string,
    context?: IntegrationContext,
  ): Promise<void> {
    let key = `integrations.active.${category}`;
    if (context?.branchId) {
      key = `integrations.active.branch.${context.branchId}.${category}`;
    } else if (context?.vendorId) {
      key = `integrations.active.vendor.${context.vendorId}.${category}`;
    }

    await this.systemConfigService.setConfig(key, providerId, userId, {
      reason: `Changed active provider for [${category}] to [${providerId}]`,
    });

    this.logger.log(`[INTEGRATION_CONFIG] Switched active provider for [${category}] to [${providerId}]`);
  }

  /**
   * Retrieves sanitized/masked provider config for Admin GET responses (NEVER exposes plaintext secrets).
   */
  async getMaskedProviderConfig(
    category: IntegrationCategory,
    providerId: string,
    context?: IntegrationContext,
  ): Promise<Record<string, any>> {
    const resolved = await this.resolveProviderConfig(category, providerId, context);
    const maskedCredentials: Record<string, string> = {};

    for (const [k, v] of Object.entries(resolved.credentials)) {
      maskedCredentials[k] = this.secretVault.maskSecret(v);
    }

    return {
      providerId: resolved.providerId,
      category: resolved.category,
      isEnabled: resolved.isEnabled,
      resolvedLevel: resolved.resolvedLevel,
      resolvedEntityId: resolved.resolvedEntityId,
      credentials: maskedCredentials,
      settings: resolved.settings,
    };
  }

  /**
   * Resolves fallback credentials and settings from environment variables.
   */
  private resolveConfigFromEnv(
    category: IntegrationCategory,
    providerId: string,
  ): { isEnabled: boolean; credentials: Record<string, string>; settings: Record<string, any> } {
    const credentials: Record<string, string> = {};
    const settings: Record<string, any> = {};
    let isEnabled = true;

    switch (providerId) {
      case 'razorpay':
        credentials['keyId'] = this.configService.get<string>('RAZORPAY_KEY_ID') || '';
        credentials['keySecret'] = this.configService.get<string>('RAZORPAY_KEY_SECRET') || '';
        credentials['webhookSecret'] = this.configService.get<string>('RAZORPAY_WEBHOOK_SECRET') || '';
        settings['useMock'] = this.configService.get<string>('RAZORPAY_USE_MOCK') === 'true';
        break;
      case 'stripe':
        credentials['publishableKey'] = this.configService.get<string>('STRIPE_PUBLISHABLE_KEY') || '';
        credentials['secretKey'] = this.configService.get<string>('STRIPE_SECRET_KEY') || '';
        credentials['webhookSecret'] = this.configService.get<string>('STRIPE_WEBHOOK_SECRET') || '';
        break;
      case 'meta':
        credentials['accessToken'] = this.configService.get<string>('WHATSAPP_ACCESS_TOKEN') || '';
        credentials['phoneNumberId'] = this.configService.get<string>('WHATSAPP_PHONE_NUMBER_ID') || '';
        settings['apiVersion'] = this.configService.get<string>('WHATSAPP_API_VERSION') || 'v20.0';
        break;
      case 'msg91':
        credentials['authKey'] = this.configService.get<string>('MSG91_AUTH_KEY') || '';
        credentials['templateId'] = this.configService.get<string>('MSG91_TEMPLATE_ID') || '';
        settings['senderId'] = this.configService.get<string>('MSG91_SENDER_ID') || 'DRIVGO';
        break;
      case 'twilio':
        credentials['accountSid'] = this.configService.get<string>('TWILIO_ACCOUNT_SID') || '';
        credentials['authToken'] = this.configService.get<string>('TWILIO_AUTH_TOKEN') || '';
        settings['fromNumber'] = this.configService.get<string>('TWILIO_PHONE_NUMBER') || '';
        break;
      case 'resend':
        credentials['apiKey'] = this.configService.get<string>('RESEND_API_KEY') || '';
        settings['fromEmail'] = this.configService.get<string>('EMAIL_FROM') || 'notifications@drivego.in';
        break;
      case 'fcm':
        credentials['projectId'] = this.configService.get<string>('FIREBASE_PROJECT_ID') || '';
        credentials['clientEmail'] = this.configService.get<string>('FIREBASE_CLIENT_EMAIL') || '';
        credentials['privateKey'] = this.configService.get<string>('FIREBASE_PRIVATE_KEY') || '';
        break;
      case 'r2':
      case 's3':
        credentials['accessKeyId'] = this.configService.get<string>('R2_ACCESS_KEY_ID') || '';
        credentials['secretAccessKey'] = this.configService.get<string>('R2_SECRET_ACCESS_KEY') || '';
        settings['bucketName'] = this.configService.get<string>('R2_BUCKET_NAME') || 'drivego-uploads';
        settings['endpoint'] = this.configService.get<string>('R2_ENDPOINT') || '';
        settings['publicUrl'] = this.configService.get<string>('R2_PUBLIC_URL') || '';
        settings['useMock'] = this.configService.get<string>('R2_USE_MOCK') === 'true';
        break;
      case 'google':
        credentials['apiKey'] = this.configService.get<string>('GOOGLE_MAPS_API_KEY') || '';
        break;
      case 'surepass':
        credentials['apiKey'] = this.configService.get<string>('SUREPASS_API_KEY') || '';
        break;
    }

    return { isEnabled, credentials, settings };
  }
}

import { Injectable, Logger, BadRequestException, Optional } from '@nestjs/common';
import { ProviderDirectoryService } from './provider-directory.service';
import { CapabilityMatrixService } from './capability-matrix.service';
import { ProviderChangeAuditService, ProviderChangeType } from '../governance/provider-change-audit.service';
import {
  CertificationLevel,
  ProviderDirectoryMetadata,
  ProviderPricingType,
} from './provider-directory.types';
import { IntegrationCategory } from '../registry/provider.types';

export interface OnboardingValidationResult {
  valid: boolean;
  isValid: boolean;
  stepResults?: Array<{
    step: string;
    passed: boolean;
    message?: string;
  }>;
  errors: string[];
  warnings?: string[];
}

@Injectable()
export class ProviderOnboardingService {
  private readonly logger = new Logger(ProviderOnboardingService.name);

  constructor(
    private readonly directoryService: ProviderDirectoryService,
    private readonly capabilityService: CapabilityMatrixService,
    @Optional() private readonly auditService?: ProviderChangeAuditService,
  ) {}

  /**
   * Validates a candidate provider definition.
   */
  public validateDefinition(def: Partial<ProviderDirectoryMetadata>): OnboardingValidationResult {
    const errors: string[] = [];
    const warnings: string[] = [];

    if (!def.providerId || !/^[a-z0-9_-]+$/.test(def.providerId)) {
      errors.push('providerId is required and must only contain lowercase alphanumeric, hyphen, or underscore');
    }

    if (!def.displayName || def.displayName.trim().length < 2) {
      errors.push('displayName is required and must be at least 2 characters');
    }

    if (!def.category || !Object.values(IntegrationCategory).includes(def.category as any)) {
      errors.push(`category is invalid or unsupported: ${def.category}`);
    }

    if (!def.description || def.description.trim().length < 10) {
      errors.push('description is required and must be at least 10 characters');
    }

    if (!Array.isArray(def.supportedCountries) || def.supportedCountries.length === 0) {
      errors.push('supportedCountries must be a non-empty array of ISO country codes or GLOBAL');
    }

    if (!Array.isArray(def.supportedCurrencies) || def.supportedCurrencies.length === 0) {
      errors.push('supportedCurrencies must be a non-empty array of ISO currency codes');
    }

    if (!Array.isArray(def.supportedCapabilities) || def.supportedCapabilities.length === 0) {
      errors.push('supportedCapabilities must be a non-empty array of capabilities');
    }

    if (def.priority === undefined || typeof def.priority !== 'number' || def.priority < 1 || def.priority > 100) {
      errors.push('priority must be a number between 1 and 100');
    }

    const isValid = errors.length === 0;
    return {
      valid: isValid,
      isValid,
      errors,
      warnings,
    };
  }

  /**
   * Submits and completes provider onboarding.
   */
  public async submitOnboarding(
    def: Partial<ProviderDirectoryMetadata>,
    actorId = 'admin_onboarding',
    actorRole = 'ADMIN',
  ): Promise<ProviderDirectoryMetadata> {
    const validation = this.validateDefinition(def);
    if (!validation.isValid) {
      throw new BadRequestException(`Validation failed: ${validation.errors.join(', ')}`);
    }

    const providerMetadata: ProviderDirectoryMetadata = {
      providerId: def.providerId!,
      displayName: def.displayName!,
      category: def.category as any,
      subcategories: def.subcategories || [],
      description: def.description!,
      icon: def.icon || 'extension',
      websiteUrl: def.websiteUrl || '',
      documentationUrl: def.documentationUrl || '',
      supportedCountries: def.supportedCountries!,
      supportedCurrencies: def.supportedCurrencies!,
      supportedLanguages: def.supportedLanguages || ['en'],
      supportedCapabilities: def.supportedCapabilities!,
      environments: def.environments || ['SANDBOX' as any, 'LIVE' as any],
      defaultEnvironment: def.defaultEnvironment || ('SANDBOX' as any),
      credentialSchema: def.credentialSchema || [],
      pricing: (def.pricing as any) || {
        type: ProviderPricingType.FREE_TIER_THEN_USAGE,
        fixedFee: 0,
        percentageFee: 0,
        currency: 'USD',
      },
      sla: def.sla || { uptimeCommitmentPercent: 99.9, responseTimeCommitmentMs: 300, supportTier: 'STANDARD' as any },
      rateLimits: def.rateLimits || { requestsPerSecond: 50, burstCapacity: 100, maxConcurrentRequests: 25 },
      reliabilityScore: def.reliabilityScore || 0.95,
      priority: def.priority || 50,
      status: 'ACTIVE' as any,
      certificationLevel: def.certificationLevel || CertificationLevel.COMMUNITY,
      version: def.version || '1.0.0',
      apiVersion: def.apiVersion || 'v1',
      supportedApis: def.supportedApis || ['REST', 'WEBHOOK'],
      webhookSupport: def.webhookSupport || { supported: false },
      complianceCertifications: def.complianceCertifications || [],
      onboardingRequirements: def.onboardingRequirements || [],
      expectedLatencyP50Ms: def.expectedLatencyP50Ms || 200,
      expectedLatencyP95Ms: def.expectedLatencyP95Ms || 450,
      fallbackCompatibility: def.fallbackCompatibility || [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    const registered = this.directoryService.registerProvider(providerMetadata);

    if (this.auditService) {
      await this.auditService.recordChange({
        providerId: registered.providerId,
        category: registered.category,
        changeType: ProviderChangeType.ONBOARDING_COMPLETED,
        actorId,
        actorRole,
        reason: `Provider '${registered.displayName}' onboarded via Enterprise Control Plane`,
        afterSnapshot: {
          providerId: registered.providerId,
          displayName: registered.displayName,
          category: registered.category,
          capabilities: registered.supportedCapabilities,
          priority: registered.priority,
        },
      });
    }

    this.logger.log(
      `[ONBOARDING_SUCCESS] Provider [${registered.providerId}] successfully onboarded by [${actorId}].`,
    );

    return registered;
  }

  /**
   * Validates and registers a new provider through the 7-step enterprise onboarding pipeline.
   */
  public async onboardProvider(
    metadata: ProviderDirectoryMetadata,
  ): Promise<{ success: boolean; validation: OnboardingValidationResult; provider?: ProviderDirectoryMetadata }> {
    const validation = this.validateOnboarding(metadata);

    if (!validation.valid) {
      this.logger.warn(
        `[ONBOARDING_REJECTED] Provider [${metadata.providerId}] failed validation: ${validation.errors.join(', ')}`,
      );
      return { success: false, validation };
    }

    // Register in directory
    const registered = this.directoryService.registerProvider(metadata);
    this.logger.log(
      `[ONBOARDING_SUCCESS] Provider [${metadata.providerId}] successfully onboarded to Enterprise Directory.`,
    );

    return { success: true, validation, provider: registered };
  }

  /**
   * Executes the 7-step onboarding validation checks.
   */
  public validateOnboarding(metadata: ProviderDirectoryMetadata): OnboardingValidationResult {
    const stepResults: Array<{ step: string; passed: boolean; message?: string }> = [];
    const errors: string[] = [];

    // Step 1: Metadata check
    const step1Passed = !!(
      metadata.providerId &&
      /^[a-z0-9_-]+$/.test(metadata.providerId) &&
      metadata.displayName &&
      metadata.category
    );
    stepResults.push({
      step: '1. Metadata Specification',
      passed: step1Passed,
      message: step1Passed
        ? 'Valid ID, Name, and Category'
        : 'Invalid providerId format or missing displayName/category',
    });
    if (!step1Passed) errors.push('Metadata validation failed');

    // Step 2: Credential schema
    const step2Passed = Array.isArray(metadata.credentialSchema) && metadata.credentialSchema.length > 0;
    stepResults.push({
      step: '2. Credential Schema Declaration',
      passed: step2Passed,
      message: step2Passed
        ? `${metadata.credentialSchema.length} credential fields defined`
        : 'At least one credential field schema is required',
    });
    if (!step2Passed) errors.push('Credential schema missing');

    // Step 3: Capability matrix assertion
    const step3Passed =
      Array.isArray(metadata.supportedCapabilities) && metadata.supportedCapabilities.length > 0;
    stepResults.push({
      step: '3. Capability Matrix Conformance',
      passed: step3Passed,
      message: step3Passed
        ? `${metadata.supportedCapabilities.length} capabilities declared`
        : 'At least one capability must be declared',
    });
    if (!step3Passed) errors.push('No capabilities declared');

    // Step 4: SLA and Rate Limits
    const step4Passed =
      metadata.sla?.uptimeCommitmentPercent > 90 && metadata.rateLimits?.requestsPerSecond > 0;
    stepResults.push({
      step: '4. SLA & Rate Limits Guarantee',
      passed: step4Passed,
      message: step4Passed
        ? `SLA: ${metadata.sla.uptimeCommitmentPercent}%, RPS: ${metadata.rateLimits.requestsPerSecond}`
        : 'Invalid SLA uptime (<90%) or RPS (<=0)',
    });
    if (!step4Passed) errors.push('Invalid SLA/rate limits');

    // Step 5: Environments & Region
    const step5Passed =
      Array.isArray(metadata.environments) &&
      metadata.environments.length > 0 &&
      Array.isArray(metadata.supportedCountries) &&
      metadata.supportedCountries.length > 0;
    stepResults.push({
      step: '5. Regional & Environment Scope',
      passed: step5Passed,
      message: step5Passed
        ? `Envs: ${metadata.environments.join(', ')}, Countries: ${metadata.supportedCountries.length}`
        : 'Missing environments or supported countries',
    });
    if (!step5Passed) errors.push('Environment or country scope missing');

    // Step 6: Fallback compatibility
    const step6Passed = Array.isArray(metadata.fallbackCompatibility);
    stepResults.push({
      step: '6. Fallback Compatibility Definition',
      passed: step6Passed,
      message: step6Passed
        ? `${metadata.fallbackCompatibility.length} fallback providers specified`
        : 'Fallback compatibility must be an array',
    });
    if (!step6Passed) errors.push('Fallback compatibility declaration invalid');

    // Step 7: Pricing schema
    const step7Passed = !!(metadata.pricing && (metadata.pricing.type || (metadata.pricing as any).pricingType));
    stepResults.push({
      step: '7. Commercial Pricing Model',
      passed: step7Passed,
      message: step7Passed
        ? `Pricing model declared`
        : 'Pricing schema missing type or currency',
    });
    if (!step7Passed) errors.push('Pricing schema incomplete');

    const isValid = errors.length === 0;
    return {
      valid: isValid,
      isValid,
      stepResults,
      errors,
    };
  }
}

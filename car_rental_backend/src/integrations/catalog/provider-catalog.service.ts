import {
  Injectable,
  Logger,
  NotFoundException,
  ConflictException,
  OnModuleInit,
} from '@nestjs/common';
import { IntegrationCategory, ProviderHealthStatus } from '../registry/provider.types';
import {
  CatalogFilter,
  CatalogProviderMetadata,
  MarketplaceProviderView,
  ProviderActivationState,
  ProviderEnvironment,
  ProviderLifecycleState,
  ProviderCertificationLevel,
  ProviderImplementationStatus,
  ProviderComparisonItem,
  ProviderComparisonResult,
} from './provider-catalog.types';
import { INITIAL_PROVIDER_CATALOG } from './provider-catalog.data';
import { IntegrationConfigService } from '../config/integration-config.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { IntegrationContext } from '../registry/provider.types';

@Injectable()
export class ProviderCatalogService implements OnModuleInit {
  private readonly logger = new Logger(ProviderCatalogService.name);
  private readonly catalog = new Map<string, CatalogProviderMetadata>();

  constructor(
    private readonly configService: IntegrationConfigService,
    private readonly healthService: ProviderHealthService,
  ) {}

  onModuleInit() {
    this.seedInitialCatalog();
  }

  /**
   * Seeds the built-in provider catalog entries.
   */
  private seedInitialCatalog(): void {
    for (const provider of INITIAL_PROVIDER_CATALOG) {
      const key = this.getKey(provider.category, provider.providerId);
      this.catalog.set(key, { ...provider });
    }
    this.logger.log(
      `[PROVIDER_CATALOG] Initialized catalog with ${this.catalog.size} enterprise providers across 13 categories`,
    );
  }

  private getKey(category: IntegrationCategory, providerId: string): string {
    return `${category}:${providerId}`.toLowerCase();
  }

  /**
   * Registers a new provider into the runtime catalog registry.
   * Enforces duplicate prevention.
   */
  registerProvider(metadata: CatalogProviderMetadata): void {
    const key = this.getKey(metadata.category, metadata.providerId);
    if (this.catalog.has(key)) {
      throw new ConflictException(
        `Provider '${metadata.providerId}' in category '${metadata.category}' is already registered in the catalog`,
      );
    }

    this.catalog.set(key, { ...metadata });
    this.logger.log(
      `[PROVIDER_CATALOG] Registered new provider [${metadata.category}/${metadata.providerId}] - ${metadata.name}`,
    );
  }

  /**
   * Retrieves a catalog provider by category and provider ID.
   */
  getProvider(category: IntegrationCategory, providerId: string): CatalogProviderMetadata {
    const key = this.getKey(category, providerId);
    const provider = this.catalog.get(key);
    if (!provider) {
      throw new NotFoundException(
        `Provider '${providerId}' in category '${category}' was not found in the catalog`,
      );
    }
    return { ...provider };
  }

  /**
   * Safely retrieves a catalog provider by category and provider ID, or undefined if not found.
   */
  getCatalogProvider(category: IntegrationCategory, providerId: string): CatalogProviderMetadata | undefined {
    const key = this.getKey(category, providerId);
    const provider = this.catalog.get(key);
    return provider ? { ...provider } : undefined;
  }

  /**
   * Finds a provider across any category by ID.
   */
  findProviderById(providerId: string): CatalogProviderMetadata | undefined {
    const normalized = providerId.toLowerCase();
    for (const provider of this.catalog.values()) {
      if (provider.providerId.toLowerCase() === normalized) {
        return { ...provider };
      }
    }
    return undefined;
  }

  /**
   * Retrieves all catalog providers belonging to a specific category.
   */
  getCategoryProviders(category: IntegrationCategory): CatalogProviderMetadata[] {
    return this.getAllProviders({ category });
  }

  /**
   * Discovers catalog providers supporting a specific capability.
   */
  getProvidersByCapability(category: IntegrationCategory, capability: string): CatalogProviderMetadata[] {
    return this.getAllProviders({ category, capability });
  }

  /**
   * Discovers catalog providers supporting a specific currency.
   */
  getProvidersForCurrency(category: IntegrationCategory, currency: string): CatalogProviderMetadata[] {
    return this.getAllProviders({ category, currency });
  }

  /**
   * Discovers catalog providers supporting a specific country/region.
   */
  getProvidersForRegion(category: IntegrationCategory, country: string): CatalogProviderMetadata[] {
    return this.getAllProviders({ category, country });
  }

  /**
   * Returns all catalog providers with optional filtering, capability discovery, regional search, and sorting.
   */
  getAllProviders(filter?: CatalogFilter): CatalogProviderMetadata[] {
    let results = Array.from(this.catalog.values());

    if (filter) {
      if (filter.category) {
        results = results.filter((p) => p.category === filter.category);
      }

      if (filter.capability) {
        const cap = filter.capability.toLowerCase();
        results = results.filter((p) =>
          p.supportedCapabilities.some((c) => c.toLowerCase() === cap),
        );
      }

      if (filter.country) {
        const country = filter.country.toUpperCase();
        results = results.filter((p) =>
          p.supportedCountries.some((c) => c.toUpperCase() === country),
        );
      }

      if (filter.currency) {
        const curr = filter.currency.toUpperCase();
        results = results.filter((p) =>
          p.supportedCurrencies.some((c) => c.toUpperCase() === curr),
        );
      }

      if (filter.environment) {
        results = results.filter((p) =>
          p.supportedEnvironments.includes(filter.environment!),
        );
      }

      if (filter.activationState) {
        results = results.filter((p) => p.activationState === filter.activationState);
      }

      if (filter.lifecycleState) {
        results = results.filter((p) => p.lifecycleState === filter.lifecycleState);
      }

      if (filter.certificationLevel) {
        results = results.filter((p) => p.certificationLevel === filter.certificationLevel);
      }

      if (filter.implementationStatus) {
        results = results.filter((p) => p.implementationStatus === filter.implementationStatus);
      }

      if (filter.tenantTier) {
        const tier = filter.tenantTier.toUpperCase();
        results = results.filter(
          (p) =>
            p.tenantTierAvailability.includes('ALL') ||
            p.tenantTierAvailability.some((t) => t.toUpperCase() === tier),
        );
      }

      if (filter.search) {
        const query = filter.search.toLowerCase();
        results = results.filter(
          (p) =>
            p.name.toLowerCase().includes(query) ||
            p.providerId.toLowerCase().includes(query) ||
            p.tagline.toLowerCase().includes(query) ||
            p.description.toLowerCase().includes(query) ||
            p.tags.some((t) => t.toLowerCase().includes(query)),
        );
      }
    }

    // Sort by priority ascending (1 = highest priority), then name
    return results.sort((a, b) => {
      if (a.priority !== b.priority) {
        return a.priority - b.priority;
      }
      return a.name.localeCompare(b.name);
    });
  }

  /**
   * Updates provider activation state (e.g. ACTIVE, DRAFT, SUSPENDED, DEPRECATED).
   */
  updateActivationState(
    category: IntegrationCategory,
    providerId: string,
    state: ProviderActivationState,
  ): CatalogProviderMetadata {
    const key = this.getKey(category, providerId);
    const provider = this.catalog.get(key);
    if (!provider) {
      throw new NotFoundException(
        `Provider '${providerId}' in category '${category}' was not found in the catalog`,
      );
    }

    provider.activationState = state;
    this.catalog.set(key, provider);
    this.logger.log(
      `[PROVIDER_CATALOG] Updated activation state for [${category}/${providerId}] to ${state}`,
    );
    return { ...provider };
  }

  /**
   * Validates credential schema requirements for a provider.
   */
  validateCredentials(
    category: IntegrationCategory,
    providerId: string,
    credentials: Record<string, any>,
    environment?: ProviderEnvironment,
  ): { isValid: boolean; errors: string[] } {
    const provider = this.getProvider(category, providerId);
    const errors: string[] = [];

    for (const field of provider.credentialSchema) {
      const val = credentials[field.key];

      // Required field check
      if (field.required) {
        if (val === undefined || val === null || val === '') {
          errors.push(`Field '${field.label}' (${field.key}) is required`);
          continue;
        }
      }

      // If value is provided, validate type and regex
      if (val !== undefined && val !== null && val !== '') {
        if (field.type === 'number' && isNaN(Number(val))) {
          errors.push(`Field '${field.label}' must be a valid number`);
        }

        if (field.type === 'url') {
          try {
            new URL(String(val));
          } catch {
            errors.push(`Field '${field.label}' must be a valid URL`);
          }
        }

        if (field.validationRegex) {
          try {
            const regex = new RegExp(field.validationRegex);
            if (!regex.test(String(val))) {
              errors.push(
                `Field '${field.label}' does not match required format (${field.validationRegex})`,
              );
            }
          } catch (e) {
            this.logger.warn(`Invalid regex in schema for field '${field.key}': ${e}`);
          }
        }
      }
    }

    return {
      isValid: errors.length === 0,
      errors,
    };
  }

  /**
   * Resolves fallback priority chain for a category based on region, currency, environment, and tier.
   * Returns ordered list of active providers ready for execution.
   */
  resolveFallbackChain(
    category: IntegrationCategory,
    options?: {
      region?: string;
      currency?: string;
      environment?: ProviderEnvironment;
      tenantTier?: string;
    },
  ): CatalogProviderMetadata[] {
    // 1. Get all active providers for the category
    let candidates = Array.from(this.catalog.values()).filter(
      (p) =>
        p.category === category &&
        p.activationState === ProviderActivationState.ACTIVE &&
        p.platformAvailability,
    );

    // 2. Filter by region if specified
    if (options?.region) {
      const reg = options.region.toUpperCase();
      candidates = candidates.filter((p) =>
        p.supportedCountries.some((c) => c.toUpperCase() === reg),
      );
    }

    // 3. Filter by currency if specified
    if (options?.currency) {
      const cur = options.currency.toUpperCase();
      candidates = candidates.filter((p) =>
        p.supportedCurrencies.some((c) => c.toUpperCase() === cur),
      );
    }

    // 4. Filter by environment if specified
    if (options?.environment) {
      candidates = candidates.filter((p) =>
        p.supportedEnvironments.includes(options.environment!),
      );
    }

    // 5. Filter by tenant tier if specified
    if (options?.tenantTier) {
      const tier = options.tenantTier.toUpperCase();
      candidates = candidates.filter(
        (p) =>
          p.tenantTierAvailability.includes('ALL') ||
          p.tenantTierAvailability.some((t) => t.toUpperCase() === tier),
      );
    }

    // 6. Sort by priority ascending (1 = highest)
    candidates.sort((a, b) => a.priority - b.priority);

    // 7. Honor explicit fallbackProviderId chaining if specified
    const ordered: CatalogProviderMetadata[] = [];
    const visited = new Set<string>();

    for (const candidate of candidates) {
      if (visited.has(candidate.providerId)) continue;
      ordered.push(candidate);
      visited.add(candidate.providerId);

      // If this provider defines an explicit fallback, add it right after if available
      if (candidate.fallbackProviderId && !visited.has(candidate.fallbackProviderId)) {
        const fallback = candidates.find(
          (c) => c.providerId === candidate.fallbackProviderId,
        );
        if (fallback) {
          ordered.push(fallback);
          visited.add(fallback.providerId);
        }
      }
    }

    return ordered;
  }

  /**
   * Generates a unified Marketplace View combining catalog metadata with configured runtime state,
   * health check results, masked credentials, and active selection.
   */
  async getMarketplaceOverview(options?: {
    vendorId?: string;
    branchId?: string;
    tenantTier?: string;
    environment?: ProviderEnvironment;
    category?: IntegrationCategory;
    search?: string;
  }): Promise<MarketplaceProviderView[]> {
    const context: IntegrationContext = {
      vendorId: options?.vendorId,
      branchId: options?.branchId,
    };

    const providers = this.getAllProviders({
      category: options?.category,
      tenantTier: options?.tenantTier,
      environment: options?.environment,
      search: options?.search,
    });

    const activeProviderCache = new Map<IntegrationCategory, string>();
    const marketplaceViews: MarketplaceProviderView[] = [];

    for (const p of providers) {
      if (!activeProviderCache.has(p.category)) {
        const activeId = await this.configService.resolveActiveProviderId(
          p.category,
          context,
        );
        activeProviderCache.set(p.category, activeId);
      }

      const activeProviderId = activeProviderCache.get(p.category);
      const isActive = activeProviderId === p.providerId;

      // Masked configuration
      let maskedConfig: Record<string, any> = {
        isEnabled: true,
        credentials: {},
        settings: {},
      };
      try {
        maskedConfig = await this.configService.getMaskedProviderConfig(
          p.category,
          p.providerId,
          context,
        );
      } catch (_) {
        // Fallback default
      }

      // Health status
      const healthRecord = this.healthService.getHealth(p.category, p.providerId);
      const hasCredentials = Object.keys(maskedConfig.credentials || {}).some(
        (k) => !!maskedConfig.credentials[k],
      );

      const isConfigured =
        hasCredentials ||
        Object.keys(maskedConfig.settings || {}).length > 0 ||
        maskedConfig.resolvedLevel !== 'PLATFORM';

      const activeEnv =
        options?.environment ||
        (maskedConfig.settings?.environment as ProviderEnvironment) ||
        p.defaultEnvironment;

      marketplaceViews.push({
        ...p,
        isConfigured,
        activeEnvironment: activeEnv,
        isActive,
        isEnabled: maskedConfig.isEnabled ?? true,
        hasCredentials,
        maskedCredentials: maskedConfig.credentials || {},
        effectiveSettings: maskedConfig.settings || {},
        health: {
          status: healthRecord.status,
          latencyMs: healthRecord.latencyMs,
          lastChecked:
            healthRecord.lastSuccessfulCheck || healthRecord.lastFailedCheck || null,
          message: healthRecord.lastErrorMessage || undefined,
        },
        lastHealthCheck:
          healthRecord.lastSuccessfulCheck || healthRecord.lastFailedCheck || null,
      });
    }

    return marketplaceViews;
  }

  /**
   * Compares providers side-by-side within a category for capabilities, currencies, pricing, and health.
   */
  compareProviders(
    category: IntegrationCategory,
    providerIds?: string[],
  ): ProviderComparisonResult {
    let list = this.getAllProviders({ category });
    if (providerIds && providerIds.length > 0) {
      const idSet = new Set(providerIds.map((id) => id.toLowerCase()));
      list = list.filter((p) => idSet.has(p.providerId.toLowerCase()));
    }

    const items: ProviderComparisonItem[] = list.map((p) => {
      let healthRecord: any = { latencyP50: 30, successRate: 100, status: ProviderHealthStatus.ACTIVE };
      try {
        const rolling = this.healthService?.getRollingHealth(p.category, p.providerId);
        if (rolling) {
          healthRecord = {
            latencyP50: rolling.latencyP50 || 30,
            successRate: rolling.successRate || 100,
            status: rolling.circuitState === 'OPEN' ? ProviderHealthStatus.UNAVAILABLE : ProviderHealthStatus.ACTIVE,
          };
        }
      } catch {
        // Fallback gracefully
      }

      return {
        providerId: p.providerId,
        name: p.name,
        category: p.category,
        lifecycleState: p.lifecycleState || ProviderLifecycleState.CATALOG_ONLY,
        certificationLevel: p.certificationLevel || ProviderCertificationLevel.CATALOG,
        implementationStatus: p.implementationStatus || ProviderImplementationStatus.CATALOG_ONLY,
        adapterImplemented: !!p.adapterImplemented,
        supportedCapabilities: p.supportedCapabilities || [],
        supportedCurrencies: p.supportedCurrencies || [],
        supportedCountries: p.supportedCountries || [],
        supportedPaymentMethods: p.supportedPaymentMethods || [],
        healthStatus: healthRecord.status,
        latencyP50Ms: healthRecord.latencyP50,
        successRatePercent: healthRecord.successRate,
        costEstimate: {
          percentageFee: p.costModel?.percentageFee || 0,
          fixedFee: p.costModel?.fixedFee || 0,
          currency: p.costModel?.currency || 'INR',
        },
        webhookSupported: !!p.webhookSignatureHeader || (p.supportedCapabilities || []).includes('WEBHOOKS'),
        refundSupported: (p.supportedCapabilities || []).some((c) => c.includes('REFUND')),
        payoutSupported: (p.supportedCapabilities || []).some((c) => c.includes('PAYOUT')),
      };
    });

    const allCaps = items.map((i) => i.supportedCapabilities);
    const commonCapabilities =
      allCaps.length > 0
        ? allCaps[0].filter((cap) => allCaps.every((caps) => caps.includes(cap)))
        : [];

    const uniqueCapabilities: Record<string, string[]> = {};
    for (const item of items) {
      uniqueCapabilities[item.providerId] = item.supportedCapabilities.filter(
        (cap) => !commonCapabilities.includes(cap),
      );
    }

    return {
      category,
      providers: items,
      commonCapabilities,
      uniqueCapabilities,
    };
  }

  /**
   * Validates a provider registration to prevent incomplete or invalid provider configurations.
   */
  validateProviderRegistration(metadata: CatalogProviderMetadata): {
    isValid: boolean;
    errors: string[];
  } {
    const errors: string[] = [];

    if (!metadata.providerId || metadata.providerId.trim() === '') {
      errors.push('Provider ID is required');
    }

    if (!metadata.name || metadata.name.trim() === '') {
      errors.push('Provider name is required');
    }

    if (!metadata.category) {
      errors.push('Category is required');
    }

    if (!metadata.supportedCapabilities || metadata.supportedCapabilities.length === 0) {
      errors.push('At least one supported capability must be specified');
    }

    // Validation rule: If claiming REFUND, ensure either credential schema or capabilities declare it
    if (
      metadata.supportedCapabilities?.some((c) => c.toUpperCase().includes('REFUND')) &&
      metadata.adapterImplemented &&
      !metadata.supportedCapabilities.includes('REFUND_PAYMENT') &&
      !metadata.supportedCapabilities.includes('REFUND')
    ) {
      errors.push('Provider declares refund capability but does not declare standard REFUND_PAYMENT capability');
    }

    // Validation rule: If declaring WEBHOOK support, ensure webhook signature or events are defined
    if (
      metadata.supportedCapabilities?.includes('WEBHOOKS') ||
      metadata.supportedCapabilities?.includes('WEBHOOK_HANDLING')
    ) {
      if (!metadata.webhookSignatureHeader && (!metadata.supportedWebhookEvents || metadata.supportedWebhookEvents.length === 0)) {
        errors.push('Provider declaring webhook support must specify webhookSignatureHeader or supportedWebhookEvents');
      }
    }

    // Validation rule: If claiming SANDBOX, must declare SANDBOX in supportedEnvironments
    if (
      metadata.lifecycleState === ProviderLifecycleState.SANDBOX_READY &&
      !metadata.supportedEnvironments?.includes(ProviderEnvironment.SANDBOX)
    ) {
      errors.push('Provider with SANDBOX_READY lifecycle state must support SANDBOX environment');
    }

    return {
      isValid: errors.length === 0,
      errors,
    };
  }
}

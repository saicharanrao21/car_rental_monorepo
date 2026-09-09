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
}

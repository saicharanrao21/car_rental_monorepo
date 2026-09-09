import { Injectable, NotFoundException } from '@nestjs/common';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { IntegrationConfigService } from '../config/integration-config.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { WebhookDispatcherService } from '../webhooks/webhook-dispatcher.service';
import { PrismaService } from '../../prisma/prisma.service';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import {
  CatalogFilter,
  CatalogProviderMetadata,
  MarketplaceProviderView,
  ProviderActivationState,
  ProviderEnvironment,
} from '../catalog/provider-catalog.types';
import {
  IntegrationCategory,
  IntegrationContext,
  ProviderDescriptor,
  TestConnectionResult,
} from '../registry/provider.types';
import {
  UpdateIntegrationConfigDto,
  TestConnectionDto,
  RegisterCatalogProviderDto,
  ValidateCredentialsDto,
} from './dto/admin-integrations.dto';

@Injectable()
export class AdminIntegrationsService {
  constructor(
    private readonly registry: ProviderRegistryService,
    private readonly configService: IntegrationConfigService,
    private readonly healthService: ProviderHealthService,
    private readonly webhookDispatcher: WebhookDispatcherService,
    private readonly prisma: PrismaService,
    private readonly catalogService: ProviderCatalogService,
  ) {}

  /**
   * Retrieves an overview of all integration categories with counts and active statuses.
   */
  async getOverview(context?: IntegrationContext): Promise<any[]> {
    const categories = Object.values(IntegrationCategory);
    const overview: any[] = [];

    for (const cat of categories) {
      const providers = await this.registry.getRegisteredProviders(cat, context);
      const activeProviderId = await this.configService.resolveActiveProviderId(cat, context);
      const enabledCount = providers.filter((p) => p.isEnabled).length;
      const healthyCount = providers.filter(
        (p) => p.health.status === 'HEALTHY' || p.health.status === 'ACTIVE',
      ).length;

      overview.push({
        category: cat,
        totalProviders: providers.length,
        enabledProviders: enabledCount,
        healthyProviders: healthyCount,
        activeProviderId,
        status: enabledCount > 0 ? 'CONFIGURED' : 'UNCONFIGURED',
      });
    }

    return overview;
  }

  /**
   * Lists all registered providers, optionally filtered by category.
   */
  async listProviders(
    category?: IntegrationCategory,
    context?: IntegrationContext,
  ): Promise<ProviderDescriptor[]> {
    return this.registry.getRegisteredProviders(category, context);
  }

  /**
   * Gets details and sanitized/masked configuration for a single provider.
   */
  async getProviderDetails(
    category: IntegrationCategory,
    providerId: string,
    context?: IntegrationContext,
  ): Promise<any> {
    const provider = await this.registry.getProvider(category, providerId, context);
    const maskedConfig = await this.configService.getMaskedProviderConfig(
      category,
      providerId,
      context,
    );
    const health = this.healthService.getHealth(category, providerId);
    const activeProviderId = await this.configService.resolveActiveProviderId(category, context);

    return {
      providerId: provider.getProviderId(),
      category: provider.getCategory(),
      displayName: provider.getDisplayName(),
      supportedCapabilities: provider.getSupportedCapabilities(),
      isActive: activeProviderId === provider.getProviderId(),
      health,
      configuration: maskedConfig,
    };
  }

  /**
   * Sets or updates provider configuration and credentials.
   */
  async updateProviderConfig(
    category: IntegrationCategory,
    providerId: string,
    dto: UpdateIntegrationConfigDto,
    userId?: string,
  ): Promise<any> {
    const context: IntegrationContext = {
      vendorId: dto.vendorId,
      branchId: dto.branchId,
    };

    if (dto.isEnabled !== undefined) {
      this.registry.enableProvider(category, providerId, dto.isEnabled);
    }

    await this.configService.setProviderConfig(
      category,
      providerId,
      {
        isEnabled: dto.isEnabled,
        priority: dto.priority,
        credentials: dto.credentials,
        settings: dto.settings,
      },
      userId,
      context,
    );

    return this.getProviderDetails(category, providerId, context);
  }

  /**
   * Switches active provider for a category.
   */
  async setActiveProvider(
    category: IntegrationCategory,
    providerId: string,
    userId?: string,
    context?: IntegrationContext,
  ): Promise<void> {
    // Assert provider exists
    await this.registry.getProvider(category, providerId, context);
    await this.configService.setActiveProvider(category, providerId, userId, context);
  }

  /**
   * Toggles enabled state of a provider.
   */
  toggleProvider(
    category: IntegrationCategory,
    providerId: string,
    enabled: boolean,
  ): void {
    this.registry.enableProvider(category, providerId, enabled);
  }

  /**
   * Tests live connection to provider.
   */
  async testConnection(
    category: IntegrationCategory,
    providerId: string,
    dto?: TestConnectionDto,
    context?: IntegrationContext,
  ): Promise<TestConnectionResult> {
    const provider = await this.registry.getProvider(category, providerId, context);

    // If no credentials explicitly passed in DTO, resolve configured decrypted credentials
    let creds = dto?.credentials;
    if (!creds || Object.keys(creds).length === 0) {
      const resolved = await this.configService.resolveProviderConfig(category, providerId, context);
      creds = resolved.credentials;
    }

    return this.healthService.testConnection(provider, creds);
  }

  /**
   * Lists webhook events with pagination and filters.
   */
  async listWebhookEvents(query?: {
    gateway?: string;
    status?: string;
    limit?: number;
    skip?: number;
  }): Promise<any> {
    if (!this.prisma.webhookEvent) {
      return { total: 0, events: [] };
    }

    const where: any = {};
    if (query?.gateway) where.gateway = query.gateway.toUpperCase();
    if (query?.status) where.status = query.status.toUpperCase();

    const [total, events] = await Promise.all([
      this.prisma.webhookEvent.count({ where }),
      this.prisma.webhookEvent.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: query?.limit || 50,
        skip: query?.skip || 0,
      }),
    ]);

    return { total, events };
  }

  /**
   * Replays a webhook event by ID.
   */
  async replayWebhookEvent(eventId: string): Promise<any> {
    return this.webhookDispatcher.replayWebhookEvent(eventId, async (event) => {
      return { replayed: true, eventId: event.eventId, timestamp: new Date() };
    });
  }

  // =========================================================================
  // PHASE J: MARKETPLACE & CATALOG REGISTRY METHODS
  // =========================================================================

  /**
   * Retrieves unified Marketplace view combining catalog metadata with configured states.
   */
  async getMarketplace(query?: {
    category?: IntegrationCategory;
    vendorId?: string;
    branchId?: string;
    tenantTier?: string;
    environment?: ProviderEnvironment;
    search?: string;
  }): Promise<MarketplaceProviderView[]> {
    return this.catalogService.getMarketplaceOverview(query);
  }

  /**
   * Lists providers from the catalog with dynamic discovery filters.
   */
  getCatalog(filter?: CatalogFilter): CatalogProviderMetadata[] {
    return this.catalogService.getAllProviders(filter);
  }

  /**
   * Retrieves a specific catalog provider by category and ID.
   */
  getCatalogProvider(
    category: IntegrationCategory,
    providerId: string,
  ): CatalogProviderMetadata {
    return this.catalogService.getProvider(category, providerId);
  }

  /**
   * Dynamically registers a new provider into the catalog registry.
   */
  registerCatalogProvider(dto: RegisterCatalogProviderDto): CatalogProviderMetadata {
    const metadata: CatalogProviderMetadata = {
      providerId: dto.providerId,
      category: dto.category,
      name: dto.name,
      tagline: dto.tagline,
      description: dto.description,
      icon: dto.icon,
      websiteUrl: dto.websiteUrl,
      documentation: dto.documentation,
      version: dto.version,
      apiVersion: dto.apiVersion,
      author: dto.author,
      tags: dto.tags || [],
      supportedEnvironments: (dto.supportedEnvironments as ProviderEnvironment[]) || [
        ProviderEnvironment.SANDBOX,
        ProviderEnvironment.LIVE,
      ],
      defaultEnvironment:
        (dto.defaultEnvironment as ProviderEnvironment) || ProviderEnvironment.SANDBOX,
      credentialSchema: dto.credentialSchema || [],
      supportedCapabilities: dto.supportedCapabilities || [],
      supportedCurrencies: dto.supportedCurrencies || ['INR'],
      supportedCountries: dto.supportedCountries || ['IN'],
      supportedWebhookEvents: dto.supportedWebhookEvents || [],
      webhookSignatureHeader: dto.webhookSignatureHeader,
      platformAvailability: dto.platformAvailability ?? true,
      tenantTierAvailability: dto.tenantTierAvailability || ['ALL'],
      activationState:
        (dto.activationState as ProviderActivationState) ||
        ProviderActivationState.ACTIVE,
      priority: dto.priority || 10,
      fallbackProviderId: dto.fallbackProviderId,
    };

    this.catalogService.registerProvider(metadata);
    return metadata;
  }

  /**
   * Updates provider activation state.
   */
  updateActivationState(
    category: IntegrationCategory,
    providerId: string,
    state: ProviderActivationState,
  ): CatalogProviderMetadata {
    return this.catalogService.updateActivationState(category, providerId, state);
  }

  /**
   * Validates credentials against catalog schema.
   */
  validateCredentials(
    category: IntegrationCategory,
    providerId: string,
    dto: ValidateCredentialsDto,
  ): { isValid: boolean; errors: string[] } {
    return this.catalogService.validateCredentials(
      category,
      providerId,
      dto.credentials,
      dto.environment as ProviderEnvironment,
    );
  }

  /**
   * Resolves fallback priority chain for category.
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
    return this.catalogService.resolveFallbackChain(category, options);
  }
}


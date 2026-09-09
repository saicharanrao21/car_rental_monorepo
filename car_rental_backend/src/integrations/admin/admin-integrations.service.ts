import { Injectable, NotFoundException, Optional } from '@nestjs/common';
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

// Phase K Runtime Services & Types
import { IntegrationRuntimeService } from '../runtime/integration-runtime.service';
import { CircuitBreakerService } from '../runtime/circuit-breaker.service';
import { ProviderRoutingService } from '../runtime/provider-routing.service';
import { ProviderSimulationService } from '../runtime/provider-simulation.service';
import { ProviderPolicyService } from '../runtime/provider-policy.service';
import { IntegrationAuditService } from '../runtime/integration-audit.service';
import { CostModelService } from '../runtime/cost-model.service';
import {
  CircuitState,
  IntegrationExecutionRequest,
  IntegrationExecutionResult,
  ProviderPolicyRule,
  RoutingStrategy,
  SimulationScenario,
} from '../runtime/runtime.types';

@Injectable()
export class AdminIntegrationsService {
  constructor(
    private readonly registry: ProviderRegistryService,
    private readonly configService: IntegrationConfigService,
    private readonly healthService: ProviderHealthService,
    private readonly webhookDispatcher: WebhookDispatcherService,
    private readonly prisma: PrismaService,
    private readonly catalogService: ProviderCatalogService,
    @Optional() private readonly runtimeService?: IntegrationRuntimeService,
    @Optional() private readonly circuitBreakerService?: CircuitBreakerService,
    @Optional() private readonly routingService?: ProviderRoutingService,
    @Optional() private readonly simulationService?: ProviderSimulationService,
    @Optional() private readonly policyService?: ProviderPolicyService,
    @Optional() private readonly auditService?: IntegrationAuditService,
    @Optional() private readonly costModelService?: CostModelService,
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
    const circuitState = this.circuitBreakerService
      ? this.circuitBreakerService.getState(providerId)
      : CircuitState.CLOSED;
    const rollingHealth = this.healthService.getRollingHealth(category, providerId, circuitState);

    return {
      providerId: provider.getProviderId(),
      category: provider.getCategory(),
      displayName: provider.getDisplayName(),
      supportedCapabilities: provider.getSupportedCapabilities(),
      isActive: activeProviderId === provider.getProviderId(),
      health,
      circuitState,
      rollingHealth,
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

  getCatalog(filter?: CatalogFilter): CatalogProviderMetadata[] {
    return this.catalogService.getAllProviders(filter);
  }

  getCatalogProvider(
    category: IntegrationCategory,
    providerId: string,
  ): CatalogProviderMetadata {
    return this.catalogService.getProvider(category, providerId);
  }

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

  updateActivationState(
    category: IntegrationCategory,
    providerId: string,
    state: ProviderActivationState,
  ): CatalogProviderMetadata {
    return this.catalogService.updateActivationState(category, providerId, state);
  }

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

  // =========================================================================
  // PHASE K: OPERATIONAL CONTROL CENTRE & RUNTIME MANAGEMENT
  // =========================================================================

  /**
   * Retrieves operational command-centre metrics: circuits, rolling health, incidents, recent executions.
   */
  async getRuntimeOverview(context?: IntegrationContext): Promise<any> {
    const categories = Object.values(IntegrationCategory);
    const circuits = this.circuitBreakerService?.getAllStates() ?? {};
    const rollingHealth = this.healthService.getAllRollingHealth((id) =>
      this.circuitBreakerService ? this.circuitBreakerService.getState(id) : CircuitState.CLOSED,
    );
    const activeIncidents = this.auditService?.getIncidents({ status: 'INVESTIGATING' }) ?? [];
    const recentExecutions = this.auditService?.getExecutions({ limit: 10 }) ?? [];

    return {
      totalCategories: categories.length,
      circuits,
      rollingHealth,
      activeIncidentsCount: activeIncidents.length,
      recentExecutions,
    };
  }

  getCircuitStates(): Record<string, CircuitState> {
    return this.circuitBreakerService?.getAllStates() ?? {};
  }

  resetCircuit(providerId: string): void {
    this.circuitBreakerService?.resetCircuit(providerId);
    this.auditService?.resolveIncident(providerId, 'Manually reset by Admin');
  }

  tripCircuit(providerId: string, reason = 'Manually tripped by Admin'): void {
    this.circuitBreakerService?.tripCircuit(providerId, reason);
    this.auditService?.recordIncident({
      providerId,
      category: 'UNKNOWN',
      title: `Circuit tripped manually: ${providerId}`,
      severity: 'HIGH',
      circuitState: CircuitState.OPEN,
      reason,
    });
  }

  setSimulation(providerId: string, scenario: SimulationScenario): void {
    this.simulationService?.setProviderSimulation(providerId, scenario);
  }

  clearSimulation(providerId: string): void {
    this.simulationService?.clearProviderSimulation(providerId);
  }

  getSimulation(providerId: string): SimulationScenario {
    return this.simulationService?.getProviderSimulation(providerId) ?? SimulationScenario.NONE;
  }

  getPolicies(): ProviderPolicyRule[] {
    return this.policyService?.getPolicies() ?? [];
  }

  upsertPolicy(policy: ProviderPolicyRule): void {
    this.policyService?.registerPolicy(policy);
  }

  deletePolicy(id: string): void {
    this.policyService?.deletePolicy(id);
  }

  getIncidents(filter?: { providerId?: string; status?: string }): any[] {
    return this.auditService?.getIncidents(filter) ?? [];
  }

  resolveIncident(providerId: string, reason?: string): void {
    this.auditService?.resolveIncident(providerId, reason);
    this.circuitBreakerService?.resetCircuit(providerId);
  }

  getExecutions(filter?: {
    category?: string;
    providerId?: string;
    status?: string;
    limit?: number;
    offset?: number;
  }): any[] {
    return this.auditService?.getExecutions(filter) ?? [];
  }

  async executeRuntime(
    request: IntegrationExecutionRequest,
  ): Promise<IntegrationExecutionResult> {
    if (!this.runtimeService) {
      throw new Error('IntegrationRuntimeService is not configured');
    }
    return this.runtimeService.execute(request);
  }
}

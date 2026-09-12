import { Injectable, Logger } from '@nestjs/common';
import { BaseProvider } from '../contracts/provider.interface';
import {
  IntegrationCategory,
  IntegrationContext,
  ProviderDescriptor,
  ProviderHealthStatus,
} from './provider.types';
import { IntegrationConfigService } from '../config/integration-config.service';
import { ProviderHealthService } from '../health/provider-health.service';
import {
  ProviderNotConfiguredError,
  CapabilityNotSupportedError,
} from '../errors/integration-error';

@Injectable()
export class ProviderRegistryService {
  private readonly logger = new Logger(ProviderRegistryService.name);
  private readonly providers = new Map<string, BaseProvider>();
  private readonly enabledStates = new Map<string, boolean>();

  constructor(
    private readonly configService: IntegrationConfigService,
    private readonly healthService: ProviderHealthService,
  ) {}

  private getKey(category: IntegrationCategory, providerId: string): string {
    return `${category}:${providerId}`.toLowerCase();
  }

  /**
   * Registers a provider adapter into the central registry.
   */
  registerProvider(provider: BaseProvider): void {
    const key = this.getKey(provider.getCategory(), provider.getProviderId());
    this.providers.set(key, provider);
    if (!this.enabledStates.has(key)) {
      this.enabledStates.set(key, true);
    }
    this.logger.log(
      `[PROVIDER_REGISTERED] Registered [${provider.getCategory()}] -> [${provider.getProviderId()}] (${provider.getDisplayName()})`,
    );
  }

  /**
   * Resolves a provider instance by category and optional providerId or active selection.
   */
  async getProvider<T extends BaseProvider = BaseProvider>(
    category: IntegrationCategory,
    providerId?: string,
    context?: IntegrationContext,
  ): Promise<T> {
    const targetProviderId =
      providerId || (await this.configService.resolveActiveProviderId(category, context));

    if (!targetProviderId) {
      throw new ProviderNotConfiguredError(category);
    }

    const key = this.getKey(category, targetProviderId);
    const provider = this.providers.get(key);

    if (!provider) {
      this.logger.warn(`Provider [${targetProviderId}] for category [${category}] is not registered`);
      throw new ProviderNotConfiguredError(category, targetProviderId);
    }

    const isEnabled = this.enabledStates.get(key) ?? true;
    if (!isEnabled) {
      this.logger.warn(`Provider [${targetProviderId}] for category [${category}] is currently disabled`);
      throw new ProviderNotConfiguredError(category, targetProviderId);
    }

    return provider as T;
  }

  /**
   * Resolves the active provider for a category.
   */
  async getActiveProvider<T extends BaseProvider = BaseProvider>(
    category: IntegrationCategory,
    context?: IntegrationContext,
  ): Promise<T> {
    return this.getProvider<T>(category, undefined, context);
  }

  /**
   * Enables or disables a registered provider.
   */
  enableProvider(
    category: IntegrationCategory,
    providerId: string,
    enabled: boolean,
  ): void {
    const key = this.getKey(category, providerId);
    this.enabledStates.set(key, enabled);
    this.logger.log(`[PROVIDER_STATE] Provider [${category}/${providerId}] enabled=${enabled}`);
  }

  setProviderEnabled(
    category: IntegrationCategory,
    providerId: string,
    enabled: boolean,
  ): void {
    this.enableProvider(category, providerId, enabled);
  }

  isProviderAvailable(category: IntegrationCategory, providerId: string): boolean {
    const key = this.getKey(category, providerId);
    return (this.enabledStates.get(key) ?? true) && this.providers.has(key);
  }

  /**
   * Returns list of all registered provider descriptors, optionally filtered by category.
   */
  async getRegisteredProviders(
    category?: IntegrationCategory,
    context?: IntegrationContext,
  ): Promise<ProviderDescriptor[]> {
    const descriptors: ProviderDescriptor[] = [];
    const activeProviderCache = new Map<IntegrationCategory, string>();

    for (const [key, provider] of this.providers.entries()) {
      if (category && provider.getCategory() !== category) {
        continue;
      }

      const pCategory = provider.getCategory();
      const pId = provider.getProviderId();

      if (!activeProviderCache.has(pCategory)) {
        const activeId = await this.configService.resolveActiveProviderId(pCategory, context);
        activeProviderCache.set(pCategory, activeId);
      }

      const isActive = activeProviderCache.get(pCategory) === pId;
      const isEnabled = this.enabledStates.get(key) ?? true;
      const healthRecord = this.healthService.getHealth(pCategory, pId);

      descriptors.push({
        providerId: pId,
        category: pCategory,
        displayName: provider.getDisplayName(),
        supportedCapabilities: provider.getSupportedCapabilities(),
        isEnabled,
        isActive,
        priority: 1,
        health: {
          status: healthRecord.status,
          latencyMs: healthRecord.latencyMs,
          message: healthRecord.lastErrorMessage || undefined,
          lastChecked: healthRecord.lastSuccessfulCheck || healthRecord.lastFailedCheck || new Date(),
          details: healthRecord.details,
        },
        hasCredentials:
          healthRecord.status !== ProviderHealthStatus.CREDENTIAL_FAILURE &&
          healthRecord.status !== ProviderHealthStatus.UNAVAILABLE,
      });
    }

    return descriptors;
  }

  /**
   * Discovers providers in a category that support all requested capabilities.
   */
  discoverCapabilities(
    category: IntegrationCategory,
    requiredCapabilities: string[],
  ): BaseProvider[] {
    const matching: BaseProvider[] = [];

    for (const provider of this.providers.values()) {
      if (provider.getCategory() !== category) continue;

      const hasAll = requiredCapabilities.every((cap) => provider.hasCapability(cap));
      if (hasAll) {
        matching.push(provider);
      }
    }

    return matching;
  }

  /**
   * Returns all instantiated providers for a category.
   */
  getProvidersByCategory(category: IntegrationCategory): BaseProvider[] {
    const list: BaseProvider[] = [];
    for (const provider of this.providers.values()) {
      if (provider.getCategory() === category) {
        list.push(provider);
      }
    }
    return list;
  }

  /**
   * Asserts that a provider supports the requested capability, or throws CapabilityNotSupportedError.
   */
  assertCapability(provider: BaseProvider, capability: string): void {
    if (!provider.hasCapability(capability)) {
      throw new CapabilityNotSupportedError(
        provider.getProviderId(),
        provider.getCategory(),
        capability,
      );
    }
  }
}

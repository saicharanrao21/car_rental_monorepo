import { Test, TestingModule } from '@nestjs/testing';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { IntegrationConfigService } from '../config/integration-config.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { SecretVaultService } from '../security/secret-vault.service';
import { ConfigService } from '@nestjs/config';
import { SystemConfigService } from '../../config-engine/system-config.service';
import {
  IntegrationCategory,
  ProviderHealthStatus,
  ProviderHealthCheckResult,
  TestConnectionResult,
} from '../registry/provider.types';
import { BaseProvider } from '../contracts/provider.interface';
import {
  ProviderNotConfiguredError,
  CapabilityNotSupportedError,
} from '../errors/integration-error';

class DummyPaymentProvider implements BaseProvider {
  constructor(private readonly id: string, private readonly capabilities: string[] = ['CREATE_ORDER']) {}

  getProviderId(): string {
    return this.id;
  }
  getCategory(): IntegrationCategory {
    return IntegrationCategory.PAYMENT;
  }
  getDisplayName(): string {
    return `Dummy Provider ${this.id}`;
  }
  getSupportedCapabilities(): string[] {
    return this.capabilities;
  }
  hasCapability(capability: string): boolean {
    return this.capabilities.includes(capability);
  }
  getDefaultTimeoutMs(): number {
    return 5000;
  }
  async checkHealth(): Promise<ProviderHealthCheckResult> {
    return {
      status: ProviderHealthStatus.HEALTHY,
      latencyMs: 1,
      lastChecked: new Date(),
    };
  }
  async testConnection(): Promise<TestConnectionResult> {
    return { success: true, latencyMs: 1 };
  }
}

describe('Phase I — ProviderRegistryService', () => {
  let registry: ProviderRegistryService;
  let configService: IntegrationConfigService;
  let healthService: ProviderHealthService;

  const mockConfigs: Record<string, any> = {};

  const mockSystemConfigService = {
    getConfig: jest.fn().mockImplementation((key: string) => {
      if (key in mockConfigs) return Promise.resolve(mockConfigs[key]);
      return Promise.reject(new Error('Not found'));
    }),
    setConfig: jest.fn().mockImplementation((key: string, val: any) => {
      mockConfigs[key] = val;
      return Promise.resolve(val);
    }),
  };

  beforeEach(async () => {
    Object.keys(mockConfigs).forEach((k) => delete mockConfigs[k]);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ProviderRegistryService,
        IntegrationConfigService,
        ProviderHealthService,
        SecretVaultService,
        { provide: SystemConfigService, useValue: mockSystemConfigService },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn().mockReturnValue(null),
          },
        },
      ],
    }).compile();

    registry = module.get<ProviderRegistryService>(ProviderRegistryService);
    configService = module.get<IntegrationConfigService>(IntegrationConfigService);
    healthService = module.get<ProviderHealthService>(ProviderHealthService);
  });

  describe('Registration & Resolution', () => {
    it('should register a provider and resolve it by category and providerId', async () => {
      const provider = new DummyPaymentProvider('dummy_rzp');
      registry.registerProvider(provider);

      const resolved = await registry.getProvider(IntegrationCategory.PAYMENT, 'dummy_rzp');
      expect(resolved).toBe(provider);
      expect(resolved.getProviderId()).toBe('dummy_rzp');
      expect(resolved.getDisplayName()).toBe('Dummy Provider dummy_rzp');
    });

    it('should resolve active provider automatically when providerId is omitted', async () => {
      const providerA = new DummyPaymentProvider('provider_a');
      const providerB = new DummyPaymentProvider('provider_b');
      registry.registerProvider(providerA);
      registry.registerProvider(providerB);

      mockConfigs['integrations.active.PAYMENT'] = 'provider_b';

      const active = await registry.getActiveProvider(IntegrationCategory.PAYMENT);
      expect(active).toBe(providerB);
    });

    it('should support vendor-level active provider override', async () => {
      const globalProvider = new DummyPaymentProvider('global_p');
      const vendorProvider = new DummyPaymentProvider('vendor_p');
      registry.registerProvider(globalProvider);
      registry.registerProvider(vendorProvider);

      mockConfigs['integrations.active.PAYMENT'] = 'global_p';
      mockConfigs['integrations.active.vendor.vendor_123.PAYMENT'] = 'vendor_p';

      const resolvedGlobal = await registry.getActiveProvider(IntegrationCategory.PAYMENT);
      expect(resolvedGlobal).toBe(globalProvider);

      const resolvedVendor = await registry.getActiveProvider(IntegrationCategory.PAYMENT, {
        vendorId: 'vendor_123',
      });
      expect(resolvedVendor).toBe(vendorProvider);
    });
  });

  describe('Disabled & Missing Providers', () => {
    it('should throw ProviderNotConfiguredError when requesting a disabled provider', async () => {
      const provider = new DummyPaymentProvider('disabled_p');
      registry.registerProvider(provider);
      registry.enableProvider(IntegrationCategory.PAYMENT, 'disabled_p', false);

      await expect(
        registry.getProvider(IntegrationCategory.PAYMENT, 'disabled_p'),
      ).rejects.toThrow(ProviderNotConfiguredError);
    });

    it('should throw ProviderNotConfiguredError when provider is not registered', async () => {
      await expect(
        registry.getProvider(IntegrationCategory.PAYMENT, 'non_existent_provider'),
      ).rejects.toThrow(ProviderNotConfiguredError);
    });
  });

  describe('Capability Discovery & Verification', () => {
    it('should discover providers matching required capabilities', () => {
      const p1 = new DummyPaymentProvider('p1', ['CREATE_ORDER', 'REFUND']);
      const p2 = new DummyPaymentProvider('p2', ['CREATE_ORDER', 'SPLIT_PAYMENT']);
      const p3 = new DummyPaymentProvider('p3', ['CREATE_ORDER', 'REFUND', 'SPLIT_PAYMENT']);

      registry.registerProvider(p1);
      registry.registerProvider(p2);
      registry.registerProvider(p3);

      const canSplit = registry.discoverCapabilities(IntegrationCategory.PAYMENT, ['SPLIT_PAYMENT']);
      expect(canSplit.map((p) => p.getProviderId())).toEqual(['p2', 'p3']);

      const canBoth = registry.discoverCapabilities(IntegrationCategory.PAYMENT, ['REFUND', 'SPLIT_PAYMENT']);
      expect(canBoth.map((p) => p.getProviderId())).toEqual(['p3']);
    });

    it('should assert capability and throw CapabilityNotSupportedError on mismatch', () => {
      const p = new DummyPaymentProvider('p_basic', ['CREATE_ORDER']);
      registry.registerProvider(p);

      expect(() => registry.assertCapability(p, 'CREATE_ORDER')).not.toThrow();
      expect(() => registry.assertCapability(p, 'SPLIT_PAYMENT')).toThrow(
        CapabilityNotSupportedError,
      );
    });
  });

  describe('Descriptors & Health Summary', () => {
    it('should return complete descriptors including health for all registered providers', async () => {
      const p = new DummyPaymentProvider('p_desc');
      registry.registerProvider(p);

      healthService.recordHealth(IntegrationCategory.PAYMENT, 'p_desc', {
        status: ProviderHealthStatus.HEALTHY,
        latencyMs: 15,
        lastChecked: new Date(),
        message: 'Ping OK',
      });

      const descriptors = await registry.getRegisteredProviders(IntegrationCategory.PAYMENT);
      expect(descriptors.length).toBeGreaterThanOrEqual(1);

      const target = descriptors.find((d) => d.providerId === 'p_desc');
      expect(target).toBeDefined();
      expect(target!.displayName).toBe('Dummy Provider p_desc');
      expect(target!.isEnabled).toBe(true);
      expect(target!.health.status).toBe(ProviderHealthStatus.HEALTHY);
      expect(target!.health.latencyMs).toBe(15);
    });
  });
});

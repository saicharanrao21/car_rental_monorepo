import { Test, TestingModule } from '@nestjs/testing';
import { AdminIntegrationsService } from '../admin/admin-integrations.service';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { IntegrationConfigService } from '../config/integration-config.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { WebhookDispatcherService } from '../webhooks/webhook-dispatcher.service';
import { SecretVaultService } from '../security/secret-vault.service';
import { SystemConfigService } from '../../config-engine/system-config.service';
import { PrismaService } from '../../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import {
  IntegrationCategory,
  ProviderHealthStatus,
} from '../registry/provider.types';
import { MockPaymentAdapter } from '../adapters/payments/mock-payment.adapter';
import { MockWhatsAppAdapter } from '../adapters/messaging/mock-whatsapp.adapter';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';

describe('Phase I — Admin Integration Centre Service', () => {
  let adminService: AdminIntegrationsService;
  let registry: ProviderRegistryService;
  let configService: IntegrationConfigService;
  let healthService: ProviderHealthService;

  const mockConfigs: Record<string, any> = {};

  const mockPrisma = {
    webhookEvent: {
      count: jest.fn().mockResolvedValue(1),
      findMany: jest.fn().mockResolvedValue([
        {
          id: 'cuid_1',
          gateway: 'RAZORPAY',
          eventId: 'evt_100',
          eventType: 'order.paid',
          status: 'PROCESSED',
          createdAt: new Date(),
        },
      ]),
      findUnique: jest.fn().mockResolvedValue({
        id: 'cuid_1',
        gateway: 'RAZORPAY',
        eventId: 'evt_100',
        eventType: 'order.paid',
        payload: { order_id: 'order_123' },
        status: 'FAILED',
      }),
      update: jest.fn().mockResolvedValue({}),
    },
  };

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
        AdminIntegrationsService,
        ProviderRegistryService,
        IntegrationConfigService,
        ProviderHealthService,
        WebhookDispatcherService,
        SecretVaultService,
        ProviderCatalogService,
        MockPaymentAdapter,
        MockWhatsAppAdapter,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: SystemConfigService, useValue: mockSystemConfigService },
        {
          provide: ConfigService,
          useValue: { get: jest.fn().mockReturnValue(null) },
        },
      ],
    }).compile();

    adminService = module.get<AdminIntegrationsService>(AdminIntegrationsService);
    registry = module.get<ProviderRegistryService>(ProviderRegistryService);
    configService = module.get<IntegrationConfigService>(IntegrationConfigService);
    healthService = module.get<ProviderHealthService>(ProviderHealthService);

    // Register adapters for test
    registry.registerProvider(module.get<MockPaymentAdapter>(MockPaymentAdapter));
    registry.registerProvider(module.get<MockWhatsAppAdapter>(MockWhatsAppAdapter));
  });

  describe('Integration Overview', () => {
    it('should return a list of all categories with their health and provider count', async () => {
      const overview = await adminService.getOverview();
      expect(overview.length).toBe(Object.values(IntegrationCategory).length);

      const paymentCategory = overview.find((c) => c.category === IntegrationCategory.PAYMENT);
      expect(paymentCategory).toBeDefined();
      expect(paymentCategory.totalProviders).toBeGreaterThanOrEqual(1);
    });
  });

  describe('Provider Management', () => {
    it('should list registered providers with health status and active provider state', async () => {
      const providers = await adminService.listProviders(IntegrationCategory.PAYMENT);
      expect(providers.length).toBeGreaterThanOrEqual(1);
      expect(providers[0].providerId).toBe('mock_payment');
      expect(providers[0].isEnabled).toBe(true);
    });

    it('should toggle provider enabled/disabled state', async () => {
      adminService.toggleProvider(IntegrationCategory.PAYMENT, 'mock_payment', false);
      const providers = await adminService.listProviders(IntegrationCategory.PAYMENT);
      const mockP = providers.find((p) => p.providerId === 'mock_payment');
      expect(mockP?.isEnabled).toBe(false);

      adminService.toggleProvider(IntegrationCategory.PAYMENT, 'mock_payment', true);
      const providersReenabled = await adminService.listProviders(IntegrationCategory.PAYMENT);
      const mockReenabled = providersReenabled.find((p) => p.providerId === 'mock_payment');
      expect(mockReenabled?.isEnabled).toBe(true);
    });

    it('should switch active provider for a category', async () => {
      await adminService.setActiveProvider(
        IntegrationCategory.PAYMENT,
        'mock_payment',
        'admin_user_1',
      );

      const activeId = await configService.resolveActiveProviderId(IntegrationCategory.PAYMENT);
      expect(activeId).toBe('mock_payment');
    });

    it('should test live connection to a provider', async () => {
      const result = await adminService.testConnection(
        IntegrationCategory.PAYMENT,
        'mock_payment',
      );
      expect(result.success).toBe(true);
      expect(result.message).toContain('Mock payment test connection successful');
    });
  });

  describe('Webhook Events & Replay', () => {
    it('should list recent webhook events with filters', async () => {
      const res = await adminService.listWebhookEvents({ gateway: 'RAZORPAY' });
      expect(res.total).toBe(1);
      expect(res.events[0].eventId).toBe('evt_100');
    });

    it('should replay a webhook event successfully', async () => {
      const replayRes = await adminService.replayWebhookEvent('evt_100');
      expect(replayRes.received).toBe(true);
      expect(replayRes.status).toBe('PROCESSED');
    });
  });
});

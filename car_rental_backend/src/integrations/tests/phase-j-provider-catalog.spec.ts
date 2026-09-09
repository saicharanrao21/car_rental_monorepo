import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import { IntegrationConfigService } from '../config/integration-config.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { SecretVaultService } from '../security/secret-vault.service';
import { ConfigService } from '@nestjs/config';
import { SystemConfigService } from '../../config-engine/system-config.service';
import { PrismaService } from '../../prisma/prisma.service';
import { WebhookDispatcherService } from '../webhooks/webhook-dispatcher.service';
import { AdminIntegrationsService } from '../admin/admin-integrations.service';
import { AdminIntegrationsController } from '../admin/admin-integrations.controller';
import {
  IntegrationCategory,
  ProviderHealthStatus,
} from '../registry/provider.types';
import {
  CatalogProviderMetadata,
  ProviderActivationState,
  ProviderEnvironment,
} from '../catalog/provider-catalog.types';

describe('Phase J — Enterprise Integration Marketplace & Provider Catalog', () => {
  let catalogService: ProviderCatalogService;
  let adminService: AdminIntegrationsService;
  let adminController: AdminIntegrationsController;
  let configService: IntegrationConfigService;
  let healthService: ProviderHealthService;
  let secretVault: SecretVaultService;

  const mockConfigs: Record<string, any> = {};

  const mockSystemConfigService = {
    getConfig: jest.fn(async (key: string) => mockConfigs[key] ?? null),
    setConfig: jest.fn(async (key: string, val: any) => {
      mockConfigs[key] = val;
    }),
  };

  const mockPrismaService = {
    webhookEvent: {
      count: jest.fn().mockResolvedValue(0),
      findMany: jest.fn().mockResolvedValue([]),
    },
  };

  beforeEach(async () => {
    for (const k of Object.keys(mockConfigs)) {
      delete mockConfigs[k];
    }

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AdminIntegrationsController],
      providers: [
        SecretVaultService,
        IntegrationConfigService,
        ProviderHealthService,
        ProviderRegistryService,
        ProviderCatalogService,
        WebhookDispatcherService,
        AdminIntegrationsService,
        {
          provide: SystemConfigService,
          useValue: mockSystemConfigService,
        },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string) => {
              if (key === 'INTEGRATION_SECRET_KEY') {
                return '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
              }
              return null;
            }),
          },
        },
        {
          provide: PrismaService,
          useValue: mockPrismaService,
        },
      ],
    }).compile();

    catalogService = module.get<ProviderCatalogService>(ProviderCatalogService);
    adminService = module.get<AdminIntegrationsService>(AdminIntegrationsService);
    adminController = module.get<AdminIntegrationsController>(AdminIntegrationsController);
    configService = module.get<IntegrationConfigService>(IntegrationConfigService);
    healthService = module.get<ProviderHealthService>(ProviderHealthService);
    secretVault = module.get<SecretVaultService>(SecretVaultService);

    // Initialize catalog
    catalogService.onModuleInit();
  });

  describe('1. Built-in Catalog Seeding & Extensibility', () => {
    it('should initialize catalog with providers across all 13 categories', () => {
      const all = catalogService.getAllProviders();
      expect(all.length).toBeGreaterThanOrEqual(20);

      const categories = new Set(all.map((p) => p.category));
      expect(categories.has(IntegrationCategory.PAYMENT)).toBe(true);
      expect(categories.has(IntegrationCategory.MESSAGING_WHATSAPP)).toBe(true);
      expect(categories.has(IntegrationCategory.MESSAGING_SMS)).toBe(true);
      expect(categories.has(IntegrationCategory.MESSAGING_EMAIL)).toBe(true);
      expect(categories.has(IntegrationCategory.MESSAGING_PUSH)).toBe(true);
      expect(categories.has(IntegrationCategory.STORAGE)).toBe(true);
      expect(categories.has(IntegrationCategory.MAPS)).toBe(true);
      expect(categories.has(IntegrationCategory.IDENTITY_VERIFICATION)).toBe(true);
      expect(categories.has(IntegrationCategory.VEHICLE_TRACKING)).toBe(true);
      expect(categories.has(IntegrationCategory.ACCOUNTING)).toBe(true);
      expect(categories.has(IntegrationCategory.AI)).toBe(true);
      expect(categories.has(IntegrationCategory.SEARCH)).toBe(true);
      expect(categories.has(IntegrationCategory.ANALYTICS)).toBe(true);
    });

    it('should retrieve existing provider by category and ID', () => {
      const rzp = catalogService.getProvider(IntegrationCategory.PAYMENT, 'razorpay');
      expect(rzp.name).toBe('Razorpay');
      expect(rzp.supportedCurrencies).toContain('INR');
      expect(rzp.supportedCountries).toContain('IN');
      expect(rzp.credentialSchema.length).toBeGreaterThanOrEqual(3);
    });

    it('should throw NotFoundException for unknown provider', () => {
      expect(() =>
        catalogService.getProvider(IntegrationCategory.PAYMENT, 'non_existent'),
      ).toThrow(NotFoundException);
    });
  });

  describe('2. Dynamic Provider Registration & Duplicate Prevention', () => {
    it('should allow registering a new provider dynamically', () => {
      const customProvider: CatalogProviderMetadata = {
        providerId: 'paytm',
        category: IntegrationCategory.PAYMENT,
        name: 'Paytm Payments Gateway',
        tagline: 'India digital wallet and UPI gateway',
        description: 'Comprehensive Indian payment orchestration',
        icon: 'account_balance_wallet',
        websiteUrl: 'https://paytm.com',
        documentation: {
          overview: 'Paytm payment processing',
          docsUrl: 'https://developer.paytm.com',
          setupGuide: 'Obtain merchant key from dashboard',
        },
        version: '1.0.0',
        author: 'One97 Communications',
        tags: ['paytm', 'upi', 'wallet'],
        supportedEnvironments: [ProviderEnvironment.SANDBOX, ProviderEnvironment.LIVE],
        defaultEnvironment: ProviderEnvironment.SANDBOX,
        credentialSchema: [
          {
            key: 'merchantId',
            label: 'Merchant ID',
            type: 'string',
            required: true,
            isSecret: false,
            description: 'Paytm MID',
          },
          {
            key: 'merchantKey',
            label: 'Merchant Key',
            type: 'password',
            required: true,
            isSecret: true,
            description: 'Paytm API Secret',
          },
        ],
        supportedCapabilities: ['CREATE_ORDER', 'UPI_INTENT', 'REFUNDS'],
        supportedCurrencies: ['INR'],
        supportedCountries: ['IN'],
        platformAvailability: true,
        tenantTierAvailability: ['ALL'],
        activationState: ProviderActivationState.ACTIVE,
        priority: 4,
      };

      catalogService.registerProvider(customProvider);

      const retrieved = catalogService.getProvider(IntegrationCategory.PAYMENT, 'paytm');
      expect(retrieved.name).toBe('Paytm Payments Gateway');
      expect(retrieved.priority).toBe(4);
    });

    it('should throw ConflictException on duplicate provider registration', () => {
      const duplicate: CatalogProviderMetadata = {
        providerId: 'razorpay',
        category: IntegrationCategory.PAYMENT,
        name: 'Duplicate Razorpay',
        tagline: '',
        description: '',
        icon: '',
        websiteUrl: '',
        documentation: { overview: '', docsUrl: '', setupGuide: '' },
        version: '1.0.0',
        author: '',
        tags: [],
        supportedEnvironments: [ProviderEnvironment.SANDBOX],
        defaultEnvironment: ProviderEnvironment.SANDBOX,
        credentialSchema: [],
        supportedCapabilities: [],
        supportedCurrencies: [],
        supportedCountries: [],
        platformAvailability: true,
        tenantTierAvailability: ['ALL'],
        activationState: ProviderActivationState.ACTIVE,
        priority: 1,
      };

      expect(() => catalogService.registerProvider(duplicate)).toThrow(ConflictException);
    });
  });

  describe('3. Dynamic Capability Discovery & Filtering', () => {
    it('should discover providers by capability', () => {
      const webhookProviders = catalogService.getAllProviders({
        capability: 'WEBHOOKS',
      });
      expect(webhookProviders.length).toBeGreaterThan(0);
      expect(
        webhookProviders.every((p) => p.supportedCapabilities.includes('WEBHOOKS')),
      ).toBe(true);

      const upiProviders = catalogService.getAllProviders({
        capability: 'UPI_INTENT',
      });
      expect(upiProviders.some((p) => p.providerId === 'razorpay')).toBe(true);
      expect(upiProviders.some((p) => p.providerId === 'cashfree')).toBe(true);
    });

    it('should filter providers by regional availability', () => {
      const inProviders = catalogService.getAllProviders({ country: 'IN' });
      expect(inProviders.some((p) => p.providerId === 'razorpay')).toBe(true);

      const usProviders = catalogService.getAllProviders({ country: 'US' });
      expect(usProviders.some((p) => p.providerId === 'stripe')).toBe(true);
      expect(usProviders.some((p) => p.providerId === 'twilio')).toBe(true);
    });

    it('should filter providers by currency support', () => {
      const eurProviders = catalogService.getAllProviders({ currency: 'EUR' });
      expect(eurProviders.some((p) => p.providerId === 'stripe')).toBe(true);
      expect(eurProviders.some((p) => p.providerId === 'adyen')).toBe(true);
    });

    it('should filter providers by tenant tier availability', () => {
      const proProviders = catalogService.getAllProviders({ tenantTier: 'PRO' });
      expect(proProviders.length).toBeGreaterThan(0);
      expect(
        proProviders.every(
          (p) =>
            p.tenantTierAvailability.includes('ALL') ||
            p.tenantTierAvailability.includes('PRO'),
        ),
      ).toBe(true);
    });

    it('should support multi-keyword full-text search', () => {
      const searchResults = catalogService.getAllProviders({ search: 'Stripe' });
      expect(searchResults.length).toBeGreaterThan(0);
      expect(searchResults[0].providerId).toBe('stripe');

      const tagResults = catalogService.getAllProviders({ search: 'whatsapp' });
      expect(tagResults.some((p) => p.providerId === 'meta')).toBe(true);
    });
  });

  describe('4. Credential Schema Validation', () => {
    it('should validate required credential fields according to schema', () => {
      const invalid = catalogService.validateCredentials(
        IntegrationCategory.PAYMENT,
        'razorpay',
        { keyId: 'rzp_test_123' }, // missing keySecret and webhookSecret
      );
      expect(invalid.isValid).toBe(false);
      expect(invalid.errors.some((e) => e.includes('Key Secret'))).toBe(true);

      const valid = catalogService.validateCredentials(
        IntegrationCategory.PAYMENT,
        'razorpay',
        {
          keyId: 'rzp_test_1234567890',
          keySecret: 'secret_abc123xyz456',
          webhookSecret: 'whsec_9876543210',
        },
      );
      expect(valid.isValid).toBe(true);
      expect(valid.errors.length).toBe(0);
    });

    it('should enforce regex validation where defined in schema', () => {
      const invalidRegex = catalogService.validateCredentials(
        IntegrationCategory.PAYMENT,
        'razorpay',
        {
          keyId: 'invalid_prefix_123', // Doesn't match ^rzp_(test|live)_[A-Za-z0-9]+$
          keySecret: 'secret_123',
          webhookSecret: 'wh_123',
        },
      );
      expect(invalidRegex.isValid).toBe(false);
      expect(invalidRegex.errors.some((e) => e.includes('format'))).toBe(true);
    });
  });

  describe('5. Fallback Priority Chain Resolution', () => {
    it('should resolve fallback priority chain in ascending order (lower number = higher priority)', () => {
      const chain = catalogService.resolveFallbackChain(IntegrationCategory.PAYMENT, {
        region: 'IN',
        currency: 'INR',
      });

      expect(chain.length).toBeGreaterThanOrEqual(2);
      expect(chain[0].providerId).toBe('razorpay'); // priority 1
      expect(chain[1].providerId).toBe('cashfree'); // priority 2
      expect(chain[0].priority).toBeLessThanOrEqual(chain[1].priority);
    });

    it('should honor explicit fallbackProviderId chaining', () => {
      const chain = catalogService.resolveFallbackChain(IntegrationCategory.MESSAGING_WHATSAPP);
      expect(chain.length).toBeGreaterThanOrEqual(2);
      expect(chain[0].providerId).toBe('meta');
      expect(chain[1].providerId).toBe('gupshup_whatsapp'); // Meta's explicit fallbackProviderId
    });

    it('should filter fallback candidates by active environment', () => {
      const liveChain = catalogService.resolveFallbackChain(IntegrationCategory.STORAGE, {
        environment: ProviderEnvironment.LIVE,
      });
      expect(liveChain.length).toBeGreaterThan(0);
      expect(
        liveChain.every((p) => p.supportedEnvironments.includes(ProviderEnvironment.LIVE)),
      ).toBe(true);
    });
  });

  describe('6. Activation State Transitions', () => {
    it('should update provider activation state and respect state in fallback resolution', () => {
      catalogService.updateActivationState(
        IntegrationCategory.PAYMENT,
        'cashfree',
        ProviderActivationState.SUSPENDED,
      );

      const updated = catalogService.getProvider(IntegrationCategory.PAYMENT, 'cashfree');
      expect(updated.activationState).toBe(ProviderActivationState.SUSPENDED);

      // Should no longer appear in active fallback chain
      const activeChain = catalogService.resolveFallbackChain(IntegrationCategory.PAYMENT, {
        region: 'IN',
      });
      expect(activeChain.some((p) => p.providerId === 'cashfree')).toBe(false);

      // Restore
      catalogService.updateActivationState(
        IntegrationCategory.PAYMENT,
        'cashfree',
        ProviderActivationState.ACTIVE,
      );
    });
  });

  describe('7. Secret Masking & Security Vault Preservation', () => {
    it('should never expose plaintext credentials in getMarketplaceOverview', async () => {
      // Configure credentials in DB
      await configService.setProviderConfig(IntegrationCategory.PAYMENT, 'razorpay', {
        credentials: {
          keyId: 'rzp_test_TOPSECRET123',
          keySecret: 'super_secret_password_never_expose',
        },
      });

      const overview = await catalogService.getMarketplaceOverview();
      const rzpView = overview.find((p) => p.providerId === 'razorpay');

      expect(rzpView).toBeDefined();
      expect(rzpView?.isConfigured).toBe(true);
      expect(rzpView?.hasCredentials).toBe(true);

      // Secrets must be masked!
      expect(rzpView?.maskedCredentials['keySecret']).not.toBe(
        'super_secret_password_never_expose',
      );
      expect(rzpView?.maskedCredentials['keySecret']).toContain('...');
      expect(rzpView?.maskedCredentials['keySecret']).not.toContain('password_never');
    });
  });

  describe('8. Admin Controller Endpoints Integration', () => {
    it('GET /marketplace should return unified marketplace provider views', async () => {
      const views = await adminController.getMarketplace(IntegrationCategory.PAYMENT);
      expect(views.length).toBeGreaterThanOrEqual(4);
      expect(views.some((v) => v.providerId === 'razorpay')).toBe(true);
      expect(views.some((v) => v.providerId === 'stripe')).toBe(true);
      expect(views[0].health).toBeDefined();
    });

    it('GET /catalog should return catalog entries with filters', async () => {
      const catalog = await adminController.getCatalog(
        IntegrationCategory.MESSAGING_SMS,
        undefined,
        'IN',
      );
      expect(catalog.length).toBeGreaterThanOrEqual(1);
      expect(catalog.some((c) => c.providerId === 'msg91')).toBe(true);
    });

    it('POST /catalog should register new provider via admin endpoint', async () => {
      const dto = {
        providerId: 'gemini_flash',
        category: IntegrationCategory.AI,
        name: 'Google Gemini 1.5 Flash',
        tagline: 'High-speed multimodal AI engine',
        description: 'Low-latency AI models for vehicle damage analysis and customer chat',
        icon: 'auto_awesome',
        websiteUrl: 'https://deepmind.google/technologies/gemini',
        documentation: {
          overview: 'Fast multimodal model',
          docsUrl: 'https://ai.google.dev',
          setupGuide: 'Obtain API key from Google AI Studio',
        },
        version: '1.5.0',
        author: 'Google DeepMind',
        tags: ['ai', 'vision', 'llm'],
        supportedCapabilities: ['DAMAGE_ASSESSMENT', 'CHAT_AGENT'],
        credentialSchema: [
          {
            key: 'apiKey',
            label: 'API Key',
            type: 'password',
            required: true,
            isSecret: true,
            description: 'Google AI Studio API Key',
          },
        ],
      };

      const registered = await adminController.registerCatalogProvider(dto as any);
      expect(registered.providerId).toBe('gemini_flash');

      const found = catalogService.getProvider(IntegrationCategory.AI, 'gemini_flash');
      expect(found.name).toBe('Google Gemini 1.5 Flash');
    });

    it('PUT /catalog/:category/:providerId/activation should update activation state', async () => {
      const updated = await adminController.updateActivationState(
        IntegrationCategory.MAPS,
        'mapbox',
        { activationState: 'SUSPENDED' },
      );
      expect(updated.activationState).toBe(ProviderActivationState.SUSPENDED);
    });

    it('POST /catalog/:category/:providerId/validate should validate credentials', async () => {
      const validation = await adminController.validateCredentials(
        IntegrationCategory.MESSAGING_EMAIL,
        'resend',
        {
          credentials: { apiKey: 're_123456789' },
        },
      );
      expect(validation.isValid).toBe(true);
    });

    it('GET /fallback-chain/:category should return resolved fallback chain', async () => {
      const chain = await adminController.getFallbackChain(
        IntegrationCategory.PAYMENT,
        'IN',
        'INR',
      );
      expect(chain.length).toBeGreaterThanOrEqual(2);
      expect(chain[0].providerId).toBe('razorpay');
    });
  });
});

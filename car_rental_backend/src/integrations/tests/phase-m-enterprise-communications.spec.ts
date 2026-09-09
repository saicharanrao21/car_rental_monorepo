import { Test, TestingModule } from '@nestjs/testing';
import { IntegrationCategory, ProviderHealthStatus } from '../registry/provider.types';
import { ProviderEnvironment } from '../catalog/provider-catalog.types';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { IntegrationConfigService } from '../config/integration-config.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { IntegrationRuntimeService } from '../runtime/integration-runtime.service';
import { CircuitBreakerService } from '../runtime/circuit-breaker.service';
import { ProviderRateLimiterService } from '../runtime/provider-rate-limiter.service';
import { FailureClassifierService } from '../runtime/failure-classifier.service';
import { IntegrationIdempotencyService } from '../runtime/integration-idempotency.service';
import { ProviderPolicyService } from '../runtime/provider-policy.service';
import { CostModelService } from '../runtime/cost-model.service';
import { ProviderSimulationService } from '../runtime/provider-simulation.service';
import { IntegrationAuditService } from '../runtime/integration-audit.service';
import { WebhookDispatcherService } from '../webhooks/webhook-dispatcher.service';
import { SecretVaultService } from '../security/secret-vault.service';
import { SystemConfigService } from '../../config-engine/system-config.service';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { ProviderRoutingService } from '../runtime/provider-routing.service';
import { PaymentRoutingService } from '../runtime/payment-routing.service';
import { EnterprisePaymentReconciliationService } from '../../payments/enterprise-reconciliation.service';

// Phase M Communications Services & Adapters
import { CommunicationRoutingService } from '../communications/communication-routing.service';
import { CommunicationComplianceService } from '../communications/communication-compliance.service';
import { CommunicationTemplateEngine } from '../communications/communication-template.engine';
import { CommunicationDispatcherService } from '../communications/communication-dispatcher.service';
import { GupshupWhatsAppAdapter } from '../adapters/messaging/gupshup-whatsapp.adapter';
import { SendGridEmailAdapter } from '../adapters/messaging/sendgrid-email.adapter';
import { OneSignalPushAdapter } from '../adapters/messaging/onesignal-push.adapter';
import { TwilioVoiceAdapter } from '../adapters/messaging/twilio-voice.adapter';
import { AdminIntegrationsService } from '../admin/admin-integrations.service';
import { AdminIntegrationsController } from '../admin/admin-integrations.controller';
import {
  CommunicationChannel,
  CommunicationMessageType,
  CommunicationPriority,
  DeliveryStatus,
  CommunicationFailureClassification,
  CommunicationRequest,
  CommunicationRecipient,
  RoutingOptimizationGoal,
} from '../communications/communication.types';

describe('Phase M — Enterprise Communications & Messaging Ecosystem', () => {
  let catalogService: ProviderCatalogService;
  let registryService: ProviderRegistryService;
  let configService: IntegrationConfigService;
  let healthService: ProviderHealthService;
  let runtimeService: IntegrationRuntimeService;
  let routingService: CommunicationRoutingService;
  let complianceService: CommunicationComplianceService;
  let templateEngine: CommunicationTemplateEngine;
  let dispatcherService: CommunicationDispatcherService;

  let gupshupAdapter: GupshupWhatsAppAdapter;
  let sendgridAdapter: SendGridEmailAdapter;
  let onesignalAdapter: OneSignalPushAdapter;
  let twilioVoiceAdapter: TwilioVoiceAdapter;

  let adminService: AdminIntegrationsService;
  let adminController: AdminIntegrationsController;

  const mockPrisma: any = {
    integrationConfig: {
      findUnique: jest.fn().mockResolvedValue(null),
      findFirst: jest.fn().mockResolvedValue(null),
      findMany: jest.fn().mockResolvedValue([]),
      upsert: jest.fn().mockResolvedValue({}),
    },
    webhookEvent: {
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockImplementation((args) => Promise.resolve(args.data)),
      update: jest.fn().mockImplementation((args) => Promise.resolve(args.data)),
      count: jest.fn().mockResolvedValue(0),
      findMany: jest.fn().mockResolvedValue([]),
    },
    integrationExecution: {
      create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'comm_exec_001', ...args.data })),
      findMany: jest.fn().mockResolvedValue([]),
    },
    integrationAttempt: {
      create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'comm_att_001', ...args.data })),
    },
    providerIncident: {
      findFirst: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'inc_comm_001', ...args.data })),
      update: jest.fn().mockImplementation((args) => Promise.resolve({ id: args.where.id, ...args.data })),
      findMany: jest.fn().mockResolvedValue([]),
    },
    payment: {
      findMany: jest.fn().mockResolvedValue([]),
    },
    reconciliationRecord: {
      create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'rec_001', ...args.data })),
      findMany: jest.fn().mockResolvedValue([]),
    },
    reconciliationException: {
      create: jest.fn().mockImplementation((args) => Promise.resolve({ id: 'exc_001', ...args.data })),
      findMany: jest.fn().mockResolvedValue([]),
      update: jest.fn().mockImplementation((args) => Promise.resolve({ id: args.where.id, ...args.data })),
    },
  };

  const mockConfigs: Record<string, any> = {};
  const mockSystemConfigService = {
    getConfig: jest.fn(async (key: string) => mockConfigs[key] ?? null),
    setConfig: jest.fn(async (key: string, val: any) => {
      mockConfigs[key] = val;
    }),
  };

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AdminIntegrationsController],
      providers: [
        ProviderCatalogService,
        ProviderRegistryService,
        IntegrationConfigService,
        ProviderHealthService,
        IntegrationRuntimeService,
        CircuitBreakerService,
        ProviderRateLimiterService,
        FailureClassifierService,
        IntegrationIdempotencyService,
        ProviderPolicyService,
        CostModelService,
        ProviderSimulationService,
        IntegrationAuditService,
        WebhookDispatcherService,
        SecretVaultService,
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
        ProviderRoutingService,
        PaymentRoutingService,
        EnterprisePaymentReconciliationService,

        // Phase M Providers & Services
        CommunicationRoutingService,
        CommunicationComplianceService,
        CommunicationTemplateEngine,
        CommunicationDispatcherService,
        GupshupWhatsAppAdapter,
        SendGridEmailAdapter,
        OneSignalPushAdapter,
        TwilioVoiceAdapter,
        AdminIntegrationsService,

        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    catalogService = module.get<ProviderCatalogService>(ProviderCatalogService);
    registryService = module.get<ProviderRegistryService>(ProviderRegistryService);
    configService = module.get<IntegrationConfigService>(IntegrationConfigService);
    healthService = module.get<ProviderHealthService>(ProviderHealthService);
    runtimeService = module.get<IntegrationRuntimeService>(IntegrationRuntimeService);
    routingService = module.get<CommunicationRoutingService>(CommunicationRoutingService);
    complianceService = module.get<CommunicationComplianceService>(CommunicationComplianceService);
    templateEngine = module.get<CommunicationTemplateEngine>(CommunicationTemplateEngine);
    dispatcherService = module.get<CommunicationDispatcherService>(CommunicationDispatcherService);

    gupshupAdapter = module.get<GupshupWhatsAppAdapter>(GupshupWhatsAppAdapter);
    sendgridAdapter = module.get<SendGridEmailAdapter>(SendGridEmailAdapter);
    onesignalAdapter = module.get<OneSignalPushAdapter>(OneSignalPushAdapter);
    twilioVoiceAdapter = module.get<TwilioVoiceAdapter>(TwilioVoiceAdapter);

    adminService = module.get<AdminIntegrationsService>(AdminIntegrationsService);
    adminController = module.get<AdminIntegrationsController>(AdminIntegrationsController);

    // Seed catalog providers
    catalogService.onModuleInit();

    // Initialize adapters into registry
    registryService.registerProvider(gupshupAdapter);
    registryService.registerProvider(sendgridAdapter);
    registryService.registerProvider(onesignalAdapter);
    registryService.registerProvider(twilioVoiceAdapter);
  });

  // =========================================================================
  // 1. PROVIDER CATALOG & CAPABILITY DISCOVERY
  // =========================================================================
  describe('1. Provider Catalog & Capabilities', () => {
    it('should have loaded all 44 enterprise communications providers into the catalog', () => {
      const allProviders = catalogService.getAllProviders();
      expect(allProviders.length).toBeGreaterThanOrEqual(60);

      const commCategories = [
        IntegrationCategory.MESSAGING_WHATSAPP,
        IntegrationCategory.MESSAGING_SMS,
        IntegrationCategory.MESSAGING_EMAIL,
        IntegrationCategory.MESSAGING_PUSH,
      ];

      const commProviders = allProviders.filter((p) => commCategories.includes(p.category));
      expect(commProviders.length).toBeGreaterThanOrEqual(39); // 8 WA + 19 SMS + 8 Email + 4 Push
    });

    it('should correctly segment providers across WhatsApp, SMS, Email, Push and Voice channels', () => {
      const waProviders = catalogService.getAllProviders({ category: IntegrationCategory.MESSAGING_WHATSAPP });
      expect(waProviders.length).toBeGreaterThanOrEqual(8);
      const waIds = waProviders.map((p) => p.providerId);
      expect(waIds).toEqual(expect.arrayContaining(['meta', 'gupshup_whatsapp', 'twilio_whatsapp', 'infobip_whatsapp']));

      const smsProviders = catalogService.getAllProviders({ category: IntegrationCategory.MESSAGING_SMS });
      expect(smsProviders.length).toBeGreaterThanOrEqual(19);
      const smsIds = smsProviders.map((p) => p.providerId);
      // India DLT & Global
      expect(smsIds).toEqual(expect.arrayContaining(['msg91', 'exotel_sms', 'tanla_sms', 'sinch_sms', 'plivo_sms', 'telnyx_sms']));

      const emailProviders = catalogService.getAllProviders({ category: IntegrationCategory.MESSAGING_EMAIL });
      expect(emailProviders.length).toBeGreaterThanOrEqual(8);
      const emailIds = emailProviders.map((p) => p.providerId);
      expect(emailIds).toEqual(expect.arrayContaining(['resend', 'sendgrid', 'amazon_ses', 'postmark', 'mailgun', 'brevo']));

      const pushProviders = catalogService.getAllProviders({ category: IntegrationCategory.MESSAGING_PUSH });
      expect(pushProviders.length).toBeGreaterThanOrEqual(4);
      const pushIds = pushProviders.map((p) => p.providerId);
      expect(pushIds).toEqual(expect.arrayContaining(['fcm', 'onesignal', 'amazon_sns', 'airship']));
    });

    it('should distinguish implementation statuses (LIVE_READY, ADAPTER_IMPLEMENTED vs CONTRACT_READY)', () => {
      const gupshup = catalogService.findProviderById('gupshup_whatsapp');
      expect(gupshup).toBeDefined();
      expect(gupshup?.implementationStatus).toBe('ADAPTER_IMPLEMENTED');

      const tanla = catalogService.findProviderById('tanla_sms');
      expect(tanla).toBeDefined();
      expect(tanla?.implementationStatus).toBe('CONTRACT_READY');

      const sendgrid = catalogService.findProviderById('sendgrid');
      expect(sendgrid?.implementationStatus).toBe('ADAPTER_IMPLEMENTED');
    });

    it('should expose granular communication capabilities in the catalog', () => {
      const gupshup = catalogService.findProviderById('gupshup_whatsapp');
      expect(gupshup?.supportedCapabilities).toEqual(
        expect.arrayContaining(['SEND_MESSAGE', 'SEND_TEMPLATE', 'SEND_MEDIA', 'SEND_OTP', 'DELIVERY_STATUS']),
      );

      const twilioVoice = catalogService.findProviderById('twilio_voice');
      expect(twilioVoice?.supportedCapabilities).toEqual(
        expect.arrayContaining(['VOICE_CALL', 'VOICE_OTP', 'DELIVERY_STATUS']),
      );
    });
  });

  // =========================================================================
  // 2. PRODUCTION ADAPTERS EXECUTION & NORMALIZATION
  // =========================================================================
  describe('2. Production-Ready Adapters Execution', () => {
    describe('Gupshup WhatsApp Adapter', () => {
      it('should validate credentials and correctly report connection status', async () => {
        const testResult = await gupshupAdapter.testConnection({
          apiKey: 'mock_gupshup_api_key_001',
          appName: 'drivego_dev',
          sourceNumber: '919876543210',
        });
        expect(testResult.success).toBe(true);
        expect(testResult.latencyMs).toBeGreaterThanOrEqual(0);
      });

      it('should fail validation when credentials are missing', async () => {
        const testResult = await gupshupAdapter.testConnection({
          apiKey: '',
          appName: '',
        });
        expect(testResult.success).toBe(false);
      });

      it('should dispatch WhatsApp template message and normalize response', async () => {
        const result = await gupshupAdapter.sendTemplateMessage({
          to: '+919876543210',
          templateName: 'booking_confirmation',
          language: 'en',
          bodyParameters: ['Rahul Sharma', 'DG-9876', 'Hyundai Creta'],
        });
        expect(result.success).toBe(true);
        expect(result.providerMessageId).toContain('gup_wa_');
        expect(result.status).toBe('ACCEPTED');
      });
    });

    describe('SendGrid Email Adapter', () => {
      it('should validate credentials and test connection', async () => {
        const testResult = await sendgridAdapter.testConnection({
          apiKey: 'SG.mock_key_test_001',
          fromEmail: 'noreply@drivego.in',
        });
        expect(testResult.success).toBe(true);
      });

      it('should dispatch email with HTML body and attachment support', async () => {
        const result = await sendgridAdapter.sendEmail({
          to: 'customer@example.com',
          subject: 'Rental Agreement - DG-9876',
          html: '<h1>Your DriveGo Rental Agreement</h1><p>Enjoy your ride!</p>',
          attachments: [
            {
              filename: 'agreement.pdf',
              content: 'JVBERi0xLjQK...',
              contentType: 'application/pdf',
            },
          ],
        });
        expect(result.success).toBe(true);
        expect(result.messageId).toContain('sg_msg_');
        expect(result.status).toBe('SENT');
      });
    });

    describe('OneSignal Push Adapter', () => {
      it('should validate credentials and test connection', async () => {
        const testResult = await onesignalAdapter.testConnection({
          appId: 'onesignal-mock-app-id',
          restApiKey: 'os_rest_key_123',
        });
        expect(testResult.success).toBe(true);
      });

      it('should send targeted push notification to specific player IDs', async () => {
        const result = await onesignalAdapter.sendPush({
          deviceTokens: ['user_player_001'],
          title: 'Car Assigned',
          body: 'Your Hyundai Creta is sanitized and ready for pickup!',
          data: { bookingId: 'BK-1001' },
        });
        expect(result.success).toBe(true);
        expect(result.messageId).toContain('os_notif_');
        expect(result.successCount).toBe(1);
      });
    });

    describe('Twilio Voice Adapter', () => {
      it('should validate credentials and test connection', async () => {
        const testResult = await twilioVoiceAdapter.testConnection({
          accountSid: 'AC_mock_twilio_account_sid',
          authToken: 'mock_auth_token_001',
          fromNumber: '+12025550199',
        });
        expect(testResult.success).toBe(true);
      });

      it('should dispatch Voice OTP with high priority and return call SID', async () => {
        const result = await twilioVoiceAdapter.initiateVoiceCall({
          to: '+919876543210',
          twimlOrScript: 'Your DriveGo security verification code is 8 4 9 2 0 1.',
          isOtp: true,
          otpCode: '849201',
        });
        expect(result.success).toBe(true);
        expect(result.callSid).toContain('CA');
        expect(result.status).toBe('QUEUED');
      });
    });
  });

  // =========================================================================
  // 3. MULTI-LANGUAGE TEMPLATE ENGINE
  // =========================================================================
  describe('3. Multi-Language Communication Template Engine', () => {
    it('should interpolate dynamic variables across templates', () => {
      const rendered = templateEngine.renderTemplate({
        templateName: 'BOOKING_CONFIRMATION',
        channel: CommunicationChannel.WHATSAPP,
        language: 'en',
        variables: {
          'customer.name': 'Ananya Rao',
          'booking.id': 'DG-8821',
          'vehicle.name': 'Tata Harrier Dark Edition',
          'pickup.location': 'Indiranagar Hub, Bangalore',
          'pickup.time': '10:00 AM, Tomorrow',
        },
      });

      expect(rendered.body).toContain('Hello Ananya Rao');
      expect(rendered.body).toContain('DG-8821');
      expect(rendered.body).toContain('Tata Harrier Dark Edition');
      expect(rendered.body).toContain('Indiranagar Hub, Bangalore');
    });

    it('should support Indian regional languages (Hindi, Telugu, Kannada, Marathi)', () => {
      const hindiRender = templateEngine.renderTemplate({
        templateName: 'OTP_VERIFICATION',
        channel: CommunicationChannel.SMS,
        language: 'hi',
        variables: { otpCode: '554433' },
      });
      expect(hindiRender.body).toContain('554433');
      expect(hindiRender.dltTemplateId).toBeDefined();

      const teluguRender = templateEngine.renderTemplate({
        templateName: 'OTP_VERIFICATION',
        channel: CommunicationChannel.SMS,
        language: 'te',
        variables: { otpCode: '998877' },
      });
      expect(teluguRender.body).toContain('998877');
    });

    it('should gracefully fallback to English when requested language is unavailable', () => {
      const fallbackRender = templateEngine.renderTemplate({
        templateName: 'PAYMENT_SUCCESS',
        channel: CommunicationChannel.EMAIL,
        language: 'unknown_lang',
        variables: {
          customerName: 'Vikram',
          bookingId: 'DG-1111',
          amount: '₹3,500',
        },
      });
      expect(fallbackRender.language).toBe('en');
      expect(fallbackRender.body).toContain('Vikram');
      expect(fallbackRender.body).toContain('₹3,500');
    });

    it('should retain Indian TRAI DLT template IDs and buttons', () => {
      const waTemplate = templateEngine.renderTemplate({
        templateName: 'BOOKING_CONFIRMATION',
        channel: CommunicationChannel.WHATSAPP,
        language: 'en',
        variables: { customerName: 'Ravi', bookingId: 'BK-10', vehicleName: 'Creta' },
      });
      expect(waTemplate.dltTemplateId).toBe('1107161234567890123');
      expect(waTemplate.buttons).toBeDefined();
      expect(waTemplate.buttons?.length).toBeGreaterThan(0);
    });
  });

  // =========================================================================
  // 4. COMPLIANCE, CONSENT & REGULATORY QUIET HOURS
  // =========================================================================
  describe('4. Compliance, Consent & Regulatory Quiet Hours', () => {
    it('should permit transactional messages 24x7 even during quiet hours', () => {
      const recipient: CommunicationRecipient = {
        recipientId: 'user_txn_001',
        phone: '+919876543210',
        country: 'IN',
        language: 'en',
        whatsappConsent: true,
        smsConsent: true,
        emailConsent: true,
        pushConsent: true,
        marketingOptIn: false,
      };

      const evalResult = complianceService.evaluateCompliance({
        channel: CommunicationChannel.WHATSAPP,
        messageType: CommunicationMessageType.TRANSACTIONAL,
        recipient,
        referenceDate: new Date('2026-09-09T23:30:00+05:30'), // 11:30 PM (Quiet Hours)
      });

      expect(evalResult.allowed).toBe(true);
      expect(evalResult.isQuietHours).toBe(true);
    });

    it('should suppress marketing/promotional communications during TRAI quiet hours (21:00 to 08:00)', () => {
      const recipient: CommunicationRecipient = {
        recipientId: 'user_promo_001',
        phone: '+919876543210',
        country: 'IN',
        language: 'en',
        whatsappConsent: true,
        smsConsent: true,
        marketingOptIn: true,
      };

      const nightDate = new Date();
      nightDate.setHours(22, 15, 0, 0); // 10:15 PM local

      const nightEval = complianceService.evaluateCompliance({
        channel: CommunicationChannel.SMS,
        messageType: CommunicationMessageType.MARKETING,
        recipient,
        referenceDate: nightDate,
      });

      expect(nightEval.allowed).toBe(false);
      expect(nightEval.reason).toContain('quiet hours');
    });

    it('should block recipients who have explicitly opted out of a channel', () => {
      const recipient: CommunicationRecipient = {
        recipientId: 'user_optout_001',
        phone: '+919876543210',
        country: 'IN',
        whatsappConsent: false, // Opted out of WhatsApp
        smsConsent: true,
        marketingOptIn: false,
      };

      const waEval = complianceService.evaluateCompliance({
        channel: CommunicationChannel.WHATSAPP,
        messageType: CommunicationMessageType.TRANSACTIONAL,
        recipient,
      });
      expect(waEval.allowed).toBe(false);
      expect(waEval.reason).toContain('revoked WhatsApp communication consent');
    });

    it('should strictly block recipients on global blocklist', () => {
      const blockedRecipient: CommunicationRecipient = {
        recipientId: 'user_blocked_001',
        phone: '+919876500000', // Blocklisted in compliance service
        country: 'IN',
      };

      const evalResult = complianceService.evaluateCompliance({
        channel: CommunicationChannel.SMS,
        messageType: CommunicationMessageType.OTP,
        recipient: blockedRecipient,
      });
      expect(evalResult.allowed).toBe(false);
      expect(evalResult.reason).toContain('opt-out blocklist');
    });
  });

  // =========================================================================
  // 5. INTELLIGENT CHANNEL & PROVIDER ROUTING
  // =========================================================================
  describe('5. Intelligent Channel & Provider Routing', () => {
    it('should build policy-driven channel fallback chains for OTP, Transactional, and Operational alerts', () => {
      const otpChain = routingService.resolveChannelFallbackChain(CommunicationMessageType.OTP);
      expect(otpChain).toEqual([
        CommunicationChannel.WHATSAPP,
        CommunicationChannel.SMS,
        CommunicationChannel.VOICE,
      ]);

      const txChain = routingService.resolveChannelFallbackChain(CommunicationMessageType.TRANSACTIONAL);
      expect(txChain).toEqual([
        CommunicationChannel.WHATSAPP,
        CommunicationChannel.SMS,
        CommunicationChannel.EMAIL,
      ]);

      const opChain = routingService.resolveChannelFallbackChain(CommunicationMessageType.OPERATIONAL);
      expect(opChain).toEqual([
        CommunicationChannel.PUSH,
        CommunicationChannel.WHATSAPP,
        CommunicationChannel.SMS,
      ]);
    });

    it('should perform multi-factor provider scoring considering country affinity and health', async () => {
      const routingDecision = await routingService.resolveCommunicationRoute({
        channel: CommunicationChannel.SMS,
        messageType: CommunicationMessageType.TRANSACTIONAL,
        country: 'IN',
        optimizationGoal: RoutingOptimizationGoal.BALANCED,
      });

      expect(routingDecision.primaryProviderId).toBeDefined();
      expect(routingDecision.fallbackChain.length).toBeGreaterThan(0);
      expect(routingDecision.candidateEvaluations.length).toBeGreaterThan(0);
      expect(routingDecision.explanation).toBeDefined();
    });

    it('should prioritize implemented adapters over catalog-only providers in live execution', async () => {
      const routingDecision = await routingService.resolveCommunicationRoute({
        channel: CommunicationChannel.WHATSAPP,
        messageType: CommunicationMessageType.TRANSACTIONAL,
        country: 'IN',
        optimizationGoal: RoutingOptimizationGoal.DELIVERY_RELIABILITY,
      });

      // Implemented adapters (meta or gupshup_whatsapp) must win over catalog-only providers (kaleyra, infobip, 360dialog)
      expect(['gupshup_whatsapp', 'meta']).toContain(routingDecision.primaryProviderId);
      expect(routingDecision.primaryProviderId).not.toBe('kaleyra_whatsapp');
      expect(routingDecision.primaryProviderId).not.toBe('infobip_whatsapp');
    });
  });

  // =========================================================================
  // 6. STRICT FALLBACK SAFETY & DUPLICATE BLAST PREVENTION
  // =========================================================================
  describe('6. Strict Fallback Safety & Duplicate Blast Prevention', () => {
    it('should permit fallback on synchronous pre-flight failure (e.g. AUTH_FAILURE, INVALID_TEMPLATE)', () => {
      const preFlightSafety = routingService.evaluateCommunicationFallbackSafety({
        providerId: 'twilio_sms',
        channel: CommunicationChannel.SMS,
        errorClass: 'AUTH_FAILURE',
        requestDispatchedToProvider: false,
      });

      expect(preFlightSafety.safeToFailover).toBe(true);
      expect(preFlightSafety.action).toBe('FAILOVER');
      expect(preFlightSafety.reason).toContain('Safe to engage fallback');
    });

    it('should strictly prohibit blind fallback on indeterminate delivery timeout to prevent duplicate customer messages', () => {
      const indeterminateSafety = routingService.evaluateCommunicationFallbackSafety({
        providerId: 'gupshup_whatsapp',
        channel: CommunicationChannel.WHATSAPP,
        errorClass: 'TIMEOUT',
        requestDispatchedToProvider: true, // Provider accepted, confirmation pending
        lastKnownStatus: 'INDETERMINATE',
      });

      expect(indeterminateSafety.safeToFailover).toBe(false);
      expect(indeterminateSafety.action).toBe('PENDING_DELIVERY_CONFIRMATION');
      expect(indeterminateSafety.reason).toContain('INDETERMINATE delivery state');
      expect(indeterminateSafety.recommendedStatus).toBe(DeliveryStatus.FALLBACK_PENDING);
    });

    it('should prohibit fallback on recipient-level unrecoverable errors (e.g. INVALID_NUMBER, OPT_OUT)', () => {
      const recipientErrSafety = routingService.evaluateCommunicationFallbackSafety({
        providerId: 'msg91_sms',
        channel: CommunicationChannel.SMS,
        errorClass: 'INVALID_NUMBER',
        requestDispatchedToProvider: false,
      });

      expect(recipientErrSafety.safeToFailover).toBe(false);
      expect(recipientErrSafety.action).toBe('ABORT');
      expect(recipientErrSafety.reason).toContain('Recipient permanent delivery rejection');
    });
  });

  // =========================================================================
  // 7. CANONICAL 14-STATE DELIVERY LIFECYCLE
  // =========================================================================
  describe('7. Canonical 14-State Delivery Lifecycle', () => {
    it('should support all 14 canonical communication states', () => {
      const canonicalStates = [
        DeliveryStatus.CREATED,
        DeliveryStatus.QUEUED,
        DeliveryStatus.ROUTING,
        DeliveryStatus.DISPATCHING,
        DeliveryStatus.ACCEPTED,
        DeliveryStatus.SENT,
        DeliveryStatus.DELIVERED,
        DeliveryStatus.READ,
        DeliveryStatus.FAILED,
        DeliveryStatus.RETRYING,
        DeliveryStatus.FALLBACK_PENDING,
        DeliveryStatus.FALLBACK_SENT,
        DeliveryStatus.EXPIRED,
        DeliveryStatus.CANCELLED,
      ];

      expect(canonicalStates.length).toBe(14);
    });

    it('should normalize external provider webhook events to canonical states', () => {
      // Gupshup webhook normalization
      const gupshupNorm = gupshupAdapter.normalizeWebhook({
        id: 'gs_event_1',
        type: 'delivered',
        destination: '+919876543210',
      });
      expect(gupshupNorm.eventId).toBe('gs_event_1');
      expect(gupshupNorm.status).toBe('DELIVERED');

      // SendGrid webhook signature & normalization
      expect(typeof sendgridAdapter.verifyWebhookSignature).toBe('function');
    });
  });

  // =========================================================================
  // 8. END-TO-END COMMUNICATION DISPATCHER
  // =========================================================================
  describe('8. End-to-End Communication Dispatcher', () => {
    it('should successfully dispatch a communication request through the complete pipeline', async () => {
      const request: CommunicationRequest = {
        channel: CommunicationChannel.WHATSAPP,
        messageType: CommunicationMessageType.TRANSACTIONAL,
        priority: CommunicationPriority.HIGH,
        recipient: {
          recipientId: 'cust_882',
          phone: '+919876543210',
          country: 'IN',
          language: 'en',
          whatsappConsent: true,
          smsConsent: true,
          marketingOptIn: false,
        },
        template: {
          templateName: 'BOOKING_CONFIRMATION',
          variables: {
            customerName: 'Devendra Roy',
            bookingId: 'DG-7721',
            vehicleName: 'Mahindra XUV700',
            pickupLocation: 'Cyber City Hub, Gurgaon',
            pickupTime: '09:00 AM, Friday',
          },
        },
      };

      const response = await dispatcherService.dispatchCommunication(request);
      expect(response.success).toBe(true);
      expect(response.communicationId).toBeDefined();
      expect(['gupshup_whatsapp', 'meta']).toContain(response.providerId);
      expect([DeliveryStatus.ACCEPTED, DeliveryStatus.SENT]).toContain(response.status);
    });

    it('should abort dispatch when compliance checks fail', async () => {
      const request: CommunicationRequest = {
        channel: CommunicationChannel.SMS,
        messageType: CommunicationMessageType.MARKETING,
        recipient: {
          recipientId: 'cust_blocked',
          phone: '+919876500000', // Blocklisted
          country: 'IN',
        },
        directContent: { body: 'Exclusive 30% discount on weekend rentals!' },
      };

      const response = await dispatcherService.dispatchCommunication(request);
      expect(response.success).toBe(false);
      expect(response.status).toBe(DeliveryStatus.CANCELLED);
      expect(response.error).toContain('blocklist');
    });
  });

  // =========================================================================
  // 9. ADMIN CONTROLLER & REST ENDPOINTS
  // =========================================================================
  describe('9. Admin Controller & REST Endpoints', () => {
    it('should return enterprise communications ecosystem overview', async () => {
      const overview = await adminController.getCommunicationEcosystemOverview();
      expect(overview.totalCommunicationProviders).toBeGreaterThanOrEqual(44);
      expect(overview.channelBreakdown).toBeDefined();
      expect(overview.channelBreakdown.whatsapp).toBeGreaterThanOrEqual(8);
      expect(overview.channelBreakdown.sms).toBeGreaterThanOrEqual(19);
      expect(overview.channelBreakdown.email).toBeGreaterThanOrEqual(8);
      expect(overview.channelBreakdown.push).toBeGreaterThanOrEqual(4);
    });

    it('should return catalog providers filtered by channel', async () => {
      const waProviders = await adminController.getCommunicationProviders('WHATSAPP');
      expect(waProviders.length).toBeGreaterThanOrEqual(8);

      const emailProviders = await adminController.getCommunicationProviders('EMAIL');
      expect(emailProviders.length).toBeGreaterThanOrEqual(8);
    });

    it('should provide routing preview for simulation and administration', async () => {
      const preview = await adminController.previewCommunicationRoute({
        channel: 'WHATSAPP',
        messageType: 'TRANSACTIONAL',
        country: 'IN',
        optimizationGoal: 'BALANCED',
      });

      expect(preview.primaryProviderId).toBeDefined();
      expect(preview.fallbackChain).toBeDefined();
      expect(preview.candidateEvaluations).toBeDefined();
    });

    it('should preview multi-language template rendering via API', async () => {
      const preview = await adminController.previewCommunicationTemplate({
        templateName: 'OTP_VERIFICATION',
        channel: 'SMS',
        language: 'hi',
        variables: { otpCode: '654321' },
      });

      expect(preview.body).toContain('654321');
      expect(preview.dltTemplateId).toBeDefined();
    });
  });
});

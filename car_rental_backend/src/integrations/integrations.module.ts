import { Module, OnModuleInit, Global } from '@nestjs/common';
import { SecretVaultService } from './security/secret-vault.service';
import { IntegrationConfigService } from './config/integration-config.service';
import { ProviderHealthService } from './health/provider-health.service';
import { ProviderRegistryService } from './registry/provider-registry.service';
import { RetryPolicyService } from './errors/retry-policy.service';
import { WebhookDispatcherService } from './webhooks/webhook-dispatcher.service';
import { AdminIntegrationsService } from './admin/admin-integrations.service';
import { AdminIntegrationsController } from './admin/admin-integrations.controller';
import { ProviderCatalogService } from './catalog/provider-catalog.service';

// Phase K Runtime Services
import { FailureClassifierService } from './runtime/failure-classifier.service';
import { CircuitBreakerService } from './runtime/circuit-breaker.service';
import { ProviderRateLimiterService } from './runtime/provider-rate-limiter.service';
import { CostModelService } from './runtime/cost-model.service';
import { ProviderPolicyService } from './runtime/provider-policy.service';
import { IntegrationIdempotencyService } from './runtime/integration-idempotency.service';
import { ProviderSimulationService } from './runtime/provider-simulation.service';
import { ProviderRoutingService } from './runtime/provider-routing.service';
import { PaymentRoutingService } from './runtime/payment-routing.service';
import { IntegrationAuditService } from './runtime/integration-audit.service';
import { IntegrationRuntimeService } from './runtime/integration-runtime.service';

// Concrete Adapters
import { RazorpayAdapter } from './adapters/payments/razorpay.adapter';
import { StripeAdapter } from './adapters/payments/stripe.adapter';
import { CashfreeAdapter } from './adapters/payments/cashfree.adapter';
import { PayUAdapter } from './adapters/payments/payu.adapter';
import { PhonePeAdapter } from './adapters/payments/phonepe.adapter';
import { AdyenAdapter } from './adapters/payments/adyen.adapter';
import { MockPaymentAdapter } from './adapters/payments/mock-payment.adapter';
import { MetaWhatsAppAdapter } from './adapters/messaging/meta-whatsapp.adapter';
import { MockWhatsAppAdapter } from './adapters/messaging/mock-whatsapp.adapter';
import { Msg91SmsAdapter } from './adapters/messaging/msg91-sms.adapter';
import { TwilioSmsAdapter } from './adapters/messaging/twilio-sms.adapter';
import { MockSmsAdapter } from './adapters/messaging/mock-sms.adapter';
import { ResendEmailAdapter } from './adapters/messaging/resend-email.adapter';
import { MockEmailAdapter } from './adapters/messaging/mock-email.adapter';
import { FcmPushAdapter } from './adapters/messaging/fcm-push.adapter';
import { MockPushAdapter } from './adapters/messaging/mock-push.adapter';
import { GupshupWhatsAppAdapter } from './adapters/messaging/gupshup-whatsapp.adapter';
import { SendGridEmailAdapter } from './adapters/messaging/sendgrid-email.adapter';
import { TwilioVoiceAdapter } from './adapters/messaging/twilio-voice.adapter';
import { OneSignalPushAdapter } from './adapters/messaging/onesignal-push.adapter';
import { CommunicationTemplateEngine } from './communications/communication-template.engine';
import { CommunicationComplianceService } from './communications/communication-compliance.service';
import { CommunicationRoutingService } from './communications/communication-routing.service';
import { CommunicationDispatcherService } from './communications/communication-dispatcher.service';
import { R2StorageAdapter } from './adapters/storage/r2-storage.adapter';
import { S3StorageAdapter } from './adapters/storage/s3-storage.adapter';
import { MockStorageAdapter } from './adapters/storage/mock-storage.adapter';
import { GoogleMapsAdapter } from './adapters/maps/google-maps.adapter';
import { MockMapsAdapter } from './adapters/maps/mock-maps.adapter';
import { SurepassKycAdapter } from './adapters/verification/surepass-kyc.adapter';
import { MockKycAdapter } from './adapters/verification/mock-kyc.adapter';
import { MockTelematicsAdapter } from './adapters/tracking/mock-telematics.adapter';
import { MockAccountingAdapter } from './adapters/accounting/mock-accounting.adapter';

import { SystemConfigModule } from '../config-engine/system-config.module';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminModule } from '../admin/admin.module';

@Global()
@Module({
  imports: [PrismaModule, SystemConfigModule, AdminModule],
  controllers: [AdminIntegrationsController],
  providers: [
    SecretVaultService,
    IntegrationConfigService,
    ProviderHealthService,
    ProviderRegistryService,
    RetryPolicyService,
    WebhookDispatcherService,
    AdminIntegrationsService,
    ProviderCatalogService,

    // Phase K Runtime Services
    FailureClassifierService,
    CircuitBreakerService,
    ProviderRateLimiterService,
    CostModelService,
    ProviderPolicyService,
    IntegrationIdempotencyService,
    ProviderSimulationService,
    ProviderRoutingService,
    PaymentRoutingService,
    IntegrationAuditService,
    IntegrationRuntimeService,

    // Phase M Communication Services
    CommunicationTemplateEngine,
    CommunicationComplianceService,
    CommunicationRoutingService,
    CommunicationDispatcherService,

    // Adapters
    RazorpayAdapter,
    StripeAdapter,
    CashfreeAdapter,
    PayUAdapter,
    PhonePeAdapter,
    AdyenAdapter,
    MockPaymentAdapter,
    MetaWhatsAppAdapter,
    MockWhatsAppAdapter,
    Msg91SmsAdapter,
    TwilioSmsAdapter,
    MockSmsAdapter,
    ResendEmailAdapter,
    MockEmailAdapter,
    FcmPushAdapter,
    MockPushAdapter,
    GupshupWhatsAppAdapter,
    SendGridEmailAdapter,
    TwilioVoiceAdapter,
    OneSignalPushAdapter,
    R2StorageAdapter,
    S3StorageAdapter,
    MockStorageAdapter,
    GoogleMapsAdapter,
    MockMapsAdapter,
    SurepassKycAdapter,
    MockKycAdapter,
    MockTelematicsAdapter,
    MockAccountingAdapter,
  ],
  exports: [
    SecretVaultService,
    IntegrationConfigService,
    ProviderHealthService,
    ProviderRegistryService,
    RetryPolicyService,
    WebhookDispatcherService,
    AdminIntegrationsService,
    ProviderCatalogService,

    // Phase K Runtime Services
    FailureClassifierService,
    CircuitBreakerService,
    ProviderRateLimiterService,
    CostModelService,
    ProviderPolicyService,
    IntegrationIdempotencyService,
    ProviderSimulationService,
    ProviderRoutingService,
    PaymentRoutingService,
    IntegrationAuditService,
    IntegrationRuntimeService,

    // Phase M Communication Services
    CommunicationTemplateEngine,
    CommunicationComplianceService,
    CommunicationRoutingService,
    CommunicationDispatcherService,

    // Adapters exported for direct injection or test wiring
    RazorpayAdapter,
    StripeAdapter,
    CashfreeAdapter,
    PayUAdapter,
    PhonePeAdapter,
    AdyenAdapter,
    MockPaymentAdapter,
    MetaWhatsAppAdapter,
    MockWhatsAppAdapter,
    Msg91SmsAdapter,
    TwilioSmsAdapter,
    MockSmsAdapter,
    ResendEmailAdapter,
    MockEmailAdapter,
    FcmPushAdapter,
    MockPushAdapter,
    GupshupWhatsAppAdapter,
    SendGridEmailAdapter,
    TwilioVoiceAdapter,
    OneSignalPushAdapter,
    R2StorageAdapter,
    S3StorageAdapter,
    MockStorageAdapter,
    GoogleMapsAdapter,
    MockMapsAdapter,
    SurepassKycAdapter,
    MockKycAdapter,
    MockTelematicsAdapter,
    MockAccountingAdapter,
  ],
})
export class IntegrationsModule implements OnModuleInit {
  constructor(
    private readonly registry: ProviderRegistryService,
    private readonly razorpayAdapter: RazorpayAdapter,
    private readonly stripeAdapter: StripeAdapter,
    private readonly cashfreeAdapter: CashfreeAdapter,
    private readonly payUAdapter: PayUAdapter,
    private readonly phonePeAdapter: PhonePeAdapter,
    private readonly adyenAdapter: AdyenAdapter,
    private readonly mockPaymentAdapter: MockPaymentAdapter,
    private readonly metaWhatsAppAdapter: MetaWhatsAppAdapter,
    private readonly mockWhatsAppAdapter: MockWhatsAppAdapter,
    private readonly msg91SmsAdapter: Msg91SmsAdapter,
    private readonly twilioSmsAdapter: TwilioSmsAdapter,
    private readonly mockSmsAdapter: MockSmsAdapter,
    private readonly resendEmailAdapter: ResendEmailAdapter,
    private readonly mockEmailAdapter: MockEmailAdapter,
    private readonly fcmPushAdapter: FcmPushAdapter,
    private readonly mockPushAdapter: MockPushAdapter,
    private readonly gupshupWhatsAppAdapter: GupshupWhatsAppAdapter,
    private readonly sendGridEmailAdapter: SendGridEmailAdapter,
    private readonly twilioVoiceAdapter: TwilioVoiceAdapter,
    private readonly oneSignalPushAdapter: OneSignalPushAdapter,
    private readonly r2StorageAdapter: R2StorageAdapter,
    private readonly s3StorageAdapter: S3StorageAdapter,
    private readonly mockStorageAdapter: MockStorageAdapter,
    private readonly googleMapsAdapter: GoogleMapsAdapter,
    private readonly mockMapsAdapter: MockMapsAdapter,
    private readonly surepassKycAdapter: SurepassKycAdapter,
    private readonly mockKycAdapter: MockKycAdapter,
    private readonly mockTelematicsAdapter: MockTelematicsAdapter,
    private readonly mockAccountingAdapter: MockAccountingAdapter,
  ) {}

  onModuleInit() {
    // Register Payment Adapters
    this.registry.registerProvider(this.razorpayAdapter);
    this.registry.registerProvider(this.stripeAdapter);
    this.registry.registerProvider(this.cashfreeAdapter);
    this.registry.registerProvider(this.payUAdapter);
    this.registry.registerProvider(this.phonePeAdapter);
    this.registry.registerProvider(this.adyenAdapter);
    this.registry.registerProvider(this.mockPaymentAdapter);

    // Register Messaging Adapters
    this.registry.registerProvider(this.metaWhatsAppAdapter);
    this.registry.registerProvider(this.mockWhatsAppAdapter);
    this.registry.registerProvider(this.msg91SmsAdapter);
    this.registry.registerProvider(this.twilioSmsAdapter);
    this.registry.registerProvider(this.mockSmsAdapter);
    this.registry.registerProvider(this.resendEmailAdapter);
    this.registry.registerProvider(this.mockEmailAdapter);
    this.registry.registerProvider(this.fcmPushAdapter);
    this.registry.registerProvider(this.mockPushAdapter);
    this.registry.registerProvider(this.gupshupWhatsAppAdapter);
    this.registry.registerProvider(this.sendGridEmailAdapter);
    this.registry.registerProvider(this.twilioVoiceAdapter);
    this.registry.registerProvider(this.oneSignalPushAdapter);

    // Register Storage Adapters
    this.registry.registerProvider(this.r2StorageAdapter);
    this.registry.registerProvider(this.s3StorageAdapter);
    this.registry.registerProvider(this.mockStorageAdapter);

    // Register Maps Adapters
    this.registry.registerProvider(this.googleMapsAdapter);
    this.registry.registerProvider(this.mockMapsAdapter);

    // Register Identity Verification Adapters
    this.registry.registerProvider(this.surepassKycAdapter);
    this.registry.registerProvider(this.mockKycAdapter);

    // Register Telematics & Accounting Adapters
    this.registry.registerProvider(this.mockTelematicsAdapter);
    this.registry.registerProvider(this.mockAccountingAdapter);
  }
}

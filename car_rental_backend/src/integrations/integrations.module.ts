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
import { CCAvenueAdapter } from './adapters/payments/ccavenue.adapter';
import { PaytmAdapter } from './adapters/payments/paytm.adapter';
import { BillDeskAdapter } from './adapters/payments/billdesk.adapter';
import { PayPalAdapter } from './adapters/payments/paypal.adapter';
import { SquareAdapter } from './adapters/payments/square.adapter';
import { CheckoutComAdapter } from './adapters/payments/checkout-com.adapter';
import { PaystackAdapter } from './adapters/payments/paystack.adapter';
import { MollieAdapter } from './adapters/payments/mollie.adapter';
import { FlutterwaveAdapter } from './adapters/payments/flutterwave.adapter';
import { XenditAdapter } from './adapters/payments/xendit.adapter';
import { MidtransAdapter } from './adapters/payments/midtrans.adapter';
import { TapPaymentAdapter } from './adapters/payments/tap.adapter';
import { PaytabsAdapter } from './adapters/payments/paytabs.adapter';
import { AuthorizeNetAdapter } from './adapters/payments/authorizenet.adapter';
import { MercadoPagoAdapter } from './adapters/payments/mercadopago.adapter';
import { InstamojoAdapter } from './adapters/payments/instamojo.adapter';
import { EasebuzzAdapter } from './adapters/payments/easebuzz.adapter';
import { JuspayAdapter } from './adapters/payments/juspay.adapter';

import { MetaWhatsAppAdapter } from './adapters/messaging/meta-whatsapp.adapter';
import { MockWhatsAppAdapter } from './adapters/messaging/mock-whatsapp.adapter';
import { Msg91SmsAdapter } from './adapters/messaging/msg91-sms.adapter';
import { TwilioSmsAdapter } from './adapters/messaging/twilio-sms.adapter';
import { MockSmsAdapter } from './adapters/messaging/mock-sms.adapter';
import { Fast2SmsAdapter } from './adapters/messaging/fast2sms.adapter';
import { TextlocalAdapter } from './adapters/messaging/textlocal.adapter';
import { KarixSmsAdapter } from './adapters/messaging/karix-sms.adapter';
import { SinchSmsAdapter } from './adapters/messaging/sinch-sms.adapter';
import { VonageSmsAdapter } from './adapters/messaging/vonage-sms.adapter';
import { InfobipSmsAdapter } from './adapters/messaging/infobip-sms.adapter';
import { PlivoSmsAdapter } from './adapters/messaging/plivo-sms.adapter';
import { ExotelSmsAdapter } from './adapters/messaging/exotel.adapter';
import { RouteMobileSmsAdapter } from './adapters/messaging/route-mobile.adapter';
import { InteraktWhatsAppAdapter } from './adapters/messaging/interakt-whatsapp.adapter';
import { TwilioWhatsAppAdapter } from './adapters/messaging/twilio-whatsapp.adapter';

import { ResendEmailAdapter } from './adapters/messaging/resend-email.adapter';
import { MockEmailAdapter } from './adapters/messaging/mock-email.adapter';
import { SendGridEmailAdapter } from './adapters/messaging/sendgrid-email.adapter';
import { PostmarkEmailAdapter } from './adapters/messaging/postmark-email.adapter';
import { AwsSesEmailAdapter } from './adapters/messaging/aws-ses-email.adapter';

import { FcmPushAdapter } from './adapters/messaging/fcm-push.adapter';
import { MockPushAdapter } from './adapters/messaging/mock-push.adapter';
import { OneSignalPushAdapter } from './adapters/messaging/onesignal-push.adapter';
import { GupshupWhatsAppAdapter } from './adapters/messaging/gupshup-whatsapp.adapter';
import { TwilioVoiceAdapter } from './adapters/messaging/twilio-voice.adapter';

import { CommunicationTemplateEngine } from './communications/communication-template.engine';
import { CommunicationComplianceService } from './communications/communication-compliance.service';
import { CommunicationRoutingService } from './communications/communication-routing.service';
import { CommunicationDispatcherService } from './communications/communication-dispatcher.service';
import { OtpOrchestratorService } from './communications/otp-orchestrator.service';
import { R2StorageAdapter } from './adapters/storage/r2-storage.adapter';
import { S3StorageAdapter } from './adapters/storage/s3-storage.adapter';
import { MockStorageAdapter } from './adapters/storage/mock-storage.adapter';
import { GcsStorageAdapter } from './adapters/storage/gcs-storage.adapter';
import { GoogleMapsAdapter } from './adapters/maps/google-maps.adapter';
import { MockMapsAdapter } from './adapters/maps/mock-maps.adapter';
import { SurepassKycAdapter } from './adapters/verification/surepass-kyc.adapter';
import { MockKycAdapter } from './adapters/verification/mock-kyc.adapter';
import { OnfidoKycAdapter } from './adapters/verification/onfido-kyc.adapter';
import { MockTelematicsAdapter } from './adapters/tracking/mock-telematics.adapter';
import { GeotabTelematicsAdapter } from './adapters/tracking/geotab-telematics.adapter';
import { MockAccountingAdapter } from './adapters/accounting/mock-accounting.adapter';

// Phase L Connector Packs & Adapters
import { ProviderPackRegistryService } from './packs/provider-pack-registry.service';
import { MapboxMapsAdapter } from './adapters/maps/mapbox-maps.adapter';
import { TraccarTelematicsAdapter } from './adapters/tracking/traccar-telematics.adapter';
import { HyperVergeKycAdapter } from './adapters/verification/hyperverge-kyc.adapter';
import { ZohoBooksAccountingAdapter } from './adapters/accounting/zoho-books.adapter';
import { GoogleGeminiAiAdapter } from './adapters/ai/google-gemini.adapter';
import { MeilisearchAdapter } from './adapters/search/meilisearch.adapter';
import { PostHogAnalyticsAdapter } from './adapters/analytics/posthog-analytics.adapter';

// Phase L Enterprise Control Plane Services & Controllers
import { ProviderDirectoryService } from './directory/provider-directory.service';
import { CapabilityMatrixService } from './directory/capability-matrix.service';
import { ProviderOnboardingService } from './directory/provider-onboarding.service';
import { ProviderScoringService } from './scoring/provider-scoring.service';
import { ProviderIncidentService } from './governance/provider-incident.service';
import { ProviderChangeAuditService } from './governance/provider-change-audit.service';
import { ProviderRecommendationService } from './governance/provider-recommendation.service';
import { AdminControlPlaneController } from './admin/admin-control-plane.controller';

import { SystemConfigModule } from '../config-engine/system-config.module';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminModule } from '../admin/admin.module';

@Global()
@Module({
  imports: [PrismaModule, SystemConfigModule, AdminModule],
  controllers: [AdminIntegrationsController, AdminControlPlaneController],
  providers: [
    SecretVaultService,
    IntegrationConfigService,
    ProviderHealthService,
    ProviderRegistryService,
    RetryPolicyService,
    WebhookDispatcherService,
    AdminIntegrationsService,
    ProviderCatalogService,
    ProviderPackRegistryService,

    // Phase L Enterprise Control Plane
    ProviderDirectoryService,
    CapabilityMatrixService,
    ProviderOnboardingService,
    ProviderScoringService,
    ProviderIncidentService,
    ProviderChangeAuditService,
    ProviderRecommendationService,

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
    OtpOrchestratorService,

    // Adapters
    RazorpayAdapter,
    StripeAdapter,
    CashfreeAdapter,
    PayUAdapter,
    PhonePeAdapter,
    AdyenAdapter,
    MockPaymentAdapter,
    CCAvenueAdapter,
    PaytmAdapter,
    BillDeskAdapter,
    PayPalAdapter,
    SquareAdapter,
    CheckoutComAdapter,
    PaystackAdapter,
    MollieAdapter,
    FlutterwaveAdapter,
    XenditAdapter,
    MidtransAdapter,
    TapPaymentAdapter,
    PaytabsAdapter,
    AuthorizeNetAdapter,
    MercadoPagoAdapter,
    InstamojoAdapter,
    EasebuzzAdapter,
    JuspayAdapter,
    MetaWhatsAppAdapter,
    MockWhatsAppAdapter,
    InteraktWhatsAppAdapter,
    TwilioWhatsAppAdapter,
    Msg91SmsAdapter,
    TwilioSmsAdapter,
    MockSmsAdapter,
    Fast2SmsAdapter,
    TextlocalAdapter,
    KarixSmsAdapter,
    SinchSmsAdapter,
    VonageSmsAdapter,
    InfobipSmsAdapter,
    PlivoSmsAdapter,
    ExotelSmsAdapter,
    RouteMobileSmsAdapter,
    ResendEmailAdapter,
    MockEmailAdapter,
    SendGridEmailAdapter,
    PostmarkEmailAdapter,
    AwsSesEmailAdapter,
    FcmPushAdapter,
    MockPushAdapter,
    OneSignalPushAdapter,
    GupshupWhatsAppAdapter,
    TwilioVoiceAdapter,
    R2StorageAdapter,
    S3StorageAdapter,
    MockStorageAdapter,
    GcsStorageAdapter,
    GoogleMapsAdapter,
    MockMapsAdapter,
    SurepassKycAdapter,
    MockKycAdapter,
    OnfidoKycAdapter,
    MockTelematicsAdapter,
    GeotabTelematicsAdapter,
    MockAccountingAdapter,

    // Phase L Adapters
    MapboxMapsAdapter,
    TraccarTelematicsAdapter,
    HyperVergeKycAdapter,
    ZohoBooksAccountingAdapter,
    GoogleGeminiAiAdapter,
    MeilisearchAdapter,
    PostHogAnalyticsAdapter,
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
    ProviderPackRegistryService,

    // Phase L Enterprise Control Plane Services
    ProviderDirectoryService,
    CapabilityMatrixService,
    ProviderOnboardingService,
    ProviderScoringService,
    ProviderIncidentService,
    ProviderChangeAuditService,
    ProviderRecommendationService,

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
    OtpOrchestratorService,

    // Adapters exported for direct injection or test wiring
    RazorpayAdapter,
    StripeAdapter,
    CashfreeAdapter,
    PayUAdapter,
    PhonePeAdapter,
    AdyenAdapter,
    MockPaymentAdapter,
    CCAvenueAdapter,
    PaytmAdapter,
    BillDeskAdapter,
    PayPalAdapter,
    SquareAdapter,
    CheckoutComAdapter,
    PaystackAdapter,
    MollieAdapter,
    FlutterwaveAdapter,
    XenditAdapter,
    MidtransAdapter,
    TapPaymentAdapter,
    PaytabsAdapter,
    AuthorizeNetAdapter,
    MercadoPagoAdapter,
    InstamojoAdapter,
    EasebuzzAdapter,
    JuspayAdapter,
    MetaWhatsAppAdapter,
    MockWhatsAppAdapter,
    InteraktWhatsAppAdapter,
    TwilioWhatsAppAdapter,
    Msg91SmsAdapter,
    TwilioSmsAdapter,
    MockSmsAdapter,
    Fast2SmsAdapter,
    TextlocalAdapter,
    KarixSmsAdapter,
    SinchSmsAdapter,
    VonageSmsAdapter,
    InfobipSmsAdapter,
    PlivoSmsAdapter,
    ExotelSmsAdapter,
    RouteMobileSmsAdapter,
    ResendEmailAdapter,
    MockEmailAdapter,
    SendGridEmailAdapter,
    PostmarkEmailAdapter,
    AwsSesEmailAdapter,
    FcmPushAdapter,
    MockPushAdapter,
    OneSignalPushAdapter,
    GupshupWhatsAppAdapter,
    TwilioVoiceAdapter,
    R2StorageAdapter,
    S3StorageAdapter,
    MockStorageAdapter,
    GcsStorageAdapter,
    GoogleMapsAdapter,
    MockMapsAdapter,
    SurepassKycAdapter,
    MockKycAdapter,
    OnfidoKycAdapter,
    MockTelematicsAdapter,
    GeotabTelematicsAdapter,
    MockAccountingAdapter,

    // Phase L Adapters
    MapboxMapsAdapter,
    TraccarTelematicsAdapter,
    HyperVergeKycAdapter,
    ZohoBooksAccountingAdapter,
    GoogleGeminiAiAdapter,
    MeilisearchAdapter,
    PostHogAnalyticsAdapter,
  ],
})
export class IntegrationsModule implements OnModuleInit {
  constructor(
    private readonly registry: ProviderRegistryService,
    private readonly packRegistry: ProviderPackRegistryService,
    private readonly razorpayAdapter: RazorpayAdapter,
    private readonly stripeAdapter: StripeAdapter,
    private readonly cashfreeAdapter: CashfreeAdapter,
    private readonly payUAdapter: PayUAdapter,
    private readonly phonePeAdapter: PhonePeAdapter,
    private readonly adyenAdapter: AdyenAdapter,
    private readonly mockPaymentAdapter: MockPaymentAdapter,
    private readonly ccavenueAdapter: CCAvenueAdapter,
    private readonly paytmAdapter: PaytmAdapter,
    private readonly billDeskAdapter: BillDeskAdapter,
    private readonly payPalAdapter: PayPalAdapter,
    private readonly squareAdapter: SquareAdapter,
    private readonly checkoutComAdapter: CheckoutComAdapter,
    private readonly paystackAdapter: PaystackAdapter,
    private readonly mollieAdapter: MollieAdapter,
    private readonly flutterwaveAdapter: FlutterwaveAdapter,
    private readonly xenditAdapter: XenditAdapter,
    private readonly midtransAdapter: MidtransAdapter,
    private readonly tapPaymentAdapter: TapPaymentAdapter,
    private readonly paytabsAdapter: PaytabsAdapter,
    private readonly authorizeNetAdapter: AuthorizeNetAdapter,
    private readonly mercadoPagoAdapter: MercadoPagoAdapter,
    private readonly instamojoAdapter: InstamojoAdapter,
    private readonly easebuzzAdapter: EasebuzzAdapter,
    private readonly juspayAdapter: JuspayAdapter,
    private readonly metaWhatsAppAdapter: MetaWhatsAppAdapter,
    private readonly mockWhatsAppAdapter: MockWhatsAppAdapter,
    private readonly interaktWhatsAppAdapter: InteraktWhatsAppAdapter,
    private readonly twilioWhatsAppAdapter: TwilioWhatsAppAdapter,
    private readonly msg91SmsAdapter: Msg91SmsAdapter,
    private readonly twilioSmsAdapter: TwilioSmsAdapter,
    private readonly mockSmsAdapter: MockSmsAdapter,
    private readonly fast2SmsAdapter: Fast2SmsAdapter,
    private readonly textlocalAdapter: TextlocalAdapter,
    private readonly karixSmsAdapter: KarixSmsAdapter,
    private readonly sinchSmsAdapter: SinchSmsAdapter,
    private readonly vonageSmsAdapter: VonageSmsAdapter,
    private readonly infobipSmsAdapter: InfobipSmsAdapter,
    private readonly plivoSmsAdapter: PlivoSmsAdapter,
    private readonly exotelSmsAdapter: ExotelSmsAdapter,
    private readonly routeMobileSmsAdapter: RouteMobileSmsAdapter,
    private readonly resendEmailAdapter: ResendEmailAdapter,
    private readonly mockEmailAdapter: MockEmailAdapter,
    private readonly sendGridEmailAdapter: SendGridEmailAdapter,
    private readonly postmarkEmailAdapter: PostmarkEmailAdapter,
    private readonly awsSesEmailAdapter: AwsSesEmailAdapter,
    private readonly fcmPushAdapter: FcmPushAdapter,
    private readonly mockPushAdapter: MockPushAdapter,
    private readonly gupshupWhatsAppAdapter: GupshupWhatsAppAdapter,
    private readonly twilioVoiceAdapter: TwilioVoiceAdapter,
    private readonly oneSignalPushAdapter: OneSignalPushAdapter,
    private readonly r2StorageAdapter: R2StorageAdapter,
    private readonly s3StorageAdapter: S3StorageAdapter,
    private readonly mockStorageAdapter: MockStorageAdapter,
    private readonly gcsStorageAdapter: GcsStorageAdapter,
    private readonly googleMapsAdapter: GoogleMapsAdapter,
    private readonly mockMapsAdapter: MockMapsAdapter,
    private readonly surepassKycAdapter: SurepassKycAdapter,
    private readonly mockKycAdapter: MockKycAdapter,
    private readonly onfidoKycAdapter: OnfidoKycAdapter,
    private readonly mockTelematicsAdapter: MockTelematicsAdapter,
    private readonly geotabTelematicsAdapter: GeotabTelematicsAdapter,
    private readonly mockAccountingAdapter: MockAccountingAdapter,
    // Phase L Adapters
    private readonly mapboxMapsAdapter: MapboxMapsAdapter,
    private readonly traccarTelematicsAdapter: TraccarTelematicsAdapter,
    private readonly hyperVergeKycAdapter: HyperVergeKycAdapter,
    private readonly zohoBooksAccountingAdapter: ZohoBooksAccountingAdapter,
    private readonly googleGeminiAiAdapter: GoogleGeminiAiAdapter,
    private readonly meilisearchAdapter: MeilisearchAdapter,
    private readonly postHogAnalyticsAdapter: PostHogAnalyticsAdapter,
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
    this.registry.registerProvider(this.ccavenueAdapter);
    this.registry.registerProvider(this.paytmAdapter);
    this.registry.registerProvider(this.billDeskAdapter);
    this.registry.registerProvider(this.payPalAdapter);
    this.registry.registerProvider(this.squareAdapter);
    this.registry.registerProvider(this.checkoutComAdapter);
    this.registry.registerProvider(this.paystackAdapter);
    this.registry.registerProvider(this.mollieAdapter);
    this.registry.registerProvider(this.flutterwaveAdapter);
    this.registry.registerProvider(this.xenditAdapter);
    this.registry.registerProvider(this.midtransAdapter);
    this.registry.registerProvider(this.tapPaymentAdapter);
    this.registry.registerProvider(this.paytabsAdapter);
    this.registry.registerProvider(this.authorizeNetAdapter);
    this.registry.registerProvider(this.mercadoPagoAdapter);
    this.registry.registerProvider(this.instamojoAdapter);
    this.registry.registerProvider(this.easebuzzAdapter);
    this.registry.registerProvider(this.juspayAdapter);

    // Register Messaging Adapters
    this.registry.registerProvider(this.metaWhatsAppAdapter);
    this.registry.registerProvider(this.mockWhatsAppAdapter);
    this.registry.registerProvider(this.interaktWhatsAppAdapter);
    this.registry.registerProvider(this.twilioWhatsAppAdapter);
    this.registry.registerProvider(this.msg91SmsAdapter);
    this.registry.registerProvider(this.twilioSmsAdapter);
    this.registry.registerProvider(this.mockSmsAdapter);
    this.registry.registerProvider(this.fast2SmsAdapter);
    this.registry.registerProvider(this.textlocalAdapter);
    this.registry.registerProvider(this.karixSmsAdapter);
    this.registry.registerProvider(this.sinchSmsAdapter);
    this.registry.registerProvider(this.vonageSmsAdapter);
    this.registry.registerProvider(this.infobipSmsAdapter);
    this.registry.registerProvider(this.plivoSmsAdapter);
    this.registry.registerProvider(this.exotelSmsAdapter);
    this.registry.registerProvider(this.routeMobileSmsAdapter);

    // Register Email Adapters
    this.registry.registerProvider(this.resendEmailAdapter);
    this.registry.registerProvider(this.mockEmailAdapter);
    this.registry.registerProvider(this.sendGridEmailAdapter);
    this.registry.registerProvider(this.postmarkEmailAdapter);
    this.registry.registerProvider(this.awsSesEmailAdapter);

    // Register Push & Voice Adapters
    this.registry.registerProvider(this.fcmPushAdapter);
    this.registry.registerProvider(this.mockPushAdapter);
    this.registry.registerProvider(this.gupshupWhatsAppAdapter);
    this.registry.registerProvider(this.twilioVoiceAdapter);
    this.registry.registerProvider(this.oneSignalPushAdapter);

    // Register Storage Adapters
    this.registry.registerProvider(this.r2StorageAdapter);
    this.registry.registerProvider(this.s3StorageAdapter);
    this.registry.registerProvider(this.mockStorageAdapter);
    this.registry.registerProvider(this.gcsStorageAdapter);

    // Register Maps Adapters
    this.registry.registerProvider(this.googleMapsAdapter);
    this.registry.registerProvider(this.mockMapsAdapter);
    this.registry.registerProvider(this.mapboxMapsAdapter);

    // Register Identity Verification Adapters
    this.registry.registerProvider(this.surepassKycAdapter);
    this.registry.registerProvider(this.mockKycAdapter);
    this.registry.registerProvider(this.hyperVergeKycAdapter);
    this.registry.registerProvider(this.onfidoKycAdapter);

    // Register Telematics & Accounting Adapters
    this.registry.registerProvider(this.mockTelematicsAdapter);
    this.registry.registerProvider(this.traccarTelematicsAdapter);
    this.registry.registerProvider(this.geotabTelematicsAdapter);
    this.registry.registerProvider(this.mockAccountingAdapter);
    this.registry.registerProvider(this.zohoBooksAccountingAdapter);

    // Register AI, Search & Analytics Adapters
    this.registry.registerProvider(this.googleGeminiAiAdapter);
    this.registry.registerProvider(this.meilisearchAdapter);
    this.registry.registerProvider(this.postHogAnalyticsAdapter);
  }
}

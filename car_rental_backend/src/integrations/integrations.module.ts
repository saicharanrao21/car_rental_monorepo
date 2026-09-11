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
import { WorldlineAdapter } from './adapters/payments/worldline.adapter';
import { PineLabsAdapter } from './adapters/payments/pinelabs.adapter';
import { ZaakpayAdapter } from './adapters/payments/zaakpay.adapter';
import { OpenMoneyAdapter } from './adapters/payments/openmoney.adapter';
import { BraintreeAdapter } from './adapters/payments/braintree.adapter';
import { WorldpayAdapter } from './adapters/payments/worldpay.adapter';
import { AirwallexAdapter } from './adapters/payments/airwallex.adapter';
import { RapydAdapter } from './adapters/payments/rapyd.adapter';
import { DLocalAdapter } from './adapters/payments/dlocal.adapter';
import { SafexpayAdapter } from './adapters/payments/safexpay.adapter';
import { PayKunAdapter } from './adapters/payments/paykun.adapter';
import { AtomAdapter } from './adapters/payments/atom.adapter';
import { AirpayAdapter } from './adapters/payments/airpay.adapter';
import { FibeAdapter } from './adapters/payments/fibe.adapter';
import { SimplAdapter } from './adapters/payments/simpl.adapter';
import { LazyPayAdapter } from './adapters/payments/lazypay.adapter';
import { KlarnaAdapter } from './adapters/payments/klarna.adapter';
import { AfterpayAdapter } from './adapters/payments/afterpay.adapter';
import { AffirmAdapter } from './adapters/payments/affirm.adapter';
import { SkrillAdapter } from './adapters/payments/skrill.adapter';
import { NetellerAdapter } from './adapters/payments/neteller.adapter';
import { TwoCheckoutAdapter } from './adapters/payments/twocheckout.adapter';
import { StripeIndiaAdapter } from './adapters/payments/stripe-india.adapter';

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
import { GupshupSmsAdapter } from './adapters/messaging/gupshup-sms.adapter';
import { ValueFirstSmsAdapter } from './adapters/messaging/valuefirst-sms.adapter';
import { TanlaSmsAdapter } from './adapters/messaging/tanla-sms.adapter';
import { TwoFactorSmsAdapter } from './adapters/messaging/twofactor-sms.adapter';
import { TelnyxSmsAdapter } from './adapters/messaging/telnyx-sms.adapter';
import { BirdSmsAdapter } from './adapters/messaging/bird-sms.adapter';
import { ClickSendSmsAdapter } from './adapters/messaging/clicksend-sms.adapter';
import { KaleyraSmsAdapter } from './adapters/messaging/kaleyra-sms.adapter';
import { SmsCountrySmsAdapter } from './adapters/messaging/smscountry-sms.adapter';
import { NetcoreSmsAdapter } from './adapters/messaging/netcore-sms.adapter';
import { TataSmsAdapter } from './adapters/messaging/tata-sms.adapter';
import { AirtelIqSmsAdapter } from './adapters/messaging/airtel-iq-sms.adapter';
import { JioSmsAdapter } from './adapters/messaging/jio-sms.adapter';
import { BhashSmsAdapter } from './adapters/messaging/bhash-sms.adapter';
import { BulkSmsAdapter } from './adapters/messaging/bulksms.adapter';
import { SmsGlobalAdapter } from './adapters/messaging/smsglobal.adapter';
import { AmazonSnsSmsAdapter } from './adapters/messaging/amazon-sns-sms.adapter';
import { MessageMediaSmsAdapter } from './adapters/messaging/messagemedia-sms.adapter';
import { ClickatellSmsAdapter } from './adapters/messaging/clickatell-sms.adapter';
import { BandwidthSmsAdapter } from './adapters/messaging/bandwidth-sms.adapter';
import { CmTelecomSmsAdapter } from './adapters/messaging/cm-telecom-sms.adapter';
import { MittoSmsAdapter } from './adapters/messaging/mitto-sms.adapter';
import { TelstraSmsAdapter } from './adapters/messaging/telstra-sms.adapter';
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
    WorldlineAdapter,
    PineLabsAdapter,
    ZaakpayAdapter,
    OpenMoneyAdapter,
    BraintreeAdapter,
    WorldpayAdapter,
    AirwallexAdapter,
    RapydAdapter,
    DLocalAdapter,
    SafexpayAdapter,
    PayKunAdapter,
    AtomAdapter,
    AirpayAdapter,
    FibeAdapter,
    SimplAdapter,
    LazyPayAdapter,
    KlarnaAdapter,
    AfterpayAdapter,
    AffirmAdapter,
    SkrillAdapter,
    NetellerAdapter,
    TwoCheckoutAdapter,
    StripeIndiaAdapter,
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
    GupshupSmsAdapter,
    ValueFirstSmsAdapter,
    TanlaSmsAdapter,
    TwoFactorSmsAdapter,
    TelnyxSmsAdapter,
    BirdSmsAdapter,
    ClickSendSmsAdapter,
    KaleyraSmsAdapter,
    SmsCountrySmsAdapter,
    NetcoreSmsAdapter,
    TataSmsAdapter,
    AirtelIqSmsAdapter,
    JioSmsAdapter,
    BhashSmsAdapter,
    BulkSmsAdapter,
    SmsGlobalAdapter,
    AmazonSnsSmsAdapter,
    MessageMediaSmsAdapter,
    ClickatellSmsAdapter,
    BandwidthSmsAdapter,
    CmTelecomSmsAdapter,
    MittoSmsAdapter,
    TelstraSmsAdapter,
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
    WorldlineAdapter,
    PineLabsAdapter,
    ZaakpayAdapter,
    OpenMoneyAdapter,
    BraintreeAdapter,
    WorldpayAdapter,
    AirwallexAdapter,
    RapydAdapter,
    DLocalAdapter,
    SafexpayAdapter,
    PayKunAdapter,
    AtomAdapter,
    AirpayAdapter,
    FibeAdapter,
    SimplAdapter,
    LazyPayAdapter,
    KlarnaAdapter,
    AfterpayAdapter,
    AffirmAdapter,
    SkrillAdapter,
    NetellerAdapter,
    TwoCheckoutAdapter,
    StripeIndiaAdapter,
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
    GupshupSmsAdapter,
    ValueFirstSmsAdapter,
    TanlaSmsAdapter,
    TwoFactorSmsAdapter,
    TelnyxSmsAdapter,
    BirdSmsAdapter,
    ClickSendSmsAdapter,
    KaleyraSmsAdapter,
    SmsCountrySmsAdapter,
    NetcoreSmsAdapter,
    TataSmsAdapter,
    AirtelIqSmsAdapter,
    JioSmsAdapter,
    BhashSmsAdapter,
    BulkSmsAdapter,
    SmsGlobalAdapter,
    AmazonSnsSmsAdapter,
    MessageMediaSmsAdapter,
    ClickatellSmsAdapter,
    BandwidthSmsAdapter,
    CmTelecomSmsAdapter,
    MittoSmsAdapter,
    TelstraSmsAdapter,
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
    private readonly worldlineAdapter: WorldlineAdapter,
    private readonly pineLabsAdapter: PineLabsAdapter,
    private readonly zaakpayAdapter: ZaakpayAdapter,
    private readonly openMoneyAdapter: OpenMoneyAdapter,
    private readonly braintreeAdapter: BraintreeAdapter,
    private readonly worldpayAdapter: WorldpayAdapter,
    private readonly airwallexAdapter: AirwallexAdapter,
    private readonly rapydAdapter: RapydAdapter,
    private readonly dLocalAdapter: DLocalAdapter,
    private readonly safexpayAdapter: SafexpayAdapter,
    private readonly payKunAdapter: PayKunAdapter,
    private readonly atomAdapter: AtomAdapter,
    private readonly airpayAdapter: AirpayAdapter,
    private readonly fibeAdapter: FibeAdapter,
    private readonly simplAdapter: SimplAdapter,
    private readonly lazyPayAdapter: LazyPayAdapter,
    private readonly klarnaAdapter: KlarnaAdapter,
    private readonly afterpayAdapter: AfterpayAdapter,
    private readonly affirmAdapter: AffirmAdapter,
    private readonly skrillAdapter: SkrillAdapter,
    private readonly netellerAdapter: NetellerAdapter,
    private readonly twoCheckoutAdapter: TwoCheckoutAdapter,
    private readonly stripeIndiaAdapter: StripeIndiaAdapter,
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
    private readonly gupshupSmsAdapter: GupshupSmsAdapter,
    private readonly valueFirstSmsAdapter: ValueFirstSmsAdapter,
    private readonly tanlaSmsAdapter: TanlaSmsAdapter,
    private readonly twoFactorSmsAdapter: TwoFactorSmsAdapter,
    private readonly telnyxSmsAdapter: TelnyxSmsAdapter,
    private readonly birdSmsAdapter: BirdSmsAdapter,
    private readonly clickSendSmsAdapter: ClickSendSmsAdapter,
    private readonly kaleyraSmsAdapter: KaleyraSmsAdapter,
    private readonly smsCountrySmsAdapter: SmsCountrySmsAdapter,
    private readonly netcoreSmsAdapter: NetcoreSmsAdapter,
    private readonly tataSmsAdapter: TataSmsAdapter,
    private readonly airtelIqSmsAdapter: AirtelIqSmsAdapter,
    private readonly jioSmsAdapter: JioSmsAdapter,
    private readonly bhashSmsAdapter: BhashSmsAdapter,
    private readonly bulkSmsAdapter: BulkSmsAdapter,
    private readonly smsGlobalAdapter: SmsGlobalAdapter,
    private readonly amazonSnsSmsAdapter: AmazonSnsSmsAdapter,
    private readonly messageMediaSmsAdapter: MessageMediaSmsAdapter,
    private readonly clickatellSmsAdapter: ClickatellSmsAdapter,
    private readonly bandwidthSmsAdapter: BandwidthSmsAdapter,
    private readonly cmTelecomSmsAdapter: CmTelecomSmsAdapter,
    private readonly mittoSmsAdapter: MittoSmsAdapter,
    private readonly telstraSmsAdapter: TelstraSmsAdapter,
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
    this.registry.registerProvider(this.worldlineAdapter);
    this.registry.registerProvider(this.pineLabsAdapter);
    this.registry.registerProvider(this.zaakpayAdapter);
    this.registry.registerProvider(this.openMoneyAdapter);
    this.registry.registerProvider(this.braintreeAdapter);
    this.registry.registerProvider(this.worldpayAdapter);
    this.registry.registerProvider(this.airwallexAdapter);
    this.registry.registerProvider(this.rapydAdapter);
    this.registry.registerProvider(this.dLocalAdapter);
    this.registry.registerProvider(this.safexpayAdapter);
    this.registry.registerProvider(this.payKunAdapter);
    this.registry.registerProvider(this.atomAdapter);
    this.registry.registerProvider(this.airpayAdapter);
    this.registry.registerProvider(this.fibeAdapter);
    this.registry.registerProvider(this.simplAdapter);
    this.registry.registerProvider(this.lazyPayAdapter);
    this.registry.registerProvider(this.klarnaAdapter);
    this.registry.registerProvider(this.afterpayAdapter);
    this.registry.registerProvider(this.affirmAdapter);
    this.registry.registerProvider(this.skrillAdapter);
    this.registry.registerProvider(this.netellerAdapter);
    this.registry.registerProvider(this.twoCheckoutAdapter);
    this.registry.registerProvider(this.stripeIndiaAdapter);

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
    this.registry.registerProvider(this.gupshupSmsAdapter);
    this.registry.registerProvider(this.valueFirstSmsAdapter);
    this.registry.registerProvider(this.tanlaSmsAdapter);
    this.registry.registerProvider(this.twoFactorSmsAdapter);
    this.registry.registerProvider(this.telnyxSmsAdapter);
    this.registry.registerProvider(this.birdSmsAdapter);
    this.registry.registerProvider(this.clickSendSmsAdapter);
    this.registry.registerProvider(this.kaleyraSmsAdapter);
    this.registry.registerProvider(this.smsCountrySmsAdapter);
    this.registry.registerProvider(this.netcoreSmsAdapter);
    this.registry.registerProvider(this.tataSmsAdapter);
    this.registry.registerProvider(this.airtelIqSmsAdapter);
    this.registry.registerProvider(this.jioSmsAdapter);
    this.registry.registerProvider(this.bhashSmsAdapter);
    this.registry.registerProvider(this.bulkSmsAdapter);
    this.registry.registerProvider(this.smsGlobalAdapter);
    this.registry.registerProvider(this.amazonSnsSmsAdapter);
    this.registry.registerProvider(this.messageMediaSmsAdapter);
    this.registry.registerProvider(this.clickatellSmsAdapter);
    this.registry.registerProvider(this.bandwidthSmsAdapter);
    this.registry.registerProvider(this.cmTelecomSmsAdapter);
    this.registry.registerProvider(this.mittoSmsAdapter);
    this.registry.registerProvider(this.telstraSmsAdapter);

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

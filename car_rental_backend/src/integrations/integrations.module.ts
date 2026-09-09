import { Module, OnModuleInit, Global } from '@nestjs/common';
import { SecretVaultService } from './security/secret-vault.service';
import { IntegrationConfigService } from './config/integration-config.service';
import { ProviderHealthService } from './health/provider-health.service';
import { ProviderRegistryService } from './registry/provider-registry.service';
import { RetryPolicyService } from './errors/retry-policy.service';
import { WebhookDispatcherService } from './webhooks/webhook-dispatcher.service';
import { AdminIntegrationsService } from './admin/admin-integrations.service';
import { AdminIntegrationsController } from './admin/admin-integrations.controller';

// Concrete Adapters
import { RazorpayAdapter } from './adapters/payments/razorpay.adapter';
import { StripeAdapter } from './adapters/payments/stripe.adapter';
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

    // Adapters
    RazorpayAdapter,
    StripeAdapter,
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

    // Adapters exported for direct injection or test wiring
    RazorpayAdapter,
    StripeAdapter,
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

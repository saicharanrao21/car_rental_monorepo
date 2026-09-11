import { ConfigService } from '@nestjs/config';

// 23 New Payment Gateways
import { WorldlineAdapter } from '../adapters/payments/worldline.adapter';
import { PineLabsAdapter } from '../adapters/payments/pinelabs.adapter';
import { ZaakpayAdapter } from '../adapters/payments/zaakpay.adapter';
import { OpenMoneyAdapter } from '../adapters/payments/openmoney.adapter';
import { BraintreeAdapter } from '../adapters/payments/braintree.adapter';
import { WorldpayAdapter } from '../adapters/payments/worldpay.adapter';
import { AirwallexAdapter } from '../adapters/payments/airwallex.adapter';
import { RapydAdapter } from '../adapters/payments/rapyd.adapter';
import { DLocalAdapter } from '../adapters/payments/dlocal.adapter';
import { SafexpayAdapter } from '../adapters/payments/safexpay.adapter';
import { PayKunAdapter } from '../adapters/payments/paykun.adapter';
import { AtomAdapter } from '../adapters/payments/atom.adapter';
import { AirpayAdapter } from '../adapters/payments/airpay.adapter';
import { FibeAdapter } from '../adapters/payments/fibe.adapter';
import { SimplAdapter } from '../adapters/payments/simpl.adapter';
import { LazyPayAdapter } from '../adapters/payments/lazypay.adapter';
import { KlarnaAdapter } from '../adapters/payments/klarna.adapter';
import { AfterpayAdapter } from '../adapters/payments/afterpay.adapter';
import { AffirmAdapter } from '../adapters/payments/affirm.adapter';
import { SkrillAdapter } from '../adapters/payments/skrill.adapter';
import { NetellerAdapter } from '../adapters/payments/neteller.adapter';
import { TwoCheckoutAdapter } from '../adapters/payments/twocheckout.adapter';
import { StripeIndiaAdapter } from '../adapters/payments/stripe-india.adapter';

// 23 New SMS Gateways
import { GupshupSmsAdapter } from '../adapters/messaging/gupshup-sms.adapter';
import { ValueFirstSmsAdapter } from '../adapters/messaging/valuefirst-sms.adapter';
import { TanlaSmsAdapter } from '../adapters/messaging/tanla-sms.adapter';
import { TwoFactorSmsAdapter } from '../adapters/messaging/twofactor-sms.adapter';
import { TelnyxSmsAdapter } from '../adapters/messaging/telnyx-sms.adapter';
import { BirdSmsAdapter } from '../adapters/messaging/bird-sms.adapter';
import { ClickSendSmsAdapter } from '../adapters/messaging/clicksend-sms.adapter';
import { KaleyraSmsAdapter } from '../adapters/messaging/kaleyra-sms.adapter';
import { SmsCountrySmsAdapter } from '../adapters/messaging/smscountry-sms.adapter';
import { NetcoreSmsAdapter } from '../adapters/messaging/netcore-sms.adapter';
import { TataSmsAdapter } from '../adapters/messaging/tata-sms.adapter';
import { AirtelIqSmsAdapter } from '../adapters/messaging/airtel-iq-sms.adapter';
import { JioSmsAdapter } from '../adapters/messaging/jio-sms.adapter';
import { BhashSmsAdapter } from '../adapters/messaging/bhash-sms.adapter';
import { BulkSmsAdapter } from '../adapters/messaging/bulksms.adapter';
import { SmsGlobalAdapter } from '../adapters/messaging/smsglobal.adapter';
import { AmazonSnsSmsAdapter } from '../adapters/messaging/amazon-sns-sms.adapter';
import { MessageMediaSmsAdapter } from '../adapters/messaging/messagemedia-sms.adapter';
import { ClickatellSmsAdapter } from '../adapters/messaging/clickatell-sms.adapter';
import { BandwidthSmsAdapter } from '../adapters/messaging/bandwidth-sms.adapter';
import { CmTelecomSmsAdapter } from '../adapters/messaging/cm-telecom-sms.adapter';
import { MittoSmsAdapter } from '../adapters/messaging/mitto-sms.adapter';
import { TelstraSmsAdapter } from '../adapters/messaging/telstra-sms.adapter';

// Existing adapters for security guard validation
import { RazorpayAdapter } from '../adapters/payments/razorpay.adapter';
import { StripeAdapter } from '../adapters/payments/stripe.adapter';
import { XenditAdapter } from '../adapters/payments/xendit.adapter';
import { Fast2SmsAdapter } from '../adapters/messaging/fast2sms.adapter';

describe('Phase U — Enterprise Gateway Expansion Spec (47 Payments + 34 SMS)', () => {
  const mockConfig: Record<string, string> = {
    // Payment Gateways
    WORLDLINE_MERCHANT_ID: 'WL_MERCHANT_001',
    WORLDLINE_API_KEY: 'wl_api_key_001',
    WORLDLINE_API_SECRET: 'wl_api_secret_001',
    WORLDLINE_WEBHOOK_SECRET: 'wl_wh_secret_001',
    PINELABS_MERCHANT_ID: 'PL_MERCHANT_002',
    PINELABS_ACCESS_CODE: 'pl_access_code_002',
    PINELABS_SECRET_KEY: 'pl_secret_key_plural_002',
    ZAAKPAY_MERCHANT_ID: 'ZP_MERCHANT_003',
    ZAAKPAY_SECRET_KEY: 'zaakpay_secret_key_003',
    OPENMONEY_ACCESS_KEY: 'open_access_004',
    OPENMONEY_SECRET_KEY: 'open_secret_004',
    BRAINTREE_MERCHANT_ID: 'bt_merchant_005',
    BRAINTREE_PUBLIC_KEY: 'bt_pub_key_005',
    BRAINTREE_PRIVATE_KEY: 'bt_priv_key_005',
    WORLDPAY_SERVICE_KEY: 'wp_service_key_006',
    WORLDPAY_CLIENT_KEY: 'wp_client_key_006',
    WORLDPAY_WEBHOOK_SECRET: 'wp_wh_secret_006',
    AIRWALLEX_CLIENT_ID: 'aw_client_007',
    AIRWALLEX_API_KEY: 'aw_api_key_007',
    AIRWALLEX_WEBHOOK_SECRET: 'aw_wh_secret_007',
    RAPYD_ACCESS_KEY: 'rapyd_access_008',
    RAPYD_SECRET_KEY: 'rapyd_secret_008',
    DLOCAL_X_LOGIN: 'dlocal_x_login_009',
    DLOCAL_X_TRANS_KEY: 'dlocal_trans_key_009',
    DLOCAL_SECRET_KEY: 'dlocal_secret_009',
    SAFEXPAY_MERCHANT_ID: 'safex_merchant_010',
    SAFEXPAY_KEY: 'safex_key_010',
    PAYKUN_MERCHANT_ID: 'paykun_merchant_011',
    PAYKUN_ACCESS_TOKEN: 'paykun_token_011',
    PAYKUN_API_SECRET: 'paykun_sec_011',
    ATOM_MERCHANT_ID: 'atom_merchant_012',
    ATOM_PASSWORD: 'atom_password_012',
    ATOM_REQ_HASH_KEY: 'atom_req_hash_012',
    ATOM_RESP_HASH_KEY: 'atom_resp_hash_012',
    AIRPAY_MERCHANT_ID: 'airpay_merchant_013',
    AIRPAY_USERNAME: 'airpay_user_013',
    AIRPAY_SECRET_KEY: 'airpay_secret_013',
    FIBE_MERCHANT_ID: 'fibe_merchant_014',
    FIBE_API_KEY: 'fibe_key_014',
    FIBE_API_SECRET: 'fibe_sec_014',
    SIMPL_MERCHANT_ID: 'simpl_merchant_015',
    SIMPL_API_KEY: 'simpl_key_015',
    LAZYPAY_MERCHANT_ID: 'lazypay_merchant_016',
    LAZYPAY_SECRET_KEY: 'lazypay_sec_016',
    KLARNA_API_USERNAME: 'klarna_user_017',
    KLARNA_API_PASSWORD: 'klarna_password_017',
    AFTERPAY_MERCHANT_ID: 'afterpay_merchant_018',
    AFTERPAY_SECRET_KEY: 'afterpay_secret_018',
    AFFIRM_PUBLIC_KEY: 'affirm_pub_019',
    AFFIRM_PRIVATE_KEY: 'affirm_priv_019',
    SKRILL_MERCHANT_EMAIL: 'merchant@drivego.in',
    SKRILL_SECRET_WORD: 'skrill_secret_word_020',
    NETELLER_MERCHANT_ID: 'neteller_merchant_021',
    NETELLER_SECRET_KEY: 'neteller_secure_021',
    TWOCHECKOUT_MERCHANT_CODE: '2co_code_022',
    TWOCHECKOUT_SECRET_KEY: '2co_secret_022',
    TWOCHECKOUT_BUY_LINK_SECRET: '2co_buylink_022',
    STRIPE_INDIA_PUBLISHABLE_KEY: 'pk_live_stripe_in_023',
    STRIPE_INDIA_SECRET_KEY: 'sk_live_stripe_in_023',
    STRIPE_INDIA_WEBHOOK_SECRET: 'whsec_stripe_in_023',

    // SMS Gateways
    GUPSHUP_SMS_API_KEY: 'gupshup_key_1',
    GUPSHUP_SMS_SENDER_ID: 'GPSHUP',
    VALUEFIRST_USERNAME: 'vfirst_user_2',
    VALUEFIRST_PASSWORD: 'vfirst_pass_2',
    VALUEFIRST_SENDER_ID: 'VFIRST',
    TANLA_SMS_API_KEY: 'tanla_key_3',
    TWOFACTOR_SMS_API_KEY: '2factor_key_4',
    TELNYX_API_KEY: 'telnyx_key_5',
    TELNYX_MESSAGING_PROFILE_ID: 'telnyx_profile_5',
    BIRD_SMS_ACCESS_KEY: 'bird_key_6',
    CLICKSEND_USERNAME: 'clicksend_user_7',
    CLICKSEND_API_KEY: 'clicksend_key_7',
    KALEYRA_SMS_API_KEY: 'kaleyra_key_8',
    KALEYRA_SMS_SID: 'kaleyra_sid_8',
    KALEYRA_SMS_SENDER_ID: 'KALYRA',
    SMSCOUNTRY_AUTH_KEY: 'smscountry_key_9',
    SMSCOUNTRY_AUTH_TOKEN: 'smscountry_token_9',
    SMSCOUNTRY_SENDER_ID: 'SMSCNT',
    NETCORE_SMS_API_KEY: 'netcore_key_10',
    TATA_SMS_API_KEY: 'tata_key_11',
    TATA_SMS_SENDER_ID: 'TATATL',
    AIRTEL_IQ_CUSTOMER_ID: 'airtel_cust_12',
    AIRTEL_IQ_API_KEY: 'airtel_key_12',
    AIRTEL_IQ_SENDER_ID: 'AIRTEL',
    JIO_SMS_APP_ID: 'jio_app_13',
    JIO_SMS_APP_SECRET: 'jio_secret_13',
    JIO_SMS_SENDER_ID: 'JIOENT',
    BHASH_SMS_USER: 'bhash_user_14',
    BHASH_SMS_PASS: 'bhash_pass_14',
    BHASH_SMS_SENDER: 'BHASHS',
    BULKSMS_TOKEN_ID: 'bulksms_token_15',
    BULKSMS_TOKEN_SECRET: 'bulksms_sec_15',
    SMSGLOBAL_API_KEY: 'smsglobal_key_16',
    SMSGLOBAL_SECRET_KEY: 'smsglobal_sec_16',
    AWS_SNS_ACCESS_KEY_ID: 'aws_sns_access_17',
    AWS_SNS_SECRET_ACCESS_KEY: 'aws_sns_secret_17',
    AWS_SNS_REGION: 'ap-south-1',
    MESSAGEMEDIA_API_KEY: 'mm_key_18',
    MESSAGEMEDIA_API_SECRET: 'mm_sec_18',
    CLICKATELL_API_KEY: 'clickatell_key_19',
    BANDWIDTH_ACCOUNT_ID: 'bw_acct_20',
    BANDWIDTH_API_TOKEN: 'bw_token_20',
    BANDWIDTH_API_SECRET: 'bw_secret_20',
    BANDWIDTH_APPLICATION_ID: 'bw_app_20',
    CM_TELECOM_PRODUCT_TOKEN: 'cm_token_21',
    MITTO_SMS_API_KEY: 'mitto_key_22',
    TELSTRA_SMS_CLIENT_ID: 'telstra_client_23',
    TELSTRA_SMS_CLIENT_SECRET: 'telstra_secret_23',

    // Existing Gateways
    RAZORPAY_KEY_ID: 'rzp_live_test',
    RAZORPAY_KEY_SECRET: 'rzp_secret_test',
    STRIPE_SECRET_KEY: 'sk_live_test',
    STRIPE_WEBHOOK_SECRET: 'whsec_test',
    XENDIT_SECRET_KEY: 'xnd_secret_test',
    XENDIT_CALLBACK_TOKEN: 'xnd_callback_test',
    FAST2SMS_AUTHORIZATION: 'fast2sms_auth_test',
  };

  const createMockConfigService = (overrides: Record<string, string> = {}): ConfigService => {
    const merged = { ...mockConfig, ...overrides };
    return {
      get: jest.fn((key: string) => merged[key] || ''),
    } as unknown as ConfigService;
  };

  const configService = createMockConfigService();

  describe('23 New Payment Gateways Lifecycle', () => {
    const paymentAdapters = [
      { create: () => new WorldlineAdapter(configService), id: 'worldline' },
      { create: () => new PineLabsAdapter(configService), id: 'pinelabs' },
      { create: () => new ZaakpayAdapter(configService), id: 'zaakpay' },
      { create: () => new OpenMoneyAdapter(configService), id: 'openmoney' },
      { create: () => new BraintreeAdapter(configService), id: 'braintree' },
      { create: () => new WorldpayAdapter(configService), id: 'worldpay' },
      { create: () => new AirwallexAdapter(configService), id: 'airwallex' },
      { create: () => new RapydAdapter(configService), id: 'rapyd' },
      { create: () => new DLocalAdapter(configService), id: 'dlocal' },
      { create: () => new SafexpayAdapter(configService), id: 'safexpay' },
      { create: () => new PayKunAdapter(configService), id: 'paykun' },
      { create: () => new AtomAdapter(configService), id: 'atom' },
      { create: () => new AirpayAdapter(configService), id: 'airpay' },
      { create: () => new FibeAdapter(configService), id: 'fibe' },
      { create: () => new SimplAdapter(configService), id: 'simpl' },
      { create: () => new LazyPayAdapter(configService), id: 'lazypay' },
      { create: () => new KlarnaAdapter(configService), id: 'klarna' },
      { create: () => new AfterpayAdapter(configService), id: 'afterpay' },
      { create: () => new AffirmAdapter(configService), id: 'affirm' },
      { create: () => new SkrillAdapter(configService), id: 'skrill' },
      { create: () => new NetellerAdapter(configService), id: 'neteller' },
      { create: () => new TwoCheckoutAdapter(configService), id: 'twocheckout' },
      { create: () => new StripeIndiaAdapter(configService), id: 'stripe_india' },
    ];

    for (const { create, id } of paymentAdapters) {
      it(`${id}: createOrder, verifyPayment, refund, and webhook processing`, async () => {
        const adapter = create();
        expect(adapter.getProviderId()).toBe(id);

        // 1. Create Order
        const order = await adapter.createOrder({
          amountPaise: 250000,
          currency: 'INR',
          receipt: `rcpt_${id}_001`,
          bookingId: `bkg_${id}_001`,
          customerId: 'cust_enterprise_01',
          customerEmail: 'customer@drivego.in',
          customerPhone: '+919876543210',
          description: 'Luxury SUV rental reservation hold',
        });

        expect(order).toBeDefined();
        expect(order.providerOrderId).toBeDefined();
        expect(order.amountPaise).toBe(250000);

        // 2. Verify Payment
        const verification = await adapter.verifyPayment({
          providerOrderId: order.providerOrderId,
          providerPaymentId: `pay_${id}_tx_999`,
          providerSignature: 'sig_valid_checksum_123',
        });

        expect(verification).toBeDefined();
        expect(verification.isValid).toBe(true);
        expect(verification.providerPaymentId).toBe(`pay_${id}_tx_999`);

        // 3. Refund Payment
        const refund = await adapter.refund({
          providerPaymentId: `pay_${id}_tx_999`,
          amountPaise: 50000,
          currency: 'INR',
          reason: 'Security deposit balance release after inspection',
        });

        expect(refund).toBeDefined();
        expect(refund.providerRefundId).toBeDefined();
        expect(refund.amountPaise).toBe(50000);

        // 4. Webhook Normalization
        const mockPayload = {
          event: 'payment.succeeded',
          transactionId: `pay_${id}_wh_111`,
          orderId: order.orderId,
          amount: 250000,
          currency: 'INR',
          status: 'SUCCESS',
        };

        const normalized = adapter.normalizeWebhook(mockPayload, { 'x-signature': 'sig123' });
        expect(normalized).toBeDefined();
        expect(normalized.eventType).toBeDefined();

        // 5. Test Connection / Health Check
        const conn = await adapter.testConnection();
        expect(conn.success).toBe(true);

        const health = await adapter.checkHealth();
        expect(health.status).toBe('HEALTHY');
      });
    }
  });

  describe('23 New SMS Gateways Lifecycle', () => {
    const smsAdapters = [
      { create: () => new GupshupSmsAdapter(configService), id: 'gupshup_sms' },
      { create: () => new ValueFirstSmsAdapter(configService), id: 'valuefirst_sms' },
      { create: () => new TanlaSmsAdapter(configService), id: 'tanla_sms' },
      { create: () => new TwoFactorSmsAdapter(configService), id: 'twofactor_sms' },
      { create: () => new TelnyxSmsAdapter(configService), id: 'telnyx_sms' },
      { create: () => new BirdSmsAdapter(configService), id: 'bird_sms' },
      { create: () => new ClickSendSmsAdapter(configService), id: 'clicksend_sms' },
      { create: () => new KaleyraSmsAdapter(configService), id: 'kaleyra_sms' },
      { create: () => new SmsCountrySmsAdapter(configService), id: 'smscountry_sms' },
      { create: () => new NetcoreSmsAdapter(configService), id: 'netcore_sms' },
      { create: () => new TataSmsAdapter(configService), id: 'tata_sms' },
      { create: () => new AirtelIqSmsAdapter(configService), id: 'airtel_iq_sms' },
      { create: () => new JioSmsAdapter(configService), id: 'jio_sms' },
      { create: () => new BhashSmsAdapter(configService), id: 'bhash_sms' },
      { create: () => new BulkSmsAdapter(configService), id: 'bulksms' },
      { create: () => new SmsGlobalAdapter(configService), id: 'smsglobal' },
      { create: () => new AmazonSnsSmsAdapter(configService), id: 'amazon_sns_sms' },
      { create: () => new MessageMediaSmsAdapter(configService), id: 'messagemedia_sms' },
      { create: () => new ClickatellSmsAdapter(configService), id: 'clickatell_sms' },
      { create: () => new BandwidthSmsAdapter(configService), id: 'bandwidth_sms' },
      { create: () => new CmTelecomSmsAdapter(configService), id: 'cm_telecom_sms' },
      { create: () => new MittoSmsAdapter(configService), id: 'mitto_sms' },
      { create: () => new TelstraSmsAdapter(configService), id: 'telstra_sms' },
    ];

    for (const { create, id } of smsAdapters) {
      it(`${id}: sendSms, connection test, and health check`, async () => {
        const adapter = create();
        expect(adapter.getProviderId()).toBe(id);

        const result = await adapter.sendSms({
          to: '+919876543210',
          message: 'Your DriveGo reservation OTP is 582910. Valid for 10 minutes.',
          templateId: 'DLT_TE_001',
          senderId: 'DRIVGO',
        });

        expect(result).toBeDefined();
        expect(result.success).toBe(true);
        expect(result.messageId).toBeDefined();

        const conn = await adapter.testConnection();
        expect(conn.success).toBe(true);

        const health = await adapter.checkHealth();
        expect(health.status).toBe('HEALTHY');
      });
    }
  });

  describe('Production Security & Webhook Hardening', () => {
    const originalEnv = process.env.NODE_ENV;

    afterEach(() => {
      process.env.NODE_ENV = originalEnv;
    });

    it('Razorpay: rejects mock_signature in production mode', () => {
      const razorpay = new RazorpayAdapter(configService);
      process.env.NODE_ENV = 'production';

      const validInProd = razorpay.verifyWebhookSignature(
        JSON.stringify({ event: 'payment.captured' }),
        'mock_signature',
      );
      expect(validInProd).toBe(false);
    });

    it('Stripe: rejects mock_signature in production mode', () => {
      const stripe = new StripeAdapter(configService);
      process.env.NODE_ENV = 'production';

      const validInProd = stripe.verifyWebhookSignature(
        JSON.stringify({ type: 'payment_intent.succeeded' }),
        'mock_signature',
      );
      expect(validInProd).toBe(false);
    });

    it('Xendit: fail-closed if callback token is missing in production mode', () => {
      const xenditNoToken = new XenditAdapter({
        get: jest.fn(() => ''),
      } as unknown as ConfigService);
      process.env.NODE_ENV = 'production';

      const verified = xenditNoToken.verifyWebhookSignature(
        JSON.stringify({ event: 'invoice.paid' }),
        'any_token',
      );
      expect(verified).toBe(false);
    });

    it('Fast2SMS: fail-fast in production mode when API key is unconfigured', async () => {
      const fast2smsNoKey = new Fast2SmsAdapter({
        get: jest.fn(() => ''),
      } as unknown as ConfigService);
      process.env.NODE_ENV = 'production';

      const result = await fast2smsNoKey.sendSms({
        to: '+919876543210',
        message: 'Test message',
      });

      expect(result.success).toBe(false);
      expect(result.error).toContain('Fast2SMS apiKey not configured in production');
    });
  });
});

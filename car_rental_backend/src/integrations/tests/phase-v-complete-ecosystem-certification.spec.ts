import { ConfigService } from '@nestjs/config';

// 47 Concrete Payment Gateways
import { RazorpayAdapter } from '../adapters/payments/razorpay.adapter';
import { StripeAdapter } from '../adapters/payments/stripe.adapter';
import { CashfreeAdapter } from '../adapters/payments/cashfree.adapter';
import { PayPalAdapter } from '../adapters/payments/paypal.adapter';
import { PayUAdapter } from '../adapters/payments/payu.adapter';
import { PhonePeAdapter } from '../adapters/payments/phonepe.adapter';
import { PaytmAdapter } from '../adapters/payments/paytm.adapter';
import { BillDeskAdapter } from '../adapters/payments/billdesk.adapter';
import { CCAvenueAdapter } from '../adapters/payments/ccavenue.adapter';
import { JuspayAdapter } from '../adapters/payments/juspay.adapter';
import { AdyenAdapter } from '../adapters/payments/adyen.adapter';
import { FlutterwaveAdapter } from '../adapters/payments/flutterwave.adapter';
import { PaystackAdapter } from '../adapters/payments/paystack.adapter';
import { MercadoPagoAdapter } from '../adapters/payments/mercadopago.adapter';
import { MidtransAdapter } from '../adapters/payments/midtrans.adapter';
import { XenditAdapter } from '../adapters/payments/xendit.adapter';
import { TapPaymentAdapter } from '../adapters/payments/tap.adapter';
import { AuthorizeNetAdapter } from '../adapters/payments/authorizenet.adapter';
import { CheckoutComAdapter } from '../adapters/payments/checkout-com.adapter';
import { EasebuzzAdapter } from '../adapters/payments/easebuzz.adapter';
import { InstamojoAdapter } from '../adapters/payments/instamojo.adapter';
import { MollieAdapter } from '../adapters/payments/mollie.adapter';
import { PaytabsAdapter } from '../adapters/payments/paytabs.adapter';
import { SquareAdapter } from '../adapters/payments/square.adapter';
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

// 34 Concrete SMS Gateways
import { Fast2SmsAdapter } from '../adapters/messaging/fast2sms.adapter';
import { Msg91SmsAdapter } from '../adapters/messaging/msg91-sms.adapter';
import { TwilioSmsAdapter } from '../adapters/messaging/twilio-sms.adapter';
import { TextlocalAdapter } from '../adapters/messaging/textlocal.adapter';
import { KarixSmsAdapter } from '../adapters/messaging/karix-sms.adapter';
import { SinchSmsAdapter } from '../adapters/messaging/sinch-sms.adapter';
import { VonageSmsAdapter } from '../adapters/messaging/vonage-sms.adapter';
import { InfobipSmsAdapter } from '../adapters/messaging/infobip-sms.adapter';
import { PlivoSmsAdapter } from '../adapters/messaging/plivo-sms.adapter';
import { ExotelSmsAdapter } from '../adapters/messaging/exotel.adapter';
import { RouteMobileSmsAdapter } from '../adapters/messaging/route-mobile.adapter';
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

describe('Phase V — Full Enterprise Gateway Ecosystem Certification (47 Payments + 34 SMS)', () => {
  const mockConfig: Record<string, string> = {
    NODE_ENV: 'test',
    JWT_ACCESS_SECRET: 'super_secret_access_jwt_key_at_least_32_chars_long!',
    JWT_REFRESH_SECRET: 'super_secret_refresh_jwt_key_at_least_32_chars_long!',
    // Payments
    RAZORPAY_KEY_ID: 'rzp_test_sample',
    RAZORPAY_KEY_SECRET: 'rzp_sec_sample',
    STRIPE_SECRET_KEY: 'sk_test_sample',
    STRIPE_WEBHOOK_SECRET: 'whsec_test_sample',
    CASHFREE_APP_ID: 'cf_app_sample',
    CASHFREE_SECRET_KEY: 'cf_sec_sample',
    PAYPAL_CLIENT_ID: 'pp_client_sample',
    PAYPAL_CLIENT_SECRET: 'pp_sec_sample',
    PAYU_KEY: 'payu_key_sample',
    PAYU_SALT: 'payu_salt_sample',
    PHONEPE_MERCHANT_ID: 'pp_merch_sample',
    PHONEPE_SALT_KEY: 'pp_salt_sample',
    PAYTM_MID: 'paytm_mid_sample',
    PAYTM_KEY: 'paytm_key_sample',
    BILLDESK_MERCHANT_ID: 'bd_merch_sample',
    BILLDESK_CLIENT_ID: 'bd_client_sample',
    BILLDESK_SECRET: 'bd_sec_sample',
    CCAVENUE_MERCHANT_ID: 'cca_merch_sample',
    CCAVENUE_ACCESS_CODE: 'cca_code_sample',
    CCAVENUE_WORKING_KEY: 'cca_key_sample',
    JUSPAY_API_KEY: 'juspay_key_sample',
    ADYEN_API_KEY: 'adyen_key_sample',
    FLUTTERWAVE_SECRET_KEY: 'fw_sec_sample',
    PAYSTACK_SECRET_KEY: 'ps_sec_sample',
    MERCADOPAGO_ACCESS_TOKEN: 'mp_token_sample',
    MIDTRANS_SERVER_KEY: 'mt_sec_sample',
    XENDIT_API_KEY: 'xendit_key_sample',
    TAP_SECRET_KEY: 'tap_sec_sample',
    AUTHORIZENET_API_LOGIN_ID: 'authnet_login_sample',
    AUTHORIZENET_TRANSACTION_KEY: 'authnet_key_sample',
    CHECKOUT_SECRET_KEY: 'checkout_sec_sample',
    EASEBUZZ_MERCHANT_KEY: 'easebuzz_key_sample',
    EASEBUZZ_SALT: 'easebuzz_salt_sample',
    INSTAMOJO_API_KEY: 'im_key_sample',
    INSTAMOJO_AUTH_TOKEN: 'im_token_sample',
    MOLLIE_API_KEY: 'mollie_key_sample',
    PAYTABS_PROFILE_ID: 'pt_profile_sample',
    PAYTABS_SERVER_KEY: 'pt_server_sample',
    SQUARE_ACCESS_TOKEN: 'sq_token_sample',
    WORLDLINE_MERCHANT_ID: 'wl_merch_sample',
    WORLDLINE_API_KEY: 'wl_api_sample',
    WORLDLINE_API_SECRET: 'wl_sec_sample',
    PINELABS_MERCHANT_ID: 'pl_merch_sample',
    PINELABS_ACCESS_CODE: 'pl_code_sample',
    PINELABS_SECRET_KEY: 'pl_sec_sample',
    ZAAKPAY_MERCHANT_ID: 'zp_merch_sample',
    ZAAKPAY_SECRET_KEY: 'zp_sec_sample',
    OPENMONEY_ACCESS_KEY: 'om_access_sample',
    OPENMONEY_SECRET_KEY: 'om_sec_sample',
    BRAINTREE_MERCHANT_ID: 'bt_merch_sample',
    BRAINTREE_PUBLIC_KEY: 'bt_pub_sample',
    BRAINTREE_PRIVATE_KEY: 'bt_priv_sample',
    WORLDPAY_SERVICE_KEY: 'wp_svc_sample',
    AIRWALLEX_CLIENT_ID: 'aw_client_sample',
    AIRWALLEX_API_KEY: 'aw_api_sample',
    RAPYD_ACCESS_KEY: 'rapyd_access_sample',
    RAPYD_SECRET_KEY: 'rapyd_sec_sample',
    DLOCAL_X_LOGIN: 'dlocal_login_sample',
    DLOCAL_X_TRANS_KEY: 'dlocal_trans_sample',
    DLOCAL_SECRET_KEY: 'dlocal_sec_sample',
    SAFEXPAY_MERCHANT_ID: 'safex_merch_sample',
    SAFEXPAY_KEY: 'safex_key_sample',
    PAYKUN_MERCHANT_ID: 'paykun_merch_sample',
    PAYKUN_ACCESS_TOKEN: 'paykun_token_sample',
    PAYKUN_API_SECRET: 'paykun_sec_sample',
    ATOM_MERCHANT_ID: 'atom_merch_sample',
    ATOM_PASSWORD: 'atom_pass_sample',
    ATOM_REQ_HASH_KEY: 'atom_req_sample',
    ATOM_RESP_HASH_KEY: 'atom_resp_sample',
    AIRPAY_MERCHANT_ID: 'airpay_merch_sample',
    AIRPAY_USERNAME: 'airpay_user_sample',
    AIRPAY_SECRET_KEY: 'airpay_sec_sample',
    FIBE_MERCHANT_ID: 'fibe_merch_sample',
    FIBE_API_KEY: 'fibe_key_sample',
    FIBE_API_SECRET: 'fibe_sec_sample',
    SIMPL_MERCHANT_ID: 'simpl_merch_sample',
    SIMPL_API_KEY: 'simpl_key_sample',
    LAZYPAY_MERCHANT_ID: 'lazypay_merch_sample',
    LAZYPAY_SECRET_KEY: 'lazypay_sec_sample',
    KLARNA_API_USERNAME: 'klarna_user_sample',
    KLARNA_API_PASSWORD: 'klarna_pass_sample',
    AFTERPAY_MERCHANT_ID: 'afterpay_merch_sample',
    AFTERPAY_SECRET_KEY: 'afterpay_sec_sample',
    AFFIRM_PUBLIC_KEY: 'affirm_pub_sample',
    AFFIRM_PRIVATE_KEY: 'affirm_priv_sample',
    SKRILL_MERCHANT_EMAIL: 'skrill_email_sample@drivego.in',
    SKRILL_SECRET_WORD: 'skrill_word_sample',
    NETELLER_MERCHANT_ID: 'neteller_merch_sample',
    NETELLER_SECRET_KEY: 'neteller_sec_sample',
    TWOCHECKOUT_MERCHANT_CODE: '2co_code_sample',
    TWOCHECKOUT_SECRET_KEY: '2co_sec_sample',
    STRIPE_INDIA_PUBLISHABLE_KEY: 'pk_live_stripe_in_sample',
    STRIPE_INDIA_SECRET_KEY: 'sk_live_stripe_in_sample',
    // SMS Gateways
    FAST2SMS_API_KEY: 'f2s_api_sample',
    MSG91_AUTH_KEY: 'msg91_auth_sample',
    TWILIO_ACCOUNT_SID: 'AC_twilio_sample_sid',
    TWILIO_AUTH_TOKEN: 'twilio_auth_sample',
    TEXTLOCAL_API_KEY: 'textlocal_api_sample',
    KARIX_API_KEY: 'karix_api_sample',
    SINCH_SERVICE_PLAN_ID: 'sinch_plan_sample',
    SINCH_API_TOKEN: 'sinch_token_sample',
    VONAGE_API_KEY: 'vonage_key_sample',
    VONAGE_API_SECRET: 'vonage_sec_sample',
    INFOBIP_API_KEY: 'infobip_key_sample',
    PLIVO_AUTH_ID: 'plivo_id_sample',
    PLIVO_AUTH_TOKEN: 'plivo_token_sample',
    EXOTEL_API_KEY: 'exotel_key_sample',
    EXOTEL_API_TOKEN: 'exotel_token_sample',
    ROUTE_MOBILE_USERNAME: 'route_user_sample',
    ROUTE_MOBILE_PASSWORD: 'route_pass_sample',
    GUPSHUP_SMS_USER_ID: 'gupshup_user_sample',
    GUPSHUP_SMS_PASSWORD: 'gupshup_pass_sample',
    VALUEFIRST_USERNAME: 'valuefirst_user_sample',
    VALUEFIRST_PASSWORD: 'valuefirst_pass_sample',
    TANLA_CLIENT_ID: 'tanla_client_sample',
    TANLA_CLIENT_SECRET: 'tanla_sec_sample',
    TWOFACTOR_API_KEY: '2factor_key_sample',
    TELNYX_API_KEY: 'telnyx_key_sample',
    BIRD_SMS_API_KEY: 'bird_key_sample',
    CLICKSEND_USERNAME: 'clicksend_user_sample',
    CLICKSEND_API_KEY: 'clicksend_key_sample',
    KALEYRA_API_KEY: 'kaleyra_key_sample',
    KALEYRA_SID: 'kaleyra_sid_sample',
    SMSCOUNTRY_USER_KEY: 'smsc_user_sample',
    SMSCOUNTRY_API_KEY: 'smsc_key_sample',
    NETCORE_API_KEY: 'netcore_key_sample',
    TATA_SMS_AUTH_KEY: 'tata_key_sample',
    AIRTEL_IQ_CLIENT_ID: 'airtel_id_sample',
    AIRTEL_IQ_SECRET: 'airtel_sec_sample',
    JIO_SMS_CLIENT_ID: 'jio_id_sample',
    JIO_SMS_SECRET: 'jio_sec_sample',
    BHASH_SMS_USER: 'bhash_user_sample',
    BHASH_SMS_PASSWORD: 'bhash_pass_sample',
    BULKSMS_USERNAME: 'bulksms_user_sample',
    BULKSMS_PASSWORD: 'bulksms_pass_sample',
    SMSGLOBAL_API_KEY: 'smsglobal_key_sample',
    SMSGLOBAL_SECRET_KEY: 'smsglobal_sec_sample',
    AWS_REGION: 'ap-south-1',
    MESSAGEMEDIA_API_KEY: 'mm_key_sample',
    MESSAGEMEDIA_API_SECRET: 'mm_sec_sample',
    CLICKATELL_API_KEY: 'clickatell_key_sample',
    BANDWIDTH_ACCOUNT_ID: 'bw_acct_sample',
    BANDWIDTH_API_TOKEN: 'bw_token_sample',
    BANDWIDTH_API_SECRET: 'bw_sec_sample',
    CM_TELECOM_PRODUCT_TOKEN: 'cm_token_sample',
    MITTO_API_KEY: 'mitto_key_sample',
    TELSTRA_CLIENT_ID: 'telstra_id_sample',
    TELSTRA_CLIENT_SECRET: 'telstra_sec_sample',
  };

  const configService = {
    get: jest.fn((key: string) => mockConfig[key] || ''),
  } as unknown as ConfigService;

  it('Verifies exactly 47 unique concrete Payment Provider Adapters', () => {
    const paymentAdapters = [
      new RazorpayAdapter(configService),
      new StripeAdapter(configService),
      new CashfreeAdapter(configService),
      new PayPalAdapter(configService),
      new PayUAdapter(configService),
      new PhonePeAdapter(configService),
      new PaytmAdapter(configService),
      new BillDeskAdapter(configService),
      new CCAvenueAdapter(configService),
      new JuspayAdapter(configService),
      new AdyenAdapter(configService),
      new FlutterwaveAdapter(configService),
      new PaystackAdapter(configService),
      new MercadoPagoAdapter(configService),
      new MidtransAdapter(configService),
      new XenditAdapter(configService),
      new TapPaymentAdapter(configService),
      new AuthorizeNetAdapter(configService),
      new CheckoutComAdapter(configService),
      new EasebuzzAdapter(configService),
      new InstamojoAdapter(configService),
      new MollieAdapter(configService),
      new PaytabsAdapter(configService),
      new SquareAdapter(configService),
      new WorldlineAdapter(configService),
      new PineLabsAdapter(configService),
      new ZaakpayAdapter(configService),
      new OpenMoneyAdapter(configService),
      new BraintreeAdapter(configService),
      new WorldpayAdapter(configService),
      new AirwallexAdapter(configService),
      new RapydAdapter(configService),
      new DLocalAdapter(configService),
      new SafexpayAdapter(configService),
      new PayKunAdapter(configService),
      new AtomAdapter(configService),
      new AirpayAdapter(configService),
      new FibeAdapter(configService),
      new SimplAdapter(configService),
      new LazyPayAdapter(configService),
      new KlarnaAdapter(configService),
      new AfterpayAdapter(configService),
      new AffirmAdapter(configService),
      new SkrillAdapter(configService),
      new NetellerAdapter(configService),
      new TwoCheckoutAdapter(configService),
      new StripeIndiaAdapter(configService),
    ];

    expect(paymentAdapters.length).toBe(47);

    const ids = paymentAdapters.map((a) => a.getProviderId());
    const uniqueIds = new Set(ids);
    expect(uniqueIds.size).toBe(47);

    for (const adapter of paymentAdapters) {
      expect(typeof adapter.getProviderId()).toBe('string');
      expect(adapter.getProviderId().length).toBeGreaterThan(0);
      expect(typeof adapter.getDisplayName()).toBe('string');
      expect(typeof adapter.createOrder).toBe('function');
      expect(typeof adapter.verifyPayment).toBe('function');
      expect(typeof adapter.refund).toBe('function');
    }
  });

  it('Verifies exactly 34 unique concrete SMS Provider Adapters', () => {
    const smsAdapters = [
      new Fast2SmsAdapter(configService),
      new Msg91SmsAdapter(configService),
      new TwilioSmsAdapter(configService),
      new TextlocalAdapter(configService),
      new KarixSmsAdapter(configService),
      new SinchSmsAdapter(configService),
      new VonageSmsAdapter(configService),
      new InfobipSmsAdapter(configService),
      new PlivoSmsAdapter(configService),
      new ExotelSmsAdapter(configService),
      new RouteMobileSmsAdapter(configService),
      new GupshupSmsAdapter(configService),
      new ValueFirstSmsAdapter(configService),
      new TanlaSmsAdapter(configService),
      new TwoFactorSmsAdapter(configService),
      new TelnyxSmsAdapter(configService),
      new BirdSmsAdapter(configService),
      new ClickSendSmsAdapter(configService),
      new KaleyraSmsAdapter(configService),
      new SmsCountrySmsAdapter(configService),
      new NetcoreSmsAdapter(configService),
      new TataSmsAdapter(configService),
      new AirtelIqSmsAdapter(configService),
      new JioSmsAdapter(configService),
      new BhashSmsAdapter(configService),
      new BulkSmsAdapter(configService),
      new SmsGlobalAdapter(configService),
      new AmazonSnsSmsAdapter(configService),
      new MessageMediaSmsAdapter(configService),
      new ClickatellSmsAdapter(configService),
      new BandwidthSmsAdapter(configService),
      new CmTelecomSmsAdapter(configService),
      new MittoSmsAdapter(configService),
      new TelstraSmsAdapter(configService),
    ];

    expect(smsAdapters.length).toBe(34);

    const ids = smsAdapters.map((a) => a.getProviderId());
    const uniqueIds = new Set(ids);
    expect(uniqueIds.size).toBe(34);

    for (const adapter of smsAdapters) {
      expect(typeof adapter.getProviderId()).toBe('string');
      expect(adapter.getProviderId().length).toBeGreaterThan(0);
      expect(typeof adapter.getDisplayName()).toBe('string');
      expect(typeof adapter.sendSms).toBe('function');
    }
  });
});

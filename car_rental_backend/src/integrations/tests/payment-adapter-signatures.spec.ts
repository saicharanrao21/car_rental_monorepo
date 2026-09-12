import { ConfigService } from '@nestjs/config';
import * as fs from 'fs';
import * as path from 'path';

describe('Payment Adapters Signature Hardening & Rejection of Garbage Signatures', () => {
  const adaptersDir = path.join(__dirname, '../adapters/payments');
  const files = fs.readdirSync(adaptersDir).filter((f) => f.endsWith('.adapter.ts'));

  const mockConfigValues: Record<string, string> = {
    NODE_ENV: 'test',
    RAZORPAY_KEY_ID: 'rzp_live_key_123',
    RAZORPAY_KEY_SECRET: 'rzp_live_secret_456',
    STRIPE_SECRET_KEY: 'sk_live_stripe_secret_123',
    STRIPE_WEBHOOK_SECRET: 'whsec_stripe_123',
    PAYPAL_CLIENT_ID: 'paypal_client_123',
    PAYPAL_CLIENT_SECRET: 'paypal_secret_123',
    PAYTM_MID: 'paytm_mid_123',
    PAYTM_MERCHANT_KEY: 'paytm_key_123',
    PHONEPE_MERCHANT_ID: 'phonepe_mid_123',
    PHONEPE_SALT_KEY: 'phonepe_salt_123',
    PAYU_KEY: 'payu_key_123',
    PAYU_SALT: 'payu_salt_123',
    CASHFREE_APP_ID: 'cashfree_app_123',
    CASHFREE_SECRET_KEY: 'cashfree_secret_123',
    CCAVENUE_MERCHANT_ID: 'ccav_merchant_123',
    CCAVENUE_WORKING_KEY: 'ccav_working_key_123',
    BILLDESK_MERCHANT_ID: 'bd_merchant_123',
    BILLDESK_CLIENT_ID: 'bd_client_123',
    BILLDESK_SECRET_KEY: 'bd_secret_key_123',
    ATOM_MERCHANT_ID: 'atom_mid_123',
    ATOM_RESP_HASH_KEY: 'atom_resp_key_123',
    FIBE_MERCHANT_ID: 'fibe_mid_123',
    FIBE_API_SECRET: 'fibe_sec_123',
    INSTAMOJO_API_KEY: 'im_api_key_123',
    INSTAMOJO_AUTH_TOKEN: 'im_auth_token_123',
    INSTAMOJO_SALT: 'im_salt_123',
    JUSPAY_MERCHANT_ID: 'juspay_mid_123',
    JUSPAY_API_KEY: 'juspay_api_key_123',
    ADYEN_MERCHANT_ACCOUNT: 'adyen_acc_123',
    ADYEN_API_KEY: 'adyen_key_123',
    ADYEN_HMAC_KEY: 'adyen_hmac_123',
    AIRPAY_MERCHANT_ID: 'airpay_mid_123',
    AIRPAY_SECRET_KEY: 'airpay_sec_123',
    AIRWALLEX_CLIENT_ID: 'airwallex_cid_123',
    AIRWALLEX_API_KEY: 'airwallex_key_123',
    AUTHORIZENET_API_LOGIN_ID: 'anet_login_123',
    AUTHORIZENET_TRANSACTION_KEY: 'anet_key_123',
    BRAINTREE_MERCHANT_ID: 'bt_mid_123',
    BRAINTREE_PUBLIC_KEY: 'bt_pub_123',
    BRAINTREE_PRIVATE_KEY: 'bt_priv_123',
    CHECKOUT_COM_SECRET_KEY: 'checkout_sec_123',
    DLOCAL_X_LOGIN: 'dlocal_login_123',
    DLOCAL_SECRET_KEY: 'dlocal_sec_123',
    EASEBUZZ_KEY: 'easebuzz_key_123',
    EASEBUZZ_SALT: 'easebuzz_salt_123',
    FLUTTERWAVE_SECRET_KEY: 'flw_sec_123',
    KLARNA_USERNAME: 'klarna_user_123',
    KLARNA_PASSWORD: 'klarna_pwd_123',
    LAZYPAY_KEY: 'lazypay_key_123',
    LAZYPAY_SECRET: 'lazypay_sec_123',
    MERCADOPAGO_ACCESS_TOKEN: 'mp_token_123',
    MIDTRANS_SERVER_KEY: 'midtrans_sec_123',
    MOLLIE_API_KEY: 'mollie_key_123',
    NETELLER_MERCHANT_ID: 'neteller_mid_123',
    NETELLER_SECRET_KEY: 'neteller_sec_123',
    OPENMONEY_ACCESS_KEY: 'openmoney_acc_123',
    OPENMONEY_SECRET_KEY: 'openmoney_sec_123',
    PAYKUN_MERCHANT_ID: 'paykun_mid_123',
    PAYKUN_ACCESS_TOKEN: 'paykun_token_123',
    PAYKUN_API_SECRET: 'paykun_sec_123',
    PAYSTACK_SECRET_KEY: 'paystack_sec_123',
    PAYTABS_SERVER_KEY: 'paytabs_sec_123',
    PINELABS_MERCHANT_ID: 'pine_mid_123',
    PINELABS_SECRET_KEY: 'pine_sec_123',
    RAPYD_ACCESS_KEY: 'rapyd_acc_123',
    RAPYD_SECRET_KEY: 'rapyd_sec_123',
    SAFEXPAY_MERCHANT_ID: 'safexpay_mid_123',
    SAFEXPAY_KEY: 'safexpay_key_123',
    SIMPL_KEY: 'simpl_key_123',
    SIMPL_SECRET: 'simpl_sec_123',
    SKRILL_MERCHANT_EMAIL: 'skrill@test.com',
    SKRILL_SECRET_WORD: 'skrill_secret_word_123',
    SQUARE_ACCESS_TOKEN: 'sq_token_123',
    STRIPE_INDIA_SECRET_KEY: 'stripe_in_sec_123',
    TAP_SECRET_KEY: 'tap_sec_123',
    TWOCHECKOUT_MERCHANT_CODE: '2co_code_123',
    TWOCHECKOUT_SECRET_KEY: '2co_sec_123',
    WORLDLINE_MERCHANT_CODE: 'wl_code_123',
    WORLDLINE_SECRET_KEY: 'wl_sec_123',
    WORLDPAY_MERCHANT_CODE: 'wp_code_123',
    WORLDPAY_XML_PASSWORD: 'wp_pwd_123',
    XENDIT_SECRET_KEY: 'xendit_sec_123',
    ZAAKPAY_MERCHANT_ID: 'zaakpay_mid_123',
    ZAAKPAY_SECRET_KEY: 'zaakpay_sec_123',
    AFFIRM_PUBLIC_KEY: 'affirm_pub_123',
    AFFIRM_PRIVATE_KEY: 'affirm_priv_123',
    AFTERPAY_MERCHANT_ID: 'afterpay_mid_123',
    AFTERPAY_SECRET_KEY: 'afterpay_sec_123',
  };

  const mockConfigService = {
    get: jest.fn((key: string) => mockConfigValues[key] || ''),
  } as unknown as ConfigService;

  it(`found all 48 payment adapter files`, () => {
    expect(files.length).toBe(48);
  });

  for (const file of files) {
    const adapterName = file.replace('.ts', '');

    describe(`Adapter: ${adapterName}`, () => {
      let adapterInstance: any;

      beforeAll(() => {
        const module = require(`../adapters/payments/${adapterName}`);
        const ExportedClass = Object.values(module).find(
          (exp: any) => typeof exp === 'function' && exp.name?.endsWith('Adapter'),
        ) as any;

        expect(ExportedClass).toBeDefined();

        try {
          adapterInstance = new ExportedClass(mockConfigService);
        } catch {
          adapterInstance = new ExportedClass();
        }
      });

      it(`returns isValid: false for random/garbage providerSignature in verifyPayment()`, async () => {
        if (!adapterInstance.verifyPayment) return;

        const garbageSignatures = [
          'random_garbage_signature_1234567890_abcdef',
          'd9a8c7b6e5f4a3b2c1d0e9f8a7b6c5d4',
          'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          'invalid_signature_test',
          'short',
          'very_long_random_hash_string_that_looks_like_a_signature_but_is_completely_invalid_987654321',
        ];

        for (const sig of garbageSignatures) {
          const result = await adapterInstance.verifyPayment({
            providerOrderId: 'order_test_12345',
            providerPaymentId: 'pay_test_67890',
            providerSignature: sig,
            bookingId: 'booking_123',
          });

          expect(result).toBeDefined();
          expect(result.isValid).toBe(false);
          expect(result.status).toBe('FAILED');
        }
      });

      it(`returns isValid: false when signature is empty string or undefined`, async () => {
        if (!adapterInstance.verifyPayment) return;

        const emptyResult = await adapterInstance.verifyPayment({
          providerOrderId: 'order_test_12345',
          providerPaymentId: 'pay_test_67890',
          providerSignature: '',
          bookingId: 'booking_123',
        });
        expect(emptyResult.isValid).toBe(false);
      });

      it(`in production, createOrder() throws ServiceUnavailableException or Error if credentials missing`, async () => {
        if (!adapterInstance.createOrder) return;
        const origEnv = process.env.NODE_ENV;
        process.env.NODE_ENV = 'production';

        const emptyConfigService = {
          get: jest.fn(() => ''),
        } as unknown as ConfigService;

        const ExportedClass = adapterInstance.constructor;
        let unconfiguredAdapter: any;
        try {
          unconfiguredAdapter = new ExportedClass(emptyConfigService);
        } catch {
          unconfiguredAdapter = new ExportedClass();
        }

        try {
          await expect(
            unconfiguredAdapter.createOrder({
              bookingId: 'booking_123',
              amountPaise: 500000,
              currency: 'INR',
              customerId: 'cust_123',
            }),
          ).rejects.toThrow();
        } finally {
          process.env.NODE_ENV = origEnv;
        }
      });
    });
  }
});

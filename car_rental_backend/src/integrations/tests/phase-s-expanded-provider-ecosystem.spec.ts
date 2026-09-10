import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { IntegrationConfigService } from '../config/integration-config.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { SecretVaultService } from '../security/secret-vault.service';
import { PrismaService } from '../../prisma/prisma.service';
import { SystemConfigService } from '../../config-engine/system-config.service';
import { IntegrationCategory, ProviderHealthStatus } from '../registry/provider.types';

// New Payment Adapters
import { CCAvenueAdapter } from '../adapters/payments/ccavenue.adapter';
import { PaytmAdapter } from '../adapters/payments/paytm.adapter';
import { BillDeskAdapter } from '../adapters/payments/billdesk.adapter';
import { PayPalAdapter } from '../adapters/payments/paypal.adapter';
import { SquareAdapter } from '../adapters/payments/square.adapter';
import { CheckoutComAdapter } from '../adapters/payments/checkout-com.adapter';
import { PaystackAdapter } from '../adapters/payments/paystack.adapter';
import { MollieAdapter } from '../adapters/payments/mollie.adapter';

// New Messaging Adapters
import { Fast2SmsAdapter } from '../adapters/messaging/fast2sms.adapter';
import { TextlocalAdapter } from '../adapters/messaging/textlocal.adapter';
import { KarixSmsAdapter } from '../adapters/messaging/karix-sms.adapter';
import { SinchSmsAdapter } from '../adapters/messaging/sinch-sms.adapter';
import { VonageSmsAdapter } from '../adapters/messaging/vonage-sms.adapter';
import { InfobipSmsAdapter } from '../adapters/messaging/infobip-sms.adapter';
import { PlivoSmsAdapter } from '../adapters/messaging/plivo-sms.adapter';
import { PostmarkEmailAdapter } from '../adapters/messaging/postmark-email.adapter';
import { AwsSesEmailAdapter } from '../adapters/messaging/aws-ses-email.adapter';

describe('Phase S — Multi-Provider Gateway & Communications Ecosystem Breadth', () => {
  let registry: ProviderRegistryService;

  // Payment Adapters
  let ccavenue: CCAvenueAdapter;
  let paytm: PaytmAdapter;
  let billdesk: BillDeskAdapter;
  let paypal: PayPalAdapter;
  let square: SquareAdapter;
  let checkoutCom: CheckoutComAdapter;
  let paystack: PaystackAdapter;
  let mollie: MollieAdapter;

  // Messaging Adapters
  let fast2sms: Fast2SmsAdapter;
  let textlocal: TextlocalAdapter;
  let karix: KarixSmsAdapter;
  let sinch: SinchSmsAdapter;
  let vonage: VonageSmsAdapter;
  let infobip: InfobipSmsAdapter;
  let plivo: PlivoSmsAdapter;
  let postmark: PostmarkEmailAdapter;
  let awsSes: AwsSesEmailAdapter;

  const mockPrisma: any = {
    integrationConfig: {
      findUnique: jest.fn().mockResolvedValue(null),
      findFirst: jest.fn().mockResolvedValue(null),
      findMany: jest.fn().mockResolvedValue([]),
      upsert: jest.fn().mockResolvedValue({}),
    },
  };

  const mockConfigs: Record<string, any> = {};
  const mockSystemConfigService = {
    getConfig: jest.fn(async (key: string) => mockConfigs[key] ?? null),
    setConfig: jest.fn(async (key: string, val: any) => {
      mockConfigs[key] = val;
    }),
  };

  const originalFetch = global.fetch;

  beforeAll(async () => {
    global.fetch = jest.fn(async (url: any, _options: any) => {
      const urlStr = String(url);
      if (urlStr.includes('fast2sms.com')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({ return: true, request_id: 'f2s_req_123', message: ['Sent'] }),
        } as any;
      }
      if (urlStr.includes('textlocal.in')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({ status: 'success', messages: [{ id: 'tl_123', recipient: '9876543210' }], balance: 100 }),
        } as any;
      }
      if (urlStr.includes('karix')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({ status: 'success', data: { uid: 'kar_ack_123' } }),
        } as any;
      }
      if (urlStr.includes('sinch.com')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({ id: 'sinch_batch_123', status: 'Queued' }),
        } as any;
      }
      if (urlStr.includes('nexmo.com') || urlStr.includes('vonage.com')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({ messages: [{ status: '0', 'message-id': 'vonage_msg_123' }] }),
        } as any;
      }
      if (urlStr.includes('infobip.com')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({ messages: [{ messageId: 'ib_msg_123', status: { name: 'PENDING_ENROUTE' } }] }),
        } as any;
      }
      if (urlStr.includes('plivo.com')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({ message: 'message(s) queued', message_uuid: ['plivo_uuid_123'] }),
        } as any;
      }
      if (urlStr.includes('postmarkapp.com')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({ To: 'customer@example.com', MessageID: 'pm_msg_123', ErrorCode: 0 }),
        } as any;
      }
      return {
        ok: true,
        status: 200,
        json: async () => ({}),
        text: async () => '',
      } as any;
    });

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ProviderRegistryService,
        IntegrationConfigService,
        ProviderHealthService,
        SecretVaultService,
        { provide: SystemConfigService, useValue: mockSystemConfigService },
        { provide: PrismaService, useValue: mockPrisma },
        {
          provide: ConfigService,
          useValue: {
            get: (key: string) => {
              const map: Record<string, string> = {
                CCAVENUE_MERCHANT_ID: 'cca_mid_123',
                CCAVENUE_ACCESS_CODE: 'cca_acc_456',
                CCAVENUE_WORKING_KEY: 'cca_key_789',
                PAYTM_MID: 'paytm_mid_123',
                PAYTM_MERCHANT_KEY: 'paytm_key_456',
                BILLDESK_MERCHANT_ID: 'bd_mid_123',
                BILLDESK_CLIENT_ID: 'bd_cid_456',
                BILLDESK_SECRET_KEY: 'bd_sec_789',
                PAYPAL_CLIENT_ID: 'pp_cid_123',
                PAYPAL_CLIENT_SECRET: 'pp_sec_456',
                SQUARE_APPLICATION_ID: 'sq_app_123',
                SQUARE_ACCESS_TOKEN: 'sq_tok_456',
                SQUARE_LOCATION_ID: 'sq_loc_789',
                CHECKOUT_PUBLIC_KEY: 'cko_pk_123',
                CHECKOUT_SECRET_KEY: 'cko_sk_456',
                PAYSTACK_PUBLIC_KEY: 'pstk_pk_123',
                PAYSTACK_SECRET_KEY: 'pstk_sk_456',
                MOLLIE_API_KEY: 'test_mollie_api_key',
                FAST2SMS_API_KEY: 'f2s_key_123',
                TEXTLOCAL_API_KEY: 'txt_key_123',
                KARIX_AUTH_KEY: 'krx_key_123',
                KARIX_ACCOUNT_ID: 'krx_acct_456',
                SINCH_SERVICE_PLAN_ID: 'sinch_plan_123',
                SINCH_API_TOKEN: 'sinch_tok_456',
                VONAGE_API_KEY: 'vng_key_123',
                VONAGE_API_SECRET: 'vng_sec_456',
                INFOBIP_API_KEY: 'ib_key_123',
                INFOBIP_BASE_URL: 'https://api.infobip.com',
                PLIVO_AUTH_ID: 'plv_id_123',
                PLIVO_AUTH_TOKEN: 'plv_tok_456',
                POSTMARK_SERVER_TOKEN: 'pm_tok_123',
                AWS_SES_ACCESS_KEY_ID: 'ses_key_123',
                AWS_SES_SECRET_ACCESS_KEY: 'ses_sec_456',
              };
              return map[key] || null;
            },
          },
        },
        CCAvenueAdapter,
        PaytmAdapter,
        BillDeskAdapter,
        PayPalAdapter,
        SquareAdapter,
        CheckoutComAdapter,
        PaystackAdapter,
        MollieAdapter,
        Fast2SmsAdapter,
        TextlocalAdapter,
        KarixSmsAdapter,
        SinchSmsAdapter,
        VonageSmsAdapter,
        InfobipSmsAdapter,
        PlivoSmsAdapter,
        PostmarkEmailAdapter,
        AwsSesEmailAdapter,
      ],
    }).compile();

    registry = module.get<ProviderRegistryService>(ProviderRegistryService);

    ccavenue = module.get<CCAvenueAdapter>(CCAvenueAdapter);
    paytm = module.get<PaytmAdapter>(PaytmAdapter);
    billdesk = module.get<BillDeskAdapter>(BillDeskAdapter);
    paypal = module.get<PayPalAdapter>(PayPalAdapter);
    square = module.get<SquareAdapter>(SquareAdapter);
    checkoutCom = module.get<CheckoutComAdapter>(CheckoutComAdapter);
    paystack = module.get<PaystackAdapter>(PaystackAdapter);
    mollie = module.get<MollieAdapter>(MollieAdapter);

    fast2sms = module.get<Fast2SmsAdapter>(Fast2SmsAdapter);
    textlocal = module.get<TextlocalAdapter>(TextlocalAdapter);
    karix = module.get<KarixSmsAdapter>(KarixSmsAdapter);
    sinch = module.get<SinchSmsAdapter>(SinchSmsAdapter);
    vonage = module.get<VonageSmsAdapter>(VonageSmsAdapter);
    infobip = module.get<InfobipSmsAdapter>(InfobipSmsAdapter);
    plivo = module.get<PlivoSmsAdapter>(PlivoSmsAdapter);
    postmark = module.get<PostmarkEmailAdapter>(PostmarkEmailAdapter);
    awsSes = module.get<AwsSesEmailAdapter>(AwsSesEmailAdapter);

    // Register all adapters
    registry.registerProvider(ccavenue);
    registry.registerProvider(paytm);
    registry.registerProvider(billdesk);
    registry.registerProvider(paypal);
    registry.registerProvider(square);
    registry.registerProvider(checkoutCom);
    registry.registerProvider(paystack);
    registry.registerProvider(mollie);

    registry.registerProvider(fast2sms);
    registry.registerProvider(textlocal);
    registry.registerProvider(karix);
    registry.registerProvider(sinch);
    registry.registerProvider(vonage);
    registry.registerProvider(infobip);
    registry.registerProvider(plivo);
    registry.registerProvider(postmark);
    registry.registerProvider(awsSes);
  });

  afterAll(() => {
    global.fetch = originalFetch;
  });

  describe('1. Payment Gateways — Multi-Provider Adapters', () => {
    it('verifies CCAvenue order creation, payment verification, and refund', async () => {
      const order = await ccavenue.createOrder({
        bookingId: 'book_cca_01',
        amountPaise: 500000,
        currency: 'INR',
        customerId: 'cust_01',
      });
      expect(order.providerOrderId).toContain('cca_ord_book_cca_01');
      expect(order.status).toBe('ACTIVE');

      const verify = await ccavenue.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'track_123',
        providerSignature: 'valid_sig',
      });
      expect(verify.isValid).toBe(true);
      expect(verify.status).toBe('PAID');

      const refund = await ccavenue.refund({
        paymentId: 'pay_01',
        providerPaymentId: 'track_123',
        amountPaise: 500000,
      });
      expect(refund.status).toBe('PROCESSED');
    });

    it('verifies Paytm All-in-One order creation, verification, and refund', async () => {
      const order = await paytm.createOrder({
        bookingId: 'book_ptm_01',
        amountPaise: 350000,
        currency: 'INR',
        customerId: 'cust_02',
      });
      expect(order.providerOrderId).toContain('paytm_ord_book_ptm_01');

      const verify = await paytm.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'txnid_999',
        providerSignature: 'valid_sig',
      });
      expect(verify.isValid).toBe(true);
      expect(verify.status).toBe('PAID');

      const refund = await paytm.refund({
        paymentId: 'pay_02',
        providerPaymentId: 'txnid_999',
        amountPaise: 350000,
      });
      expect(refund.status).toBe('PROCESSED');
    });

    it('verifies BillDesk order creation and payment verification', async () => {
      const order = await billdesk.createOrder({
        bookingId: 'book_bd_01',
        amountPaise: 420000,
        currency: 'INR',
        customerId: 'cust_03',
      });
      expect(order.providerOrderId).toContain('bd_ord_book_bd_01');

      const verify = await billdesk.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'bd_txn_123',
        providerSignature: 'valid_sig',
      });
      expect(verify.isValid).toBe(true);
      expect(verify.status).toBe('PAID');
    });

    it('verifies PayPal global order creation and refund flow', async () => {
      const order = await paypal.createOrder({
        bookingId: 'book_pp_01',
        amountPaise: 15000, // $150.00
        currency: 'USD',
        customerId: 'cust_04',
      });
      expect(order.providerOrderId).toContain('PAYPAL_ORD_');
      expect(order.currency).toBe('USD');

      const refund = await paypal.refund({
        paymentId: 'pay_pp_01',
        providerPaymentId: 'cap_123',
        amountPaise: 15000,
      });
      expect(refund.status).toBe('PROCESSED');
    });

    it('verifies Square payment adapter operations', async () => {
      const order = await square.createOrder({
        bookingId: 'book_sq_01',
        amountPaise: 20000,
        currency: 'USD',
        customerId: 'cust_05',
      });
      expect(order.providerOrderId).toContain('sq_ord_');

      const verify = await square.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'sq_pay_123',
        providerSignature: 'valid_sig',
      });
      expect(verify.isValid).toBe(true);
      expect(verify.status).toBe('PAID');
    });

    it('verifies Checkout.com global unified API order creation and refund', async () => {
      const order = await checkoutCom.createOrder({
        bookingId: 'book_cko_01',
        amountPaise: 8000,
        currency: 'EUR',
        customerId: 'cust_06',
      });
      expect(order.providerOrderId).toContain('pay_cko_');

      const refund = await checkoutCom.refund({
        paymentId: 'pay_cko_01',
        providerPaymentId: 'act_123',
        amountPaise: 8000,
      });
      expect(refund.status).toBe('PROCESSED');
    });

    it('verifies Paystack and Mollie multi-currency payment adapters', async () => {
      const pstkOrder = await paystack.createOrder({
        bookingId: 'book_pstk_01',
        amountPaise: 5000000, // NGN
        currency: 'NGN',
        customerId: 'cust_07',
      });
      expect(pstkOrder.providerOrderId).toContain('pstk_ref_');

      const mollieOrder = await mollie.createOrder({
        bookingId: 'book_mol_01',
        amountPaise: 12000, // EUR
        currency: 'EUR',
        customerId: 'cust_08',
      });
      expect(mollieOrder.providerOrderId).toContain('tr_');
    });
  });

  describe('2. SMS & Communications — Multi-Provider Adapters', () => {
    it('verifies Fast2SMS OTP and transactional dispatch', async () => {
      const res = await fast2sms.sendSms({
        to: '9876543210',
        message: 'Your DriveGo OTP is 456789',
        otpCode: '456789',
      });
      expect(res.success).toBe(true);
      expect(res.status).toBe('SENT');
    });

    it('verifies Textlocal enterprise SMS dispatch', async () => {
      const res = await textlocal.sendSms({
        to: '9876543210',
        message: 'Your trip is confirmed. Drive safely with DriveGo!',
      });
      expect(res.success).toBe(true);
      expect(res.status).toBe('SENT');
    });

    it('verifies Karix telecom gateway dispatch', async () => {
      const res = await karix.sendSms({
        to: '9876543210',
        message: 'Your booking OTP is 112233',
      });
      expect(res.success).toBe(true);
      expect(res.status).toBe('SENT');
    });

    it('verifies Sinch and Vonage global SMS delivery', async () => {
      const sinchRes = await sinch.sendSms({
        to: '+14155552671',
        message: 'Your rental car is ready for pickup.',
      });
      expect(sinchRes.success).toBe(true);
      expect(sinchRes.status).toBe('SENT');

      const vonageRes = await vonage.sendSms({
        to: '14155552672',
        message: 'DriveGo invoice is ready.',
      });
      expect(vonageRes.success).toBe(true);
      expect(vonageRes.status).toBe('SENT');
    });

    it('verifies Infobip and Plivo SMS delivery', async () => {
      const ibRes = await infobip.sendSms({
        to: '9876543210',
        message: 'Rental security deposit released.',
      });
      expect(ibRes.success).toBe(true);
      expect(ibRes.status).toBe('SENT');

      const plivoRes = await plivo.sendSms({
        to: '14155552673',
        message: 'Return inspection passed with 0 damage.',
      });
      expect(plivoRes.success).toBe(true);
      expect(plivoRes.status).toBe('SENT');
    });

    it('verifies Postmark and AWS SES transactional email adapters', async () => {
      const pmRes = await postmark.sendEmail({
        to: 'customer@drivego.in',
        subject: 'DriveGo Booking Confirmation',
        html: '<p>Thank you for choosing DriveGo!</p>',
      });
      expect(pmRes.success).toBe(true);
      expect(pmRes.status).toBe('SENT');

      const sesRes = await awsSes.sendEmail({
        to: 'corporate@acme.com',
        subject: 'Monthly Corporate Billing Statement',
        html: '<h2>Acme Corp Monthly Summary</h2>',
      });
      expect(sesRes.success).toBe(true);
      expect(sesRes.status).toBe('SENT');
    });
  });

  describe('3. Registry Resolution & Discovery', () => {
    it('resolves all newly registered payment and messaging providers dynamically', async () => {
      const cca = await registry.getProvider(IntegrationCategory.PAYMENT, 'ccavenue');
      expect(cca.getDisplayName()).toBe('CCAvenue Multi-Currency Gateway');

      const ptm = await registry.getProvider(IntegrationCategory.PAYMENT, 'paytm_pg');
      expect(ptm.getDisplayName()).toBe('Paytm All-In-One Gateway');

      const bd = await registry.getProvider(IntegrationCategory.PAYMENT, 'billdesk');
      expect(bd.getDisplayName()).toBe('BillDesk Enterprise Gateway');

      const pp = await registry.getProvider(IntegrationCategory.PAYMENT, 'paypal');
      expect(pp.getDisplayName()).toBe('PayPal Global Payments');

      const f2s = await registry.getProvider(IntegrationCategory.MESSAGING_SMS, 'fast2sms');
      expect(f2s.getDisplayName()).toBe('Fast2SMS Gateway');

      const krx = await registry.getProvider(IntegrationCategory.MESSAGING_SMS, 'karix_sms');
      expect(krx.getDisplayName()).toBe('Karix / Tanla Enterprise Telecom SMS');

      const pm = await registry.getProvider(IntegrationCategory.MESSAGING_EMAIL, 'postmark');
      expect(pm.getDisplayName()).toBe('Postmark Transactional Email');

      const ses = await registry.getProvider(IntegrationCategory.MESSAGING_EMAIL, 'amazon_ses');
      expect(ses.getDisplayName()).toBe('Amazon Simple Email Service (SES)');
    });
  });
});

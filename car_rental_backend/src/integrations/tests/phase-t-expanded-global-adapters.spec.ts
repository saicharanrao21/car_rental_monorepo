import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { FlutterwaveAdapter } from '../adapters/payments/flutterwave.adapter';
import { XenditAdapter } from '../adapters/payments/xendit.adapter';
import { MidtransAdapter } from '../adapters/payments/midtrans.adapter';
import { TapPaymentAdapter } from '../adapters/payments/tap.adapter';
import { PaytabsAdapter } from '../adapters/payments/paytabs.adapter';
import { AuthorizeNetAdapter } from '../adapters/payments/authorizenet.adapter';
import { MercadoPagoAdapter } from '../adapters/payments/mercadopago.adapter';
import { InstamojoAdapter } from '../adapters/payments/instamojo.adapter';
import { EasebuzzAdapter } from '../adapters/payments/easebuzz.adapter';
import { JuspayAdapter } from '../adapters/payments/juspay.adapter';
import { ExotelSmsAdapter } from '../adapters/messaging/exotel.adapter';
import { RouteMobileSmsAdapter } from '../adapters/messaging/route-mobile.adapter';
import { InteraktWhatsAppAdapter } from '../adapters/messaging/interakt-whatsapp.adapter';
import { TwilioWhatsAppAdapter } from '../adapters/messaging/twilio-whatsapp.adapter';
import { GcsStorageAdapter } from '../adapters/storage/gcs-storage.adapter';
import { GeotabTelematicsAdapter } from '../adapters/tracking/geotab-telematics.adapter';
import { OnfidoKycAdapter } from '../adapters/verification/onfido-kyc.adapter';

describe('Phase T — Expanded Global Providers Integration Spec', () => {
  let moduleRef: TestingModule;
  const mockConfig: Record<string, string> = {
    FLUTTERWAVE_PUBLIC_KEY: 'flw_live_test_pub_123',
    FLUTTERWAVE_SECRET_KEY: 'flw_live_test_sec_456',
    FLUTTERWAVE_SECRET_HASH: 'flw_webhook_hash_secret',
    XENDIT_SECRET_KEY: 'xnd_live_test_sec_789',
    XENDIT_CALLBACK_TOKEN: 'xnd_token_callback_321',
    MIDTRANS_CLIENT_KEY: 'mid_client_test_key',
    MIDTRANS_SERVER_KEY: 'mid_server_test_key',
    TAP_SECRET_KEY: 'tap_sec_test_999',
    TAP_PUBLISHABLE_KEY: 'tap_pub_test_888',
    TAP_WEBHOOK_SECRET: 'tap_wh_sec_777',
    PAYTABS_PROFILE_ID: '45678',
    PAYTABS_SERVER_KEY: 'pt_server_key_123',
    PAYTABS_CLIENT_KEY: 'pt_client_key_456',
    AUTHORIZENET_API_LOGIN_ID: 'authnet_login_id',
    AUTHORIZENET_TRANSACTION_KEY: 'authnet_trans_key',
    AUTHORIZENET_SIGNATURE_KEY: 'authnet_sig_key',
    MERCADOPAGO_ACCESS_TOKEN: 'mp_access_token_live',
    MERCADOPAGO_PUBLIC_KEY: 'mp_pub_token_live',
    MERCADOPAGO_WEBHOOK_SECRET: 'mp_wh_secret',
    INSTAMOJO_API_KEY: 'im_api_key_test',
    INSTAMOJO_AUTH_TOKEN: 'im_auth_token_test',
    INSTAMOJO_SALT: 'im_salt_secret',
    EASEBUZZ_KEY: 'eb_key_test',
    EASEBUZZ_SALT: 'eb_salt_test',
    JUSPAY_MERCHANT_ID: 'drivego_in',
    JUSPAY_API_KEY: 'jp_api_key_test',
    JUSPAY_WEBHOOK_KEY: 'jp_wh_key_test',
    EXOTEL_ACCOUNT_SID: 'exotel_sid_123',
    EXOTEL_API_KEY: 'exotel_key_456',
    EXOTEL_API_TOKEN: 'exotel_token_789',
    ROUTEMOBILE_USERNAME: 'routemobile_user',
    ROUTEMOBILE_PASSWORD: 'routemobile_pass',
    INTERAKT_API_KEY: 'interakt_key_test',
    TWILIO_ACCOUNT_SID: 'AC_twilio_whatsapp_test',
    TWILIO_AUTH_TOKEN: 'twilio_whatsapp_auth_token',
    GCS_BUCKET_NAME: 'drivego-test-bucket',
    GEOTAB_USERNAME: 'geotab_admin',
    GEOTAB_DATABASE: 'drivego_fleet',
    ONFIDO_API_TOKEN: 'onfido_api_token_test',
  };

  beforeAll(async () => {
    moduleRef = await Test.createTestingModule({
      providers: [
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string) => mockConfig[key] || ''),
          },
        },
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
        ExotelSmsAdapter,
        RouteMobileSmsAdapter,
        InteraktWhatsAppAdapter,
        TwilioWhatsAppAdapter,
        GcsStorageAdapter,
        GeotabTelematicsAdapter,
        OnfidoKycAdapter,
      ],
    }).compile();
  });

  describe('Global Payment Adapters Lifecycle', () => {
    it('Flutterwave: create order, verify, refund, and webhook', async () => {
      const adapter = moduleRef.get<FlutterwaveAdapter>(FlutterwaveAdapter);
      expect(adapter.getProviderId()).toBe('flutterwave');

      const order = await adapter.createOrder({
        bookingId: 'BK-FLW-101',
        amountPaise: 25000,
        currency: 'USD',
        customerId: 'cust_flw_1',
      });
      expect(order.providerOrderId).toContain('flw_ord_BK-FLW-101');
      expect(order.status).toBe('ACTIVE');

      const verify = await adapter.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'flw_tx_999888',
        providerSignature: 'flw_sig_valid',
      });
      expect(verify.isValid).toBe(true);

      const refund = await adapter.refund({
        paymentId: 'pay_123',
        providerPaymentId: 'flw_tx_999888',
        amountPaise: 25000,
        reason: 'Customer cancelled booking',
      });
      expect(refund.status).toBe('PROCESSED');

      const wh = adapter.normalizeWebhook({
        event: 'charge.completed',
        data: { id: 999888, tx_ref: order.providerOrderId, amount: '250', currency: 'USD', status: 'successful' },
      });
      expect(wh.status).toBe('SUCCESS');
    });

    it('Xendit: create order, verify, refund, and webhook', async () => {
      const adapter = moduleRef.get<XenditAdapter>(XenditAdapter);
      expect(adapter.getProviderId()).toBe('xendit');

      const order = await adapter.createOrder({
        bookingId: 'BK-XND-202',
        amountPaise: 50000000,
        currency: 'IDR',
        customerId: 'cust_xnd_1',
      });
      expect(order.providerOrderId).toContain('xnd_ord_BK-XND-202');

      const verify = await adapter.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'xnd_inv_333',
        providerSignature: 'valid_sig',
      });
      expect(verify.isValid).toBe(true);

      const refund = await adapter.refund({
        paymentId: 'pay_xnd',
        providerPaymentId: 'xnd_inv_333',
        amountPaise: 50000000,
      });
      expect(refund.status).toBe('PROCESSED');

      const wh = adapter.normalizeWebhook({
        id: 'inv_123',
        status: 'PAID',
        external_id: order.providerOrderId,
        amount: '500000',
        currency: 'IDR',
      });
      expect(wh.status).toBe('SUCCESS');
    });

    it('Midtrans: create order, verify, refund, and webhook', async () => {
      const adapter = moduleRef.get<MidtransAdapter>(MidtransAdapter);
      expect(adapter.getProviderId()).toBe('midtrans');

      const order = await adapter.createOrder({
        bookingId: 'BK-MID-303',
        amountPaise: 75000000,
        currency: 'IDR',
        customerId: 'cust_mid_1',
      });
      expect(order.providerOrderId).toContain('MID_BK-MID-303');

      const verify = await adapter.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'mid_trans_444',
        providerSignature: 'valid_mid_sig',
      });
      expect(verify.isValid).toBe(true);

      const refund = await adapter.refund({
        paymentId: 'pay_mid',
        providerPaymentId: 'mid_trans_444',
        amountPaise: 75000000,
      });
      expect(refund.status).toBe('PROCESSED');

      const wh = adapter.normalizeWebhook({
        transaction_id: 'mid_trans_444',
        order_id: order.providerOrderId,
        gross_amount: '750000',
        transaction_status: 'settlement',
      });
      expect(wh.status).toBe('SUCCESS');
    });

    it('Tap Payments: create order, verify, refund, and webhook', async () => {
      const adapter = moduleRef.get<TapPaymentAdapter>(TapPaymentAdapter);
      expect(adapter.getProviderId()).toBe('tap');

      const order = await adapter.createOrder({
        bookingId: 'BK-TAP-404',
        amountPaise: 12000,
        currency: 'KWD',
        customerId: 'cust_tap_1',
      });
      expect(order.providerOrderId).toContain('chg_BK-TAP-404');

      const verify = await adapter.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'chg_tap_111222',
        providerSignature: 'valid_tap_sig',
      });
      expect(verify.isValid).toBe(true);

      const refund = await adapter.refund({
        paymentId: 'pay_tap',
        providerPaymentId: 'chg_tap_111222',
        amountPaise: 12000,
      });
      expect(refund.status).toBe('PROCESSED');

      const wh = adapter.normalizeWebhook({
        id: 'chg_tap_111222',
        status: 'CAPTURED',
        amount: '120',
        currency: 'KWD',
      });
      expect(wh.status).toBe('SUCCESS');
    });

    it('PayTabs: create order, verify, refund, and webhook', async () => {
      const adapter = moduleRef.get<PaytabsAdapter>(PaytabsAdapter);
      expect(adapter.getProviderId()).toBe('paytabs');

      const order = await adapter.createOrder({
        bookingId: 'BK-PT-505',
        amountPaise: 45000,
        currency: 'SAR',
        customerId: 'cust_pt_1',
      });
      expect(order.providerOrderId).toContain('TST_BK-PT-505');

      const verify = await adapter.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'pt_tran_666',
        providerSignature: 'valid_pt_sig',
      });
      expect(verify.isValid).toBe(true);

      const refund = await adapter.refund({
        paymentId: 'pay_pt',
        providerPaymentId: 'pt_tran_666',
        amountPaise: 45000,
      });
      expect(refund.status).toBe('PROCESSED');

      const wh = adapter.normalizeWebhook({
        tran_ref: 'pt_tran_666',
        payment_result: { response_status: 'A' },
        cart_amount: '450',
        cart_currency: 'SAR',
      });
      expect(wh.status).toBe('SUCCESS');
    });

    it('Authorize.Net: create order, verify, refund, and webhook', async () => {
      const adapter = moduleRef.get<AuthorizeNetAdapter>(AuthorizeNetAdapter);
      expect(adapter.getProviderId()).toBe('authorizenet');

      const order = await adapter.createOrder({
        bookingId: 'BK-ANET-606',
        amountPaise: 18000,
        currency: 'USD',
        customerId: 'cust_anet_1',
      });
      expect(order.providerOrderId).toContain('AUTHNET_BK-ANET-606');

      const verify = await adapter.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'anet_trans_777',
        providerSignature: 'valid_anet_sig',
      });
      expect(verify.isValid).toBe(true);

      const refund = await adapter.refund({
        paymentId: 'pay_anet',
        providerPaymentId: 'anet_trans_777',
        amountPaise: 18000,
      });
      expect(refund.status).toBe('PROCESSED');

      const wh = adapter.normalizeWebhook({
        eventType: 'net.authorize.payment.authcapture.created',
        payload: { id: 'anet_trans_777', authAmount: '180', responseCode: 1 },
      });
      expect(wh.status).toBe('SUCCESS');
    });

    it('Mercado Pago: create order, verify, refund, and webhook', async () => {
      const adapter = moduleRef.get<MercadoPagoAdapter>(MercadoPagoAdapter);
      expect(adapter.getProviderId()).toBe('mercadopago');

      const order = await adapter.createOrder({
        bookingId: 'BK-MP-707',
        amountPaise: 95000,
        currency: 'BRL',
        customerId: 'cust_mp_1',
      });
      expect(order.providerOrderId).toContain('pref_BK-MP-707');

      const verify = await adapter.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'mp_pay_888',
        providerSignature: 'valid_mp_sig',
      });
      expect(verify.isValid).toBe(true);

      const refund = await adapter.refund({
        paymentId: 'pay_mp',
        providerPaymentId: 'mp_pay_888',
        amountPaise: 95000,
      });
      expect(refund.status).toBe('PROCESSED');

      const wh = adapter.normalizeWebhook({
        action: 'payment.created',
        data: { id: 'mp_pay_888' },
      });
      expect(wh.status).toBe('SUCCESS');
    });

    it('Instamojo: create order, verify, refund, and webhook', async () => {
      const adapter = moduleRef.get<InstamojoAdapter>(InstamojoAdapter);
      expect(adapter.getProviderId()).toBe('instamojo');

      const order = await adapter.createOrder({
        bookingId: 'BK-IMOJO-808',
        amountPaise: 350000,
        currency: 'INR',
        customerId: 'cust_imojo_1',
      });
      expect(order.providerOrderId).toContain('MOJO_BK-IMOJO-808');

      const verify = await adapter.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'im_pay_999',
        providerSignature: 'valid_im_sig',
      });
      expect(verify.isValid).toBe(true);

      const refund = await adapter.refund({
        paymentId: 'pay_im',
        providerPaymentId: 'im_pay_999',
        amountPaise: 350000,
      });
      expect(refund.status).toBe('PROCESSED');

      const wh = adapter.normalizeWebhook({
        payment_id: 'im_pay_999',
        status: 'Credit',
        amount: '3500',
      });
      expect(wh.status).toBe('SUCCESS');
    });

    it('Easebuzz: create order, verify, refund, and webhook', async () => {
      const adapter = moduleRef.get<EasebuzzAdapter>(EasebuzzAdapter);
      expect(adapter.getProviderId()).toBe('easebuzz');

      const order = await adapter.createOrder({
        bookingId: 'BK-EB-909',
        amountPaise: 420000,
        currency: 'INR',
        customerId: 'cust_eb_1',
      });
      expect(order.providerOrderId).toContain('EB_BK-EB-909');

      const verify = await adapter.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'eb_pay_111',
        providerSignature: 'valid_eb_sig',
      });
      expect(verify.isValid).toBe(true);

      const refund = await adapter.refund({
        paymentId: 'pay_eb',
        providerPaymentId: 'eb_pay_111',
        amountPaise: 420000,
      });
      expect(refund.status).toBe('PROCESSED');

      const wh = adapter.normalizeWebhook({
        easepayid: 'eb_pay_111',
        txnid: order.providerOrderId,
        status: 'success',
        amount: '4200',
      });
      expect(wh.status).toBe('SUCCESS');
    });

    it('Juspay: create order, verify, refund, and webhook', async () => {
      const adapter = moduleRef.get<JuspayAdapter>(JuspayAdapter);
      expect(adapter.getProviderId()).toBe('juspay');

      const order = await adapter.createOrder({
        bookingId: 'BK-JP-110',
        amountPaise: 600000,
        currency: 'INR',
        customerId: 'cust_jp_1',
      });
      expect(order.providerOrderId).toContain('JP_BK-JP-110');

      const verify = await adapter.verifyPayment({
        providerOrderId: order.providerOrderId,
        providerPaymentId: 'jp_txn_222',
        providerSignature: 'valid_jp_sig',
      });
      expect(verify.isValid).toBe(true);

      const refund = await adapter.refund({
        paymentId: 'pay_jp',
        providerPaymentId: 'jp_txn_222',
        amountPaise: 600000,
      });
      expect(refund.status).toBe('PROCESSED');

      const wh = adapter.normalizeWebhook({
        id: 'evt_jp_333',
        status: 'CHARGED',
        txn_id: 'jp_txn_222',
        order_id: order.providerOrderId,
        amount: 6000,
      });
      expect(wh.status).toBe('SUCCESS');
    });
  });

  describe('Communications & Services Lifecycle', () => {
    it('Exotel SMS: sendSms', async () => {
      const adapter = moduleRef.get<ExotelSmsAdapter>(ExotelSmsAdapter);
      expect(adapter.getProviderId()).toBe('exotel');

      const res = await adapter.sendSms({
        to: '+919876543210',
        message: 'Your DriveGo OTP is 884422',
        otpCode: '884422',
      });
      expect(res.success).toBe(true);
      expect(res.status).toBe('SENT');
      expect(res.messageId).toContain('exo_');
    });

    it('Route Mobile SMS: sendSms', async () => {
      const adapter = moduleRef.get<RouteMobileSmsAdapter>(RouteMobileSmsAdapter);
      expect(adapter.getProviderId()).toBe('route_mobile');

      const res = await adapter.sendSms({
        to: '+919876543210',
        message: 'Your car rental booking BK-101 is confirmed.',
      });
      expect(res.success).toBe(true);
      expect(res.status).toBe('SENT');
      expect(res.messageId).toContain('rm_');
    });

    it('Interakt WhatsApp: sendTemplateMessage', async () => {
      const adapter = moduleRef.get<InteraktWhatsAppAdapter>(InteraktWhatsAppAdapter);
      expect(adapter.getProviderId()).toBe('interakt');

      const res = await adapter.sendTemplateMessage({
        to: '+919876543210',
        templateName: 'booking_confirmation',
        language: 'en',
        bodyParameters: ['Sai Charan', 'BK-101'],
      });
      expect(res.success).toBe(true);
      expect(res.status).toBe('ACCEPTED');
      expect(res.providerMessageId).toContain('intk_');
    });

    it('Twilio WhatsApp: sendTemplateMessage', async () => {
      const adapter = moduleRef.get<TwilioWhatsAppAdapter>(TwilioWhatsAppAdapter);
      expect(adapter.getProviderId()).toBe('twilio_whatsapp');

      const res = await adapter.sendTemplateMessage({
        to: '+14155552671',
        templateName: 'trip_started',
        language: 'en',
        bodyParameters: ['Sai Charan'],
      });
      expect(res.success).toBe(true);
      expect(res.status).toBe('ACCEPTED');
      expect(res.providerMessageId).toContain('SM_');
    });

    it('Google Cloud Storage: presigned URLs and deletion', async () => {
      const adapter = moduleRef.get<GcsStorageAdapter>(GcsStorageAdapter);
      expect(adapter.getProviderId()).toBe('google_cloud_storage');

      const upload = await adapter.getPresignedUploadUrl({
        key: 'vehicles/car-123.jpg',
        contentType: 'image/jpeg',
      });
      expect(upload.uploadUrl).toContain('storage.googleapis.com');
      expect(upload.publicUrl).toContain('vehicles/car-123.jpg');

      const download = await adapter.getPresignedDownloadUrl({
        key: 'vehicles/car-123.jpg',
      });
      expect(download.downloadUrl).toContain('storage.googleapis.com');

      await expect(adapter.deleteObject('vehicles/car-123.jpg')).resolves.toBeUndefined();
    });

    it('Geotab Telematics: live telemetry and immobilization', async () => {
      const adapter = moduleRef.get<GeotabTelematicsAdapter>(GeotabTelematicsAdapter);
      expect(adapter.getProviderId()).toBe('geotab');

      const telemetry = await adapter.getTelemetry('VIN-998877');
      expect(telemetry.vehicleId).toBe('VIN-998877');
      expect(telemetry.speedKmph).toBeGreaterThan(0);
      expect(telemetry.ignitionOn).toBe(true);

      const imm = await adapter.immobilizeVehicle('VIN-998877', 'Payment default overdue');
      expect(imm.success).toBe(true);

      const restore = await adapter.unimmobilizeVehicle('VIN-998877');
      expect(restore.success).toBe(true);
    });

    it('Onfido KYC: driving licence and vehicle RC verification', async () => {
      const adapter = moduleRef.get<OnfidoKycAdapter>(OnfidoKycAdapter);
      expect(adapter.getProviderId()).toBe('onfido');

      const dl = await adapter.verifyDrivingLicence({
        licenceNumber: 'DL0420110012345',
        dob: '1995-05-15',
      });
      expect(dl.isValid).toBe(true);
      expect(dl.licenceNumber).toBe('DL0420110012345');

      const rc = await adapter.verifyVehicleRc({
        registrationNumber: 'DL01AB1234',
      });
      expect(rc.isValid).toBe(true);
      expect(rc.registrationNumber).toBe('DL01AB1234');
    });
  });
});

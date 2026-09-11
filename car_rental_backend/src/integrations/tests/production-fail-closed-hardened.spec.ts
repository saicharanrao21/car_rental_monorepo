import { ConfigService } from '@nestjs/config';
import { MockWhatsAppProvider } from '../../whatsapp/whatsapp-provider.service';
import { MockSmsProvider as NotificationMockSmsProvider, TwilioSmsProvider } from '../../notifications/providers/sms-provider.service';
import { MockEmailProvider, SmtpEmailProvider } from '../../notifications/providers/email-provider.service';
import { MockSmsProvider as AuthMockSmsProvider } from '../../auth/sms-provider.service';
import { MockStorageAdapter } from '../adapters/storage/mock-storage.adapter';
import { MockAccountingAdapter } from '../adapters/accounting/mock-accounting.adapter';

describe('Production Fail-Closed Hardened Guards', () => {
  const originalEnv = process.env.NODE_ENV;

  afterEach(() => {
    process.env.NODE_ENV = originalEnv;
  });

  it('should throw critical security error when MockWhatsAppProvider is invoked in production', async () => {
    process.env.NODE_ENV = 'production';
    const provider = new MockWhatsAppProvider();
    await expect(
      provider.sendMessage('+919876543210', 'test_template', 'en', ['val1']),
    ).rejects.toThrow(/MockWhatsAppProvider cannot be used in production/);
  });

  it('should throw critical security error when Notification MockSmsProvider is invoked in production', async () => {
    process.env.NODE_ENV = 'production';
    const provider = new NotificationMockSmsProvider();
    await expect(
      provider.sendSms('+919876543210', 'Test message'),
    ).rejects.toThrow(/MockSmsProvider cannot be used in production/);
  });

  it('should throw critical security error when TwilioSmsProvider is missing credentials in production', async () => {
    process.env.NODE_ENV = 'production';
    const configService = new ConfigService();
    const provider = new TwilioSmsProvider(configService);
    await expect(
      provider.sendSms('+919876543210', 'Test message'),
    ).rejects.toThrow(/Twilio SMS credentials missing in production/);
  });

  it('should throw critical security error when MockEmailProvider is invoked in production', async () => {
    process.env.NODE_ENV = 'production';
    const provider = new MockEmailProvider();
    await expect(
      provider.sendEmail('test@drivego.in', 'Test', '<p>Test</p>'),
    ).rejects.toThrow(/MockEmailProvider cannot be used in production/);
  });

  it('should throw critical security error when SmtpEmailProvider is missing credentials in production', async () => {
    process.env.NODE_ENV = 'production';
    const configService = new ConfigService();
    const provider = new SmtpEmailProvider(configService);
    await expect(
      provider.sendEmail('test@drivego.in', 'Test', '<p>Test</p>'),
    ).rejects.toThrow(/Email provider API key missing in production/);
  });

  it('should throw critical security error when Auth MockSmsProvider is invoked in production', async () => {
    process.env.NODE_ENV = 'production';
    const provider = new AuthMockSmsProvider();
    await expect(
      provider.sendSms('+919876543210', 'Test OTP', '123456'),
    ).rejects.toThrow(/MockSmsProvider cannot be used in production/);
  });

  it('should throw critical security error when MockStorageAdapter is invoked in production', async () => {
    process.env.NODE_ENV = 'production';
    const adapter = new MockStorageAdapter();
    await expect(
      adapter.getPresignedUploadUrl({
        key: 'docs/test.pdf',
        contentType: 'application/pdf',
        expiresInSeconds: 300,
      }),
    ).rejects.toThrow(/MockStorageAdapter cannot be used in production/);

    await expect(
      adapter.getPresignedDownloadUrl({
        key: 'docs/test.pdf',
        expiresInSeconds: 300,
      }),
    ).rejects.toThrow(/MockStorageAdapter cannot be used in production/);

    await expect(adapter.deleteObject('docs/test.pdf')).rejects.toThrow(
      /MockStorageAdapter cannot be used in production/,
    );

    expect(() => adapter.getPublicUrl('docs/test.pdf')).toThrow(
      /MockStorageAdapter cannot be used in production/,
    );
  });

  it('should throw critical security error when MockAccountingAdapter is invoked in production', async () => {
    process.env.NODE_ENV = 'production';
    const adapter = new MockAccountingAdapter();
    await expect(
      adapter.syncInvoice({
        invoiceNumber: 'INV-001',
        customerName: 'Customer',
        customerEmail: 'cust@test.com',
        amount: 5000,
        currency: 'INR',
        issuedAt: new Date(),
        dueAt: new Date(),
        lineItems: [],
      }),
    ).rejects.toThrow(/MockAccountingAdapter cannot be used in production/);

    await expect(
      adapter.syncPayout({
        payoutId: 'PO-001',
        vendorName: 'Vendor',
        vendorEmail: 'vendor@test.com',
        amount: 4000,
        currency: 'INR',
        initiatedAt: new Date(),
        destinationAccount: 'ACC123',
      }),
    ).rejects.toThrow(/MockAccountingAdapter cannot be used in production/);
  });
});

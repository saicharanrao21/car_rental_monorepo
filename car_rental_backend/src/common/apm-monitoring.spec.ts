import { ApmMonitoringService } from './apm-monitoring.service';
import { ConfigService } from '@nestjs/config';
import * as Sentry from '@sentry/node';

jest.mock('@sentry/node', () => ({
  init: jest.fn(),
  captureException: jest.fn(),
  captureMessage: jest.fn(),
  withScope: jest.fn((cb) => {
    const scopeMock = {
      setLevel: jest.fn(),
      setTag: jest.fn(),
      setContext: jest.fn(),
      setUser: jest.fn(),
    };
    cb(scopeMock);
  }),
}));

describe('ApmMonitoringService — Production Hardening', () => {
  let service: ApmMonitoringService;
  let configService: ConfigService;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('1. Safe Initialization without SENTRY_DSN', () => {
    it('disables error monitoring safely when SENTRY_DSN is absent', () => {
      configService = new ConfigService({
        NODE_ENV: 'development',
      });
      service = new ApmMonitoringService(configService);
      service.onModuleInit();

      expect(service.getIsEnabled()).toBe(false);
      expect(Sentry.init).not.toHaveBeenCalled();
    });

    it('does not throw when captureException or captureFinancialInconsistency is called in offline mode', () => {
      configService = new ConfigService({});
      service = new ApmMonitoringService(configService);
      service.onModuleInit();

      expect(() => {
        service.captureException(new Error('Test error'));
        service.captureFinancialInconsistency('Discrepancy title', {
          bookingId: 'book_1',
          paymentId: 'pay_1',
          correlationId: 'req_trace_123',
        });
      }).not.toThrow();

      expect(Sentry.captureMessage).not.toHaveBeenCalled();
    });
  });

  describe('2. Initialization with SENTRY_DSN', () => {
    it('initializes Sentry when SENTRY_DSN is provided', () => {
      configService = new ConfigService({
        SENTRY_DSN: 'https://public@sentry.io/123456',
        SENTRY_ENVIRONMENT: 'staging',
        SENTRY_RELEASE: 'drivego@1.0.0',
      });
      service = new ApmMonitoringService(configService);
      service.onModuleInit();

      expect(service.getIsEnabled()).toBe(true);
      expect(Sentry.init).toHaveBeenCalledWith(
        expect.objectContaining({
          dsn: 'https://public@sentry.io/123456',
          environment: 'staging',
          release: 'drivego@1.0.0',
        }),
      );
    });
  });

  describe('3. Sensitive Value Scrubbing', () => {
    beforeEach(() => {
      configService = new ConfigService({
        SENTRY_DSN: 'https://public@sentry.io/123456',
      });
      service = new ApmMonitoringService(configService);
      service.onModuleInit();
    });

    it('redacts sensitive keys in objects (passwords, tokens, OTPs, bankDetails, secrets)', () => {
      const input = {
        userId: 'usr_123',
        password: 'SuperSecretPassword!',
        token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
        otp: '123456',
        bankDetails: {
          accountNumber: '123456789012',
          ifsc: 'HDFC0001234',
        },
        safeData: 'normal-data',
      };

      const sanitized = service.sanitizeObject(input);

      expect(sanitized.password).toBe('[REDACTED]');
      expect(sanitized.token).toBe('[REDACTED]');
      expect(sanitized.otp).toBe('[REDACTED]');
      expect(sanitized.bankDetails).toBe('[REDACTED]');
      expect(sanitized.safeData).toBe('normal-data');
      expect(sanitized.userId).toBe('usr_123');
    });

    it('redacts sensitive values matching regex patterns in strings', () => {
      const inputString =
        'Authorization Bearer secret.jwt.token failed for password "myPass123" and otp "654321"';
      const sanitized = service.sanitizeString(inputString);

      expect(sanitized).not.toContain('secret.jwt.token');
      expect(sanitized).not.toContain('myPass123');
      expect(sanitized).not.toContain('654321');
      expect(sanitized).toContain('[REDACTED]');
    });

    it('strips authorization and razorpay signature headers from Sentry events', () => {
      const event: any = {
        request: {
          headers: {
            'x-request-id': 'req-123',
            authorization: 'Bearer secret_token',
            'x-razorpay-signature': 'sig_secret_123',
            cookie: 'session=123',
          },
        },
      };

      const sanitizedEvent = service.sanitizeSentryEvent(event);

      expect(sanitizedEvent.request.headers['authorization']).toBeUndefined();
      expect(sanitizedEvent.request.headers['x-razorpay-signature']).toBeUndefined();
      expect(sanitizedEvent.request.headers['cookie']).toBeUndefined();
      expect(sanitizedEvent.request.headers['x-request-id']).toBe('req-123');
    });
  });

  describe('4. Financial Inconsistency Event Capture with Correlation ID', () => {
    beforeEach(() => {
      configService = new ConfigService({
        SENTRY_DSN: 'https://public@sentry.io/123456',
      });
      service = new ApmMonitoringService(configService);
      service.onModuleInit();
    });

    it('captures financial discrepancy with correlationId, bookingId, paymentId tags and sanitized context', () => {
      service.captureFinancialInconsistency(
        'RECONCILIATION_INCONSISTENCY: Cancelled booking with Paid payment without refund',
        {
          bookingId: 'book_inconsistent_99',
          paymentId: 'pay_inconsistent_99',
          razorpayPaymentId: 'pay_gateway_99',
          expectedAmount: 3500.0,
          actualAmount: 0,
          correlationId: 'trace-uuid-1234-abcd',
          severity: 'fatal',
          extra: {
            password: 'doNotInclude',
            bookingStatus: 'CANCELLED',
          },
        },
      );

      expect(Sentry.captureMessage).toHaveBeenCalledWith(
        expect.stringContaining('[FINANCIAL_ALERT] RECONCILIATION_INCONSISTENCY'),
      );
    });
  });
});

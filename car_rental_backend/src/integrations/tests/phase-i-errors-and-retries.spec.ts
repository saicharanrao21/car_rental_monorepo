import { ErrorNormalizer } from '../errors/error-normalizer.util';
import { RetryPolicyService } from '../errors/retry-policy.service';
import { IntegrationCategory } from '../registry/provider.types';
import {
  ProviderTimeoutError,
  TransientNetworkError,
  RateLimitExceededError,
  AuthenticationError,
  MalformedResponseError,
  PermanentError,
} from '../errors/integration-error';

describe('Phase I — Error Normalization & Safe Retry Infrastructure', () => {
  const retryPolicy = new RetryPolicyService();

  describe('ErrorNormalizer', () => {
    it('should map timeout/abort errors to ProviderTimeoutError (isTransient: true, isRetryable: true)', () => {
      const abortErr = new Error('The user aborted a request.');
      abortErr.name = 'AbortError';

      const normalized = ErrorNormalizer.normalize(
        abortErr,
        'razorpay',
        IntegrationCategory.PAYMENT,
        8000,
      );

      expect(normalized).toBeInstanceOf(ProviderTimeoutError);
      expect(normalized.isTransient).toBe(true);
      expect(normalized.isRetryable).toBe(true);
      expect(normalized.details?.timeoutMs).toBe(8000);
    });

    it('should map HTTP 401 and 403 to AuthenticationError (isTransient: false, isRetryable: false)', () => {
      const authErr = {
        status: 401,
        message: 'Invalid API key provided',
      };

      const normalized = ErrorNormalizer.normalize(
        authErr,
        'meta',
        IntegrationCategory.MESSAGING_WHATSAPP,
      );

      expect(normalized).toBeInstanceOf(AuthenticationError);
      expect(normalized.isTransient).toBe(false);
      expect(normalized.isRetryable).toBe(false);
    });

    it('should map HTTP 429 to RateLimitExceededError with retryAfterMs (isTransient: true, isRetryable: true)', () => {
      const rateErr = {
        status: 429,
        message: 'Too many requests',
        response: { headers: { 'retry-after': '3' } },
      };

      const normalized = ErrorNormalizer.normalize(
        rateErr,
        'msg91',
        IntegrationCategory.MESSAGING_SMS,
      );

      expect(normalized).toBeInstanceOf(RateLimitExceededError);
      expect(normalized.isTransient).toBe(true);
      expect(normalized.isRetryable).toBe(true);
      expect((normalized as RateLimitExceededError).retryAfterMs).toBe(3000);
    });

    it('should map HTTP 500-599 to TransientNetworkError (isTransient: true, isRetryable: true)', () => {
      const serverErr = {
        status: 503,
        message: 'Service Unavailable',
      };

      const normalized = ErrorNormalizer.normalize(
        serverErr,
        'resend',
        IntegrationCategory.MESSAGING_EMAIL,
      );

      expect(normalized).toBeInstanceOf(TransientNetworkError);
      expect(normalized.isTransient).toBe(true);
      expect(normalized.isRetryable).toBe(true);
    });

    it('should map socket/network errors to TransientNetworkError', () => {
      const netErr = new Error('connect ECONNREFUSED 127.0.0.1:443');
      const normalized = ErrorNormalizer.normalize(
        netErr,
        'google',
        IntegrationCategory.MAPS,
      );

      expect(normalized).toBeInstanceOf(TransientNetworkError);
      expect(normalized.isTransient).toBe(true);
    });

    it('should map JSON parse error to MalformedResponseError (isTransient: false, isRetryable: false)', () => {
      const parseErr = new SyntaxError('Unexpected token < in JSON at position 0');
      const normalized = ErrorNormalizer.normalize(
        parseErr,
        'surepass',
        IntegrationCategory.IDENTITY_VERIFICATION,
      );

      expect(normalized).toBeInstanceOf(MalformedResponseError);
      expect(normalized.isTransient).toBe(false);
      expect(normalized.isRetryable).toBe(false);
    });
  });

  describe('RetryPolicyService — Idempotent Safety Invariants', () => {
    it('should retry transient errors for IDEMPOTENT operations up to maxRetries', async () => {
      let attempts = 0;
      const operation = jest.fn().mockImplementation((attempt: number) => {
        attempts++;
        if (attempt < 3) {
          throw new TransientNetworkError('razorpay', IntegrationCategory.PAYMENT, 'Socket dropped');
        }
        return Promise.resolve({ success: true, attempts });
      });

      const result = await retryPolicy.executeWithRetry(operation, {
        isIdempotent: true, // IDEMPOTENT: Safe to retry
        maxRetries: 3,
        initialDelayMs: 10,
        maxDelayMs: 50,
      });

      expect(result.success).toBe(true);
      expect(attempts).toBe(3);
    });

    it('CRITICAL: Should NEVER retry NON-IDEMPOTENT operations even on transient errors', async () => {
      let attempts = 0;
      const operation = jest.fn().mockImplementation(() => {
        attempts++;
        throw new TransientNetworkError(
          'razorpay',
          IntegrationCategory.PAYMENT,
          'Connection reset during charge',
        );
      });

      // NON-IDEMPOTENT: e.g. charging card or dispatching non-idempotent SMS
      await expect(
        retryPolicy.executeWithRetry(operation, {
          isIdempotent: false, // NOT IDEMPOTENT
          maxRetries: 3,
          initialDelayMs: 10,
        }),
      ).rejects.toThrow(TransientNetworkError);

      // Must have failed on the very FIRST attempt without retrying!
      expect(attempts).toBe(1);
    });

    it('should NOT retry PERMANENT errors even if operation is marked idempotent', async () => {
      let attempts = 0;
      const operation = jest.fn().mockImplementation(() => {
        attempts++;
        throw new AuthenticationError('stripe', IntegrationCategory.PAYMENT, 'Invalid API Key');
      });

      await expect(
        retryPolicy.executeWithRetry(operation, {
          isIdempotent: true,
          maxRetries: 3,
          initialDelayMs: 10,
        }),
      ).rejects.toThrow(AuthenticationError);

      expect(attempts).toBe(1);
    });
  });
});

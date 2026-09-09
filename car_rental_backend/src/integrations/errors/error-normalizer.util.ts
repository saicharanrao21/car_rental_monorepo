import { IntegrationCategory } from '../registry/provider.types';
import {
  IntegrationError,
  ProviderTimeoutError,
  TransientNetworkError,
  RateLimitExceededError,
  AuthenticationError,
  MalformedResponseError,
  PermanentError,
} from './integration-error';

export class ErrorNormalizer {
  /**
   * Normalizes any raw error thrown during third-party provider calls into a typed IntegrationError.
   */
  static normalize(
    err: any,
    providerId: string,
    category: IntegrationCategory,
    timeoutMs = 10000,
  ): IntegrationError {
    if (err instanceof IntegrationError) {
      return err;
    }

    const message = err?.message || String(err);
    const status = err?.status || err?.statusCode || err?.response?.status;

    // 1. Timeout detection
    if (
      err?.name === 'AbortError' ||
      err?.name === 'TimeoutError' ||
      message.toLowerCase().includes('timeout') ||
      message.toLowerCase().includes('timed out')
    ) {
      return new ProviderTimeoutError(providerId, category, timeoutMs, err);
    }

    // 2. HTTP Status Code Mappings
    if (status) {
      if (status === 401 || status === 403) {
        return new AuthenticationError(
          providerId,
          category,
          `Provider rejected credentials with HTTP ${status}: ${message}`,
          err,
        );
      }

      if (status === 429) {
        const retryAfterHeader = err?.response?.headers?.['retry-after'];
        const retryAfterMs = retryAfterHeader
          ? parseInt(retryAfterHeader, 10) * 1000
          : 5000;
        return new RateLimitExceededError(
          providerId,
          category,
          retryAfterMs,
          err,
        );
      }

      if (status >= 500 && status <= 599) {
        return new TransientNetworkError(
          providerId,
          category,
          `Provider server error (HTTP ${status}): ${message}`,
          err,
        );
      }

      if (status === 400 || status === 422) {
        return new PermanentError(
          providerId,
          category,
          `Provider client validation error (HTTP ${status}): ${message}`,
          err,
          { status, responseData: err?.response?.data },
        );
      }
    }

    // 3. Network connection errors
    if (
      message.includes('ECONNREFUSED') ||
      message.includes('ECONNRESET') ||
      message.includes('ETIMEDOUT') ||
      message.includes('EAI_AGAIN') ||
      message.includes('fetch failed') ||
      message.includes('network')
    ) {
      return new TransientNetworkError(
        providerId,
        category,
        `Network failure communicating with ${providerId}: ${message}`,
        err,
      );
    }

    // 4. JSON parsing / malformed response
    if (
      err instanceof SyntaxError &&
      message.toLowerCase().includes('json')
    ) {
      return new MalformedResponseError(
        providerId,
        category,
        `Failed to parse JSON response from provider: ${message}`,
        err,
      );
    }

    // Default to PermanentError
    return new PermanentError(
      providerId,
      category,
      `Provider operation failed: ${message}`,
      err,
    );
  }
}

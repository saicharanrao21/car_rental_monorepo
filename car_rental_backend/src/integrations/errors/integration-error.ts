import { IntegrationCategory } from '../registry/provider.types';

export abstract class IntegrationError extends Error {
  public abstract readonly isTransient: boolean;
  public abstract readonly isRetryable: boolean;

  constructor(
    message: string,
    public readonly providerId: string,
    public readonly category: IntegrationCategory,
    public readonly originalError?: any,
    public readonly details?: Record<string, any>,
  ) {
    super(message);
    this.name = this.constructor.name;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export class ProviderTimeoutError extends IntegrationError {
  public readonly isTransient = true;
  public readonly isRetryable = true;

  constructor(
    providerId: string,
    category: IntegrationCategory,
    timeoutMs: number,
    originalError?: any,
  ) {
    super(
      `Integration provider [${providerId}] for [${category}] timed out after ${timeoutMs}ms`,
      providerId,
      category,
      originalError,
      { timeoutMs },
    );
  }
}

export class TransientNetworkError extends IntegrationError {
  public readonly isTransient = true;
  public readonly isRetryable = true;

  constructor(
    providerId: string,
    category: IntegrationCategory,
    message = 'Transient network failure connecting to provider',
    originalError?: any,
  ) {
    super(message, providerId, category, originalError);
  }
}

export class RateLimitExceededError extends IntegrationError {
  public readonly isTransient = true;
  public readonly isRetryable = true;

  constructor(
    providerId: string,
    category: IntegrationCategory,
    public readonly retryAfterMs?: number,
    originalError?: any,
  ) {
    super(
      `Rate limit exceeded for provider [${providerId}] (${category}). Retry after ${retryAfterMs ?? 'unknown'}ms`,
      providerId,
      category,
      originalError,
      { retryAfterMs },
    );
  }
}

export class AuthenticationError extends IntegrationError {
  public readonly isTransient = false;
  public readonly isRetryable = false;

  constructor(
    providerId: string,
    category: IntegrationCategory,
    message = 'Authentication failed with third-party provider. Check API keys/credentials.',
    originalError?: any,
  ) {
    super(message, providerId, category, originalError);
  }
}

export class PermanentError extends IntegrationError {
  public readonly isTransient = false;
  public readonly isRetryable = false;

  constructor(
    providerId: string,
    category: IntegrationCategory,
    message: string,
    originalError?: any,
    details?: Record<string, any>,
  ) {
    super(message, providerId, category, originalError, details);
  }
}

export class MalformedResponseError extends IntegrationError {
  public readonly isTransient = false;
  public readonly isRetryable = false;

  constructor(
    providerId: string,
    category: IntegrationCategory,
    message = 'Malformed or unexpected response structure received from provider',
    originalError?: any,
  ) {
    super(message, providerId, category, originalError);
  }
}

export class DuplicateRequestError extends IntegrationError {
  public readonly isTransient = false;
  public readonly isRetryable = false;
  public readonly isDuplicate = true;

  constructor(
    providerId: string,
    category: IntegrationCategory,
    idempotencyKey: string,
    originalError?: any,
  ) {
    super(
      `Duplicate request detected for provider [${providerId}] with idempotencyKey: ${idempotencyKey}`,
      providerId,
      category,
      originalError,
      { idempotencyKey },
    );
  }
}

export class WebhookVerificationError extends IntegrationError {
  public readonly isTransient = false;
  public readonly isRetryable = false;

  constructor(
    providerId: string,
    category: IntegrationCategory,
    message = 'Webhook cryptographic signature verification failed',
    originalError?: any,
  ) {
    super(message, providerId, category, originalError);
  }
}

export class ProviderNotConfiguredError extends IntegrationError {
  public readonly isTransient = false;
  public readonly isRetryable = false;

  constructor(category: IntegrationCategory, providerId = 'none') {
    super(
      `No active or configured provider found for integration category [${category}]`,
      providerId,
      category,
    );
  }
}

export class CapabilityNotSupportedError extends IntegrationError {
  public readonly isTransient = false;
  public readonly isRetryable = false;

  constructor(
    providerId: string,
    category: IntegrationCategory,
    capability: string,
  ) {
    super(
      `Provider [${providerId}] does not support capability [${capability}]`,
      providerId,
      category,
      undefined,
      { capability },
    );
  }
}

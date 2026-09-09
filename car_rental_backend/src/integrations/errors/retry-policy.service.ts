import { Injectable, Logger } from '@nestjs/common';
import { IntegrationError } from './integration-error';

export interface RetryOptions {
  maxRetries?: number;
  initialDelayMs?: number;
  maxDelayMs?: number;
  backoffFactor?: number;
  isIdempotent: boolean; // MANDATORY: Explicitly declares whether the operation is safe to retry
  onRetry?: (error: Error, attempt: number, delayMs: number) => void;
}

const DEFAULT_RETRY_OPTIONS: Required<Omit<RetryOptions, 'isIdempotent' | 'onRetry'>> = {
  maxRetries: 3,
  initialDelayMs: 200,
  maxDelayMs: 3000,
  backoffFactor: 2,
};

@Injectable()
export class RetryPolicyService {
  private readonly logger = new Logger(RetryPolicyService.name);

  /**
   * Executes an asynchronous operation with controlled exponential backoff.
   * STRICT SAFETY INVARIANT: Non-idempotent operations are NEVER retried.
   */
  async executeWithRetry<T>(
    operation: (attempt: number) => Promise<T>,
    options: RetryOptions,
  ): Promise<T> {
    const {
      maxRetries = DEFAULT_RETRY_OPTIONS.maxRetries,
      initialDelayMs = DEFAULT_RETRY_OPTIONS.initialDelayMs,
      maxDelayMs = DEFAULT_RETRY_OPTIONS.maxDelayMs,
      backoffFactor = DEFAULT_RETRY_OPTIONS.backoffFactor,
      isIdempotent,
      onRetry,
    } = options;

    let attempt = 0;

    while (true) {
      try {
        attempt++;
        return await operation(attempt);
      } catch (err: any) {
        // Check if retryable:
        const isRetryableError =
          err instanceof IntegrationError ? err.isRetryable : false;

        // NON-IDEMPOTENT OPERATIONS MUST NEVER BE BLINDLY RETRIED
        if (!isIdempotent) {
          this.logger.warn(
            `[RETRY_POLICY] Operation failed but is NOT idempotent. Aborting retry: ${err?.message}`,
          );
          throw err;
        }

        // Check if exceeded maxRetries or error is permanent
        if (attempt > maxRetries || !isRetryableError) {
          throw err;
        }

        // Calculate exponential backoff with full jitter
        const baseDelay = initialDelayMs * Math.pow(backoffFactor, attempt - 1);
        const cappedDelay = Math.min(baseDelay, maxDelayMs);
        const jitter = Math.random() * 0.3 * cappedDelay; // Up to 30% jitter
        const delayMs = Math.round(cappedDelay + jitter);

        this.logger.log(
          `[RETRY_POLICY] Retrying transient failure (attempt ${attempt}/${maxRetries}) after ${delayMs}ms: ${err?.message}`,
        );

        if (onRetry) {
          onRetry(err, attempt, delayMs);
        }

        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  }
}

import { Injectable, Logger } from '@nestjs/common';
import { FailureClassification } from './runtime.types';
import {
  IntegrationError,
  ProviderTimeoutError,
  TransientNetworkError,
  RateLimitExceededError,
  AuthenticationError,
  DuplicateRequestError,
  CapabilityNotSupportedError,
  ProviderNotConfiguredError,
} from '../errors/integration-error';

export interface ClassificationResult {
  classification: FailureClassification;
  isRetryable: boolean;
  isFallbackEligible: boolean;
  retryAfterMs?: number;
  message: string;
}

@Injectable()
export class FailureClassifierService {
  private readonly logger = new Logger(FailureClassifierService.name);

  classify(error: any): FailureClassification {
    const details = this.classifyDetails(error);
    return details.classification;
  }

  classifyDetails(error: any): ClassificationResult {
    let classification = FailureClassification.PERMANENT;
    let isRetryable = false;
    let isFallbackEligible = false;
    let retryAfterMs: number | undefined;

    const message = error?.message || String(error);
    const status = error?.status || error?.statusCode || error?.response?.status;
    const code = error?.code || error?.response?.data?.code;

    // 1. Check known IntegrationError instances
    if (error instanceof RateLimitExceededError) {
      classification = FailureClassification.RATE_LIMITED;
      isRetryable = true;
      isFallbackEligible = true;
      retryAfterMs = error.retryAfterMs;
    } else if (error instanceof ProviderTimeoutError) {
      classification = FailureClassification.TIMEOUT;
      isRetryable = true;
      isFallbackEligible = true;
    } else if (error instanceof TransientNetworkError) {
      classification = FailureClassification.NETWORK;
      isRetryable = true;
      isFallbackEligible = true;
    } else if (error instanceof AuthenticationError) {
      classification = FailureClassification.AUTHENTICATION;
      isRetryable = false;
      isFallbackEligible = true;
    } else if (error instanceof DuplicateRequestError) {
      classification = FailureClassification.DUPLICATE;
      isRetryable = false;
      isFallbackEligible = false;
    } else if (error instanceof CapabilityNotSupportedError) {
      classification = FailureClassification.NOT_SUPPORTED;
      isRetryable = false;
      isFallbackEligible = true;
    } else if (error instanceof ProviderNotConfiguredError) {
      classification = FailureClassification.CONFIGURATION;
      isRetryable = false;
      isFallbackEligible = true;
    }

    // 2. String code / Network socket errors
    else if (
      code === 'ETIMEDOUT' ||
      code === 'ESOCKETTIMEDOUT' ||
      message.toLowerCase().includes('timeout') ||
      status === 504
    ) {
      classification = FailureClassification.TIMEOUT;
      isRetryable = true;
      isFallbackEligible = true;
    } else if (
      code === 'ECONNRESET' ||
      code === 'ECONNREFUSED' ||
      code === 'EAI_AGAIN' ||
      code === 'ENOTFOUND' ||
      code === 'EPIPE' ||
      message.toLowerCase().includes('network')
    ) {
      classification = FailureClassification.NETWORK;
      isRetryable = true;
      isFallbackEligible = true;
    }

    // 3. HTTP status code classification
    else if (status === 429 || message.toLowerCase().includes('rate limit')) {
      classification = FailureClassification.RATE_LIMITED;
      isRetryable = true;
      isFallbackEligible = true;
      const retryHeader =
        error?.response?.headers?.['retry-after'] || error?.response?.headers?.['Retry-After'];
      if (retryHeader) {
        const parsed = parseInt(retryHeader, 10);
        if (!isNaN(parsed)) {
          retryAfterMs = parsed * 1000;
        }
      }
    } else if (status === 401 || status === 403 || message.toLowerCase().includes('unauthorized')) {
      classification = FailureClassification.AUTHENTICATION;
      isRetryable = false;
      isFallbackEligible = true;
    } else if (status === 409 || message.toLowerCase().includes('duplicate')) {
      classification = FailureClassification.DUPLICATE;
      isRetryable = false;
      isFallbackEligible = false;
    } else if (status === 400 || status === 422 || message.toLowerCase().includes('validation')) {
      const msgLower = message.toLowerCase();
      if (
        msgLower.includes('declined') ||
        msgLower.includes('insufficient') ||
        msgLower.includes('rejected') ||
        msgLower.includes('expired_card')
      ) {
        classification = FailureClassification.PROVIDER_DECLINED;
        isRetryable = false;
        isFallbackEligible = true;
      } else {
        classification = FailureClassification.INVALID_REQUEST;
        isRetryable = false;
        isFallbackEligible = false;
      }
    } else if (
      (status && status >= 500) ||
      message.includes('503') ||
      message.includes('502') ||
      message.includes('504') ||
      message.includes('500') ||
      message.toLowerCase().includes('unavailable')
    ) {
      classification = FailureClassification.TRANSIENT;
      isRetryable = true;
      isFallbackEligible = true;
    }

    return {
      classification,
      isRetryable,
      isFallbackEligible,
      retryAfterMs,
      message,
    };
  }

  isRetryable(classification: FailureClassification | ClassificationResult): boolean {
    if (typeof classification === 'object' && classification !== null && 'isRetryable' in classification) {
      return (classification as ClassificationResult).isRetryable;
    }
    return [
      FailureClassification.TRANSIENT,
      FailureClassification.RATE_LIMITED,
      FailureClassification.TIMEOUT,
      FailureClassification.NETWORK,
    ].includes(classification as FailureClassification);
  }

  isFallbackEligible(classification: FailureClassification | ClassificationResult): boolean {
    if (typeof classification === 'object' && classification !== null && 'isFallbackEligible' in classification) {
      return (classification as ClassificationResult).isFallbackEligible;
    }
    return (
      classification !== FailureClassification.INVALID_REQUEST &&
      classification !== FailureClassification.PERMANENT &&
      classification !== FailureClassification.DUPLICATE
    );
  }

  calculateBackoff(attempt: number, error?: any, baseMs = 100, maxMs = 5000): number {
    // If Retry-After header is available, respect it
    const retryHeader =
      error?.response?.headers?.['retry-after'] || error?.response?.headers?.['Retry-After'];
    if (retryHeader) {
      const parsed = parseInt(retryHeader, 10);
      if (!isNaN(parsed)) {
        return Math.min(maxMs, parsed * 1000);
      }
    }

    // Exponential backoff with full jitter
    const exp = Math.min(maxMs, baseMs * Math.pow(2, attempt));
    const jitter = Math.floor(Math.random() * (exp * 0.25));
    return exp + jitter;
  }
}

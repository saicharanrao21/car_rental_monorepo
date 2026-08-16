import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as Sentry from '@sentry/node';

const SENSITIVE_KEY_REGEX =
  /(password|token|secret|jwt|otp|auth|authorization|bankdetails|accountnumber|ifsc|pannumber|gstnumber|cvv|cardnumber|signature|encryptionkey)/i;

const SENSITIVE_VALUE_PATTERNS = [
  /Bearer\s+[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*/gi,
  /password["':\s]+["']?([^"',\s]+)/gi,
  /otp["':\s]+["']?(\d{4,6})/gi,
  /rawOtp["':\s]+["']?(\d{4,6})/gi,
  /keySecret["':\s]+["']?([^"',\s]+)/gi,
  /webhookSecret["':\s]+["']?([^"',\s]+)/gi,
  /BANK_ENCRYPTION_KEY["':\s]+["']?([^"',\s]+)/gi,
];

export interface FinancialEventContext {
  bookingId?: string;
  paymentId?: string;
  razorpayOrderId?: string;
  razorpayPaymentId?: string;
  razorpayRefundId?: string;
  expectedAmount?: number | string;
  actualAmount?: number | string;
  correlationId?: string;
  severity?: 'warning' | 'error' | 'fatal';
  extra?: Record<string, any>;
}

@Injectable()
export class ApmMonitoringService implements OnModuleInit {
  private readonly logger = new Logger(ApmMonitoringService.name);
  private isInitialized = false;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    this.initSentry();
  }

  /**
   * Initializes Sentry safely if SENTRY_DSN is provided.
   * If SENTRY_DSN is absent, operates in safe offline/noop mode without throwing errors.
   */
  private initSentry() {
    const dsn = this.configService.get<string>('SENTRY_DSN')?.trim();

    if (!dsn) {
      this.logger.log(
        'SENTRY_DSN not configured. APM error tracking is operating in offline/noop mode.',
      );
      this.isInitialized = false;
      return;
    }

    const environment =
      this.configService.get<string>('SENTRY_ENVIRONMENT') ||
      this.configService.get<string>('NODE_ENV') ||
      'development';

    const release =
      this.configService.get<string>('SENTRY_RELEASE') ||
      'drivego-backend@1.0.0';

    try {
      Sentry.init({
        dsn,
        environment,
        release,
        tracesSampleRate: environment === 'production' ? 0.2 : 1.0,
        beforeSend: (event) => this.sanitizeSentryEvent(event),
        beforeBreadcrumb: (breadcrumb) => this.sanitizeBreadcrumb(breadcrumb),
      });

      this.isInitialized = true;
      this.logger.log(
        `APM error tracking initialized successfully for environment: ${environment}`,
      );
    } catch (err: any) {
      this.logger.warn(
        `Failed to initialize Sentry APM tracking: ${err?.message || err}. Continuing in noop mode.`,
      );
      this.isInitialized = false;
    }
  }

  public getIsEnabled(): boolean {
    return this.isInitialized;
  }

  /**
   * Captures a high-severity financial inconsistency or anomaly event.
   */
  captureFinancialInconsistency(
    title: string,
    context: FinancialEventContext,
  ): void {
    const sanitizedTitle = this.sanitizeString(title);
    const sanitizedExtra = this.sanitizeObject(context.extra || {});

    this.logger.error(
      `[FINANCIAL_ALERT] ${sanitizedTitle} | correlationId=${context.correlationId || 'N/A'} bookingId=${context.bookingId || 'N/A'} paymentId=${context.paymentId || 'N/A'}`,
    );

    if (!this.isInitialized) return;

    Sentry.withScope((scope) => {
      scope.setLevel(
        context.severity === 'warning'
          ? 'warning'
          : context.severity === 'fatal'
            ? 'fatal'
            : 'error',
      );

      if (context.correlationId) {
        scope.setTag('correlation_id', context.correlationId);
      }
      if (context.bookingId) {
        scope.setTag('booking_id', context.bookingId);
      }
      if (context.paymentId) {
        scope.setTag('payment_id', context.paymentId);
      }
      if (context.razorpayOrderId) {
        scope.setTag('razorpay_order_id', context.razorpayOrderId);
      }
      if (context.razorpayPaymentId) {
        scope.setTag('razorpay_payment_id', context.razorpayPaymentId);
      }
      if (context.razorpayRefundId) {
        scope.setTag('razorpay_refund_id', context.razorpayRefundId);
      }

      scope.setContext('financial_discrepancy', {
        expectedAmount: context.expectedAmount,
        actualAmount: context.actualAmount,
        ...sanitizedExtra,
      });

      Sentry.captureMessage(`[FINANCIAL_ALERT] ${sanitizedTitle}`);
    });
  }

  /**
   * Captures an unexpected exception with correlation and user context.
   */
  captureException(
    err: any,
    context?: {
      correlationId?: string;
      userId?: string;
      tags?: Record<string, string>;
      extra?: Record<string, any>;
    },
  ): void {
    if (!this.isInitialized) return;

    Sentry.withScope((scope) => {
      if (context?.correlationId) {
        scope.setTag('correlation_id', context.correlationId);
      }
      if (context?.userId) {
        scope.setUser({ id: context.userId });
      }
      if (context?.tags) {
        for (const [key, value] of Object.entries(context.tags)) {
          scope.setTag(key, value);
        }
      }
      if (context?.extra) {
        scope.setContext('extra_context', this.sanitizeObject(context.extra));
      }

      Sentry.captureException(err);
    });
  }

  /**
   * Sanitizes sensitive fields before sending event to Sentry.
   */
  public sanitizeSentryEvent(
    event: Sentry.ErrorEvent,
  ): Sentry.ErrorEvent | null {
    if (event.request?.headers) {
      delete event.request.headers['authorization'];
      delete event.request.headers['cookie'];
      delete event.request.headers['x-razorpay-signature'];
    }

    if (event.request?.data) {
      event.request.data = this.sanitizeObject(event.request.data);
    }

    if (event.extra) {
      event.extra = this.sanitizeObject(event.extra);
    }

    if (event.contexts) {
      event.contexts = this.sanitizeObject(event.contexts);
    }

    if (event.message) {
      event.message = this.sanitizeString(event.message);
    }

    return event;
  }

  /**
   * Sanitizes breadcrumbs before storing.
   */
  public sanitizeBreadcrumb(
    breadcrumb: Sentry.Breadcrumb,
  ): Sentry.Breadcrumb | null {
    if (breadcrumb.data) {
      breadcrumb.data = this.sanitizeObject(breadcrumb.data);
    }
    if (breadcrumb.message) {
      breadcrumb.message = this.sanitizeString(breadcrumb.message);
    }
    return breadcrumb;
  }

  public sanitizeString(str: string): string {
    if (typeof str !== 'string') return str;
    let sanitized = str;
    for (const pattern of SENSITIVE_VALUE_PATTERNS) {
      sanitized = sanitized.replace(pattern, '[REDACTED]');
    }
    return sanitized;
  }

  public sanitizeObject(obj: any): any {
    if (obj === null || obj === undefined) return obj;
    if (typeof obj === 'string') return this.sanitizeString(obj);
    if (typeof obj !== 'object') return obj;

    if (Array.isArray(obj)) {
      return obj.map((item) => this.sanitizeObject(item));
    }

    const sanitized: Record<string, any> = {};
    for (const [key, value] of Object.entries(obj)) {
      if (SENSITIVE_KEY_REGEX.test(key)) {
        sanitized[key] = '[REDACTED]';
      } else if (typeof value === 'object') {
        sanitized[key] = this.sanitizeObject(value);
      } else if (typeof value === 'string') {
        sanitized[key] = this.sanitizeString(value);
      } else {
        sanitized[key] = value;
      }
    }
    return sanitized;
  }
}

import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  validateSync,
} from 'class-validator';

export enum Environment {
  Development = 'development',
  Production = 'production',
  Test = 'test',
  Staging = 'staging',
}

export class EnvironmentVariables {
  @IsEnum(Environment)
  @IsOptional()
  NODE_ENV: Environment = Environment.Development;

  @IsNumber()
  @IsOptional()
  PORT: number = 3000;

  @IsString()
  DATABASE_URL: string;

  @IsString()
  JWT_ACCESS_SECRET: string;

  @IsString()
  JWT_REFRESH_SECRET: string;

  @IsString()
  @IsOptional()
  JWT_ACCESS_EXPIRY: string = '15m';

  @IsString()
  @IsOptional()
  JWT_REFRESH_EXPIRY: string = '30d';

  @IsString()
  @IsOptional()
  REDIS_URL?: string;

  @IsString()
  @IsOptional()
  REDIS_USE_MOCK?: string = 'false';

  @IsString()
  @IsOptional()
  CORS_ALLOWED_ORIGINS?: string;

  @IsString()
  @IsOptional()
  SMS_PROVIDER?: string;

  @IsString()
  @IsOptional()
  MSG91_AUTH_KEY?: string;

  @IsString()
  @IsOptional()
  MSG91_TEMPLATE_ID?: string;

  @IsString()
  @IsOptional()
  MSG91_SENDER_ID?: string;

  @IsString()
  @IsOptional()
  RAZORPAY_KEY_ID?: string;

  @IsString()
  @IsOptional()
  RAZORPAY_KEY_SECRET?: string;

  @IsString()
  @IsOptional()
  RAZORPAY_WEBHOOK_SECRET?: string;

  @IsString()
  @IsOptional()
  RAZORPAY_USE_MOCK?: string = 'false';

  @IsString()
  @IsOptional()
  R2_USE_MOCK?: string = 'true';

  @IsString()
  @IsOptional()
  R2_ACCESS_KEY_ID?: string;

  @IsString()
  @IsOptional()
  R2_SECRET_ACCESS_KEY?: string;

  @IsString()
  @IsOptional()
  R2_BUCKET_NAME?: string;

  @IsString()
  @IsOptional()
  R2_ENDPOINT?: string;

  @IsString()
  @IsOptional()
  R2_PUBLIC_URL?: string;

  @IsString()
  @IsOptional()
  BANK_ENCRYPTION_KEY?: string;

  @IsString()
  @IsOptional()
  RECONCILIATION_ENABLED?: string = 'true';

  @IsNumber()
  @IsOptional()
  RECONCILIATION_INTERVAL_MINUTES?: number = 15;

  @IsNumber()
  @IsOptional()
  RECONCILIATION_LOOKBACK_MINUTES?: number = 30;

  @IsNumber()
  @IsOptional()
  STALE_PAYMENT_ORDER_HOURS?: number = 24;

  @IsString()
  @IsOptional()
  SENTRY_DSN?: string;

  @IsString()
  @IsOptional()
  SENTRY_ENVIRONMENT?: string;

  @IsString()
  @IsOptional()
  SENTRY_RELEASE?: string;
}

const KNOWN_PLACEHOLDER_SECRETS = new Set([
  'dev_access_secret_key_change_me_12345!',
  'dev_refresh_secret_key_change_me_12345!',
  'dev_bank_encryption_key_32_bytes_hex_1234567890abcdef1234567890abcdef',
  'placeholderKeySecret',
  'placeholderWebhookSecret',
  'rzp_test_placeholderKeyId',
  'mock_access_key',
  'mock_secret_key',
  'placeholder_msg91_auth_key',
  'placeholder_template_id',
  'placeholder_auth_key',
  'secret',
  'changeme',
]);

export function validateEnv(
  config: Record<string, unknown>,
): EnvironmentVariables {
  const validatedConfig = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });

  const errors = validateSync(validatedConfig, {
    skipMissingProperties: false,
  });
  const validationErrors: string[] = [];

  if (errors.length > 0) {
    for (const err of errors) {
      if (err.constraints) {
        validationErrors.push(...Object.values(err.constraints));
      }
    }
  }

  const isProduction = validatedConfig.NODE_ENV === Environment.Production;

  // Strict Production-only security validations
  if (isProduction) {
    // 1. JWT Secrets must not be defaults and must be sufficiently strong (>= 32 chars)
    if (
      !validatedConfig.JWT_ACCESS_SECRET ||
      KNOWN_PLACEHOLDER_SECRETS.has(validatedConfig.JWT_ACCESS_SECRET) ||
      validatedConfig.JWT_ACCESS_SECRET.length < 32
    ) {
      validationErrors.push(
        'PRODUCTION ERROR: JWT_ACCESS_SECRET is missing, uses a known placeholder, or is shorter than 32 characters.',
      );
    }

    if (
      !validatedConfig.JWT_REFRESH_SECRET ||
      KNOWN_PLACEHOLDER_SECRETS.has(validatedConfig.JWT_REFRESH_SECRET) ||
      validatedConfig.JWT_REFRESH_SECRET.length < 32
    ) {
      validationErrors.push(
        'PRODUCTION ERROR: JWT_REFRESH_SECRET is missing, uses a known placeholder, or is shorter than 32 characters.',
      );
    }

    // 2. Redis is strictly required in production (no mock Redis allowed)
    if (validatedConfig.REDIS_USE_MOCK === 'true') {
      validationErrors.push(
        'PRODUCTION SECURITY ERROR: REDIS_USE_MOCK cannot be "true" in production environment.',
      );
    }

    if (
      !validatedConfig.REDIS_URL ||
      (!validatedConfig.REDIS_URL.startsWith('redis://') &&
        !validatedConfig.REDIS_URL.startsWith('rediss://'))
    ) {
      validationErrors.push(
        'PRODUCTION ERROR: REDIS_URL is mandatory in production and must start with redis:// or rediss://.',
      );
    }

    // 3. CORS origins must be explicitly provided and must not contain wildcard '*'
    if (
      !validatedConfig.CORS_ALLOWED_ORIGINS ||
      validatedConfig.CORS_ALLOWED_ORIGINS.trim() === ''
    ) {
      validationErrors.push(
        'PRODUCTION ERROR: CORS_ALLOWED_ORIGINS is mandatory in production to restrict browser API access.',
      );
    } else {
      const origins = validatedConfig.CORS_ALLOWED_ORIGINS.split(',').map((s) =>
        s.trim(),
      );
      if (origins.includes('*')) {
        validationErrors.push(
          'PRODUCTION SECURITY ERROR: CORS_ALLOWED_ORIGINS must not contain wildcard "*" in production.',
        );
      }
    }

    // 4. SMS Provider validations: Mock provider is forbidden in production
    if (validatedConfig.SMS_PROVIDER === 'mock') {
      validationErrors.push(
        'PRODUCTION SECURITY ERROR: SMS_PROVIDER cannot be "mock" in production environment.',
      );
    } else {
      if (
        !validatedConfig.MSG91_AUTH_KEY ||
        KNOWN_PLACEHOLDER_SECRETS.has(validatedConfig.MSG91_AUTH_KEY) ||
        !validatedConfig.MSG91_TEMPLATE_ID ||
        KNOWN_PLACEHOLDER_SECRETS.has(validatedConfig.MSG91_TEMPLATE_ID)
      ) {
        validationErrors.push(
          'PRODUCTION ERROR: Real MSG91 credentials (MSG91_AUTH_KEY, MSG91_TEMPLATE_ID) are required in production.',
        );
      }
    }

    // 5. Razorpay mock fallback is strictly forbidden in production
    if (validatedConfig.RAZORPAY_USE_MOCK === 'true') {
      validationErrors.push(
        'PRODUCTION SECURITY ERROR: RAZORPAY_USE_MOCK cannot be "true" in production environment.',
      );
    } else {
      if (
        !validatedConfig.RAZORPAY_KEY_ID ||
        KNOWN_PLACEHOLDER_SECRETS.has(validatedConfig.RAZORPAY_KEY_ID) ||
        !validatedConfig.RAZORPAY_KEY_SECRET ||
        KNOWN_PLACEHOLDER_SECRETS.has(validatedConfig.RAZORPAY_KEY_SECRET) ||
        !validatedConfig.RAZORPAY_WEBHOOK_SECRET ||
        KNOWN_PLACEHOLDER_SECRETS.has(validatedConfig.RAZORPAY_WEBHOOK_SECRET)
      ) {
        validationErrors.push(
          'PRODUCTION ERROR: Real Razorpay credentials (RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, RAZORPAY_WEBHOOK_SECRET) are required in production.',
        );
      }
    }

    // 6. R2 mock storage fallback is strictly forbidden in production
    if (validatedConfig.R2_USE_MOCK === 'true') {
      validationErrors.push(
        'PRODUCTION SECURITY ERROR: R2_USE_MOCK cannot be "true" in production environment.',
      );
    } else {
      if (
        !validatedConfig.R2_ACCESS_KEY_ID ||
        KNOWN_PLACEHOLDER_SECRETS.has(validatedConfig.R2_ACCESS_KEY_ID) ||
        !validatedConfig.R2_SECRET_ACCESS_KEY ||
        KNOWN_PLACEHOLDER_SECRETS.has(validatedConfig.R2_SECRET_ACCESS_KEY) ||
        !validatedConfig.R2_ENDPOINT
      ) {
        validationErrors.push(
          'PRODUCTION ERROR: Real Cloudflare R2 credentials (R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT) are required in production.',
        );
      }
    }

    // 7. Bank encryption key is mandatory and must not be a known placeholder in production
    if (
      !validatedConfig.BANK_ENCRYPTION_KEY ||
      KNOWN_PLACEHOLDER_SECRETS.has(validatedConfig.BANK_ENCRYPTION_KEY) ||
      validatedConfig.BANK_ENCRYPTION_KEY.length < 32
    ) {
      validationErrors.push(
        'PRODUCTION ERROR: BANK_ENCRYPTION_KEY is mandatory in production, must not be a placeholder, and must be at least 32 characters.',
      );
    }
  } else if (validatedConfig.SMS_PROVIDER === 'msg91') {
    // Non-production environment explicitly choosing MSG91
    if (!validatedConfig.MSG91_AUTH_KEY || !validatedConfig.MSG91_TEMPLATE_ID) {
      validationErrors.push(
        'CONFIG ERROR: MSG91_AUTH_KEY and MSG91_TEMPLATE_ID must be provided when SMS_PROVIDER is set to "msg91".',
      );
    }
  }

  // Non-production safety guards: Never allow live credentials in staging/development/test
  if (!isProduction) {
    if (
      validatedConfig.RAZORPAY_KEY_ID &&
      validatedConfig.RAZORPAY_KEY_ID.startsWith('rzp_live_')
    ) {
      validationErrors.push(
        'SECURITY ERROR: Live Razorpay key (rzp_live_...) is strictly forbidden in non-production environments.',
      );
    }
  }

  if (validationErrors.length > 0) {
    throw new Error(
      `\n=========================================================\n[CONFIG VALIDATION FAILED] Startup aborted due to configuration errors:\n` +
        validationErrors.map((e) => `  - ${e}`).join('\n') +
        `\n=========================================================\n`,
    );
  }

  return validatedConfig;
}

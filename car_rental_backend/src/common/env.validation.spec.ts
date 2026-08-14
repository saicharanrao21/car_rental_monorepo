import 'reflect-metadata';
import { validateEnv, Environment } from './env.validation';

describe('Environment Configuration Validation (Phase 1, 2A & 2B)', () => {
  const validDevConfig = {
    NODE_ENV: 'development',
    DATABASE_URL:
      'postgresql://postgres:password@localhost:5432/db?schema=public',
    JWT_ACCESS_SECRET: 'dev_access_secret_key_change_me_12345!',
    JWT_REFRESH_SECRET: 'dev_refresh_secret_key_change_me_12345!',
  };

  const validProdConfig = {
    NODE_ENV: 'production',
    DATABASE_URL:
      'postgresql://realuser:realpassword@production-db:5432/drivego?schema=public',
    REDIS_URL: 'rediss://production-redis:6380',
    REDIS_USE_MOCK: 'false',
    JWT_ACCESS_SECRET:
      'a_very_secure_random_and_long_production_access_key_123456789!',
    JWT_REFRESH_SECRET:
      'a_very_secure_random_and_long_production_refresh_key_123456789!',
    CORS_ALLOWED_ORIGINS:
      'https://admin.drivego.in,https://vendor.drivego.in,https://drivego.in',
    SMS_PROVIDER: 'msg91',
    MSG91_AUTH_KEY: 'real_msg91_live_auth_key_123456789',
    MSG91_TEMPLATE_ID: 'dlt_approved_template_123456',
    MSG91_SENDER_ID: 'DRIVGO',
    RAZORPAY_KEY_ID: 'rzp_live_realKeyId998877665544332211',
    RAZORPAY_KEY_SECRET: 'realKeySecret99887766554433221100',
    RAZORPAY_WEBHOOK_SECRET: 'realWebhookSecret99887766554433221100',
    RAZORPAY_USE_MOCK: 'false',
    R2_USE_MOCK: 'false',
    R2_ACCESS_KEY_ID: 'real_r2_access_key_id_123456789',
    R2_SECRET_ACCESS_KEY: 'real_r2_secret_access_key_123456789_abcdef',
    R2_ENDPOINT: 'https://real-account-id.r2.cloudflarestorage.com',
    BANK_ENCRYPTION_KEY:
      'real_production_bank_encryption_key_32_bytes_hex_1234567890abcdef',
  };

  it('should pass validation for valid development configuration', () => {
    const result = validateEnv(validDevConfig);
    expect(result.NODE_ENV).toBe(Environment.Development);
    expect(result.JWT_ACCESS_SECRET).toBe(
      'dev_access_secret_key_change_me_12345!',
    );
  });

  it('should pass validation for valid production configuration', () => {
    const result = validateEnv(validProdConfig);
    expect(result.NODE_ENV).toBe(Environment.Production);
    expect(result.SMS_PROVIDER).toBe('msg91');
    expect(result.RAZORPAY_USE_MOCK).toBe('false');
    expect(result.R2_USE_MOCK).toBe('false');
    expect(result.REDIS_USE_MOCK).toBe('false');
  });

  it('should fail startup in production if JWT_ACCESS_SECRET is a known placeholder', () => {
    const badConfig = {
      ...validProdConfig,
      JWT_ACCESS_SECRET: 'dev_access_secret_key_change_me_12345!',
    };

    expect(() => validateEnv(badConfig)).toThrow(
      /JWT_ACCESS_SECRET is missing, uses a known placeholder, or is shorter than 32 characters/,
    );
  });

  it('should fail startup in production if JWT secret is shorter than 32 characters', () => {
    const badConfig = {
      ...validProdConfig,
      JWT_ACCESS_SECRET: 'short_secret_key_123',
    };

    expect(() => validateEnv(badConfig)).toThrow(
      /JWT_ACCESS_SECRET is missing, uses a known placeholder, or is shorter than 32 characters/,
    );
  });

  it('should fail startup in production if REDIS_URL is missing', () => {
    const badConfig = {
      ...validProdConfig,
      REDIS_URL: undefined,
    };

    expect(() => validateEnv(badConfig)).toThrow(
      /REDIS_URL is mandatory in production/,
    );
  });

  it('should fail startup in production if REDIS_USE_MOCK is set to "true"', () => {
    const badConfig = {
      ...validProdConfig,
      REDIS_USE_MOCK: 'true',
    };

    expect(() => validateEnv(badConfig)).toThrow(
      /REDIS_USE_MOCK cannot be "true" in production environment/,
    );
  });

  it('should fail startup in production if CORS_ALLOWED_ORIGINS contains wildcard "*"', () => {
    const badConfig = {
      ...validProdConfig,
      CORS_ALLOWED_ORIGINS: 'https://drivego.in, *',
    };

    expect(() => validateEnv(badConfig)).toThrow(
      /CORS_ALLOWED_ORIGINS must not contain wildcard "\*"/,
    );
  });

  it('should fail startup in production if SMS_PROVIDER is set to "mock"', () => {
    const badConfig = {
      ...validProdConfig,
      SMS_PROVIDER: 'mock',
    };

    expect(() => validateEnv(badConfig)).toThrow(
      /SMS_PROVIDER cannot be "mock" in production environment/,
    );
  });

  it('should fail startup in production if MSG91_AUTH_KEY is missing', () => {
    const badConfig = {
      ...validProdConfig,
      MSG91_AUTH_KEY: undefined,
    };

    expect(() => validateEnv(badConfig)).toThrow(
      /Real MSG91 credentials .* are required in production/,
    );
  });

  it('should fail startup in production if MSG91_AUTH_KEY is a placeholder default', () => {
    const badConfig = {
      ...validProdConfig,
      MSG91_AUTH_KEY: 'placeholder_msg91_auth_key',
    };

    expect(() => validateEnv(badConfig)).toThrow(
      /Real MSG91 credentials .* are required in production/,
    );
  });

  it('should fail startup in production if RAZORPAY_USE_MOCK is set to "true"', () => {
    const badConfig = {
      ...validProdConfig,
      RAZORPAY_USE_MOCK: 'true',
    };

    expect(() => validateEnv(badConfig)).toThrow(
      /RAZORPAY_USE_MOCK cannot be "true" in production/,
    );
  });

  it('should fail startup in production if Razorpay credentials are placeholder defaults', () => {
    const badConfig = {
      ...validProdConfig,
      RAZORPAY_KEY_ID: 'rzp_test_placeholderKeyId',
    };

    expect(() => validateEnv(badConfig)).toThrow(
      /Real Razorpay credentials .* are required in production/,
    );
  });

  it('should fail startup in production if R2_USE_MOCK is set to "true"', () => {
    const badConfig = {
      ...validProdConfig,
      R2_USE_MOCK: 'true',
    };

    expect(() => validateEnv(badConfig)).toThrow(
      /R2_USE_MOCK cannot be "true" in production environment/,
    );
  });

  it('should fail startup in production if BANK_ENCRYPTION_KEY is placeholder or missing', () => {
    const badConfig = {
      ...validProdConfig,
      BANK_ENCRYPTION_KEY:
        'dev_bank_encryption_key_32_bytes_hex_1234567890abcdef1234567890abcdef',
    };

    expect(() => validateEnv(badConfig)).toThrow(
      /BANK_ENCRYPTION_KEY is mandatory in production/,
    );
  });
});

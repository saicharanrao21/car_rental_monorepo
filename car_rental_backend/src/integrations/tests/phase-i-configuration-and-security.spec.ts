import { Test, TestingModule } from '@nestjs/testing';
import { IntegrationConfigService } from '../config/integration-config.service';
import { SecretVaultService } from '../security/secret-vault.service';
import { SystemConfigService } from '../../config-engine/system-config.service';
import { ConfigService } from '@nestjs/config';
import { IntegrationCategory } from '../registry/provider.types';

describe('Phase I — Configuration Hierarchy & Secret Vault Security', () => {
  let configService: IntegrationConfigService;
  let secretVault: SecretVaultService;

  const mockDbConfigs: Record<string, any> = {};

  const mockSystemConfigService = {
    getConfig: jest.fn().mockImplementation((key: string) => {
      if (key in mockDbConfigs) return Promise.resolve(mockDbConfigs[key]);
      return Promise.reject(new Error(`Key ${key} not found`));
    }),
    setConfig: jest.fn().mockImplementation((key: string, val: any) => {
      mockDbConfigs[key] = val;
      return Promise.resolve(val);
    }),
  };

  beforeEach(async () => {
    Object.keys(mockDbConfigs).forEach((k) => delete mockDbConfigs[k]);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        IntegrationConfigService,
        SecretVaultService,
        { provide: SystemConfigService, useValue: mockSystemConfigService },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn().mockImplementation((key: string) => {
              if (key === 'BANK_ENCRYPTION_KEY') return 'test_bank_encryption_key_32_bytes_hex!';
              return null;
            }),
          },
        },
      ],
    }).compile();

    configService = module.get<IntegrationConfigService>(IntegrationConfigService);
    secretVault = module.get<SecretVaultService>(SecretVaultService);
  });

  describe('Secret Vault: AES-256-GCM Encryption', () => {
    it('should encrypt plaintext into AES-256-GCM format and decrypt back correctly', () => {
      const plaintextSecret = 'rzp_live_secret_key_123456789!#$';
      const encrypted = secretVault.encrypt(plaintextSecret);

      expect(encrypted).not.toBe(plaintextSecret);
      expect(encrypted.startsWith('enc:v1:')).toBe(true);

      const decrypted = secretVault.decrypt(encrypted);
      expect(decrypted).toBe(plaintextSecret);
    });

    it('should not double-encrypt an already encrypted value', () => {
      const encrypted = secretVault.encrypt('my_secret_token');
      const doubleEncrypted = secretVault.encrypt(encrypted);
      expect(doubleEncrypted).toBe(encrypted);
    });

    it('should correctly identify encrypted strings', () => {
      expect(secretVault.isEncrypted('enc:v1:abc:def:123')).toBe(true);
      expect(secretVault.isEncrypted('plaintext_secret')).toBe(false);
    });
  });

  describe('Secret Redaction & Masking', () => {
    it('should mask API keys and secrets correctly', () => {
      const longSecret = 'rzp_test_1234567890abcdef';
      const masked = secretVault.maskSecret(longSecret);
      expect(masked).toBe('rzp_test...cdef');
      expect(masked).not.toContain('1234567890');

      const shortSecret = '12345';
      expect(secretVault.maskSecret(shortSecret)).toBe('****');

      const encValue = secretVault.encrypt('my_secret');
      expect(secretVault.maskSecret(encValue)).toContain('[ENCRYPTED]');
    });

    it('should recursively sanitize sensitive keys in configuration objects', () => {
      const rawConfig = {
        providerId: 'razorpay',
        category: 'PAYMENT',
        settings: { timeoutMs: 5000, environment: 'production' },
        credentials: {
          keyId: 'rzp_live_keyId123456789',
          keySecret: 'rzp_live_secret987654321',
          webhookSecret: 'whsec_very_secret_hash_value',
        },
        metadata: {
          nested: {
            authToken: 'secret_token_value_abc',
            publicInfo: 'visible_info',
          },
        },
      };

      const sanitized = secretVault.sanitizeObject(rawConfig);

      // Sensitive fields must be masked
      expect(sanitized.credentials.keySecret).not.toBe('rzp_live_secret987654321');
      expect(sanitized.credentials.keySecret).toContain('...');
      expect(sanitized.credentials.webhookSecret).toContain('...');
      expect(sanitized.metadata.nested.authToken).toContain('...');

      // Non-sensitive fields must remain untouched
      expect(sanitized.providerId).toBe('razorpay');
      expect(sanitized.settings.timeoutMs).toBe(5000);
      expect(sanitized.metadata.nested.publicInfo).toBe('visible_info');
    });
  });

  describe('Configuration Hierarchy Resolution (Platform -> Vendor -> Branch)', () => {
    it('should resolve Platform-level configuration when no overrides exist', async () => {
      await configService.setProviderConfig(IntegrationCategory.PAYMENT, 'razorpay', {
        isEnabled: true,
        credentials: { keyId: 'platform_key', keySecret: 'platform_secret' },
        settings: { currency: 'INR' },
      });

      const resolved = await configService.resolveProviderConfig(
        IntegrationCategory.PAYMENT,
        'razorpay',
      );

      expect(resolved.resolvedLevel).toBe('PLATFORM');
      expect(resolved.credentials.keyId).toBe('platform_key');
      expect(resolved.credentials.keySecret).toBe('platform_secret');
      expect(resolved.settings.currency).toBe('INR');
    });

    it('should override Platform config with Vendor-level config when vendorId is present', async () => {
      // 1. Set Platform Config
      await configService.setProviderConfig(IntegrationCategory.PAYMENT, 'razorpay', {
        credentials: { keyId: 'platform_key', keySecret: 'platform_secret' },
      });

      // 2. Set Vendor Override
      await configService.setProviderConfig(
        IntegrationCategory.PAYMENT,
        'razorpay',
        {
          credentials: { keyId: 'vendor_override_key', keySecret: 'vendor_override_secret' },
          settings: { vendorCommissionTier: 'PRO' },
        },
        'admin_1',
        { vendorId: 'vendor_456' },
      );

      // Resolve for general platform -> gets platform
      const general = await configService.resolveProviderConfig(
        IntegrationCategory.PAYMENT,
        'razorpay',
      );
      expect(general.resolvedLevel).toBe('PLATFORM');
      expect(general.credentials.keyId).toBe('platform_key');

      // Resolve for vendor_456 -> gets vendor override
      const vendorResolved = await configService.resolveProviderConfig(
        IntegrationCategory.PAYMENT,
        'razorpay',
        { vendorId: 'vendor_456' },
      );
      expect(vendorResolved.resolvedLevel).toBe('VENDOR');
      expect(vendorResolved.resolvedEntityId).toBe('vendor_456');
      expect(vendorResolved.credentials.keyId).toBe('vendor_override_key');
      expect(vendorResolved.credentials.keySecret).toBe('vendor_override_secret');
    });

    it('should override Vendor config with Branch-level config when branchId is present', async () => {
      // Set Branch Override
      await configService.setProviderConfig(
        IntegrationCategory.PAYMENT,
        'razorpay',
        {
          credentials: { keyId: 'branch_override_key' },
          settings: { posTerminal: 'POS-001' },
        },
        'admin_1',
        { branchId: 'branch_789' },
      );

      const branchResolved = await configService.resolveProviderConfig(
        IntegrationCategory.PAYMENT,
        'razorpay',
        { branchId: 'branch_789' },
      );

      expect(branchResolved.resolvedLevel).toBe('BRANCH');
      expect(branchResolved.resolvedEntityId).toBe('branch_789');
      expect(branchResolved.credentials.keyId).toBe('branch_override_key');
      expect(branchResolved.settings.posTerminal).toBe('POS-001');
    });

    it('should never expose plaintext secrets in getMaskedProviderConfig API response', async () => {
      await configService.setProviderConfig(IntegrationCategory.PAYMENT, 'stripe', {
        credentials: { secretKey: 'sk_live_verySecretKey1234567890' },
      });

      const masked = await configService.getMaskedProviderConfig(
        IntegrationCategory.PAYMENT,
        'stripe',
      );

      expect(masked.credentials.secretKey).not.toBe('sk_live_verySecretKey1234567890');
      expect(masked.credentials.secretKey).toContain('...');
      expect(masked.credentials.secretKey.startsWith('sk_live_')).toBe(true);
    });
  });
});

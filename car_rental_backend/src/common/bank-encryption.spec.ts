import { BankEncryptionService } from './bank-encryption.service';
import { ConfigService } from '@nestjs/config';
import { BadRequestException } from '@nestjs/common';

describe('Phase 4B: Vendor Bank Data Security & AES-256-GCM Encryption', () => {
  let encryptionService: BankEncryptionService;
  let mockConfigService: any;
  const testKey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  beforeEach(() => {
    mockConfigService = {
      get: jest.fn().mockImplementation((key: string) => {
        if (key === 'BANK_ENCRYPTION_KEY') return testKey;
        if (key === 'NODE_ENV') return 'development';
        return undefined;
      }),
    };

    encryptionService = new BankEncryptionService(
      mockConfigService as ConfigService,
    );
  });

  describe('1. AES-256-GCM Encryption & Ciphertext Structure', () => {
    it('encrypts plaintext into versioned enc:v1:<iv>:<tag>:<ciphertext> format', () => {
      const plaintext = 'HDFC Bank - 50100234567890';
      const encrypted = encryptionService.encrypt(plaintext);

      expect(encrypted).toBeDefined();
      expect(encrypted).toMatch(/^enc:v1:[0-9a-f]{24}:[0-9a-f]{32}:[0-9a-f]+$/);
    });

    it('generates unique random IVs on every encryption call for the same plaintext', () => {
      const plaintext = 'ICICI Bank - 000401234567';
      const enc1 = encryptionService.encrypt(plaintext);
      const enc2 = encryptionService.encrypt(plaintext);

      expect(enc1).not.toEqual(enc2);
      expect(encryptionService.decrypt(enc1)).toEqual(plaintext);
      expect(encryptionService.decrypt(enc2)).toEqual(plaintext);
    });

    it('idempotently returns already-encrypted strings', () => {
      const plaintext = 'State Bank of India - 30012345678';
      const enc = encryptionService.encrypt(plaintext);
      const reEncrypted = encryptionService.encrypt(enc);

      expect(reEncrypted).toEqual(enc);
    });

    it('returns null for null, undefined, or empty plaintext', () => {
      expect(encryptionService.encrypt(null)).toBeNull();
      expect(encryptionService.encrypt(undefined)).toBeNull();
      expect(encryptionService.encrypt('')).toBeNull();
      expect(encryptionService.encrypt('   ')).toBeNull();
    });
  });

  describe('2. AES-256-GCM Decryption & Tamper Detection', () => {
    it('successfully recovers exact original plaintext bank details', () => {
      const original = 'Axis Bank - 912010023456789 | IFSC: UTIB0000123';
      const ciphertext = encryptionService.encrypt(original);
      const decrypted = encryptionService.decrypt(ciphertext);

      expect(decrypted).toEqual(original);
    });

    it('throws BadRequestException when ciphertext has been tampered with', () => {
      const original = 'Kotak Bank - 1234567890';
      const ciphertext = encryptionService.encrypt(original)!;

      // Tamper with ciphertext byte
      const parts = ciphertext.split(':');
      const tamperedHex =
        parts[4].slice(0, -2) + (parts[4].endsWith('00') ? 'ff' : '00');
      parts[4] = tamperedHex;
      const tamperedCiphertext = parts.join(':');

      expect(() => encryptionService.decrypt(tamperedCiphertext)).toThrow(
        BadRequestException,
      );
    });

    it('throws BadRequestException when authentication tag has been tampered with', () => {
      const original = 'Punjab National Bank - 0123000100234567';
      const ciphertext = encryptionService.encrypt(original)!;

      const parts = ciphertext.split(':');
      parts[3] = '00000000000000000000000000000000'; // Corrupt authTag
      const tamperedCiphertext = parts.join(':');

      expect(() => encryptionService.decrypt(tamperedCiphertext)).toThrow(
        BadRequestException,
      );
    });

    it('gracefully returns legacy unencrypted plaintext records for backward compatibility', () => {
      const legacyPlaintext = 'Canara Bank - 100923456789';
      const result = encryptionService.decrypt(legacyPlaintext);

      expect(result).toEqual(legacyPlaintext);
    });
  });

  describe('3. Financial Data Masking on Retrieval', () => {
    it('masks account number showing only the last 4 digits for plaintext input', () => {
      const plaintext = 'HDFC Bank - 50100234567890';
      const masked = encryptionService.mask(plaintext);

      expect(masked).toEqual('HDFC Bank - ••••••••7890');
    });

    it('automatically decrypts and masks when input is ciphertext', () => {
      const original = 'State Bank of India - 31098765432';
      const ciphertext = encryptionService.encrypt(original);
      const masked = encryptionService.mask(ciphertext);

      expect(masked).toEqual('State Bank of India - ••••••••5432');
    });

    it('leaves short strings <= 4 digits unmasked', () => {
      expect(encryptionService.mask('1234')).toEqual('1234');
    });

    it('returns null for null, undefined, or empty values', () => {
      expect(encryptionService.mask(null)).toBeNull();
      expect(encryptionService.mask(undefined)).toBeNull();
      expect(encryptionService.mask('')).toBeNull();
    });
  });

  describe('4. Environment & Production Key Validation', () => {
    it('throws a critical configuration error if BANK_ENCRYPTION_KEY is missing or uses placeholder in production', () => {
      const prodConfig = {
        get: jest.fn().mockImplementation((key: string) => {
          if (key === 'NODE_ENV') return 'production';
          if (key === 'BANK_ENCRYPTION_KEY')
            return 'dev_bank_encryption_key_32_bytes_hex_1234567890abcdef1234567890abcdef';
          return undefined;
        }),
      };

      expect(
        () => new BankEncryptionService(prodConfig as any),
      ).toThrow(
        /CRITICAL SECURITY CONFIGURATION ERROR: Real BANK_ENCRYPTION_KEY is required in production/,
      );
    });
  });
});

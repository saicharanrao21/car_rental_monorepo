import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

@Injectable()
export class SecretVaultService {
  private readonly logger = new Logger(SecretVaultService.name);
  private readonly encryptionKey: Buffer;
  private static readonly ALGORITHM = 'aes-256-gcm';
  private static readonly IV_LENGTH = 12;
  private static readonly AUTH_TAG_LENGTH = 16;

  private static readonly SENSITIVE_KEYS = new Set([
    'keysecret',
    'secret',
    'authtoken',
    'apikey',
    'privatekey',
    'password',
    'webhooksecret',
    'authkey',
    'accesskey',
    'secretaccesskey',
    'accesstoken',
    'token',
    'clientsecret',
    'credential',
    'credentials',
  ]);

  constructor(private readonly configService: ConfigService) {
    const rawKey =
      this.configService.get<string>('BANK_ENCRYPTION_KEY') ||
      this.configService.get<string>('JWT_ACCESS_SECRET') ||
      'dev_secret_vault_key_32_bytes_1234567890abcdef';

    // Derive deterministic 32-byte key via SHA-256
    this.encryptionKey = crypto.createHash('sha256').update(rawKey).digest();
  }

  /**
   * Encrypts a plaintext secret string using AES-256-GCM.
   * Format: enc:v1:<iv_hex>:<authTag_hex>:<ciphertext_hex>
   */
  encrypt(plaintext: string): string {
    if (!plaintext) return plaintext;
    if (this.isEncrypted(plaintext)) return plaintext; // Prevent double encryption

    const iv = crypto.randomBytes(SecretVaultService.IV_LENGTH);
    const cipher = crypto.createCipheriv(
      SecretVaultService.ALGORITHM,
      this.encryptionKey,
      iv,
    );

    let ciphertext = cipher.update(plaintext, 'utf8', 'hex');
    ciphertext += cipher.final('hex');
    const authTag = cipher.getAuthTag().toString('hex');

    return `enc:v1:${iv.toString('hex')}:${authTag}:${ciphertext}`;
  }

  /**
   * Decrypts an encrypted secret string.
   */
  decrypt(encryptedText: string): string {
    if (!encryptedText) return encryptedText;
    if (!this.isEncrypted(encryptedText)) return encryptedText;

    try {
      const parts = encryptedText.split(':');
      if (parts.length !== 5 || parts[0] !== 'enc' || parts[1] !== 'v1') {
        throw new Error('Invalid encrypted secret format');
      }

      const iv = Buffer.from(parts[2], 'hex');
      const authTag = Buffer.from(parts[3], 'hex');
      const ciphertext = parts[4];

      const decipher = crypto.createDecipheriv(
        SecretVaultService.ALGORITHM,
        this.encryptionKey,
        iv,
      );
      decipher.setAuthTag(authTag);

      let plaintext = decipher.update(ciphertext, 'hex', 'utf8');
      plaintext += decipher.final('utf8');

      return plaintext;
    } catch (err: any) {
      this.logger.error(`Failed to decrypt secret: ${err?.message}`);
      throw new Error('Secret decryption failed. Key may have changed or data corrupted.');
    }
  }

  /**
   * Returns true if the string is formatted as an encrypted value.
   */
  isEncrypted(val: string): boolean {
    return typeof val === 'string' && val.startsWith('enc:v1:');
  }

  /**
   * Masks a secret string for safe display in logs and admin UI.
   * e.g., 'rzp_test_1234567890abcdef' -> 'rzp_test_...cdef'
   * e.g., 'short' -> '****'
   */
  maskSecret(val: string): string {
    if (!val || typeof val !== 'string') return '';
    if (this.isEncrypted(val)) {
      return '******** [ENCRYPTED]';
    }

    const trimmed = val.trim();
    if (trimmed.length <= 8) {
      return '****';
    }

    if (trimmed.length <= 16) {
      return `${trimmed.substring(0, 3)}...${trimmed.substring(trimmed.length - 3)}`;
    }

    return `${trimmed.substring(0, 8)}...${trimmed.substring(trimmed.length - 4)}`;
  }

  /**
   * Recursively sanitizes any config object or payload by masking all sensitive keys.
   */
  sanitizeObject<T = any>(obj: T): T {
    if (obj === null || obj === undefined) return obj;
    if (typeof obj !== 'object') return obj;

    if (Array.isArray(obj)) {
      return obj.map((item) => this.sanitizeObject(item)) as unknown as T;
    }

    const sanitized: Record<string, any> = {};
    for (const [key, value] of Object.entries(obj)) {
      const lowerKey = key.toLowerCase().replace(/[^a-z]/g, '');
      const isSensitive = SecretVaultService.SENSITIVE_KEYS.has(lowerKey);

      if (isSensitive && typeof value === 'string') {
        sanitized[key] = this.maskSecret(value);
      } else if (typeof value === 'object' && value !== null) {
        sanitized[key] = this.sanitizeObject(value);
      } else {
        sanitized[key] = value;
      }
    }

    return sanitized as T;
  }
}

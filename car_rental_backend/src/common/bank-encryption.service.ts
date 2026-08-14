import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

@Injectable()
export class BankEncryptionService {
  private readonly logger = new Logger(BankEncryptionService.name);
  private readonly keyBuffer: Buffer;

  constructor(private readonly configService: ConfigService) {
    const rawKey =
      this.configService.get<string>('BANK_ENCRYPTION_KEY') ||
      'dev_bank_encryption_key_32_bytes_hex_1234567890abcdef1234567890abcdef';

    if (
      this.configService.get<string>('NODE_ENV') === 'production' &&
      (!this.configService.get<string>('BANK_ENCRYPTION_KEY') ||
        rawKey.startsWith('dev_'))
    ) {
      throw new Error(
        'CRITICAL SECURITY CONFIGURATION ERROR: Real BANK_ENCRYPTION_KEY is required in production.',
      );
    }

    // Derive 32-byte key buffer (if 64 hex chars, parse as hex; otherwise SHA256 digest)
    if (/^[0-9a-fA-F]{64}$/.test(rawKey)) {
      this.keyBuffer = Buffer.from(rawKey, 'hex');
    } else {
      this.keyBuffer = crypto.createHash('sha256').update(rawKey).digest();
    }
  }

  /**
   * Encrypts plaintext bank details using AES-256-GCM.
   * Returns format: enc:v1:<iv_hex>:<authTag_hex>:<ciphertext_hex>
   */
  encrypt(plaintext: string | null | undefined): string | null {
    if (!plaintext || plaintext.trim() === '') {
      return null;
    }

    // Already encrypted with version prefix
    if (plaintext.startsWith('enc:v1:')) {
      return plaintext;
    }

    try {
      const iv = crypto.randomBytes(12); // 96-bit IV recommended for GCM
      const cipher = crypto.createCipheriv('aes-256-gcm', this.keyBuffer, iv);

      let encrypted = cipher.update(plaintext, 'utf8', 'hex');
      encrypted += cipher.final('hex');

      const authTag = cipher.getAuthTag().toString('hex');
      const ivHex = iv.toString('hex');

      return `enc:v1:${ivHex}:${authTag}:${encrypted}`;
    } catch (err: any) {
      this.logger.error('Failed to encrypt bank details', err.message);
      throw new BadRequestException('Failed to process bank details securely.');
    }
  }

  /**
   * Decrypts ciphertext bank details using AES-256-GCM.
   * Gracefully returns legacy plaintext strings if not prefixed with enc:v1:
   */
  decrypt(ciphertext: string | null | undefined): string | null {
    if (!ciphertext || ciphertext.trim() === '') {
      return null;
    }

    // Legacy unencrypted plaintext record
    if (!ciphertext.startsWith('enc:v1:')) {
      return ciphertext;
    }

    try {
      const parts = ciphertext.split(':');
      if (parts.length !== 5) {
        throw new Error('Malformed encrypted ciphertext structure.');
      }

      const [, , ivHex, authTagHex, encryptedDataHex] = parts;
      const iv = Buffer.from(ivHex, 'hex');
      const authTag = Buffer.from(authTagHex, 'hex');

      const decipher = crypto.createDecipheriv(
        'aes-256-gcm',
        this.keyBuffer,
        iv,
      );
      decipher.setAuthTag(authTag);

      let decrypted = decipher.update(encryptedDataHex, 'hex', 'utf8');
      decrypted += decipher.final('utf8');

      return decrypted;
    } catch (err: any) {
      this.logger.error('Failed to authenticate/decrypt bank details', err.message);
      throw new BadRequestException('Unable to authenticate and decrypt bank details.');
    }
  }

  /**
   * Masks bank details for display in API responses (shows only last 4 digits).
   * Automatically decrypts if the input is in encrypted form.
   */
  mask(value: string | null | undefined): string | null {
    if (!value || value.trim() === '') {
      return null;
    }

    const plaintext = value.startsWith('enc:v1:') ? this.decrypt(value) : value;
    if (!plaintext) {
      return null;
    }

    // Find sequence of digits (account number) and mask all but last 4
    return plaintext.replace(/\b(\d{4,})\b/g, (match) => {
      if (match.length <= 4) return match;
      const visible = match.slice(-4);
      return '••••••••' + visible;
    });
  }
}

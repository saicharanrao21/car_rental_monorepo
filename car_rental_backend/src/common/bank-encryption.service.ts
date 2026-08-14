import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

@Injectable()
export class BankEncryptionService {
  private readonly logger = new Logger(BankEncryptionService.name);
  private readonly keyRegistry: Map<string, Buffer> = new Map();
  private readonly activeVersion: string;

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

    // Register primary V1 key
    const v1Buffer = this.deriveKeyBuffer(rawKey);
    this.keyRegistry.set('v1', v1Buffer);

    // Register optional V2 key for key rotation workflows
    const rawKeyV2 = this.configService.get<string>('BANK_ENCRYPTION_KEY_V2');
    if (rawKeyV2) {
      this.keyRegistry.set('v2', this.deriveKeyBuffer(rawKeyV2));
    }

    this.activeVersion =
      this.configService.get<string>('BANK_ENCRYPTION_ACTIVE_VERSION') ||
      (rawKeyV2 ? 'v2' : 'v1');
  }

  private deriveKeyBuffer(keyString: string): Buffer {
    if (/^[0-9a-fA-F]{64}$/.test(keyString)) {
      return Buffer.from(keyString, 'hex');
    }
    return crypto.createHash('sha256').update(keyString).digest();
  }

  /**
   * Registers an in-memory key version (used for rotation utilities and unit testing).
   */
  registerKeyVersion(version: string, keyString: string) {
    this.keyRegistry.set(version, this.deriveKeyBuffer(keyString));
  }

  /**
   * Encrypts plaintext bank details using AES-256-GCM under the active key version.
   * Returns format: enc:v<version>:<iv_hex>:<authTag_hex>:<ciphertext_hex>
   */
  encrypt(plaintext: string | null | undefined, targetVersion?: string): string | null {
    if (!plaintext || plaintext.trim() === '') {
      return null;
    }

    const version = targetVersion || this.activeVersion;
    const keyBuffer = this.keyRegistry.get(version);

    if (!keyBuffer) {
      throw new BadRequestException(`Encryption key for version ${version} is not configured.`);
    }

    // Already encrypted with target version prefix
    if (plaintext.startsWith(`enc:${version}:`)) {
      return plaintext;
    }

    try {
      const iv = crypto.randomBytes(12); // 96-bit IV recommended for GCM
      const cipher = crypto.createCipheriv('aes-256-gcm', keyBuffer, iv);

      let encrypted = cipher.update(plaintext, 'utf8', 'hex');
      encrypted += cipher.final('hex');

      const authTag = cipher.getAuthTag().toString('hex');
      const ivHex = iv.toString('hex');

      return `enc:${version}:${ivHex}:${authTag}:${encrypted}`;
    } catch (err: any) {
      this.logger.error('Failed to encrypt bank details', err.message);
      throw new BadRequestException('Failed to process bank details securely.');
    }
  }

  /**
   * Decrypts ciphertext bank details using AES-256-GCM by matching the version tag.
   * Gracefully returns legacy plaintext strings if not prefixed with enc:v...:
   */
  decrypt(ciphertext: string | null | undefined): string | null {
    if (!ciphertext || ciphertext.trim() === '') {
      return null;
    }

    // Legacy unencrypted plaintext record
    if (!ciphertext.startsWith('enc:')) {
      return ciphertext;
    }

    try {
      const parts = ciphertext.split(':');
      if (parts.length !== 5) {
        throw new Error('Malformed encrypted ciphertext structure.');
      }

      const [, version, ivHex, authTagHex, encryptedDataHex] = parts;
      const keyBuffer = this.keyRegistry.get(version);

      if (!keyBuffer) {
        throw new Error(`Decryption key for version ${version} is not available in registry.`);
      }

      const iv = Buffer.from(ivHex, 'hex');
      const authTag = Buffer.from(authTagHex, 'hex');

      const decipher = crypto.createDecipheriv('aes-256-gcm', keyBuffer, iv);
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
   * Re-encrypts ciphertext from its current key version to a target key version.
   */
  reencrypt(ciphertext: string | null | undefined, targetVersion: string = this.activeVersion): string | null {
    if (!ciphertext || ciphertext.trim() === '') return null;
    const decrypted = this.decrypt(ciphertext);
    return this.encrypt(decrypted, targetVersion);
  }

  /**
   * Masks bank details for display in API responses (shows only last 4 digits).
   * Automatically decrypts if the input is in encrypted form.
   */
  mask(value: string | null | undefined): string | null {
    if (!value || value.trim() === '') {
      return null;
    }

    const plaintext = value.startsWith('enc:') ? this.decrypt(value) : value;
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

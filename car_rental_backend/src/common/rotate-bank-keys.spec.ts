import { BankEncryptionService } from './bank-encryption.service';
import { ConfigService } from '@nestjs/config';

describe('Phase 5: Multi-Key Bank Encryption Rotation', () => {
  let encryptionService: BankEncryptionService;
  const keyV1 = 'dev_bank_encryption_key_32_bytes_hex_1234567890abcdef1234567890abcdef';
  const keyV2 = 'second_rotation_key_32_bytes_hex_abcdef1234567890abcdef1234567890';

  beforeEach(() => {
    const configService = new ConfigService({
      BANK_ENCRYPTION_KEY: keyV1,
      BANK_ENCRYPTION_KEY_V2: keyV2,
      BANK_ENCRYPTION_ACTIVE_VERSION: 'v1',
    });
    encryptionService = new BankEncryptionService(configService);
  });

  it('encrypts under V1 and decrypts correctly under V1', () => {
    const plaintext = JSON.stringify({
      accountNumber: '98765432109876',
      ifscCode: 'HDFC0001234',
      accountHolderName: 'Rahul Motors',
    });

    const encryptedV1 = encryptionService.encrypt(plaintext, 'v1');
    expect(encryptedV1).toBeDefined();
    expect(encryptedV1!.startsWith('enc:v1:')).toBe(true);

    const decrypted = encryptionService.decrypt(encryptedV1);
    expect(decrypted).toBe(plaintext);
  });

  it('re-encrypts from V1 to V2 seamlessly without data loss', () => {
    const plaintext = JSON.stringify({
      accountNumber: '11223344556677',
      ifscCode: 'ICIC0005678',
      accountHolderName: 'Priya Travels',
    });

    const encryptedV1 = encryptionService.encrypt(plaintext, 'v1');
    expect(encryptedV1!.startsWith('enc:v1:')).toBe(true);

    const reencryptedV2 = encryptionService.reencrypt(encryptedV1, 'v2');
    expect(reencryptedV2).toBeDefined();
    expect(reencryptedV2!.startsWith('enc:v2:')).toBe(true);
    expect(reencryptedV2).not.toEqual(encryptedV1);

    // Decrypting V2 ciphertext succeeds using V2 key in registry
    const decryptedV2 = encryptionService.decrypt(reencryptedV2);
    expect(decryptedV2).toBe(plaintext);
  });

  it('masks V1 and V2 ciphertexts identically', () => {
    const plaintext = JSON.stringify({
      accountNumber: '99887766554433',
      ifscCode: 'SBIN0009999',
    });

    const encV1 = encryptionService.encrypt(plaintext, 'v1');
    const encV2 = encryptionService.encrypt(plaintext, 'v2');

    const maskedV1 = encryptionService.mask(encV1);
    const maskedV2 = encryptionService.mask(encV2);

    expect(maskedV1).toContain('••••••••4433');
    expect(maskedV2).toContain('••••••••4433');
  });
});

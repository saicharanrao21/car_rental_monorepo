import { runBackfill } from '../../scripts/backfill-bank-encryption';
import { BankEncryptionService } from './bank-encryption.service';
import { ConfigService } from '@nestjs/config';

describe('Phase 4B.1: Existing Bank Data Encryption Backfill Migration', () => {
  let encryptionService: BankEncryptionService;
  let mockPrisma: any;
  let mockVendors: any[];

  beforeEach(() => {
    const mockConfig = {
      get: jest.fn().mockImplementation((key: string) => {
        if (key === 'BANK_ENCRYPTION_KEY')
          return '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        if (key === 'NODE_ENV') return 'development';
        return undefined;
      }),
    };

    encryptionService = new BankEncryptionService(mockConfig as ConfigService);

    mockVendors = [
      {
        id: 'vendor_01',
        businessName: 'Vendor 1',
        bankDetails: 'HDFC Bank - 50100234567890',
      },
      {
        id: 'vendor_02',
        businessName: 'Vendor 2',
        bankDetails: 'ICICI Bank - 000401234567',
      },
      {
        id: 'vendor_03',
        businessName: 'Vendor 3',
        bankDetails: 'enc:v1:0123456789abcdef01234567:0123456789abcdef0123456789abcdef:12345678', // Already encrypted
      },
      {
        id: 'vendor_04',
        businessName: 'Vendor 4',
        bankDetails: null, // Null bank details
      },
      {
        id: 'vendor_05',
        businessName: 'Vendor 5',
        bankDetails: '', // Empty bank details
      },
    ];

    mockPrisma = {
      vendor: {
        count: jest.fn().mockImplementation(() => Promise.resolve(mockVendors.length)),
        findMany: jest.fn().mockImplementation((args?: any) => {
          let list = [...mockVendors];
          if (args?.where?.bankDetails?.not === null && args?.where?.NOT?.bankDetails?.startsWith === 'enc:v1:') {
            list = list.filter((v) => v.bankDetails !== null && !v.bankDetails.startsWith('enc:v1:'));
          } else if (args?.where?.bankDetails?.not === null) {
            list = list.filter((v) => v.bankDetails !== null);
          }
          if (args?.where?.id?.gt) {
            list = list.filter((v) => v.id > args.where.id.gt);
          }
          if (args?.take) {
            list = list.slice(0, args.take);
          }
          return Promise.resolve(list);
        }),
        updateMany: jest.fn().mockImplementation((args: any) => {
          const target = mockVendors.find(
            (v) => v.id === args.where.id && v.bankDetails === args.where.bankDetails,
          );
          if (target) {
            target.bankDetails = args.data.bankDetails;
            return Promise.resolve({ count: 1 });
          }
          return Promise.resolve({ count: 0 });
        }),
      },
    };
  });

  it('1. converts legacy plaintext records to encrypted AES-256-GCM ciphertext', async () => {
    const result = await runBackfill(mockPrisma, encryptionService, { dryRun: false, batchSize: 10 });

    expect(result.totalVendors).toBe(5);
    expect(result.alreadyEncryptedCount).toBe(1);
    expect(result.plaintextCount).toBe(2);
    expect(result.migratedCount).toBe(2);
    expect(result.failedCount).toBe(0);
    expect(result.remainingPlaintextCount).toBe(0);

    // Verify vendor_01 and vendor_02 are now encrypted
    expect(mockVendors[0].bankDetails).toMatch(/^enc:v1:/);
    expect(mockVendors[1].bankDetails).toMatch(/^enc:v1:/);

    // Decrypting recovers original plaintext
    expect(encryptionService.decrypt(mockVendors[0].bankDetails)).toBe('HDFC Bank - 50100234567890');
    expect(encryptionService.decrypt(mockVendors[1].bankDetails)).toBe('ICICI Bank - 000401234567');
  });

  it('2. leaves already encrypted, null, and empty records unchanged (idempotent)', async () => {
    const originalEncrypted = mockVendors[2].bankDetails;
    await runBackfill(mockPrisma, encryptionService, { dryRun: false });

    expect(mockVendors[2].bankDetails).toBe(originalEncrypted);
    expect(mockVendors[3].bankDetails).toBeNull();
    expect(mockVendors[4].bankDetails).toBe('');
  });

  it('3. performs zero database mutations in dry-run mode (--dry-run)', async () => {
    const originalV1 = mockVendors[0].bankDetails;
    const originalV2 = mockVendors[1].bankDetails;

    const result = await runBackfill(mockPrisma, encryptionService, { dryRun: true });

    expect(result.plaintextCount).toBe(2);
    expect(result.migratedCount).toBe(0);
    expect(mockPrisma.vendor.updateMany).not.toHaveBeenCalled();

    expect(mockVendors[0].bankDetails).toBe(originalV1);
    expect(mockVendors[1].bankDetails).toBe(originalV2);
  });

  it('4. prevents overwriting concurrent vendor updates via optimistic concurrency check', async () => {
    // Override updateMany to simulate concurrent modification on vendor_01
    mockPrisma.vendor.updateMany = jest.fn().mockImplementation((args: any) => {
      if (args.where.id === 'vendor_01') {
        // Vendor updated their bank details through API before backfill updateMany executed
        return Promise.resolve({ count: 0 });
      }
      return Promise.resolve({ count: 1 });
    });

    const result = await runBackfill(mockPrisma, encryptionService, { dryRun: false });

    expect(result.skippedConcurrentCount).toBe(1);
    expect(result.migratedCount).toBe(1);
  });
});

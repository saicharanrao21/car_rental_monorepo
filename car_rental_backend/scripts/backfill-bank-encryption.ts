import { PrismaClient } from '@prisma/client';
import { ConfigService } from '@nestjs/config';
import { BankEncryptionService } from '../src/common/bank-encryption.service';

export interface BackfillOptions {
  dryRun?: boolean;
  batchSize?: number;
}

export interface BackfillResult {
  totalVendors: number;
  nullOrEmptyCount: number;
  alreadyEncryptedCount: number;
  plaintextCount: number;
  migratedCount: number;
  skippedConcurrentCount: number;
  failedCount: number;
  remainingPlaintextCount: number;
  durationMs: number;
}

export async function runBackfill(
  prisma: PrismaClient,
  encryptionService: BankEncryptionService,
  options: BackfillOptions = {},
): Promise<BackfillResult> {
  const startTime = Date.now();
  const dryRun = options.dryRun ?? false;
  const batchSize = options.batchSize ?? 100;

  // 1. Pre-Migration Inventory
  const [totalVendors, allWithBankDetails] = await Promise.all([
    prisma.vendor.count(),
    prisma.vendor.findMany({
      where: { bankDetails: { not: null } },
      select: { id: true, bankDetails: true },
    }),
  ]);

  let alreadyEncryptedCount = 0;
  let plaintextCount = 0;
  let nullOrEmptyCount = totalVendors - allWithBankDetails.length;

  for (const v of allWithBankDetails) {
    if (!v.bankDetails || v.bankDetails.trim() === '') {
      nullOrEmptyCount++;
    } else if (v.bankDetails.startsWith('enc:v1:')) {
      alreadyEncryptedCount++;
    } else {
      plaintextCount++;
    }
  }

  console.log('========================================================');
  console.log('DRIVEGO VENDOR BANK DATA ENCRYPTION BACKFILL');
  console.log('========================================================');
  console.log(`Mode:                     ${dryRun ? '[DRY RUN - No Database Mutations]' : '[LIVE MIGRATION]'}`);
  console.log(`Total Vendors:            ${totalVendors}`);
  console.log(`Already Encrypted:        ${alreadyEncryptedCount}`);
  console.log(`Null / Empty Details:     ${nullOrEmptyCount}`);
  console.log(`Plaintext To Migrate:     ${plaintextCount}`);
  console.log(`Batch Size:               ${batchSize}`);
  console.log('========================================================');

  let migratedCount = 0;
  let skippedConcurrentCount = 0;
  let failedCount = 0;

  if (plaintextCount > 0 && !dryRun) {
    let lastId = '';
    let hasMore = true;

    while (hasMore) {
      const batch = await prisma.vendor.findMany({
        where: {
          id: lastId ? { gt: lastId } : undefined,
          bankDetails: { not: null },
          NOT: { bankDetails: { startsWith: 'enc:v1:' } },
        },
        orderBy: { id: 'asc' },
        take: batchSize,
        select: { id: true, bankDetails: true },
      });

      if (batch.length === 0) {
        hasMore = false;
        break;
      }

      for (const vendor of batch) {
        lastId = vendor.id;

        if (!vendor.bankDetails || vendor.bankDetails.trim() === '' || vendor.bankDetails.startsWith('enc:v1:')) {
          continue;
        }

        try {
          const ciphertext = encryptionService.encrypt(vendor.bankDetails);
          if (!ciphertext) {
            continue;
          }

          // Optimistic Concurrency Check: Update only if bankDetails hasn't changed since read
          const updateResult = await prisma.vendor.updateMany({
            where: {
              id: vendor.id,
              bankDetails: vendor.bankDetails,
            },
            data: {
              bankDetails: ciphertext,
            },
          });

          if (updateResult.count > 0) {
            migratedCount++;
          } else {
            // Concurrent API update occurred
            skippedConcurrentCount++;
          }
        } catch (err: any) {
          failedCount++;
          console.error(`[ERROR] Failed to encrypt vendor ${vendor.id}: ${err.message}`);
        }
      }

      if (batch.length < batchSize) {
        hasMore = false;
      }
    }
  }

  // 3. Post-Migration Verification
  const remainingPlaintext = await prisma.vendor.findMany({
    where: {
      bankDetails: { not: null },
      NOT: { bankDetails: { startsWith: 'enc:v1:' } },
    },
    select: { id: true, bankDetails: true },
  });

  const remainingPlaintextCount = remainingPlaintext.filter(
    (v) => v.bankDetails && v.bankDetails.trim() !== '',
  ).length;

  const durationMs = Date.now() - startTime;

  console.log('========================================================');
  console.log('MIGRATION SUMMARY');
  console.log('========================================================');
  console.log(`Migrated:                 ${migratedCount}`);
  console.log(`Skipped (Concurrent Mod): ${skippedConcurrentCount}`);
  console.log(`Failed:                   ${failedCount}`);
  console.log(`Remaining Plaintext:      ${dryRun ? plaintextCount : remainingPlaintextCount}`);
  console.log(`Duration:                 ${durationMs}ms`);
  console.log('========================================================');

  if (!dryRun) {
    if (remainingPlaintextCount === 0 && failedCount === 0) {
      console.log('[SUCCESS] All vendor bank details are fully encrypted at rest (AES-256-GCM).');
    } else {
      console.warn(`[WARNING] Migration incomplete: ${remainingPlaintextCount} plaintext records remain.`);
    }
  }

  return {
    totalVendors,
    nullOrEmptyCount,
    alreadyEncryptedCount,
    plaintextCount,
    migratedCount,
    skippedConcurrentCount,
    failedCount,
    remainingPlaintextCount: dryRun ? plaintextCount : remainingPlaintextCount,
    durationMs,
  };
}

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const batchSizeArg = args.find((a) => a.startsWith('--batch-size='));
  const batchSize = batchSizeArg ? parseInt(batchSizeArg.split('=')[1], 10) : 100;

  const prisma = new PrismaClient();
  const configService = new ConfigService();
  const encryptionService = new BankEncryptionService(configService);

  try {
    const result = await runBackfill(prisma, encryptionService, { dryRun, batchSize });
    if (!dryRun && (result.remainingPlaintextCount > 0 || result.failedCount > 0)) {
      process.exit(1);
    }
  } catch (err: any) {
    console.error(`[FATAL] Backfill migration failed: ${err.message}`);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main();
}

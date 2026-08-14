import { PrismaClient } from '@prisma/client';
import { ConfigService } from '@nestjs/config';
import { BankEncryptionService } from '../src/common/bank-encryption.service';

/**
 * DRIVEGO BANK DATA KEY ROTATION SCRIPT (Phase 5)
 *
 * Scans all Vendor records encrypted under an older version tag (e.g. enc:v1:)
 * and re-encrypts them under the active version tag (e.g. enc:v2:) using
 * optimistic concurrency control.
 *
 * Usage:
 *   Dry Run: npx ts-node scripts/rotate-bank-keys.ts --dry-run
 *   Live:    npx ts-node scripts/rotate-bank-keys.ts
 */
export async function runKeyRotation(
  prisma: PrismaClient,
  encryptionService: BankEncryptionService,
  options: { isDryRun?: boolean; batchSize?: number; targetVersion?: string } = {},
) {
  const isDryRun = options.isDryRun ?? process.argv.includes('--dry-run');
  const batchSize = options.batchSize ?? 100;
  const targetVersion = options.targetVersion ?? 'v2';

  const startTime = Date.now();

  console.log('========================================================');
  console.log('DRIVEGO VENDOR BANK KEY ROTATION');
  console.log('========================================================');
  console.log(`Mode:                     [${isDryRun ? 'DRY RUN - No Database Mutations' : 'LIVE ROTATION'}]`);
  console.log(`Target Version:           [${targetVersion}]`);
  console.log(`Batch Size:               ${batchSize}`);
  console.log('========================================================');

  const allVendors = await prisma.vendor.findMany({
    select: { id: true, businessName: true, bankDetails: true },
    orderBy: { id: 'asc' },
  });

  const toRotate = allVendors.filter((v) => {
    return v.bankDetails && v.bankDetails.startsWith('enc:') && !v.bankDetails.startsWith(`enc:${targetVersion}:`);
  });

  console.log(`Total Vendors:            ${allVendors.length}`);
  console.log(`Already on ${targetVersion}:          ${allVendors.filter((v) => v.bankDetails?.startsWith(`enc:${targetVersion}:`)).length}`);
  console.log(`Needs Rotation:           ${toRotate.length}`);
  console.log('========================================================');

  let rotatedCount = 0;
  let skippedCount = 0;
  let failedCount = 0;

  for (const vendor of toRotate) {
    try {
      const currentCiphertext = vendor.bankDetails!;
      const newCiphertext = encryptionService.reencrypt(currentCiphertext, targetVersion);

      if (!newCiphertext) {
        failedCount++;
        continue;
      }

      if (!isDryRun) {
        // Optimistic concurrency update
        const result = await prisma.vendor.updateMany({
          where: {
            id: vendor.id,
            bankDetails: currentCiphertext,
          },
          data: {
            bankDetails: newCiphertext,
          },
        });

        if (result.count === 1) {
          rotatedCount++;
        } else {
          console.warn(`[SKIP] Vendor ${vendor.id} modified concurrently.`);
          skippedCount++;
        }
      }
    } catch (err: any) {
      console.error(`[ERROR] Failed to rotate vendor ${vendor.id}:`, err.message);
      failedCount++;
    }
  }

  const durationMs = Date.now() - startTime;

  console.log('========================================================');
  console.log('ROTATION SUMMARY');
  console.log('========================================================');
  console.log(`Rotated:                 ${rotatedCount}`);
  console.log(`Skipped (Concurrent Mod): ${skippedCount}`);
  console.log(`Failed:                   ${failedCount}`);
  console.log(`Duration:                 ${durationMs}ms`);
  console.log('========================================================');

  return {
    total: allVendors.length,
    needsRotation: toRotate.length,
    rotated: rotatedCount,
    skipped: skippedCount,
    failed: failedCount,
    durationMs,
  };
}

if (require.main === module) {
  const prisma = new PrismaClient();
  const configService = new ConfigService();
  const encryptionService = new BankEncryptionService(configService);

  runKeyRotation(prisma, encryptionService)
    .catch((err) => {
      console.error('Fatal Key Rotation Error:', err);
      process.exit(1);
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('========================================================');
  console.log('DRIVEGO LIVE DATABASE FORENSIC INVARIANTS AUDIT');
  console.log('========================================================\n');

  // 1. Entity Counts
  const [
    userCount,
    vendorCount,
    carCount,
    bookingCount,
    paymentCount,
    paymentRefundCount,
    walletCount,
    walletLedgerCount,
    platformLedgerCount,
    corporateAccountCount,
    corporateLedgerCount,
    vendorDepositLedgerCount,
    invoiceCount,
  ] = await Promise.all([
    prisma.user.count(),
    prisma.vendor.count(),
    prisma.car.count(),
    prisma.booking.count(),
    prisma.payment.count(),
    prisma.paymentRefund.count(),
    prisma.wallet.count(),
    prisma.walletLedgerEntry.count(),
    prisma.platformLedgerEntry.count(),
    prisma.corporateAccount.count(),
    prisma.corporateCreditLedgerEntry.count(),
    prisma.vendorDepositLedgerEntry.count(),
    prisma.invoice.count(),
  ]);

  console.log('--- 1. DATABASE RECORD COUNTS ---');
  console.log(`Users:                     ${userCount}`);
  console.log(`Vendors:                   ${vendorCount}`);
  console.log(`Cars:                      ${carCount}`);
  console.log(`Bookings:                  ${bookingCount}`);
  console.log(`Payments:                  ${paymentCount}`);
  console.log(`Payment Refunds:           ${paymentRefundCount}`);
  console.log(`Invoices:                  ${invoiceCount}`);
  console.log(`Wallets:                   ${walletCount}`);
  console.log(`Wallet Ledger Entries:     ${walletLedgerCount}`);
  console.log(`Platform Ledger Entries:   ${platformLedgerCount}`);
  console.log(`Corporate Accounts:        ${corporateAccountCount}`);
  console.log(`Corporate Ledger Entries:  ${corporateLedgerCount}`);
  console.log(`Vendor Deposit Entries:    ${vendorDepositLedgerCount}\n`);

  // 2. Financial Ledger Invariants
  console.log('--- 2. DOUBLE-ENTRY PLATFORM LEDGER AUDIT ---');
  
  if (platformLedgerCount > 0) {
    const platformDebits = await prisma.platformLedgerEntry.aggregate({
      where: { side: 'DEBIT' },
      _sum: { amount: true },
    });
    const platformCredits = await prisma.platformLedgerEntry.aggregate({
      where: { side: 'CREDIT' },
      _sum: { amount: true },
    });
    const debits = platformDebits._sum?.amount?.toNumber() ?? 0;
    const credits = platformCredits._sum?.amount?.toNumber() ?? 0;
    console.log(`Platform Total Debits:   ₹${debits.toFixed(2)}`);
    console.log(`Platform Total Credits:  ₹${credits.toFixed(2)}`);
    console.log(`Ledger Balanced Overall: ${debits === credits ? 'YES (DEBITS == CREDITS)' : 'DISCREPANCY: ' + (credits - debits)}`);

    // Journal-by-Journal Invariant: Every journalId MUST have Debits == Credits
    const journalDiscrepancies = await prisma.$queryRaw<Array<{ journalId: string; debits: number; credits: number; diff: number }>>`
      SELECT 
        "journalId",
        SUM(CASE WHEN side = 'DEBIT' THEN amount ELSE 0 END)::numeric as debits,
        SUM(CASE WHEN side = 'CREDIT' THEN amount ELSE 0 END)::numeric as credits,
        ABS(SUM(CASE WHEN side = 'DEBIT' THEN amount ELSE -amount END))::numeric as diff
      FROM "PlatformLedgerEntry"
      GROUP BY "journalId"
      HAVING ABS(SUM(CASE WHEN side = 'DEBIT' THEN amount ELSE -amount END)) > 0.001
    `;
    console.log(`Unbalanced Journals:     ${journalDiscrepancies.length}`);
    if (journalDiscrepancies.length > 0) {
      console.log('Discrepant Journals:', JSON.stringify(journalDiscrepancies));
    } else {
      console.log('Journal Invariant:       PERFECT (100% of journal batches strictly balance)');
    }
  } else {
    console.log('Platform Ledger Entries: 0 (No platform journal entries recorded yet)');
  }

  // Wallet Ledgers
  console.log('\n--- 2B. WALLET LEDGER AUDIT ---');
  if (walletLedgerCount > 0) {
    const walletDebits = await prisma.walletLedgerEntry.aggregate({
      where: { direction: 'DEBIT' },
      _sum: { amount: true },
    });
    const walletCredits = await prisma.walletLedgerEntry.aggregate({
      where: { direction: 'CREDIT' },
      _sum: { amount: true },
    });
    console.log(`Wallet Ledger Debits:    ₹${walletDebits._sum?.amount?.toNumber() ?? 0}`);
    console.log(`Wallet Ledger Credits:   ₹${walletCredits._sum?.amount?.toNumber() ?? 0}`);
  } else {
    console.log('Wallet Ledger Entries:   0');
  }

  // Corporate Ledgers
  console.log('\n--- 2C. CORPORATE CREDIT AUDIT ---');
  if (corporateAccountCount > 0) {
    const corpAccounts = await prisma.corporateAccount.findMany();
    let corpDiscrepancies = 0;
    for (const ca of corpAccounts) {
      const creditLimit = ca.creditLimit.toNumber();
      const usedCredit = ca.usedCredit.toNumber();
      if (usedCredit > creditLimit) {
        corpDiscrepancies++;
        console.warn(`[WARNING] Corporate Account ${ca.companyName} (${ca.id}) over limit: used=${usedCredit}, limit=${creditLimit}`);
      }
    }
    console.log(`Total Corporate Accounts:     ${corpAccounts.length}`);
    console.log(`Accounts Exceeding Limit:     ${corpDiscrepancies}`);
  }

  // 3. Foreign Key & Orphan Integrity Checks
  console.log('\n--- 3. ORPHAN RECORD AUDIT ---');
  
  const bookingsWithoutCustomer = await prisma.$queryRaw<Array<{ count: bigint }>>`
    SELECT COUNT(*) FROM "Booking" b
    LEFT JOIN "User" u ON b."customerId" = u.id
    WHERE u.id IS NULL
  `;
  const orphanBookingsCust = Number(bookingsWithoutCustomer[0]?.count ?? 0);
  console.log(`Orphan Bookings (Missing Customer): ${orphanBookingsCust}`);

  const bookingsWithoutCar = await prisma.$queryRaw<Array<{ count: bigint }>>`
    SELECT COUNT(*) FROM "Booking" b
    LEFT JOIN "Car" c ON b."carId" = c.id
    WHERE c.id IS NULL
  `;
  const orphanBookingsCar = Number(bookingsWithoutCar[0]?.count ?? 0);
  console.log(`Orphan Bookings (Missing Car):      ${orphanBookingsCar}`);

  const carsWithoutVendor = await prisma.$queryRaw<Array<{ count: bigint }>>`
    SELECT COUNT(*) FROM "Car" c
    LEFT JOIN "Vendor" v ON c."vendorId" = v.id
    WHERE v.id IS NULL
  `;
  const orphanCarsVendor = Number(carsWithoutVendor[0]?.count ?? 0);
  console.log(`Orphan Cars (Missing Vendor):       ${orphanCarsVendor}`);

  const paymentsWithoutBooking = await prisma.$queryRaw<Array<{ count: bigint }>>`
    SELECT COUNT(*) FROM "Payment" p
    LEFT JOIN "Booking" b ON p."bookingId" = b.id
    WHERE b.id IS NULL
  `;
  const orphanPayments = Number(paymentsWithoutBooking[0]?.count ?? 0);
  console.log(`Orphan Payments (Missing Booking):  ${orphanPayments}`);

  // 4. Overlapping Double Bookings Check
  console.log('\n--- 4. CONCURRENCY & OVERLAPPING BOOKINGS AUDIT ---');
  const overlappingBookings = await prisma.$queryRaw<Array<{ b1_id: string; b2_id: string; car_id: string }>>`
    SELECT b1.id as b1_id, b2.id as b2_id, b1."carId" as car_id
    FROM "Booking" b1
    JOIN "Booking" b2 ON b1."carId" = b2."carId" AND b1.id < b2.id
    WHERE b1.status NOT IN ('CANCELLED', 'REFUNDED', 'EXPIRED')
      AND b2.status NOT IN ('CANCELLED', 'REFUNDED', 'EXPIRED')
      AND b1."startDate" < b2."endDate"
      AND b1."endDate" > b2."startDate"
  `;
  console.log(`Active Overlapping Bookings Found:  ${overlappingBookings.length}`);
  if (overlappingBookings.length > 0) {
    console.log('Discrepancies:', JSON.stringify(overlappingBookings));
  } else {
    console.log('Overlap Invariant:                  PERFECT (0 overlapping active reservations)');
  }

  // 5. Payment Amount vs Booking Total Fare + Security Deposit Invariant
  console.log('\n--- 5. PAYMENT VS FARE & DEPOSIT CEILING AUDIT ---');
  const overpaidBookings = await prisma.$queryRaw<Array<{ id: string; totalExpected: number; paidSum: number }>>`
    SELECT 
      b.id, 
      (b."totalFare" + COALESCE(sd.amount, 0))::numeric as "totalExpected", 
      SUM(p.amount)::numeric as "paidSum"
    FROM "Booking" b
    LEFT JOIN "SecurityDeposit" sd ON b.id = sd."bookingId"
    JOIN "Payment" p ON b.id = p."bookingId"
    WHERE p.status IN ('PAID', 'CAPTURED')
    GROUP BY b.id, b."totalFare", sd.amount
    HAVING SUM(p.amount) > (b."totalFare" + COALESCE(sd.amount, 0)) + 0.01
  `;
  console.log(`Discrepant / Overpaid Bookings:      ${overpaidBookings.length}`);
  if (overpaidBookings.length === 0) {
    console.log('Payment Ceiling Invariant:          PERFECT (100% payments match fare + refundable deposit)');
  } else {
    console.log('Discrepancies:', JSON.stringify(overpaidBookings, null, 2));
  }

  console.log('\n========================================================');
  console.log('FORENSIC AUDIT COMPLETE');
  console.log('========================================================');
}

main()
  .catch((e) => {
    console.error('Audit failed with error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

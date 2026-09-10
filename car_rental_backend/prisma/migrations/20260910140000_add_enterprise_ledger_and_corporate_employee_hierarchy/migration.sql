-- AlterEnum
ALTER TYPE "RefundStatus" ADD VALUE IF NOT EXISTS 'RETRYABLE';

-- CreateEnum
CREATE TYPE "LedgerAccountType" AS ENUM ('GATEWAY_CLEARING', 'CUSTOMER_WALLET', 'CUSTOMER_DEPOSIT_ESCROW', 'VENDOR_PAYABLE', 'PLATFORM_COMMISSION_REVENUE', 'TAX_GST_LIABILITY', 'CORPORATE_RECEIVABLE', 'DISPUTE_HOLD');

-- CreateEnum
CREATE TYPE "LedgerEntrySide" AS ENUM ('DEBIT', 'CREDIT');

-- AlterTable Booking
ALTER TABLE "Booking" ADD COLUMN IF NOT EXISTS "corporateAccountId" TEXT;

-- CreateTable PlatformLedgerEntry
CREATE TABLE "PlatformLedgerEntry" (
    "id" TEXT NOT NULL,
    "journalId" TEXT NOT NULL,
    "accountType" "LedgerAccountType" NOT NULL,
    "accountEntityId" TEXT,
    "side" "LedgerEntrySide" NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "bookingId" TEXT,
    "paymentId" TEXT,
    "payoutId" TEXT,
    "referenceType" TEXT NOT NULL,
    "referenceId" TEXT NOT NULL,
    "narration" TEXT NOT NULL,
    "metadata" JSONB,
    "idempotencyKey" TEXT,
    "postedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PlatformLedgerEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable CorporateEmployee
CREATE TABLE "CorporateEmployee" (
    "id" TEXT NOT NULL,
    "corporateAccountId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "employeeCode" TEXT,
    "department" TEXT,
    "spendingLimitMonthly" DECIMAL(10,2),
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CorporateEmployee_pkey" PRIMARY KEY ("id")
);

-- CreateTable CorporateCreditLedgerEntry
CREATE TABLE "CorporateCreditLedgerEntry" (
    "id" TEXT NOT NULL,
    "corporateAccountId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "bookingId" TEXT,
    "type" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "balanceAfter" DECIMAL(12,2) NOT NULL,
    "referenceKey" TEXT,
    "notes" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CorporateCreditLedgerEntry_pkey" PRIMARY KEY ("id")
);

-- CreateIndexes on PlatformLedgerEntry
CREATE UNIQUE INDEX "PlatformLedgerEntry_idempotencyKey_key" ON "PlatformLedgerEntry"("idempotencyKey");
CREATE INDEX "PlatformLedgerEntry_journalId_idx" ON "PlatformLedgerEntry"("journalId");
CREATE INDEX "PlatformLedgerEntry_accountType_accountEntityId_idx" ON "PlatformLedgerEntry"("accountType", "accountEntityId");
CREATE INDEX "PlatformLedgerEntry_bookingId_idx" ON "PlatformLedgerEntry"("bookingId");
CREATE INDEX "PlatformLedgerEntry_paymentId_idx" ON "PlatformLedgerEntry"("paymentId");
CREATE INDEX "PlatformLedgerEntry_payoutId_idx" ON "PlatformLedgerEntry"("payoutId");
CREATE INDEX "PlatformLedgerEntry_referenceType_referenceId_idx" ON "PlatformLedgerEntry"("referenceType", "referenceId");
CREATE INDEX "PlatformLedgerEntry_postedAt_idx" ON "PlatformLedgerEntry"("postedAt");

-- CreateIndexes on CorporateEmployee
CREATE UNIQUE INDEX "CorporateEmployee_corporateAccountId_userId_key" ON "CorporateEmployee"("corporateAccountId", "userId");
CREATE INDEX "CorporateEmployee_userId_idx" ON "CorporateEmployee"("userId");
CREATE INDEX "CorporateEmployee_corporateAccountId_isActive_idx" ON "CorporateEmployee"("corporateAccountId", "isActive");

-- CreateIndexes on CorporateCreditLedgerEntry
CREATE UNIQUE INDEX "CorporateCreditLedgerEntry_referenceKey_key" ON "CorporateCreditLedgerEntry"("referenceKey");
CREATE INDEX "CorporateCreditLedgerEntry_corporateAccountId_idx" ON "CorporateCreditLedgerEntry"("corporateAccountId");
CREATE INDEX "CorporateCreditLedgerEntry_bookingId_idx" ON "CorporateCreditLedgerEntry"("bookingId");
CREATE INDEX "CorporateCreditLedgerEntry_userId_idx" ON "CorporateCreditLedgerEntry"("userId");

-- CreateIndex on CorporateAccount companyName
CREATE INDEX IF NOT EXISTS "CorporateAccount_companyName_idx" ON "CorporateAccount"("companyName");

-- CreateIndex on Booking corporateAccountId
CREATE INDEX IF NOT EXISTS "Booking_corporateAccountId_idx" ON "Booking"("corporateAccountId");

-- AddForeignKeys
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_corporateAccountId_fkey" FOREIGN KEY ("corporateAccountId") REFERENCES "CorporateAccount"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "PlatformLedgerEntry" ADD CONSTRAINT "PlatformLedgerEntry_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "PlatformLedgerEntry" ADD CONSTRAINT "PlatformLedgerEntry_paymentId_fkey" FOREIGN KEY ("paymentId") REFERENCES "Payment"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "PlatformLedgerEntry" ADD CONSTRAINT "PlatformLedgerEntry_payoutId_fkey" FOREIGN KEY ("payoutId") REFERENCES "Payout"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "CorporateEmployee" ADD CONSTRAINT "CorporateEmployee_corporateAccountId_fkey" FOREIGN KEY ("corporateAccountId") REFERENCES "CorporateAccount"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CorporateEmployee" ADD CONSTRAINT "CorporateEmployee_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CorporateCreditLedgerEntry" ADD CONSTRAINT "CorporateCreditLedgerEntry_corporateAccountId_fkey" FOREIGN KEY ("corporateAccountId") REFERENCES "CorporateAccount"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CorporateCreditLedgerEntry" ADD CONSTRAINT "CorporateCreditLedgerEntry_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE SET NULL ON UPDATE CASCADE;

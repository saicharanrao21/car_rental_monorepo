-- AlterEnum
ALTER TYPE "VendorDepositStatus" ADD VALUE IF NOT EXISTS 'NOT_REQUIRED';
ALTER TYPE "VendorDepositStatus" ADD VALUE IF NOT EXISTS 'PAYMENT_INITIATED';
ALTER TYPE "VendorDepositStatus" ADD VALUE IF NOT EXISTS 'PAYMENT_FAILED';
ALTER TYPE "VendorDepositStatus" ADD VALUE IF NOT EXISTS 'REFUND_PENDING';
ALTER TYPE "VendorDepositStatus" ADD VALUE IF NOT EXISTS 'PARTIALLY_REFUNDED';
ALTER TYPE "VendorDepositStatus" ADD VALUE IF NOT EXISTS 'REVIEW_REQUIRED';

-- AlterTable
ALTER TABLE "VendorSecurityDeposit" ADD COLUMN IF NOT EXISTS "provider" TEXT DEFAULT 'RAZORPAY';
ALTER TABLE "VendorSecurityDeposit" ADD COLUMN IF NOT EXISTS "providerOrderId" TEXT;
ALTER TABLE "VendorSecurityDeposit" ADD COLUMN IF NOT EXISTS "providerPaymentId" TEXT;
ALTER TABLE "VendorSecurityDeposit" ADD COLUMN IF NOT EXISTS "providerSignature" TEXT;
ALTER TABLE "VendorSecurityDeposit" ADD COLUMN IF NOT EXISTS "policyVersion" INTEGER DEFAULT 1;
ALTER TABLE "VendorSecurityDeposit" ADD COLUMN IF NOT EXISTS "refundAmount" DECIMAL(10,2) DEFAULT 0;
ALTER TABLE "VendorSecurityDeposit" ADD COLUMN IF NOT EXISTS "refundStatus" TEXT DEFAULT 'NONE';
ALTER TABLE "VendorSecurityDeposit" ADD COLUMN IF NOT EXISTS "isExempt" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "VendorSecurityDeposit" ADD COLUMN IF NOT EXISTS "exemptionReason" TEXT;
ALTER TABLE "VendorSecurityDeposit" ADD COLUMN IF NOT EXISTS "exemptedBy" TEXT;
ALTER TABLE "VendorSecurityDeposit" ADD COLUMN IF NOT EXISTS "exemptedAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE IF NOT EXISTS "VendorDepositPolicy" (
    "id" TEXT NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "isRequired" BOOLEAN NOT NULL DEFAULT true,
    "amount" DECIMAL(10,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "refundPolicy" TEXT NOT NULL DEFAULT 'REFUNDABLE',
    "description" TEXT,
    "refundConditions" TEXT,
    "paymentProvider" TEXT NOT NULL DEFAULT 'RAZORPAY',
    "deadlineDays" INTEGER,
    "exemptions" JSONB,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "effectiveFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VendorDepositPolicy_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "VendorSecurityDeposit_providerOrderId_key" ON "VendorSecurityDeposit"("providerOrderId");
CREATE INDEX IF NOT EXISTS "VendorSecurityDeposit_providerOrderId_idx" ON "VendorSecurityDeposit"("providerOrderId");
CREATE INDEX IF NOT EXISTS "VendorSecurityDeposit_providerPaymentId_idx" ON "VendorSecurityDeposit"("providerPaymentId");

CREATE INDEX IF NOT EXISTS "VendorDepositPolicy_isActive_idx" ON "VendorDepositPolicy"("isActive");
CREATE INDEX IF NOT EXISTS "VendorDepositPolicy_version_idx" ON "VendorDepositPolicy"("version");

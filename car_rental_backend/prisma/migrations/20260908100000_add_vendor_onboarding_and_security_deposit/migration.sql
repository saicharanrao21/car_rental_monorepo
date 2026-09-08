-- CreateEnum
CREATE TYPE "RequirementCategory" AS ENUM ('DOCUMENT', 'MONETARY', 'PHYSICAL_ASSET', 'VERIFICATION', 'OTHER');

-- CreateEnum
CREATE TYPE "RequirementScope" AS ENUM ('GLOBAL', 'VENDOR_SPECIFIC', 'VEHICLE_CATEGORY', 'SERVICE_AREA');

-- CreateEnum
CREATE TYPE "RequirementFulfillmentStatus" AS ENUM ('PENDING', 'SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'EXPIRED', 'WAIVED');

-- CreateEnum
CREATE TYPE "VendorDepositStatus" AS ENUM ('REQUIRED', 'PENDING', 'PARTIALLY_PAID', 'PAID', 'HELD', 'RELEASED', 'REFUNDED', 'FORFEITED');

-- CreateEnum
CREATE TYPE "VendorDepositTransactionType" AS ENUM ('INITIAL_PAYMENT', 'PARTIAL_PAYMENT', 'TOP_UP', 'RELEASE', 'REFUND', 'FORFEITURE', 'ADMIN_ADJUSTMENT');

-- CreateTable
CREATE TABLE "OnboardingRequirementDefinition" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "category" "RequirementCategory" NOT NULL,
    "isRequired" BOOLEAN NOT NULL DEFAULT true,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "displayOrder" INTEGER NOT NULL DEFAULT 0,
    "scope" "RequirementScope" NOT NULL DEFAULT 'GLOBAL',
    "targetScopeValue" TEXT,
    "version" INTEGER NOT NULL DEFAULT 1,
    "effectiveFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "effectiveTo" TIMESTAMP(3),
    "config" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OnboardingRequirementDefinition_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VendorRequirementState" (
    "id" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "requirementDefinitionId" TEXT NOT NULL,
    "status" "RequirementFulfillmentStatus" NOT NULL DEFAULT 'PENDING',
    "documentId" TEXT,
    "documentNumber" TEXT,
    "issuedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "submissionData" JSONB,
    "submittedAt" TIMESTAMP(3),
    "rejectionReason" TEXT,
    "reviewedByUserId" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "waivedByUserId" TEXT,
    "waivedReason" TEXT,
    "waivedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VendorRequirementState_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VendorSecurityDeposit" (
    "id" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "requiredAmount" DECIMAL(10,2) NOT NULL,
    "paidAmount" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "remainingAmount" DECIMAL(10,2) NOT NULL,
    "status" "VendorDepositStatus" NOT NULL DEFAULT 'REQUIRED',
    "requirementCode" TEXT,
    "requirementVersion" INTEGER,
    "heldAt" TIMESTAMP(3),
    "releasedAt" TIMESTAMP(3),
    "refundedAt" TIMESTAMP(3),
    "forfeitedAt" TIMESTAMP(3),
    "forfeitedReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VendorSecurityDeposit_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VendorDepositLedgerEntry" (
    "id" TEXT NOT NULL,
    "depositId" TEXT NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "direction" "LedgerDirection" NOT NULL,
    "balanceBefore" DECIMAL(10,2) NOT NULL,
    "balanceAfter" DECIMAL(10,2) NOT NULL,
    "transactionType" "VendorDepositTransactionType" NOT NULL,
    "paymentMethod" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "reason" TEXT,
    "actorId" TEXT,
    "actorRole" TEXT,
    "idempotencyKey" TEXT NOT NULL,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VendorDepositLedgerEntry_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "OnboardingRequirementDefinition_code_version_key" ON "OnboardingRequirementDefinition"("code", "version");
CREATE INDEX "OnboardingRequirementDefinition_category_isActive_idx" ON "OnboardingRequirementDefinition"("category", "isActive");
CREATE INDEX "OnboardingRequirementDefinition_scope_targetScopeValue_idx" ON "OnboardingRequirementDefinition"("scope", "targetScopeValue");
CREATE INDEX "OnboardingRequirementDefinition_effectiveFrom_effectiveTo_idx" ON "OnboardingRequirementDefinition"("effectiveFrom", "effectiveTo");

-- CreateIndex
CREATE UNIQUE INDEX "VendorRequirementState_vendorId_requirementDefinitionId_key" ON "VendorRequirementState"("vendorId", "requirementDefinitionId");
CREATE INDEX "VendorRequirementState_vendorId_status_idx" ON "VendorRequirementState"("vendorId", "status");
CREATE INDEX "VendorRequirementState_status_idx" ON "VendorRequirementState"("status");
CREATE INDEX "VendorRequirementState_expiresAt_idx" ON "VendorRequirementState"("expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "VendorSecurityDeposit_vendorId_key" ON "VendorSecurityDeposit"("vendorId");
CREATE INDEX "VendorSecurityDeposit_vendorId_idx" ON "VendorSecurityDeposit"("vendorId");
CREATE INDEX "VendorSecurityDeposit_status_idx" ON "VendorSecurityDeposit"("status");

-- CreateIndex
CREATE UNIQUE INDEX "VendorDepositLedgerEntry_idempotencyKey_key" ON "VendorDepositLedgerEntry"("idempotencyKey");
CREATE INDEX "VendorDepositLedgerEntry_depositId_idx" ON "VendorDepositLedgerEntry"("depositId");
CREATE INDEX "VendorDepositLedgerEntry_transactionType_idx" ON "VendorDepositLedgerEntry"("transactionType");
CREATE INDEX "VendorDepositLedgerEntry_createdAt_idx" ON "VendorDepositLedgerEntry"("createdAt");
CREATE INDEX "VendorDepositLedgerEntry_idempotencyKey_idx" ON "VendorDepositLedgerEntry"("idempotencyKey");

-- AddForeignKey
ALTER TABLE "VendorRequirementState" ADD CONSTRAINT "VendorRequirementState_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VendorRequirementState" ADD CONSTRAINT "VendorRequirementState_requirementDefinitionId_fkey" FOREIGN KEY ("requirementDefinitionId") REFERENCES "OnboardingRequirementDefinition"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VendorRequirementState" ADD CONSTRAINT "VendorRequirementState_documentId_fkey" FOREIGN KEY ("documentId") REFERENCES "Document"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VendorSecurityDeposit" ADD CONSTRAINT "VendorSecurityDeposit_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VendorDepositLedgerEntry" ADD CONSTRAINT "VendorDepositLedgerEntry_depositId_fkey" FOREIGN KEY ("depositId") REFERENCES "VendorSecurityDeposit"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateEnum
CREATE TYPE "WalletStatus" AS ENUM ('ACTIVE', 'FROZEN', 'CLOSED');

-- CreateEnum
CREATE TYPE "WalletBucketType" AS ENUM ('REAL_MONEY', 'PROMOTIONAL', 'REFUND_CREDIT');

-- CreateEnum
CREATE TYPE "LedgerEntryType" AS ENUM ('CUSTOMER_DEPOSIT', 'CHECKOUT_DEBIT', 'BOOKING_REFUND', 'REFERRAL_REWARD', 'LOYALTY_CONVERSION', 'ADMIN_ADJUSTMENT', 'CANCELLATION_CREDIT', 'EXPIRATION');

-- CreateEnum
CREATE TYPE "LedgerDirection" AS ENUM ('CREDIT', 'DEBIT');

-- CreateEnum
CREATE TYPE "ReferralStatus" AS ENUM ('INVITED', 'REGISTERED', 'QUALIFIED', 'REWARDED', 'CANCELLED', 'EXPIRED', 'FRAUD_BLOCKED');

-- CreateEnum
CREATE TYPE "LoyaltyTierCode" AS ENUM ('BRONZE', 'SILVER', 'GOLD', 'PLATINUM');

-- CreateEnum
CREATE TYPE "LoyaltyTransactionType" AS ENUM ('TRIP_COMPLETION_EARNED', 'PROMOTION_BONUS', 'REDEMPTION_TO_WALLET', 'TIER_UPGRADE_BONUS', 'ADMIN_ADJUSTMENT', 'CANCELLATION_REVERSAL', 'POINTS_EXPIRY');

-- AlterTable
ALTER TABLE "User" ADD COLUMN "referralCode" TEXT;

-- AlterTable
ALTER TABLE "Booking" ADD COLUMN "walletDeduction" DECIMAL(10,2) NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "Wallet" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "availableBalance" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "lockedBalance" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "realBalance" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "promoBalance" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "status" "WalletStatus" NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Wallet_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WalletLedgerEntry" (
    "id" TEXT NOT NULL,
    "walletId" TEXT NOT NULL,
    "type" "LedgerEntryType" NOT NULL,
    "direction" "LedgerDirection" NOT NULL,
    "bucket" "WalletBucketType" NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "balanceBefore" DECIMAL(10,2) NOT NULL,
    "balanceAfter" DECIMAL(10,2) NOT NULL,
    "referenceType" TEXT NOT NULL,
    "referenceId" TEXT,
    "idempotencyKey" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3),
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WalletLedgerEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReferralCampaign" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "referrerRewardAmount" DECIMAL(10,2) NOT NULL,
    "refereeRewardAmount" DECIMAL(10,2) NOT NULL,
    "minBookingAmount" DECIMAL(10,2) NOT NULL DEFAULT 1000,
    "city" TEXT,
    "startDate" TIMESTAMP(3),
    "endDate" TIMESTAMP(3),
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "maxReferralsPerUser" INTEGER NOT NULL DEFAULT 20,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReferralCampaign_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReferralAttribution" (
    "id" TEXT NOT NULL,
    "referrerId" TEXT NOT NULL,
    "refereeId" TEXT NOT NULL,
    "campaignId" TEXT,
    "referralCodeUsed" TEXT NOT NULL,
    "status" "ReferralStatus" NOT NULL DEFAULT 'REGISTERED',
    "qualifyingBookingId" TEXT,
    "referrerRewardAmount" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "refereeRewardAmount" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "referrerLedgerEntryId" TEXT,
    "refereeLedgerEntryId" TEXT,
    "fraudFlags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "qualifiedAt" TIMESTAMP(3),
    "rewardedAt" TIMESTAMP(3),

    CONSTRAINT "ReferralAttribution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LoyaltyTier" (
    "id" TEXT NOT NULL,
    "code" "LoyaltyTierCode" NOT NULL,
    "name" TEXT NOT NULL,
    "minPointsRequired" INTEGER NOT NULL DEFAULT 0,
    "pointsMultiplier" DECIMAL(3,2) NOT NULL DEFAULT 1.00,
    "cashbackPercent" DECIMAL(5,2) NOT NULL DEFAULT 1.00,
    "prioritySupport" BOOLEAN NOT NULL DEFAULT false,
    "freeCancellationCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "LoyaltyTier_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LoyaltyAccount" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tierId" TEXT NOT NULL,
    "pointsBalance" INTEGER NOT NULL DEFAULT 0,
    "lifetimePoints" INTEGER NOT NULL DEFAULT 0,
    "tierExpiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "LoyaltyAccount_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LoyaltyTransaction" (
    "id" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "type" "LoyaltyTransactionType" NOT NULL,
    "points" INTEGER NOT NULL,
    "balanceBefore" INTEGER NOT NULL,
    "balanceAfter" INTEGER NOT NULL,
    "referenceType" TEXT NOT NULL,
    "referenceId" TEXT,
    "idempotencyKey" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LoyaltyTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_referralCode_key" ON "User"("referralCode");

-- CreateIndex
CREATE UNIQUE INDEX "Wallet_userId_key" ON "Wallet"("userId");

-- CreateIndex
CREATE INDEX "Wallet_userId_idx" ON "Wallet"("userId");

-- CreateIndex
CREATE INDEX "Wallet_status_idx" ON "Wallet"("status");

-- CreateIndex
CREATE UNIQUE INDEX "WalletLedgerEntry_idempotencyKey_key" ON "WalletLedgerEntry"("idempotencyKey");

-- CreateIndex
CREATE INDEX "WalletLedgerEntry_walletId_idx" ON "WalletLedgerEntry"("walletId");

-- CreateIndex
CREATE INDEX "WalletLedgerEntry_referenceType_referenceId_idx" ON "WalletLedgerEntry"("referenceType", "referenceId");

-- CreateIndex
CREATE INDEX "WalletLedgerEntry_bucket_idx" ON "WalletLedgerEntry"("bucket");

-- CreateIndex
CREATE INDEX "WalletLedgerEntry_createdAt_idx" ON "WalletLedgerEntry"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "ReferralCampaign_code_key" ON "ReferralCampaign"("code");

-- CreateIndex
CREATE INDEX "ReferralCampaign_code_idx" ON "ReferralCampaign"("code");

-- CreateIndex
CREATE INDEX "ReferralCampaign_city_idx" ON "ReferralCampaign"("city");

-- CreateIndex
CREATE INDEX "ReferralCampaign_isActive_idx" ON "ReferralCampaign"("isActive");

-- CreateIndex
CREATE UNIQUE INDEX "ReferralAttribution_refereeId_key" ON "ReferralAttribution"("refereeId");

-- CreateIndex
CREATE INDEX "ReferralAttribution_referrerId_idx" ON "ReferralAttribution"("referrerId");

-- CreateIndex
CREATE INDEX "ReferralAttribution_refereeId_idx" ON "ReferralAttribution"("refereeId");

-- CreateIndex
CREATE INDEX "ReferralAttribution_referralCodeUsed_idx" ON "ReferralAttribution"("referralCodeUsed");

-- CreateIndex
CREATE INDEX "ReferralAttribution_status_idx" ON "ReferralAttribution"("status");

-- CreateIndex
CREATE UNIQUE INDEX "LoyaltyTier_code_key" ON "LoyaltyTier"("code");

-- CreateIndex
CREATE UNIQUE INDEX "LoyaltyAccount_userId_key" ON "LoyaltyAccount"("userId");

-- CreateIndex
CREATE INDEX "LoyaltyAccount_userId_idx" ON "LoyaltyAccount"("userId");

-- CreateIndex
CREATE INDEX "LoyaltyAccount_tierId_idx" ON "LoyaltyAccount"("tierId");

-- CreateIndex
CREATE UNIQUE INDEX "LoyaltyTransaction_idempotencyKey_key" ON "LoyaltyTransaction"("idempotencyKey");

-- CreateIndex
CREATE INDEX "LoyaltyTransaction_accountId_idx" ON "LoyaltyTransaction"("accountId");

-- CreateIndex
CREATE INDEX "LoyaltyTransaction_createdAt_idx" ON "LoyaltyTransaction"("createdAt");

-- AddForeignKey
ALTER TABLE "Wallet" ADD CONSTRAINT "Wallet_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WalletLedgerEntry" ADD CONSTRAINT "WalletLedgerEntry_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralAttribution" ADD CONSTRAINT "ReferralAttribution_referrerId_fkey" FOREIGN KEY ("referrerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralAttribution" ADD CONSTRAINT "ReferralAttribution_refereeId_fkey" FOREIGN KEY ("refereeId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralAttribution" ADD CONSTRAINT "ReferralAttribution_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "ReferralCampaign"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LoyaltyAccount" ADD CONSTRAINT "LoyaltyAccount_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LoyaltyAccount" ADD CONSTRAINT "LoyaltyAccount_tierId_fkey" FOREIGN KEY ("tierId") REFERENCES "LoyaltyTier"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LoyaltyTransaction" ADD CONSTRAINT "LoyaltyTransaction_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "LoyaltyAccount"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "PayoutStatus" ADD VALUE IF NOT EXISTS 'APPROVED';
ALTER TYPE "PayoutStatus" ADD VALUE IF NOT EXISTS 'PROCESSING';
ALTER TYPE "PayoutStatus" ADD VALUE IF NOT EXISTS 'REJECTED';
ALTER TYPE "PayoutStatus" ADD VALUE IF NOT EXISTS 'REVERSED';

-- DropForeignKey
ALTER TABLE "CreditNote" DROP CONSTRAINT "CreditNote_bookingId_fkey";

-- DropForeignKey
ALTER TABLE "CreditNote" DROP CONSTRAINT "CreditNote_invoiceId_fkey";

-- DropForeignKey
ALTER TABLE "Invoice" DROP CONSTRAINT "Invoice_bookingId_fkey";

-- DropForeignKey
ALTER TABLE "Invoice" DROP CONSTRAINT "Invoice_customerId_fkey";

-- DropForeignKey
ALTER TABLE "Invoice" DROP CONSTRAINT "Invoice_vendorId_fkey";

-- DropIndex
DROP INDEX "DepositRule_carCategory_isActive_idx";

-- AlterTable
ALTER TABLE "CreditNote" ALTER COLUMN "amount" SET DATA TYPE DECIMAL(10,2);

-- AlterTable
ALTER TABLE "DepositRule" ALTER COLUMN "depositAmount" SET DATA TYPE DECIMAL(10,2);

-- AlterTable
ALTER TABLE "Invoice" DROP COLUMN "updatedAt",
ALTER COLUMN "baseFare" SET DATA TYPE DECIMAL(10,2),
ALTER COLUMN "platformFee" SET DATA TYPE DECIMAL(10,2),
ALTER COLUMN "gstRate" SET DATA TYPE DECIMAL(5,2),
ALTER COLUMN "gstAmount" SET DATA TYPE DECIMAL(10,2),
ALTER COLUMN "discountAmount" SET DATA TYPE DECIMAL(10,2),
ALTER COLUMN "totalFare" SET DATA TYPE DECIMAL(10,2),
ALTER COLUMN "depositAmount" SET DATA TYPE DECIMAL(10,2);

-- AlterTable
ALTER TABLE "Notification" ADD COLUMN     "actionUrl" TEXT,
ADD COLUMN     "category" TEXT NOT NULL DEFAULT 'GENERAL',
ADD COLUMN     "entityId" TEXT,
ADD COLUMN     "entityType" TEXT,
ADD COLUMN     "eventType" TEXT,
ADD COLUMN     "idempotencyKey" TEXT,
ADD COLUMN     "metadata" JSONB,
ADD COLUMN     "readAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "NotificationPreference" DROP COLUMN "createdAt",
DROP COLUMN "quietHoursEnabled",
DROP COLUMN "quietHoursEnd",
DROP COLUMN "quietHoursStart",
ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AlterTable
ALTER TABLE "Payout" ADD COLUMN     "approvedAt" TIMESTAMP(3),
ADD COLUMN     "approvedByUserId" TEXT,
ADD COLUMN     "bankAccountSnapshot" JSONB,
ADD COLUMN     "feeAmount" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN     "idempotencyKey" TEXT,
ADD COLUMN     "initiatedByUserId" TEXT,
ADD COLUMN     "netAmount" DECIMAL(10,2),
ADD COLUMN     "notes" TEXT,
ADD COLUMN     "payoutNumber" TEXT,
ADD COLUMN     "processedAt" TIMESTAMP(3),
ADD COLUMN     "provider" TEXT NOT NULL DEFAULT 'MANUAL',
ADD COLUMN     "providerFailureReason" TEXT,
ADD COLUMN     "providerFee" DECIMAL(10,2),
ADD COLUMN     "providerTransferId" TEXT,
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- AlterTable
ALTER TABLE "PickupHub" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AlterTable
ALTER TABLE "SupportTicket" ADD COLUMN     "escalatedAt" TIMESTAMP(3),
ADD COLUMN     "escalatedReason" TEXT,
ADD COLUMN     "escalationTier" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN     "firstRespondedAt" TIMESTAMP(3),
ADD COLUMN     "slaFirstResponseDue" TIMESTAMP(3),
ADD COLUMN     "slaResolutionDue" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "UserDevice" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- CreateTable
CREATE TABLE "FinancialAdjustment" (
    "id" TEXT NOT NULL,
    "adjustmentNumber" TEXT NOT NULL,
    "targetType" TEXT NOT NULL,
    "targetId" TEXT NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "direction" "LedgerDirection" NOT NULL,
    "reason" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "referenceId" TEXT,
    "approvedByUserId" TEXT NOT NULL,
    "idempotencyKey" TEXT NOT NULL,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FinancialAdjustment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReconciliationRecord" (
    "id" TEXT NOT NULL,
    "periodStart" TIMESTAMP(3) NOT NULL,
    "periodEnd" TIMESTAMP(3) NOT NULL,
    "status" TEXT NOT NULL,
    "totalTransactions" INTEGER NOT NULL DEFAULT 0,
    "matchedTransactions" INTEGER NOT NULL DEFAULT 0,
    "mismatchedTransactions" INTEGER NOT NULL DEFAULT 0,
    "totalAmountGateway" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "totalAmountInternal" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "discrepancyAmount" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "performedByUserId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReconciliationRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReconciliationException" (
    "id" TEXT NOT NULL,
    "reconciliationRecordId" TEXT,
    "referenceType" TEXT NOT NULL,
    "referenceId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "gatewayAmount" DECIMAL(10,2),
    "internalAmount" DECIMAL(10,2),
    "gatewayStatus" TEXT,
    "internalStatus" TEXT,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "resolutionNotes" TEXT,
    "resolvedByUserId" TEXT,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReconciliationException_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SystemConfig" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "category" TEXT NOT NULL DEFAULT 'GENERAL',
    "description" TEXT,
    "isPublic" BOOLEAN NOT NULL DEFAULT false,
    "updatedBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SystemConfig_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PromotionalCampaign" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" TEXT NOT NULL DEFAULT 'GENERAL',
    "city" TEXT,
    "carCategory" "CarCategory",
    "discountType" "DiscountType" NOT NULL DEFAULT 'PERCENTAGE',
    "discountValue" DECIMAL(10,2) NOT NULL,
    "maxDiscountAmount" DECIMAL(10,2),
    "minBookingAmount" DECIMAL(10,2),
    "budget" DECIMAL(10,2),
    "spentBudget" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "redemptionCount" INTEGER NOT NULL DEFAULT 0,
    "maxRedemptions" INTEGER,
    "startDate" TIMESTAMP(3),
    "endDate" TIMESTAMP(3),
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PromotionalCampaign_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SponsoredCampaign" (
    "id" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "carId" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "boostMultiplier" DOUBLE PRECISION NOT NULL DEFAULT 1.25,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "impressionsCount" INTEGER NOT NULL DEFAULT 0,
    "clicksCount" INTEGER NOT NULL DEFAULT 0,
    "bookingsCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SponsoredCampaign_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeaturedListing" (
    "id" TEXT NOT NULL,
    "carId" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "priority" INTEGER NOT NULL DEFAULT 1,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FeaturedListing_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BookingAttribution" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'ORGANIC',
    "campaignId" TEXT,
    "sponsoredCampaignId" TEXT,
    "referralAttributionId" TEXT,
    "couponId" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BookingAttribution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnalyticsEvent" (
    "id" TEXT NOT NULL,
    "eventType" TEXT NOT NULL,
    "userId" TEXT,
    "vendorId" TEXT,
    "carId" TEXT,
    "bookingId" TEXT,
    "city" TEXT,
    "sessionId" TEXT,
    "platform" TEXT,
    "source" TEXT,
    "metadata" JSONB,
    "idempotencyKey" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AnalyticsEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DailyMarketplaceMetric" (
    "id" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "totalSearches" INTEGER NOT NULL DEFAULT 0,
    "totalViews" INTEGER NOT NULL DEFAULT 0,
    "totalBookings" INTEGER NOT NULL DEFAULT 0,
    "completedTrips" INTEGER NOT NULL DEFAULT 0,
    "cancelledBookings" INTEGER NOT NULL DEFAULT 0,
    "grossMerchandiseValue" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "platformRevenue" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "vendorPayable" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "refundTotal" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "activeCustomers" INTEGER NOT NULL DEFAULT 0,
    "activeVendors" INTEGER NOT NULL DEFAULT 0,
    "activeFleet" INTEGER NOT NULL DEFAULT 0,
    "avgUtilizationRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DailyMarketplaceMetric_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DailyCityMetric" (
    "id" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "city" TEXT NOT NULL,
    "searches" INTEGER NOT NULL DEFAULT 0,
    "noResultSearches" INTEGER NOT NULL DEFAULT 0,
    "bookings" INTEGER NOT NULL DEFAULT 0,
    "completedTrips" INTEGER NOT NULL DEFAULT 0,
    "cancelledBookings" INTEGER NOT NULL DEFAULT 0,
    "gmv" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "platformRevenue" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "activeCars" INTEGER NOT NULL DEFAULT 0,
    "utilizationRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DailyCityMetric_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunicationMessage" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT,
    "vendorId" TEXT,
    "branchId" TEXT,
    "userId" TEXT,
    "recipient" TEXT NOT NULL,
    "channel" TEXT NOT NULL,
    "messageType" TEXT NOT NULL,
    "priority" TEXT NOT NULL DEFAULT 'NORMAL',
    "status" TEXT NOT NULL DEFAULT 'CREATED',
    "templateName" TEXT,
    "language" TEXT NOT NULL DEFAULT 'en',
    "providerId" TEXT,
    "providerMessageId" TEXT,
    "idempotencyKey" TEXT,
    "correlationId" TEXT,
    "cost" DECIMAL(10,4),
    "currency" TEXT DEFAULT 'INR',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "deliveredAt" TIMESTAMP(3),
    "readAt" TIMESTAMP(3),
    "failedAt" TIMESTAMP(3),
    "lastError" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunicationMessage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OtpChallenge" (
    "id" TEXT NOT NULL,
    "identifier" TEXT NOT NULL,
    "purpose" TEXT NOT NULL,
    "channel" TEXT NOT NULL,
    "otpHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "verifiedAt" TIMESTAMP(3),
    "attemptCount" INTEGER NOT NULL DEFAULT 0,
    "maxAttempts" INTEGER NOT NULL DEFAULT 3,
    "resendCount" INTEGER NOT NULL DEFAULT 0,
    "riskScore" DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    "deviceFingerprint" TEXT,
    "ipAddress" TEXT,
    "providerId" TEXT,
    "communicationId" TEXT,
    "idempotencyKey" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OtpChallenge_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunicationConsent" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "identifier" TEXT NOT NULL,
    "channel" TEXT NOT NULL,
    "marketingAllowed" BOOLEAN NOT NULL DEFAULT false,
    "transactionalAllowed" BOOLEAN NOT NULL DEFAULT true,
    "dndRegistered" BOOLEAN NOT NULL DEFAULT false,
    "optedOutAt" TIMESTAMP(3),
    "optInSource" TEXT,
    "ipAddress" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunicationConsent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "FinancialAdjustment_adjustmentNumber_key" ON "FinancialAdjustment"("adjustmentNumber");

-- CreateIndex
CREATE UNIQUE INDEX "FinancialAdjustment_idempotencyKey_key" ON "FinancialAdjustment"("idempotencyKey");

-- CreateIndex
CREATE INDEX "FinancialAdjustment_targetType_targetId_idx" ON "FinancialAdjustment"("targetType", "targetId");

-- CreateIndex
CREATE INDEX "FinancialAdjustment_approvedByUserId_idx" ON "FinancialAdjustment"("approvedByUserId");

-- CreateIndex
CREATE INDEX "FinancialAdjustment_createdAt_idx" ON "FinancialAdjustment"("createdAt");

-- CreateIndex
CREATE INDEX "ReconciliationRecord_createdAt_idx" ON "ReconciliationRecord"("createdAt");

-- CreateIndex
CREATE INDEX "ReconciliationRecord_status_idx" ON "ReconciliationRecord"("status");

-- CreateIndex
CREATE INDEX "ReconciliationException_referenceType_referenceId_idx" ON "ReconciliationException"("referenceType", "referenceId");

-- CreateIndex
CREATE INDEX "ReconciliationException_status_idx" ON "ReconciliationException"("status");

-- CreateIndex
CREATE INDEX "ReconciliationException_type_idx" ON "ReconciliationException"("type");

-- CreateIndex
CREATE INDEX "ReconciliationException_reconciliationRecordId_idx" ON "ReconciliationException"("reconciliationRecordId");

-- CreateIndex
CREATE UNIQUE INDEX "SystemConfig_key_key" ON "SystemConfig"("key");

-- CreateIndex
CREATE INDEX "SystemConfig_category_idx" ON "SystemConfig"("category");

-- CreateIndex
CREATE INDEX "SystemConfig_isPublic_idx" ON "SystemConfig"("isPublic");

-- CreateIndex
CREATE UNIQUE INDEX "PromotionalCampaign_code_key" ON "PromotionalCampaign"("code");

-- CreateIndex
CREATE INDEX "PromotionalCampaign_code_idx" ON "PromotionalCampaign"("code");

-- CreateIndex
CREATE INDEX "PromotionalCampaign_type_idx" ON "PromotionalCampaign"("type");

-- CreateIndex
CREATE INDEX "PromotionalCampaign_city_idx" ON "PromotionalCampaign"("city");

-- CreateIndex
CREATE INDEX "PromotionalCampaign_isActive_idx" ON "PromotionalCampaign"("isActive");

-- CreateIndex
CREATE INDEX "SponsoredCampaign_vendorId_idx" ON "SponsoredCampaign"("vendorId");

-- CreateIndex
CREATE INDEX "SponsoredCampaign_carId_idx" ON "SponsoredCampaign"("carId");

-- CreateIndex
CREATE INDEX "SponsoredCampaign_city_status_idx" ON "SponsoredCampaign"("city", "status");

-- CreateIndex
CREATE INDEX "SponsoredCampaign_status_startDate_endDate_idx" ON "SponsoredCampaign"("status", "startDate", "endDate");

-- CreateIndex
CREATE INDEX "FeaturedListing_carId_idx" ON "FeaturedListing"("carId");

-- CreateIndex
CREATE INDEX "FeaturedListing_city_isActive_idx" ON "FeaturedListing"("city", "isActive");

-- CreateIndex
CREATE INDEX "FeaturedListing_isActive_startDate_endDate_idx" ON "FeaturedListing"("isActive", "startDate", "endDate");

-- CreateIndex
CREATE UNIQUE INDEX "BookingAttribution_bookingId_key" ON "BookingAttribution"("bookingId");

-- CreateIndex
CREATE INDEX "BookingAttribution_bookingId_idx" ON "BookingAttribution"("bookingId");

-- CreateIndex
CREATE INDEX "BookingAttribution_source_idx" ON "BookingAttribution"("source");

-- CreateIndex
CREATE INDEX "BookingAttribution_campaignId_idx" ON "BookingAttribution"("campaignId");

-- CreateIndex
CREATE INDEX "BookingAttribution_sponsoredCampaignId_idx" ON "BookingAttribution"("sponsoredCampaignId");

-- CreateIndex
CREATE UNIQUE INDEX "AnalyticsEvent_idempotencyKey_key" ON "AnalyticsEvent"("idempotencyKey");

-- CreateIndex
CREATE INDEX "AnalyticsEvent_eventType_createdAt_idx" ON "AnalyticsEvent"("eventType", "createdAt");

-- CreateIndex
CREATE INDEX "AnalyticsEvent_userId_createdAt_idx" ON "AnalyticsEvent"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "AnalyticsEvent_vendorId_createdAt_idx" ON "AnalyticsEvent"("vendorId", "createdAt");

-- CreateIndex
CREATE INDEX "AnalyticsEvent_carId_createdAt_idx" ON "AnalyticsEvent"("carId", "createdAt");

-- CreateIndex
CREATE INDEX "AnalyticsEvent_city_createdAt_idx" ON "AnalyticsEvent"("city", "createdAt");

-- CreateIndex
CREATE INDEX "AnalyticsEvent_createdAt_idx" ON "AnalyticsEvent"("createdAt");

-- CreateIndex
CREATE INDEX "AnalyticsEvent_idempotencyKey_idx" ON "AnalyticsEvent"("idempotencyKey");

-- CreateIndex
CREATE UNIQUE INDEX "DailyMarketplaceMetric_date_key" ON "DailyMarketplaceMetric"("date");

-- CreateIndex
CREATE INDEX "DailyMarketplaceMetric_date_idx" ON "DailyMarketplaceMetric"("date");

-- CreateIndex
CREATE INDEX "DailyCityMetric_city_date_idx" ON "DailyCityMetric"("city", "date");

-- CreateIndex
CREATE INDEX "DailyCityMetric_date_idx" ON "DailyCityMetric"("date");

-- CreateIndex
CREATE UNIQUE INDEX "DailyCityMetric_date_city_key" ON "DailyCityMetric"("date", "city");

-- CreateIndex
CREATE UNIQUE INDEX "CommunicationMessage_idempotencyKey_key" ON "CommunicationMessage"("idempotencyKey");

-- CreateIndex
CREATE INDEX "CommunicationMessage_recipient_channel_idx" ON "CommunicationMessage"("recipient", "channel");

-- CreateIndex
CREATE INDEX "CommunicationMessage_providerId_status_idx" ON "CommunicationMessage"("providerId", "status");

-- CreateIndex
CREATE INDEX "CommunicationMessage_tenantId_vendorId_idx" ON "CommunicationMessage"("tenantId", "vendorId");

-- CreateIndex
CREATE INDEX "CommunicationMessage_createdAt_idx" ON "CommunicationMessage"("createdAt");

-- CreateIndex
CREATE INDEX "CommunicationMessage_idempotencyKey_idx" ON "CommunicationMessage"("idempotencyKey");

-- CreateIndex
CREATE UNIQUE INDEX "OtpChallenge_idempotencyKey_key" ON "OtpChallenge"("idempotencyKey");

-- CreateIndex
CREATE INDEX "OtpChallenge_identifier_purpose_verified_idx" ON "OtpChallenge"("identifier", "purpose", "verified");

-- CreateIndex
CREATE INDEX "OtpChallenge_expiresAt_idx" ON "OtpChallenge"("expiresAt");

-- CreateIndex
CREATE INDEX "OtpChallenge_createdAt_idx" ON "OtpChallenge"("createdAt");

-- CreateIndex
CREATE INDEX "CommunicationConsent_userId_idx" ON "CommunicationConsent"("userId");

-- CreateIndex
CREATE INDEX "CommunicationConsent_identifier_idx" ON "CommunicationConsent"("identifier");

-- CreateIndex
CREATE UNIQUE INDEX "CommunicationConsent_identifier_channel_key" ON "CommunicationConsent"("identifier", "channel");

-- CreateIndex
CREATE INDEX "AuditLog_targetType_targetId_idx" ON "AuditLog"("targetType", "targetId");

-- CreateIndex
CREATE INDEX "AuditLog_createdAt_idx" ON "AuditLog"("createdAt");

-- CreateIndex
CREATE INDEX "Booking_createdAt_idx" ON "Booking"("createdAt");

-- CreateIndex
CREATE INDEX "Booking_customerId_status_idx" ON "Booking"("customerId", "status");

-- CreateIndex
CREATE INDEX "Booking_vendorId_status_idx" ON "Booking"("vendorId", "status");

-- CreateIndex
CREATE INDEX "Booking_status_createdAt_idx" ON "Booking"("status", "createdAt");

-- CreateIndex
CREATE INDEX "Car_vendorId_isAvailable_idx" ON "Car"("vendorId", "isAvailable");

-- CreateIndex
CREATE INDEX "Car_type_pricePerDay_idx" ON "Car"("type", "pricePerDay");

-- CreateIndex
CREATE INDEX "DepositRule_carCategory_idx" ON "DepositRule"("carCategory");

-- CreateIndex
CREATE UNIQUE INDEX "Notification_idempotencyKey_key" ON "Notification"("idempotencyKey");

-- CreateIndex
CREATE INDEX "Notification_userId_isRead_createdAt_idx" ON "Notification"("userId", "isRead", "createdAt");

-- CreateIndex
CREATE INDEX "Notification_userId_category_idx" ON "Notification"("userId", "category");

-- CreateIndex
CREATE INDEX "Notification_createdAt_idx" ON "Notification"("createdAt");

-- CreateIndex
CREATE INDEX "Payment_status_createdAt_idx" ON "Payment"("status", "createdAt");

-- CreateIndex
CREATE INDEX "Payment_bookingId_status_idx" ON "Payment"("bookingId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "Payout_payoutNumber_key" ON "Payout"("payoutNumber");

-- CreateIndex
CREATE UNIQUE INDEX "Payout_providerTransferId_key" ON "Payout"("providerTransferId");

-- CreateIndex
CREATE UNIQUE INDEX "Payout_idempotencyKey_key" ON "Payout"("idempotencyKey");

-- CreateIndex
CREATE INDEX "Payout_createdAt_idx" ON "Payout"("createdAt");

-- CreateIndex
CREATE INDEX "Payout_payoutNumber_idx" ON "Payout"("payoutNumber");

-- CreateIndex
CREATE INDEX "Payout_providerTransferId_idx" ON "Payout"("providerTransferId");

-- CreateIndex
CREATE INDEX "Payout_idempotencyKey_idx" ON "Payout"("idempotencyKey");

-- CreateIndex
CREATE INDEX "PickupHub_isActive_idx" ON "PickupHub"("isActive");

-- CreateIndex
CREATE INDEX "ReferralAttribution_referrerId_status_idx" ON "ReferralAttribution"("referrerId", "status");

-- CreateIndex
CREATE INDEX "SupportTicket_customerId_status_idx" ON "SupportTicket"("customerId", "status");

-- CreateIndex
CREATE INDEX "Vendor_city_verificationStatus_idx" ON "Vendor"("city", "verificationStatus");

-- CreateIndex
CREATE INDEX "Vendor_isSponsored_boostExpiresAt_idx" ON "Vendor"("isSponsored", "boostExpiresAt");

-- CreateIndex
CREATE INDEX "Vendor_rating_idx" ON "Vendor"("rating");

-- CreateIndex
CREATE INDEX "WalletLedgerEntry_walletId_createdAt_idx" ON "WalletLedgerEntry"("walletId", "createdAt");

-- CreateIndex
CREATE INDEX "WalletLedgerEntry_walletId_bucket_idx" ON "WalletLedgerEntry"("walletId", "bucket");

-- AddForeignKey
ALTER TABLE "FinancialAdjustment" ADD CONSTRAINT "FinancialAdjustment_approvedByUserId_fkey" FOREIGN KEY ("approvedByUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReconciliationException" ADD CONSTRAINT "ReconciliationException_reconciliationRecordId_fkey" FOREIGN KEY ("reconciliationRecordId") REFERENCES "ReconciliationRecord"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Invoice" ADD CONSTRAINT "Invoice_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Invoice" ADD CONSTRAINT "Invoice_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Invoice" ADD CONSTRAINT "Invoice_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CreditNote" ADD CONSTRAINT "CreditNote_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "Invoice"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CreditNote" ADD CONSTRAINT "CreditNote_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SponsoredCampaign" ADD CONSTRAINT "SponsoredCampaign_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SponsoredCampaign" ADD CONSTRAINT "SponsoredCampaign_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeaturedListing" ADD CONSTRAINT "FeaturedListing_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingAttribution" ADD CONSTRAINT "BookingAttribution_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingAttribution" ADD CONSTRAINT "BookingAttribution_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "PromotionalCampaign"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingAttribution" ADD CONSTRAINT "BookingAttribution_sponsoredCampaignId_fkey" FOREIGN KEY ("sponsoredCampaignId") REFERENCES "SponsoredCampaign"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingAttribution" ADD CONSTRAINT "BookingAttribution_referralAttributionId_fkey" FOREIGN KEY ("referralAttributionId") REFERENCES "ReferralAttribution"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingAttribution" ADD CONSTRAINT "BookingAttribution_couponId_fkey" FOREIGN KEY ("couponId") REFERENCES "Coupon"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- RenameIndex
ALTER INDEX IF EXISTS "VendorLocationMatrix_vendorId_pickupLocationId_returnLocat_key" RENAME TO "VendorLocationMatrix_vendorId_pickupLocationId_returnLocati_key";

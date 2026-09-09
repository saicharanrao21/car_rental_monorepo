-- CreateEnum
CREATE TYPE "FulfillmentStage" AS ENUM ('PENDING_ALLOCATION', 'ALLOCATED', 'PREPARATION_SCHEDULED', 'PREPARATION_IN_PROGRESS', 'CLEANING_COMPLETED', 'INSPECTION_COMPLETED', 'READY_FOR_PICKUP', 'CUSTOMER_CHECKED_IN', 'HANDOVER_IN_PROGRESS', 'ACTIVE_RENTAL', 'RETURN_INSPECTION_PENDING', 'SETTLEMENT_PENDING', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "SubstitutionDecision" AS ENUM ('AUTO_SUBSTITUTE', 'MANUAL_SUBSTITUTE', 'CUSTOMER_APPROVAL_REQUIRED', 'UPGRADE_REQUIRED', 'NO_ALTERNATIVE');

-- CreateEnum
CREATE TYPE "SubstitutionReason" AS ENUM ('MECHANICAL_BREAKDOWN', 'SCHEDULED_MAINTENANCE', 'ACCIDENT_DAMAGE', 'CLEANING_DELAY', 'GPS_TELEMATICS_FAILURE', 'LATE_RETURN_OVERLAP', 'COMPLIANCE_HOLD', 'ADMIN_OVERRIDE');

-- CreateEnum
CREATE TYPE "SlaSeverity" AS ENUM ('INFO', 'WARNING', 'CRITICAL', 'EMERGENCY');

-- CreateEnum
CREATE TYPE "InventoryTransferStatus" AS ENUM ('PROPOSED', 'APPROVED', 'DISPATCHED', 'IN_TRANSIT', 'RECEIVED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "SalesChannel" AS ENUM ('CUSTOMER_APP', 'WEB_MARKETPLACE', 'VENDOR_DIRECT', 'BRANCH_DESK', 'ADMIN_PORTAL', 'CORPORATE_B2B', 'AFFILIATE_PARTNER');

-- CreateTable
CREATE TABLE "FulfillmentRecord" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "branchId" TEXT,
    "carId" TEXT,
    "stage" "FulfillmentStage" NOT NULL DEFAULT 'PENDING_ALLOCATION',
    "preparationNotes" TEXT,
    "cleanedAt" TIMESTAMP(3),
    "inspectedAt" TIMESTAMP(3),
    "readyForPickupAt" TIMESTAMP(3),
    "customerCheckedInAt" TIMESTAMP(3),
    "handoverStartedAt" TIMESTAMP(3),
    "handoverCompletedAt" TIMESTAMP(3),
    "returnStartedAt" TIMESTAMP(3),
    "returnCompletedAt" TIMESTAMP(3),
    "settlementCompletedAt" TIMESTAMP(3),
    "assignedStaffId" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FulfillmentRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VehicleSubstitutionRecord" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "originalCarId" TEXT NOT NULL,
    "substitutedCarId" TEXT,
    "decision" "SubstitutionDecision" NOT NULL,
    "reason" "SubstitutionReason" NOT NULL,
    "reasonDetails" TEXT,
    "originalClass" "CarCategory" NOT NULL,
    "substitutedClass" "CarCategory",
    "priceDifference" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "isCustomerApproved" BOOLEAN NOT NULL DEFAULT false,
    "isFreeUpgrade" BOOLEAN NOT NULL DEFAULT false,
    "authorizedBy" TEXT NOT NULL,
    "authorizedRole" "Role" NOT NULL DEFAULT 'ADMIN',
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VehicleSubstitutionRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DynamicPricingPolicy" (
    "id" TEXT NOT NULL,
    "scope" "PricingRuleScope" NOT NULL DEFAULT 'PLATFORM',
    "vendorId" TEXT,
    "branchId" TEXT,
    "vehicleClass" "CarCategory",
    "name" TEXT NOT NULL,
    "minDailyPrice" DECIMAL(10,2) NOT NULL,
    "maxDailyPrice" DECIMAL(10,2) NOT NULL,
    "maxSurgeMultiplier" DECIMAL(3,2) NOT NULL DEFAULT 1.50,
    "minDiscountMultiplier" DECIMAL(3,2) NOT NULL DEFAULT 0.80,
    "utilizationThresholdHigh" DOUBLE PRECISION NOT NULL DEFAULT 0.85,
    "utilizationThresholdLow" DOUBLE PRECISION NOT NULL DEFAULT 0.30,
    "surgeStepPct" DOUBLE PRECISION NOT NULL DEFAULT 0.05,
    "discountStepPct" DOUBLE PRECISION NOT NULL DEFAULT 0.05,
    "leadTimeCurveDays" INTEGER NOT NULL DEFAULT 7,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DynamicPricingPolicy_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CompetitorPriceObservation" (
    "id" TEXT NOT NULL,
    "providerSource" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "vehicleClass" "CarCategory" NOT NULL,
    "competitorName" TEXT NOT NULL,
    "observedDailyPrice" DECIMAL(10,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "confidenceScore" DOUBLE PRECISION NOT NULL DEFAULT 0.90,
    "observedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "metadata" JSONB,

    CONSTRAINT "CompetitorPriceObservation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "InventoryTransferRecommendation" (
    "id" TEXT NOT NULL,
    "sourceBranchId" TEXT NOT NULL,
    "destinationBranchId" TEXT NOT NULL,
    "vehicleClass" "CarCategory" NOT NULL,
    "recommendedUnits" INTEGER NOT NULL DEFAULT 1,
    "reason" TEXT NOT NULL,
    "sourceUtilization" DOUBLE PRECISION NOT NULL,
    "destinationDemandScore" DOUBLE PRECISION NOT NULL,
    "projectedRevenueGain" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "estimatedTransferCost" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "confidence" DOUBLE PRECISION NOT NULL DEFAULT 0.85,
    "status" "InventoryTransferStatus" NOT NULL DEFAULT 'PROPOSED',
    "approvedBy" TEXT,
    "dispatchedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "InventoryTransferRecommendation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SlaPolicyDefinition" (
    "id" TEXT NOT NULL,
    "scope" "PricingRuleScope" NOT NULL DEFAULT 'PLATFORM',
    "vendorId" TEXT,
    "targetProcess" TEXT NOT NULL,
    "thresholdMinutes" INTEGER NOT NULL,
    "severity" "SlaSeverity" NOT NULL DEFAULT 'WARNING',
    "action" TEXT NOT NULL DEFAULT 'ALERT_AND_TASK',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SlaPolicyDefinition_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SlaBreachIncident" (
    "id" TEXT NOT NULL,
    "policyId" TEXT NOT NULL,
    "bookingId" TEXT,
    "vendorId" TEXT,
    "branchId" TEXT,
    "targetProcess" TEXT NOT NULL,
    "severity" "SlaSeverity" NOT NULL,
    "elapsedMinutes" INTEGER NOT NULL,
    "thresholdMinutes" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "actionTaken" TEXT,
    "resolvedAt" TIMESTAMP(3),
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SlaBreachIncident_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MarketplaceCommissionRule" (
    "id" TEXT NOT NULL,
    "scope" "PricingRuleScope" NOT NULL DEFAULT 'PLATFORM',
    "vendorId" TEXT,
    "branchId" TEXT,
    "vehicleClass" "CarCategory",
    "channel" "SalesChannel" NOT NULL DEFAULT 'CUSTOMER_APP',
    "platformPct" DECIMAL(5,2) NOT NULL DEFAULT 15.00,
    "vendorPct" DECIMAL(5,2) NOT NULL DEFAULT 80.00,
    "branchPct" DECIMAL(5,2) NOT NULL DEFAULT 5.00,
    "fixedPlatformFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "gatewayFeeRecovery" DECIMAL(5,2) NOT NULL DEFAULT 2.00,
    "taxGstPct" DECIMAL(5,2) NOT NULL DEFAULT 18.00,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MarketplaceCommissionRule_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CorporateAccount" (
    "id" TEXT NOT NULL,
    "companyName" TEXT NOT NULL,
    "corporateCode" TEXT NOT NULL,
    "contactEmail" TEXT NOT NULL,
    "contactPhone" TEXT NOT NULL,
    "taxIdNumber" TEXT,
    "billingAddress" TEXT NOT NULL,
    "creditLimit" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "usedCredit" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "negotiatedDiscountPct" DECIMAL(5,2) NOT NULL DEFAULT 10.00,
    "paymentTermsDays" INTEGER NOT NULL DEFAULT 30,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "preferredVendorId" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CorporateAccount_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "FulfillmentRecord_bookingId_key" ON "FulfillmentRecord"("bookingId");

-- CreateIndex
CREATE INDEX "FulfillmentRecord_vendorId_stage_idx" ON "FulfillmentRecord"("vendorId", "stage");

-- CreateIndex
CREATE INDEX "FulfillmentRecord_branchId_stage_idx" ON "FulfillmentRecord"("branchId", "stage");

-- CreateIndex
CREATE INDEX "FulfillmentRecord_stage_idx" ON "FulfillmentRecord"("stage");

-- CreateIndex
CREATE INDEX "FulfillmentRecord_bookingId_idx" ON "FulfillmentRecord"("bookingId");

-- CreateIndex
CREATE INDEX "VehicleSubstitutionRecord_bookingId_idx" ON "VehicleSubstitutionRecord"("bookingId");

-- CreateIndex
CREATE INDEX "VehicleSubstitutionRecord_originalCarId_idx" ON "VehicleSubstitutionRecord"("originalCarId");

-- CreateIndex
CREATE INDEX "VehicleSubstitutionRecord_substitutedCarId_idx" ON "VehicleSubstitutionRecord"("substitutedCarId");

-- CreateIndex
CREATE INDEX "VehicleSubstitutionRecord_decision_idx" ON "VehicleSubstitutionRecord"("decision");

-- CreateIndex
CREATE INDEX "VehicleSubstitutionRecord_createdAt_idx" ON "VehicleSubstitutionRecord"("createdAt");

-- CreateIndex
CREATE INDEX "DynamicPricingPolicy_scope_idx" ON "DynamicPricingPolicy"("scope");

-- CreateIndex
CREATE INDEX "DynamicPricingPolicy_vendorId_idx" ON "DynamicPricingPolicy"("vendorId");

-- CreateIndex
CREATE INDEX "DynamicPricingPolicy_branchId_idx" ON "DynamicPricingPolicy"("branchId");

-- CreateIndex
CREATE INDEX "DynamicPricingPolicy_vehicleClass_idx" ON "DynamicPricingPolicy"("vehicleClass");

-- CreateIndex
CREATE INDEX "DynamicPricingPolicy_isActive_idx" ON "DynamicPricingPolicy"("isActive");

-- CreateIndex
CREATE INDEX "CompetitorPriceObservation_city_vehicleClass_idx" ON "CompetitorPriceObservation"("city", "vehicleClass");

-- CreateIndex
CREATE INDEX "CompetitorPriceObservation_providerSource_idx" ON "CompetitorPriceObservation"("providerSource");

-- CreateIndex
CREATE INDEX "CompetitorPriceObservation_observedAt_idx" ON "CompetitorPriceObservation"("observedAt");

-- CreateIndex
CREATE INDEX "InventoryTransferRecommendation_sourceBranchId_idx" ON "InventoryTransferRecommendation"("sourceBranchId");

-- CreateIndex
CREATE INDEX "InventoryTransferRecommendation_destinationBranchId_idx" ON "InventoryTransferRecommendation"("destinationBranchId");

-- CreateIndex
CREATE INDEX "InventoryTransferRecommendation_status_idx" ON "InventoryTransferRecommendation"("status");

-- CreateIndex
CREATE INDEX "InventoryTransferRecommendation_createdAt_idx" ON "InventoryTransferRecommendation"("createdAt");

-- CreateIndex
CREATE INDEX "SlaPolicyDefinition_targetProcess_isActive_idx" ON "SlaPolicyDefinition"("targetProcess", "isActive");

-- CreateIndex
CREATE INDEX "SlaPolicyDefinition_scope_idx" ON "SlaPolicyDefinition"("scope");

-- CreateIndex
CREATE INDEX "SlaBreachIncident_policyId_idx" ON "SlaBreachIncident"("policyId");

-- CreateIndex
CREATE INDEX "SlaBreachIncident_bookingId_idx" ON "SlaBreachIncident"("bookingId");

-- CreateIndex
CREATE INDEX "SlaBreachIncident_vendorId_status_idx" ON "SlaBreachIncident"("vendorId", "status");

-- CreateIndex
CREATE INDEX "SlaBreachIncident_status_idx" ON "SlaBreachIncident"("status");

-- CreateIndex
CREATE INDEX "SlaBreachIncident_createdAt_idx" ON "SlaBreachIncident"("createdAt");

-- CreateIndex
CREATE INDEX "MarketplaceCommissionRule_scope_channel_idx" ON "MarketplaceCommissionRule"("scope", "channel");

-- CreateIndex
CREATE INDEX "MarketplaceCommissionRule_vendorId_idx" ON "MarketplaceCommissionRule"("vendorId");

-- CreateIndex
CREATE INDEX "MarketplaceCommissionRule_branchId_idx" ON "MarketplaceCommissionRule"("branchId");

-- CreateIndex
CREATE INDEX "MarketplaceCommissionRule_isActive_idx" ON "MarketplaceCommissionRule"("isActive");

-- CreateIndex
CREATE UNIQUE INDEX "CorporateAccount_corporateCode_key" ON "CorporateAccount"("corporateCode");

-- CreateIndex
CREATE INDEX "CorporateAccount_corporateCode_idx" ON "CorporateAccount"("corporateCode");

-- CreateIndex
CREATE INDEX "CorporateAccount_isActive_idx" ON "CorporateAccount"("isActive");

-- AddForeignKey
ALTER TABLE "FulfillmentRecord" ADD CONSTRAINT "FulfillmentRecord_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FulfillmentRecord" ADD CONSTRAINT "FulfillmentRecord_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FulfillmentRecord" ADD CONSTRAINT "FulfillmentRecord_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "PickupHub"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FulfillmentRecord" ADD CONSTRAINT "FulfillmentRecord_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VehicleSubstitutionRecord" ADD CONSTRAINT "VehicleSubstitutionRecord_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VehicleSubstitutionRecord" ADD CONSTRAINT "VehicleSubstitutionRecord_originalCarId_fkey" FOREIGN KEY ("originalCarId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VehicleSubstitutionRecord" ADD CONSTRAINT "VehicleSubstitutionRecord_substitutedCarId_fkey" FOREIGN KEY ("substitutedCarId") REFERENCES "Car"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DynamicPricingPolicy" ADD CONSTRAINT "DynamicPricingPolicy_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DynamicPricingPolicy" ADD CONSTRAINT "DynamicPricingPolicy_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "PickupHub"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InventoryTransferRecommendation" ADD CONSTRAINT "InventoryTransferRecommendation_sourceBranchId_fkey" FOREIGN KEY ("sourceBranchId") REFERENCES "PickupHub"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InventoryTransferRecommendation" ADD CONSTRAINT "InventoryTransferRecommendation_destinationBranchId_fkey" FOREIGN KEY ("destinationBranchId") REFERENCES "PickupHub"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SlaBreachIncident" ADD CONSTRAINT "SlaBreachIncident_policyId_fkey" FOREIGN KEY ("policyId") REFERENCES "SlaPolicyDefinition"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MarketplaceCommissionRule" ADD CONSTRAINT "MarketplaceCommissionRule_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MarketplaceCommissionRule" ADD CONSTRAINT "MarketplaceCommissionRule_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "PickupHub"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CorporateAccount" ADD CONSTRAINT "CorporateAccount_preferredVendorId_fkey" FOREIGN KEY ("preferredVendorId") REFERENCES "Vendor"("id") ON DELETE SET NULL ON UPDATE CASCADE;

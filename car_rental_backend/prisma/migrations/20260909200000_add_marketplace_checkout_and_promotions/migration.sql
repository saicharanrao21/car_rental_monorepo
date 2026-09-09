-- CreateEnum
CREATE TYPE "CheckoutSessionStatus" AS ENUM ('DRAFT', 'QUOTE_LOCKED', 'PAYMENT_PENDING', 'PAYMENT_PROCESSING', 'CONFIRMED', 'PAYMENT_FAILED', 'EXPIRED', 'CANCELLED');

-- AlterTable
ALTER TABLE "Coupon" ADD COLUMN IF NOT EXISTS "vendorId" TEXT;
ALTER TABLE "Coupon" ADD COLUMN IF NOT EXISTS "branchId" TEXT;
ALTER TABLE "Coupon" ADD COLUMN IF NOT EXISTS "minRentalDays" INTEGER;
ALTER TABLE "Coupon" ADD COLUMN IF NOT EXISTS "stackable" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "CheckoutSession" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "quoteId" TEXT NOT NULL,
    "status" "CheckoutSessionStatus" NOT NULL DEFAULT 'QUOTE_LOCKED',
    "driverDetails" JSONB,
    "customerDetails" JSONB,
    "ancillarySelections" JSONB,
    "selectedPaymentMethod" TEXT,
    "selectedPaymentProvider" TEXT,
    "paymentAttempts" INTEGER NOT NULL DEFAULT 0,
    "lastPaymentError" JSONB,
    "bookingId" TEXT,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "completedAt" TIMESTAMP(3),
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CheckoutSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AncillaryProduct" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "category" TEXT NOT NULL,
    "pricingModel" TEXT NOT NULL DEFAULT 'PER_DAY',
    "basePrice" DECIMAL(10,2) NOT NULL,
    "taxRate" DECIMAL(5,2) NOT NULL DEFAULT 0.18,
    "vendorId" TEXT,
    "branchId" TEXT,
    "vehicleClass" "CarCategory",
    "isRequired" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "maxQuantity" INTEGER NOT NULL DEFAULT 1,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AncillaryProduct_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CancellationPolicyDefinition" (
    "id" TEXT NOT NULL,
    "scope" "PricingRuleScope" NOT NULL DEFAULT 'PLATFORM',
    "vendorId" TEXT,
    "branchId" TEXT,
    "vehicleClass" "CarCategory",
    "name" TEXT NOT NULL,
    "freeCancellationHours" INTEGER NOT NULL DEFAULT 24,
    "tier1HoursBeforePickup" INTEGER NOT NULL DEFAULT 6,
    "tier1PenaltyPercent" DOUBLE PRECISION NOT NULL DEFAULT 25.0,
    "tier2HoursBeforePickup" INTEGER NOT NULL DEFAULT 0,
    "tier2PenaltyPercent" DOUBLE PRECISION NOT NULL DEFAULT 50.0,
    "afterStartFeePercent" DOUBLE PRECISION NOT NULL DEFAULT 100.0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CancellationPolicyDefinition_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "CheckoutSession_sessionId_key" ON "CheckoutSession"("sessionId");
CREATE UNIQUE INDEX "CheckoutSession_bookingId_key" ON "CheckoutSession"("bookingId");
CREATE INDEX "CheckoutSession_customerId_status_idx" ON "CheckoutSession"("customerId", "status");
CREATE INDEX "CheckoutSession_quoteId_idx" ON "CheckoutSession"("quoteId");
CREATE INDEX "CheckoutSession_status_expiresAt_idx" ON "CheckoutSession"("status", "expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "AncillaryProduct_code_key" ON "AncillaryProduct"("code");
CREATE INDEX "AncillaryProduct_category_isActive_idx" ON "AncillaryProduct"("category", "isActive");
CREATE INDEX "AncillaryProduct_vendorId_idx" ON "AncillaryProduct"("vendorId");
CREATE INDEX "AncillaryProduct_branchId_idx" ON "AncillaryProduct"("branchId");

-- CreateIndex
CREATE INDEX "CancellationPolicyDefinition_scope_idx" ON "CancellationPolicyDefinition"("scope");
CREATE INDEX "CancellationPolicyDefinition_vendorId_idx" ON "CancellationPolicyDefinition"("vendorId");
CREATE INDEX "CancellationPolicyDefinition_branchId_idx" ON "CancellationPolicyDefinition"("branchId");
CREATE INDEX "CancellationPolicyDefinition_vehicleClass_idx" ON "CancellationPolicyDefinition"("vehicleClass");

-- CreateIndex
CREATE INDEX "Coupon_vendorId_idx" ON "Coupon"("vendorId");
CREATE INDEX "Coupon_branchId_idx" ON "Coupon"("branchId");

-- AddForeignKey
ALTER TABLE "Coupon" ADD CONSTRAINT "Coupon_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Coupon" ADD CONSTRAINT "Coupon_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "PickupHub"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CheckoutSession" ADD CONSTRAINT "CheckoutSession_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CheckoutSession" ADD CONSTRAINT "CheckoutSession_quoteId_fkey" FOREIGN KEY ("quoteId") REFERENCES "BookingQuote"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CheckoutSession" ADD CONSTRAINT "CheckoutSession_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AncillaryProduct" ADD CONSTRAINT "AncillaryProduct_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "AncillaryProduct" ADD CONSTRAINT "AncillaryProduct_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "PickupHub"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CancellationPolicyDefinition" ADD CONSTRAINT "CancellationPolicyDefinition_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CancellationPolicyDefinition" ADD CONSTRAINT "CancellationPolicyDefinition_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "PickupHub"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateEnum
CREATE TYPE "PricingRuleScope" AS ENUM ('PLATFORM', 'VENDOR', 'BRANCH', 'VEHICLE_CLASS');

-- AlterTable Booking
ALTER TABLE "Booking" ADD COLUMN "vehicleClass" "CarCategory",
ADD COLUMN "allocationStatus" TEXT NOT NULL DEFAULT 'ALLOCATED',
ADD COLUMN "allocationStrategy" TEXT DEFAULT 'EXACT_VEHICLE';

-- CreateIndex
CREATE INDEX "Booking_allocationStatus_idx" ON "Booking"("allocationStatus");
CREATE INDEX "Booking_vehicleClass_idx" ON "Booking"("vehicleClass");

-- CreateTable
CREATE TABLE "VehicleAllocationRecord" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "carId" TEXT NOT NULL,
    "strategy" TEXT NOT NULL,
    "reason" TEXT,
    "allocatedBy" TEXT NOT NULL,
    "allocatedByRole" "Role" NOT NULL DEFAULT 'ADMIN',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "allocatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "releasedAt" TIMESTAMP(3),
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VehicleAllocationRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RentalPricingRule" (
    "id" TEXT NOT NULL,
    "scope" "PricingRuleScope" NOT NULL,
    "vendorId" TEXT,
    "branchId" TEXT,
    "vehicleClass" "CarCategory",
    "carId" TEXT,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "hourlyRateMultiplier" DECIMAL(5,2),
    "dailyRate" DECIMAL(10,2),
    "weeklyDiscountPct" DOUBLE PRECISION DEFAULT 0,
    "monthlyDiscountPct" DOUBLE PRECISION DEFAULT 0,
    "weekendMultiplier" DECIMAL(5,2) DEFAULT 1.0,
    "peakSeasonMultiplier" DECIMAL(5,2) DEFAULT 1.0,
    "holidayMultiplier" DECIMAL(5,2) DEFAULT 1.0,
    "extraKmRate" DECIMAL(10,2),
    "lateReturnHourlyFee" DECIMAL(10,2),
    "securityDepositAmount" DECIMAL(10,2),
    "convenienceFee" DECIMAL(10,2) DEFAULT 0,
    "oneWayBaseFee" DECIMAL(10,2) DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "priority" INTEGER NOT NULL DEFAULT 0,
    "effectiveFrom" TIMESTAMP(3),
    "effectiveTo" TIMESTAMP(3),
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RentalPricingRule_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "VehicleAllocationRecord_bookingId_idx" ON "VehicleAllocationRecord"("bookingId");
CREATE INDEX "VehicleAllocationRecord_carId_idx" ON "VehicleAllocationRecord"("carId");
CREATE INDEX "VehicleAllocationRecord_isActive_idx" ON "VehicleAllocationRecord"("isActive");
CREATE INDEX "VehicleAllocationRecord_allocatedAt_idx" ON "VehicleAllocationRecord"("allocatedAt");

-- CreateIndex
CREATE INDEX "RentalPricingRule_scope_idx" ON "RentalPricingRule"("scope");
CREATE INDEX "RentalPricingRule_vendorId_idx" ON "RentalPricingRule"("vendorId");
CREATE INDEX "RentalPricingRule_branchId_idx" ON "RentalPricingRule"("branchId");
CREATE INDEX "RentalPricingRule_vehicleClass_idx" ON "RentalPricingRule"("vehicleClass");
CREATE INDEX "RentalPricingRule_carId_idx" ON "RentalPricingRule"("carId");
CREATE INDEX "RentalPricingRule_isActive_idx" ON "RentalPricingRule"("isActive");
CREATE INDEX "RentalPricingRule_priority_idx" ON "RentalPricingRule"("priority");

-- AddForeignKey
ALTER TABLE "VehicleAllocationRecord" ADD CONSTRAINT "VehicleAllocationRecord_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VehicleAllocationRecord" ADD CONSTRAINT "VehicleAllocationRecord_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RentalPricingRule" ADD CONSTRAINT "RentalPricingRule_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RentalPricingRule" ADD CONSTRAINT "RentalPricingRule_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "PickupHub"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RentalPricingRule" ADD CONSTRAINT "RentalPricingRule_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;

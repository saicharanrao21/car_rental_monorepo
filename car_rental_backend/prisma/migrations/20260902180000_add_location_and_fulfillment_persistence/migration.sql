-- CreateEnum
CREATE TYPE "VendorLocationType" AS ENUM ('VENDOR_YARD', 'BRANCH', 'AIRPORT', 'RAILWAY_STATION', 'BUS_TERMINAL', 'PUBLIC_POINT', 'COMMERCIAL_OFFICE');

-- CreateEnum
CREATE TYPE "LocationStatus" AS ENUM ('DRAFT', 'PENDING_REVIEW', 'ACTIVE', 'PAUSED', 'SUSPENDED', 'ARCHIVED', 'INACTIVE');

-- CreateEnum
CREATE TYPE "DeliveryPricingModel" AS ENUM ('FREE', 'FIXED', 'DISTANCE_BASED');

-- CreateEnum
CREATE TYPE "LocationExceptionType" AS ENUM ('HOLIDAY', 'TEMPORARY_CLOSURE', 'EMERGENCY_CLOSURE', 'CUSTOM_HOURS');

-- AlterTable PickupHub
ALTER TABLE "PickupHub" ADD COLUMN "serviceRadiusKm" DOUBLE PRECISION NOT NULL DEFAULT 25.0,
ADD COLUMN "locationType" "VendorLocationType" NOT NULL DEFAULT 'VENDOR_YARD',
ADD COLUMN "status" "LocationStatus" NOT NULL DEFAULT 'ACTIVE',
ADD COLUMN "allowsPickup" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "allowsReturn" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "allowsDelivery" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "pickupFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN "returnFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN "oneWayFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN "is24x7" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "openingTime" TEXT DEFAULT '08:00',
ADD COLUMN "closingTime" TEXT DEFAULT '22:00';

-- CreateTable LocationException
CREATE TABLE "LocationException" (
    "id" TEXT NOT NULL,
    "locationId" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "exceptionType" "LocationExceptionType" NOT NULL DEFAULT 'HOLIDAY',
    "isClosed" BOOLEAN NOT NULL DEFAULT true,
    "customOpeningTime" TEXT,
    "customClosingTime" TEXT,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LocationException_pkey" PRIMARY KEY ("id")
);

-- CreateTable VendorDeliveryPolicy
CREATE TABLE "VendorDeliveryPolicy" (
    "id" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "deliveryEnabled" BOOLEAN NOT NULL DEFAULT true,
    "maxDeliveryRadiusKm" DOUBLE PRECISION NOT NULL DEFAULT 25.0,
    "pricingModel" "DeliveryPricingModel" NOT NULL DEFAULT 'DISTANCE_BASED',
    "baseDeliveryFee" DECIMAL(10,2) NOT NULL DEFAULT 100.0,
    "perKmDeliveryFee" DECIMAL(10,2) NOT NULL DEFAULT 20.0,
    "freeDeliveryWithinKm" DOUBLE PRECISION NOT NULL DEFAULT 5.0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VendorDeliveryPolicy_pkey" PRIMARY KEY ("id")
);

-- CreateTable VendorLocationMatrix
CREATE TABLE "VendorLocationMatrix" (
    "id" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "pickupLocationId" TEXT NOT NULL,
    "returnLocationId" TEXT NOT NULL,
    "isSupported" BOOLEAN NOT NULL DEFAULT true,
    "oneWaySurcharge" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VendorLocationMatrix_pkey" PRIMARY KEY ("id")
);

-- CreateTable PublicTransportPoint
CREATE TABLE "PublicTransportPoint" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" "VendorLocationType" NOT NULL DEFAULT 'AIRPORT',
    "city" TEXT NOT NULL,
    "state" TEXT,
    "locality" TEXT,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "category" TEXT NOT NULL,
    "isApproved" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PublicTransportPoint_pkey" PRIMARY KEY ("id")
);

-- AlterTable Booking
ALTER TABLE "Booking" ADD COLUMN "pickupFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN "returnFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN "oneWayFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN "pickupHubId" TEXT,
ADD COLUMN "returnHubId" TEXT,
ADD COLUMN "pickupName" TEXT,
ADD COLUMN "dropName" TEXT;

-- CreateIndex
CREATE INDEX "PickupHub_locationType_idx" ON "PickupHub"("locationType");
CREATE INDEX "PickupHub_status_idx" ON "PickupHub"("status");

-- CreateIndex
CREATE INDEX "LocationException_locationId_idx" ON "LocationException"("locationId");
CREATE INDEX "LocationException_date_idx" ON "LocationException"("date");

-- CreateIndex
CREATE UNIQUE INDEX "VendorDeliveryPolicy_vendorId_key" ON "VendorDeliveryPolicy"("vendorId");
CREATE INDEX "VendorDeliveryPolicy_vendorId_idx" ON "VendorDeliveryPolicy"("vendorId");

-- CreateIndex
CREATE INDEX "VendorLocationMatrix_vendorId_idx" ON "VendorLocationMatrix"("vendorId");
CREATE INDEX "VendorLocationMatrix_pickupLocationId_idx" ON "VendorLocationMatrix"("pickupLocationId");
CREATE INDEX "VendorLocationMatrix_returnLocationId_idx" ON "VendorLocationMatrix"("returnLocationId");
CREATE UNIQUE INDEX "VendorLocationMatrix_vendorId_pickupLocationId_returnLocat_key" ON "VendorLocationMatrix"("vendorId", "pickupLocationId", "returnLocationId");

-- CreateIndex
CREATE INDEX "PublicTransportPoint_city_idx" ON "PublicTransportPoint"("city");
CREATE INDEX "PublicTransportPoint_type_idx" ON "PublicTransportPoint"("type");
CREATE INDEX "PublicTransportPoint_city_isApproved_idx" ON "PublicTransportPoint"("city", "isApproved");

-- AddForeignKey
ALTER TABLE "LocationException" ADD CONSTRAINT "LocationException_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "PickupHub"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VendorDeliveryPolicy" ADD CONSTRAINT "VendorDeliveryPolicy_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VendorLocationMatrix" ADD CONSTRAINT "VendorLocationMatrix_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

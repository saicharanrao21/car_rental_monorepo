-- CreateEnum
CREATE TYPE "VendorLocationType" AS ENUM ('VENDOR_YARD', 'BRANCH', 'AIRPORT', 'RAILWAY_STATION', 'BUS_TERMINAL', 'PUBLIC_POINT', 'COMMERCIAL_OFFICE');

-- CreateEnum
CREATE TYPE "LocationStatus" AS ENUM ('DRAFT', 'PENDING_REVIEW', 'ACTIVE', 'PAUSED', 'SUSPENDED', 'ARCHIVED', 'INACTIVE');

-- CreateEnum
CREATE TYPE "DeliveryPricingModel" AS ENUM ('FREE', 'FIXED', 'DISTANCE_BASED');

-- CreateEnum
CREATE TYPE "LocationExceptionType" AS ENUM ('HOLIDAY', 'TEMPORARY_CLOSURE', 'EMERGENCY_CLOSURE', 'CUSTOM_HOURS');

-- CreateTable PickupHub if not exists
CREATE TABLE IF NOT EXISTS "PickupHub" (
    "id" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "locality" TEXT,
    "city" TEXT NOT NULL,
    "state" TEXT,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "serviceRadiusKm" DOUBLE PRECISION NOT NULL DEFAULT 25.0,
    "operatingHours" TEXT,
    "contactPhone" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "locationType" "VendorLocationType" NOT NULL DEFAULT 'VENDOR_YARD',
    "status" "LocationStatus" NOT NULL DEFAULT 'ACTIVE',
    "allowsPickup" BOOLEAN NOT NULL DEFAULT true,
    "allowsReturn" BOOLEAN NOT NULL DEFAULT true,
    "allowsDelivery" BOOLEAN NOT NULL DEFAULT true,
    "pickupFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "returnFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "oneWayFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "is24x7" BOOLEAN NOT NULL DEFAULT false,
    "openingTime" TEXT DEFAULT '08:00',
    "closingTime" TEXT DEFAULT '22:00',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PickupHub_pkey" PRIMARY KEY ("id")
);

-- Foreign key to Vendor if not exists
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'PickupHub_vendorId_fkey'
  ) THEN
    ALTER TABLE "PickupHub" ADD CONSTRAINT "PickupHub_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

-- Add pickupHubId to Car if not exists
ALTER TABLE "Car" ADD COLUMN IF NOT EXISTS "pickupHubId" TEXT;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'Car_pickupHubId_fkey'
  ) THEN
    ALTER TABLE "Car" ADD CONSTRAINT "Car_pickupHubId_fkey" FOREIGN KEY ("pickupHubId") REFERENCES "PickupHub"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS "Car_pickupHubId_idx" ON "Car"("pickupHubId");

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
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Booking' AND column_name = 'pickupFee') THEN
    ALTER TABLE "Booking" ADD COLUMN "pickupFee" DECIMAL(10,2) NOT NULL DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Booking' AND column_name = 'returnFee') THEN
    ALTER TABLE "Booking" ADD COLUMN "returnFee" DECIMAL(10,2) NOT NULL DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Booking' AND column_name = 'oneWayFee') THEN
    ALTER TABLE "Booking" ADD COLUMN "oneWayFee" DECIMAL(10,2) NOT NULL DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Booking' AND column_name = 'pickupHubId') THEN
    ALTER TABLE "Booking" ADD COLUMN "pickupHubId" TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Booking' AND column_name = 'returnHubId') THEN
    ALTER TABLE "Booking" ADD COLUMN "returnHubId" TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Booking' AND column_name = 'pickupName') THEN
    ALTER TABLE "Booking" ADD COLUMN "pickupName" TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Booking' AND column_name = 'dropName') THEN
    ALTER TABLE "Booking" ADD COLUMN "dropName" TEXT;
  END IF;
END $$;

-- CreateIndex
CREATE INDEX IF NOT EXISTS "PickupHub_locationType_idx" ON "PickupHub"("locationType");
CREATE INDEX IF NOT EXISTS "PickupHub_status_idx" ON "PickupHub"("status");
CREATE INDEX IF NOT EXISTS "PickupHub_vendorId_idx" ON "PickupHub"("vendorId");
CREATE INDEX IF NOT EXISTS "PickupHub_city_idx" ON "PickupHub"("city");
CREATE INDEX IF NOT EXISTS "PickupHub_city_isActive_idx" ON "PickupHub"("city", "isActive");

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

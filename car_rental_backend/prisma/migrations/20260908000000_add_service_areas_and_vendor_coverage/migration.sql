-- CreateEnum
CREATE TYPE "ServiceAreaStatus" AS ENUM ('ACTIVE', 'COMING_SOON', 'INACTIVE');

-- AlterTable
ALTER TABLE "SupportedCity" ADD COLUMN     "country" TEXT NOT NULL DEFAULT 'India',
ADD COLUMN     "createdBy" TEXT,
ADD COLUMN     "normalizedName" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "status" "ServiceAreaStatus" NOT NULL DEFAULT 'ACTIVE',
ADD COLUMN     "timezone" TEXT NOT NULL DEFAULT 'Asia/Kolkata',
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "updatedBy" TEXT;

-- CreateTable
CREATE TABLE "ServiceArea" (
    "id" TEXT NOT NULL,
    "cityId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "normalizedName" TEXT NOT NULL,
    "status" "ServiceAreaStatus" NOT NULL DEFAULT 'ACTIVE',
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "radiusMeters" DOUBLE PRECISION NOT NULL DEFAULT 5000,
    "priority" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdBy" TEXT,
    "updatedBy" TEXT,

    CONSTRAINT "ServiceArea_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VendorServiceArea" (
    "id" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "serviceAreaId" TEXT NOT NULL,
    "isPrimary" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "assignedBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VendorServiceArea_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ServiceArea_cityId_idx" ON "ServiceArea"("cityId");

-- CreateIndex
CREATE INDEX "ServiceArea_status_idx" ON "ServiceArea"("status");

-- CreateIndex
CREATE INDEX "ServiceArea_latitude_longitude_idx" ON "ServiceArea"("latitude", "longitude");

-- CreateIndex
CREATE INDEX "ServiceArea_cityId_status_idx" ON "ServiceArea"("cityId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "ServiceArea_cityId_normalizedName_key" ON "ServiceArea"("cityId", "normalizedName");

-- CreateIndex
CREATE INDEX "VendorServiceArea_vendorId_idx" ON "VendorServiceArea"("vendorId");

-- CreateIndex
CREATE INDEX "VendorServiceArea_serviceAreaId_idx" ON "VendorServiceArea"("serviceAreaId");

-- CreateIndex
CREATE INDEX "VendorServiceArea_serviceAreaId_isActive_idx" ON "VendorServiceArea"("serviceAreaId", "isActive");

-- CreateIndex
CREATE INDEX "VendorServiceArea_vendorId_isActive_idx" ON "VendorServiceArea"("vendorId", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "VendorServiceArea_vendorId_serviceAreaId_key" ON "VendorServiceArea"("vendorId", "serviceAreaId");

-- CreateIndex
CREATE INDEX "SupportedCity_status_idx" ON "SupportedCity"("status");

-- CreateIndex
CREATE INDEX "SupportedCity_name_idx" ON "SupportedCity"("name");

-- AddForeignKey
ALTER TABLE "ServiceArea" ADD CONSTRAINT "ServiceArea_cityId_fkey" FOREIGN KEY ("cityId") REFERENCES "SupportedCity"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VendorServiceArea" ADD CONSTRAINT "VendorServiceArea_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VendorServiceArea" ADD CONSTRAINT "VendorServiceArea_serviceAreaId_fkey" FOREIGN KEY ("serviceAreaId") REFERENCES "ServiceArea"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "MileagePackage" (
    "id" TEXT NOT NULL,
    "carId" TEXT NOT NULL,
    "tripType" "TripType" NOT NULL,
    "name" TEXT NOT NULL,
    "includedKmPerDay" INTEGER,
    "basePricePerDay" DECIMAL(10,2) NOT NULL,
    "extraKmRate" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "isDefault" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MileagePackage_pkey" PRIMARY KEY ("id")
);

-- AlterTable Booking
ALTER TABLE "Booking" ADD COLUMN "mileagePackageId" TEXT,
ADD COLUMN "mileagePackageName" TEXT,
ADD COLUMN "includedKmPerDay" INTEGER,
ADD COLUMN "includedKmTotal" INTEGER,
ADD COLUMN "packageBasePricePerDay" DECIMAL(10,2),
ADD COLUMN "extraKmRate" DECIMAL(10,2),
ADD COLUMN "pricingBasis" TEXT NOT NULL DEFAULT 'LEGACY_DAILY';

-- CreateIndex
CREATE INDEX "MileagePackage_carId_idx" ON "MileagePackage"("carId");
CREATE INDEX "MileagePackage_tripType_idx" ON "MileagePackage"("tripType");
CREATE INDEX "MileagePackage_isActive_idx" ON "MileagePackage"("isActive");

-- CreateIndex
CREATE INDEX "Booking_mileagePackageId_idx" ON "Booking"("mileagePackageId");

-- AddForeignKey
ALTER TABLE "MileagePackage" ADD CONSTRAINT "MileagePackage_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_mileagePackageId_fkey" FOREIGN KEY ("mileagePackageId") REFERENCES "MileagePackage"("id") ON DELETE SET NULL ON UPDATE CASCADE;

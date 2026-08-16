-- CreateEnum
CREATE TYPE "DeliveryType" AS ENUM ('NONE', 'DOORSTEP_DELIVERY', 'DOORSTEP_PICKUP', 'ROUND_TRIP_DELIVERY');

-- CreateEnum
CREATE TYPE "ExtensionStatus" AS ENUM ('PENDING_PAYMENT', 'CONFIRMED', 'CANCELLED', 'EXPIRED');

-- AlterTable
ALTER TABLE "Booking" ADD COLUMN "deliveryType" "DeliveryType" NOT NULL DEFAULT 'NONE',
ADD COLUMN "deliveryAddress" TEXT,
ADD COLUMN "deliveryLatitude" DOUBLE PRECISION,
ADD COLUMN "deliveryLongitude" DOUBLE PRECISION,
ADD COLUMN "deliveryFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN "pickupAddress" TEXT,
ADD COLUMN "pickupLatitude" DOUBLE PRECISION,
ADD COLUMN "pickupLongitude" DOUBLE PRECISION,
ADD COLUMN "pickupFee" DECIMAL(10,2) NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "TripExtension" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "currentEndDate" TIMESTAMP(3) NOT NULL,
    "requestedEndDate" TIMESTAMP(3) NOT NULL,
    "extraDays" INTEGER NOT NULL DEFAULT 0,
    "extraHours" INTEGER NOT NULL DEFAULT 0,
    "baseFare" DECIMAL(10,2) NOT NULL,
    "platformFee" DECIMAL(10,2) NOT NULL,
    "gstAmount" DECIMAL(10,2) NOT NULL,
    "totalFare" DECIMAL(10,2) NOT NULL,
    "netToVendor" DECIMAL(10,2) NOT NULL,
    "razorpayOrderId" TEXT,
    "razorpayPaymentId" TEXT,
    "status" "ExtensionStatus" NOT NULL DEFAULT 'PENDING_PAYMENT',
    "invoiceNumber" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TripExtension_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AdditionalDriver" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "email" TEXT,
    "licenceNumber" TEXT NOT NULL,
    "licenceFrontUrl" TEXT NOT NULL,
    "licenceBackUrl" TEXT NOT NULL,
    "expiryDate" TIMESTAMP(3) NOT NULL,
    "kycStatus" "KycStatus" NOT NULL DEFAULT 'PENDING',
    "rejectionReason" TEXT,
    "verifiedAt" TIMESTAMP(3),
    "feeAmount" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AdditionalDriver_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "TripExtension_bookingId_idx" ON "TripExtension"("bookingId");

-- CreateIndex
CREATE INDEX "TripExtension_status_idx" ON "TripExtension"("status");

-- CreateIndex
CREATE INDEX "AdditionalDriver_bookingId_idx" ON "AdditionalDriver"("bookingId");

-- CreateIndex
CREATE INDEX "AdditionalDriver_licenceNumber_idx" ON "AdditionalDriver"("licenceNumber");

-- CreateIndex
CREATE INDEX "AdditionalDriver_kycStatus_idx" ON "AdditionalDriver"("kycStatus");

-- AddForeignKey
ALTER TABLE "TripExtension" ADD CONSTRAINT "TripExtension_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AdditionalDriver" ADD CONSTRAINT "AdditionalDriver_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

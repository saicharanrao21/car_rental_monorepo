-- CreateEnum
CREATE TYPE "InspectionType" AS ENUM ('PRE_TRIP', 'POST_TRIP');

-- CreateEnum
CREATE TYPE "HandoverOtpType" AS ENUM ('PICKUP', 'RETURN');

-- CreateTable
CREATE TABLE "Inspection" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "type" "InspectionType" NOT NULL,
    "performedById" TEXT NOT NULL,
    "odometer" DECIMAL(10,2) NOT NULL,
    "fuelPercent" INTEGER NOT NULL,
    "conditionNotes" TEXT,
    "damagePhotos" TEXT[],
    "finalized" BOOLEAN NOT NULL DEFAULT false,
    "finalizedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Inspection_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "HandoverOtp" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "otpType" "HandoverOtpType" NOT NULL,
    "recipientId" TEXT NOT NULL,
    "otpHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "verifiedAt" TIMESTAMP(3),
    "attemptCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "HandoverOtp_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Inspection_bookingId_idx" ON "Inspection"("bookingId");

-- CreateIndex
CREATE INDEX "Inspection_performedById_idx" ON "Inspection"("performedById");

-- CreateIndex
CREATE UNIQUE INDEX "Inspection_bookingId_type_key" ON "Inspection"("bookingId", "type");

-- CreateIndex
CREATE INDEX "HandoverOtp_bookingId_otpType_idx" ON "HandoverOtp"("bookingId", "otpType");

-- CreateIndex
CREATE INDEX "HandoverOtp_recipientId_idx" ON "HandoverOtp"("recipientId");

-- AddForeignKey
ALTER TABLE "Inspection" ADD CONSTRAINT "Inspection_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Inspection" ADD CONSTRAINT "Inspection_performedById_fkey" FOREIGN KEY ("performedById") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "HandoverOtp" ADD CONSTRAINT "HandoverOtp_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "HandoverOtp" ADD CONSTRAINT "HandoverOtp_recipientId_fkey" FOREIGN KEY ("recipientId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

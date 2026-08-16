-- CreateEnum
CREATE TYPE "KycStatus" AS ENUM ('PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "BookingStatus" ADD VALUE 'HANDOVER_READY';
ALTER TYPE "BookingStatus" ADD VALUE 'RETURN_PENDING';
ALTER TYPE "BookingStatus" ADD VALUE 'REFUND_PENDING';
ALTER TYPE "BookingStatus" ADD VALUE 'REFUNDED';
ALTER TYPE "BookingStatus" ADD VALUE 'DISPUTED';
ALTER TYPE "BookingStatus" ADD VALUE 'EXPIRED';

-- CreateTable
CREATE TABLE "CustomerKyc" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "licenceNumber" TEXT NOT NULL,
    "expiryDate" TIMESTAMP(3) NOT NULL,
    "licenceFrontUrl" TEXT NOT NULL,
    "licenceBackUrl" TEXT NOT NULL,
    "status" "KycStatus" NOT NULL DEFAULT 'PENDING',
    "rejectionReason" TEXT,
    "verifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CustomerKyc_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "CustomerKyc_userId_key" ON "CustomerKyc"("userId");

-- CreateIndex
CREATE INDEX "CustomerKyc_userId_idx" ON "CustomerKyc"("userId");

-- CreateIndex
CREATE INDEX "CustomerKyc_status_idx" ON "CustomerKyc"("status");

-- AddForeignKey
ALTER TABLE "CustomerKyc" ADD CONSTRAINT "CustomerKyc_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

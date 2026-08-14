-- CreateEnum
CREATE TYPE "SecurityDepositStatus" AS ENUM ('REQUIRED', 'HELD', 'REFUNDED', 'PARTIALLY_REFUNDED', 'FORFEITED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "DamageClaimStatus" AS ENUM ('SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'PARTIALLY_APPROVED', 'REJECTED', 'SETTLED');

-- CreateTable
CREATE TABLE "SecurityDeposit" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "refundedAmount" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "deductedAmount" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "razorpayPaymentId" TEXT,
    "razorpayRefundId" TEXT,
    "status" "SecurityDepositStatus" NOT NULL DEFAULT 'REQUIRED',
    "heldAt" TIMESTAMP(3),
    "releasedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SecurityDeposit_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DamageClaim" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "claimedAmount" DECIMAL(10,2) NOT NULL,
    "approvedAmount" DECIMAL(10,2),
    "status" "DamageClaimStatus" NOT NULL DEFAULT 'SUBMITTED',
    "description" TEXT NOT NULL,
    "damagePhotos" TEXT[],
    "vendorNotes" TEXT,
    "adminNotes" TEXT,
    "customerDispute" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt" TIMESTAMP(3),

    CONSTRAINT "DamageClaim_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SecurityDeposit_bookingId_key" ON "SecurityDeposit"("bookingId");

-- CreateIndex
CREATE UNIQUE INDEX "SecurityDeposit_razorpayRefundId_key" ON "SecurityDeposit"("razorpayRefundId");

-- CreateIndex
CREATE INDEX "SecurityDeposit_bookingId_idx" ON "SecurityDeposit"("bookingId");

-- CreateIndex
CREATE INDEX "SecurityDeposit_status_idx" ON "SecurityDeposit"("status");

-- CreateIndex
CREATE INDEX "DamageClaim_bookingId_idx" ON "DamageClaim"("bookingId");

-- CreateIndex
CREATE INDEX "DamageClaim_vendorId_idx" ON "DamageClaim"("vendorId");

-- CreateIndex
CREATE INDEX "DamageClaim_status_idx" ON "DamageClaim"("status");

-- AddForeignKey
ALTER TABLE "SecurityDeposit" ADD CONSTRAINT "SecurityDeposit_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DamageClaim" ADD CONSTRAINT "DamageClaim_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DamageClaim" ADD CONSTRAINT "DamageClaim_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

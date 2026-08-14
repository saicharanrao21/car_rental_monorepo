-- CreateEnum
CREATE TYPE "RefundStatus" AS ENUM ('NONE', 'PENDING', 'PROCESSED', 'FAILED');

-- AlterTable
ALTER TABLE "Booking" ADD COLUMN     "cancellationFee" DECIMAL(10,2),
ADD COLUMN     "cancelledAt" TIMESTAMP(3),
ADD COLUMN     "cancelledBy" TEXT,
ADD COLUMN     "refundAmount" DECIMAL(10,2);

-- AlterTable
ALTER TABLE "Payment" ADD COLUMN     "razorpayRefundId" TEXT,
ADD COLUMN     "refundAmount" DECIMAL(10,2),
ADD COLUMN     "refundStatus" "RefundStatus" NOT NULL DEFAULT 'NONE';

-- CreateIndex
CREATE UNIQUE INDEX "Payment_razorpayRefundId_key" ON "Payment"("razorpayRefundId");

-- CreateIndex
CREATE INDEX "Payment_razorpayRefundId_idx" ON "Payment"("razorpayRefundId");

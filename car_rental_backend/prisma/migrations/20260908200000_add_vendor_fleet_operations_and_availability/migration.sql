-- CreateEnum
CREATE TYPE "VehicleOperationalStatus" AS ENUM ('DRAFT', 'PENDING_VERIFICATION', 'ACTIVE', 'INACTIVE', 'MAINTENANCE', 'SUSPENDED', 'RETIRED');

-- CreateEnum
CREATE TYPE "VehicleVerificationStatus" AS ENUM ('PENDING', 'VERIFIED', 'REJECTED');

-- AlterTable
ALTER TABLE "Car" ADD COLUMN "operationalStatus" "VehicleOperationalStatus" NOT NULL DEFAULT 'DRAFT',
ADD COLUMN "verificationStatus" "VehicleVerificationStatus" NOT NULL DEFAULT 'PENDING',
ADD COLUMN "serviceAreaId" TEXT,
ADD COLUMN "rejectionReason" TEXT,
ADD COLUMN "verifiedAt" TIMESTAMP(3),
ADD COLUMN "reviewedByUserId" TEXT,
ADD COLUMN "maintenanceReason" TEXT,
ADD COLUMN "maintenanceStartedAt" TIMESTAMP(3),
ADD COLUMN "expectedReturnDate" TIMESTAMP(3);

-- Update existing cars to ACTIVE and VERIFIED if isAvailable is true for backward compatibility
UPDATE "Car" SET "operationalStatus" = 'ACTIVE', "verificationStatus" = 'VERIFIED' WHERE "isAvailable" = true;

-- CreateTable
CREATE TABLE "VehicleAuditLog" (
    "id" TEXT NOT NULL,
    "carId" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "actorRole" "Role" NOT NULL DEFAULT 'VENDOR',
    "action" TEXT NOT NULL,
    "fromStatus" "VehicleOperationalStatus",
    "toStatus" "VehicleOperationalStatus" NOT NULL,
    "reason" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VehicleAuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Car_operationalStatus_idx" ON "Car"("operationalStatus");

-- CreateIndex
CREATE INDEX "Car_verificationStatus_idx" ON "Car"("verificationStatus");

-- CreateIndex
CREATE INDEX "Car_serviceAreaId_idx" ON "Car"("serviceAreaId");

-- CreateIndex
CREATE INDEX "Car_vendorId_operationalStatus_idx" ON "Car"("vendorId", "operationalStatus");

-- CreateIndex
CREATE INDEX "VehicleAuditLog_carId_idx" ON "VehicleAuditLog"("carId");

-- CreateIndex
CREATE INDEX "VehicleAuditLog_action_idx" ON "VehicleAuditLog"("action");

-- CreateIndex
CREATE INDEX "VehicleAuditLog_createdAt_idx" ON "VehicleAuditLog"("createdAt");

-- AddForeignKey
ALTER TABLE "Car" ADD CONSTRAINT "Car_serviceAreaId_fkey" FOREIGN KEY ("serviceAreaId") REFERENCES "ServiceArea"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VehicleAuditLog" ADD CONSTRAINT "VehicleAuditLog_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;

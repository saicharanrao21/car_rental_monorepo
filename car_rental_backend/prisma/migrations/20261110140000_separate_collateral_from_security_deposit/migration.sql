-- Non-destructive migration: Separate non-monetary collateral custody from monetary security deposits

-- 1. Create CollateralType Enum safely
DO $$ BEGIN
    CREATE TYPE "CollateralType" AS ENUM ('PHYSICAL_VEHICLE', 'ORIGINAL_DOCUMENT', 'DIGILOCKER_HIGH_TRUST');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Create CollateralStatus Enum safely
DO $$ BEGIN
    CREATE TYPE "CollateralStatus" AS ENUM ('HELD', 'RETURNED', 'FORFEITED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. Create CollateralRecord Table safely
CREATE TABLE IF NOT EXISTS "CollateralRecord" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "collateralType" "CollateralType" NOT NULL,
    "status" "CollateralStatus" NOT NULL DEFAULT 'HELD',
    "vehicleRegistrationNumber" TEXT,
    "vehicleMake" TEXT,
    "vehicleModel" TEXT,
    "yardSlotNumber" TEXT,
    "keysCollected" BOOLEAN NOT NULL DEFAULT false,
    "documentType" TEXT,
    "documentNumberMasked" TEXT,
    "vaultLockerNumber" TEXT,
    "verifiedPhysically" BOOLEAN NOT NULL DEFAULT false,
    "notes" TEXT,
    "photoUrls" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "customerAcknowledgementUrl" TEXT,
    "heldAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "releasedAt" TIMESTAMP(3),
    "recordedByUserId" TEXT,
    "releasedByUserId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CollateralRecord_pkey" PRIMARY KEY ("id")
);

-- 4. Create Indexes safely
CREATE UNIQUE INDEX IF NOT EXISTS "CollateralRecord_bookingId_key" ON "CollateralRecord"("bookingId");
CREATE INDEX IF NOT EXISTS "CollateralRecord_bookingId_idx" ON "CollateralRecord"("bookingId");
CREATE INDEX IF NOT EXISTS "CollateralRecord_status_idx" ON "CollateralRecord"("status");

-- 5. Create Foreign Key Reference safely
DO $$ BEGIN
    ALTER TABLE "CollateralRecord" ADD CONSTRAINT "CollateralRecord_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 6. Safe cleanup: remove any synthetic monetary security deposits erroneously stored with COLLATERAL tags while preserving all genuine monetary deposits
DELETE FROM "SecurityDeposit" WHERE "razorpayPaymentId" LIKE 'COLLATERAL:%';


-- AlterTable
ALTER TABLE "PlatformSettings" ADD COLUMN     "enabledTripTypes" TEXT[] DEFAULT ARRAY['SELF_DRIVE', 'OUTSTATION']::TEXT[];

-- CreateTable
CREATE TABLE "SupportedCity" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "state" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SupportedCity_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SupportedCity_name_key" ON "SupportedCity"("name");

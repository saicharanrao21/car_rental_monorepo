-- CreateEnum
CREATE TYPE "VehicleBlockType" AS ENUM ('MAINTENANCE', 'ACCIDENT_REPAIR', 'ROUTINE_INSPECTION', 'VENDOR_BLACKOUT', 'ADMIN_LOCK', 'SAFETY_HOLD');

-- CreateEnum
CREATE TYPE "VehicleHoldStatus" AS ENUM ('ACTIVE', 'RELEASED', 'EXPIRED', 'CONVERTED');

-- CreateEnum
CREATE TYPE "NotificationChannel" AS ENUM ('IN_APP', 'PUSH', 'SMS', 'WHATSAPP', 'EMAIL');

-- CreateEnum
CREATE TYPE "DeliveryStatus" AS ENUM ('PENDING', 'QUEUED', 'SENT', 'DELIVERED', 'FAILED', 'SKIPPED', 'DEAD_LETTER');

-- CreateEnum
CREATE TYPE "NotificationPriority" AS ENUM ('HIGH', 'NORMAL', 'LOW');

-- CreateEnum
CREATE TYPE "QuoteStatus" AS ENUM ('ACTIVE', 'ACCEPTED', 'EXPIRED', 'SUPERSEDED');

-- CreateEnum
CREATE TYPE "QuoteLineItemType" AS ENUM ('BASE_RENTAL', 'HOURLY_RENTAL', 'PACKAGE_TIER', 'DURATION_DISCOUNT', 'COUPON_DISCOUNT', 'REFERRAL_DISCOUNT', 'PLATFORM_FEE', 'GST', 'DELIVERY_FEE', 'PICKUP_FEE', 'RETURN_FEE', 'ONE_WAY_SURCHARGE', 'PROTECTION_FEE', 'SECURITY_DEPOSIT', 'EXTRA_ADDON');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "PaymentStatus" ADD VALUE 'PENDING';
ALTER TYPE "PaymentStatus" ADD VALUE 'AUTHORIZED';
ALTER TYPE "PaymentStatus" ADD VALUE 'CAPTURED';
ALTER TYPE "PaymentStatus" ADD VALUE 'CANCELLED';
ALTER TYPE "PaymentStatus" ADD VALUE 'EXPIRED';
ALTER TYPE "PaymentStatus" ADD VALUE 'PARTIALLY_REFUNDED';

-- AlterEnum
ALTER TYPE "RefundStatus" ADD VALUE 'REQUESTED';

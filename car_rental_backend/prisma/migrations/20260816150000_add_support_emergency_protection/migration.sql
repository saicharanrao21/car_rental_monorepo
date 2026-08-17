-- CreateEnum
CREATE TYPE "TicketCategory" AS ENUM ('BOOKING', 'PAYMENT', 'REFUND', 'SECURITY_DEPOSIT', 'VEHICLE', 'PICKUP_DELIVERY', 'KYC_LICENCE', 'TRIP_EXTENSION', 'DAMAGE_DISPUTE', 'EMERGENCY', 'OTHER');

-- CreateEnum
CREATE TYPE "TicketPriority" AS ENUM ('LOW', 'NORMAL', 'HIGH', 'URGENT');

-- CreateEnum
CREATE TYPE "TicketStatus" AS ENUM ('OPEN', 'ASSIGNED', 'IN_PROGRESS', 'WAITING_FOR_CUSTOMER', 'WAITING_FOR_VENDOR', 'RESOLVED', 'CLOSED');

-- CreateEnum
CREATE TYPE "IncidentType" AS ENUM ('ACCIDENT', 'BREAKDOWN', 'FLAT_TYRE', 'BATTERY', 'LOCKOUT', 'FUEL_EMERGENCY', 'ENGINE_ISSUE', 'TOWING_REQUIRED', 'MEDICAL_EMERGENCY', 'OTHER');

-- CreateEnum
CREATE TYPE "EmergencyStatus" AS ENUM ('REQUESTED', 'ACKNOWLEDGED', 'ASSIGNED', 'PROVIDER_EN_ROUTE', 'CUSTOMER_CONTACTED', 'ON_SITE', 'RESOLVED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "ProtectionPlanCode" AS ENUM ('BASIC', 'STANDARD', 'PREMIUM', 'ZERO_DEP');

-- AlterTable
ALTER TABLE "Booking" ADD COLUMN "protectionPackageId" TEXT,
ADD COLUMN "protectionCode" TEXT,
ADD COLUMN "protectionFee" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN "protectionDeductible" DECIMAL(10,2);

-- AlterTable
ALTER TABLE "Invoice" ADD COLUMN "protectionFee" DECIMAL(10,2) NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "SupportTicket" (
    "id" TEXT NOT NULL,
    "ticketNumber" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "bookingId" TEXT,
    "category" "TicketCategory" NOT NULL,
    "priority" "TicketPriority" NOT NULL DEFAULT 'NORMAL',
    "subject" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "status" "TicketStatus" NOT NULL DEFAULT 'OPEN',
    "assignedToUserId" TEXT,
    "resolvedAt" TIMESTAMP(3),
    "closedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SupportTicket_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TicketMessage" (
    "id" TEXT NOT NULL,
    "ticketId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "senderRole" "Role" NOT NULL,
    "message" TEXT NOT NULL,
    "attachments" TEXT[],
    "isInternal" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TicketMessage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EmergencyRequest" (
    "id" TEXT NOT NULL,
    "requestNumber" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "carId" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "incidentType" "IncidentType" NOT NULL,
    "urgency" "TicketPriority" NOT NULL DEFAULT 'URGENT',
    "status" "EmergencyStatus" NOT NULL DEFAULT 'REQUESTED',
    "customerNotes" TEXT,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "locationAddress" TEXT,
    "assignedProviderName" TEXT,
    "assignedProviderPhone" TEXT,
    "contactNotes" TEXT,
    "resolutionNotes" TEXT,
    "estimatedEtaMinutes" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "resolvedAt" TIMESTAMP(3),

    CONSTRAINT "EmergencyRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProtectionPackage" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" "ProtectionPlanCode" NOT NULL,
    "description" TEXT NOT NULL,
    "dailyRate" DECIMAL(10,2) NOT NULL,
    "coverageSummary" TEXT[],
    "deductibleAmount" DECIMAL(10,2) NOT NULL,
    "maxCoverageAmount" DECIMAL(10,2) NOT NULL,
    "exclusions" TEXT[],
    "termsUrl" TEXT,
    "city" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "displayOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ProtectionPackage_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SupportTicket_ticketNumber_key" ON "SupportTicket"("ticketNumber");
CREATE INDEX "SupportTicket_customerId_idx" ON "SupportTicket"("customerId");
CREATE INDEX "SupportTicket_bookingId_idx" ON "SupportTicket"("bookingId");
CREATE INDEX "SupportTicket_status_idx" ON "SupportTicket"("status");
CREATE INDEX "SupportTicket_category_idx" ON "SupportTicket"("category");
CREATE INDEX "SupportTicket_priority_idx" ON "SupportTicket"("priority");
CREATE INDEX "SupportTicket_assignedToUserId_idx" ON "SupportTicket"("assignedToUserId");

-- CreateIndex
CREATE INDEX "TicketMessage_ticketId_idx" ON "TicketMessage"("ticketId");
CREATE INDEX "TicketMessage_senderId_idx" ON "TicketMessage"("senderId");

-- CreateIndex
CREATE UNIQUE INDEX "EmergencyRequest_requestNumber_key" ON "EmergencyRequest"("requestNumber");
CREATE INDEX "EmergencyRequest_customerId_idx" ON "EmergencyRequest"("customerId");
CREATE INDEX "EmergencyRequest_bookingId_idx" ON "EmergencyRequest"("bookingId");
CREATE INDEX "EmergencyRequest_vendorId_idx" ON "EmergencyRequest"("vendorId");
CREATE INDEX "EmergencyRequest_city_idx" ON "EmergencyRequest"("city");
CREATE INDEX "EmergencyRequest_status_idx" ON "EmergencyRequest"("status");
CREATE INDEX "EmergencyRequest_incidentType_idx" ON "EmergencyRequest"("incidentType");

-- CreateIndex
CREATE INDEX "ProtectionPackage_city_idx" ON "ProtectionPackage"("city");
CREATE INDEX "ProtectionPackage_isActive_idx" ON "ProtectionPackage"("isActive");
CREATE UNIQUE INDEX "ProtectionPackage_code_city_key" ON "ProtectionPackage"("code", "city");

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_protectionPackageId_fkey" FOREIGN KEY ("protectionPackageId") REFERENCES "ProtectionPackage"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SupportTicket" ADD CONSTRAINT "SupportTicket_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SupportTicket" ADD CONSTRAINT "SupportTicket_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SupportTicket" ADD CONSTRAINT "SupportTicket_assignedToUserId_fkey" FOREIGN KEY ("assignedToUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TicketMessage" ADD CONSTRAINT "TicketMessage_ticketId_fkey" FOREIGN KEY ("ticketId") REFERENCES "SupportTicket"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TicketMessage" ADD CONSTRAINT "TicketMessage_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EmergencyRequest" ADD CONSTRAINT "EmergencyRequest_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EmergencyRequest" ADD CONSTRAINT "EmergencyRequest_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EmergencyRequest" ADD CONSTRAINT "EmergencyRequest_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EmergencyRequest" ADD CONSTRAINT "EmergencyRequest_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

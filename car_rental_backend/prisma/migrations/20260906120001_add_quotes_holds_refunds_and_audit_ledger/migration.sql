-- AlterTable
ALTER TABLE "Booking" ADD COLUMN     "priceSnapshot" JSONB,
ADD COLUMN     "quoteId" TEXT;

-- AlterTable
ALTER TABLE "Notification" ADD COLUMN     "priority" "NotificationPriority" NOT NULL DEFAULT 'NORMAL';

-- AlterTable
ALTER TABLE "Payment" ADD COLUMN     "capturedAt" TIMESTAMP(3),
ADD COLUMN     "currency" TEXT NOT NULL DEFAULT 'INR',
ADD COLUMN     "failedAt" TIMESTAMP(3),
ADD COLUMN     "failureReason" TEXT,
ADD COLUMN     "gatewayAmountPaise" INTEGER,
ADD COLUMN     "gatewayProvider" TEXT NOT NULL DEFAULT 'RAZORPAY',
ADD COLUMN     "gatewaySignature" TEXT,
ADD COLUMN     "idempotencyKey" TEXT,
ADD COLUMN     "metadata" JSONB,
ADD COLUMN     "paymentMethod" TEXT,
ADD COLUMN     "tenantId" TEXT NOT NULL DEFAULT 'default';

-- CreateTable
CREATE TABLE "VehicleBlock" (
    "id" TEXT NOT NULL,
    "carId" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "blockType" "VehicleBlockType" NOT NULL DEFAULT 'VENDOR_BLACKOUT',
    "reason" TEXT,
    "actorId" TEXT NOT NULL,
    "actorRole" "Role" NOT NULL DEFAULT 'VENDOR',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VehicleBlock_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VehicleHold" (
    "id" TEXT NOT NULL,
    "carId" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "status" "VehicleHoldStatus" NOT NULL DEFAULT 'ACTIVE',
    "idempotencyKey" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VehicleHold_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NotificationDelivery" (
    "id" TEXT NOT NULL,
    "notificationId" TEXT NOT NULL,
    "channel" "NotificationChannel" NOT NULL,
    "status" "DeliveryStatus" NOT NULL DEFAULT 'PENDING',
    "recipient" TEXT NOT NULL,
    "provider" TEXT,
    "providerMessageId" TEXT,
    "attemptCount" INTEGER NOT NULL DEFAULT 0,
    "maxRetries" INTEGER NOT NULL DEFAULT 3,
    "lastError" TEXT,
    "deliveredAt" TIMESTAMP(3),
    "failedAt" TIMESTAMP(3),
    "idempotencyKey" TEXT NOT NULL,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NotificationDelivery_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PaymentRefund" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL DEFAULT 'default',
    "paymentId" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "gatewayRefundId" TEXT,
    "idempotencyKey" TEXT NOT NULL,
    "requestedAmount" DECIMAL(10,2) NOT NULL,
    "processedAmount" DECIMAL(10,2),
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "reason" TEXT,
    "requestedByUserId" TEXT,
    "status" "RefundStatus" NOT NULL DEFAULT 'REQUESTED',
    "failureReason" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PaymentRefund_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PaymentAuditLog" (
    "id" TEXT NOT NULL,
    "paymentId" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL DEFAULT 'default',
    "eventType" TEXT NOT NULL,
    "fromStatus" "PaymentStatus",
    "toStatus" "PaymentStatus" NOT NULL,
    "amount" DECIMAL(10,2),
    "gatewayReference" TEXT,
    "actorId" TEXT,
    "actorRole" TEXT,
    "source" TEXT NOT NULL,
    "payloadHash" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PaymentAuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WebhookEvent" (
    "id" TEXT NOT NULL,
    "gateway" TEXT NOT NULL DEFAULT 'RAZORPAY',
    "eventId" TEXT NOT NULL,
    "eventType" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "signature" TEXT,
    "status" TEXT NOT NULL DEFAULT 'PROCESSED',
    "processedAt" TIMESTAMP(3),
    "failureReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WebhookEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BookingOutboxEvent" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "eventType" TEXT NOT NULL,
    "aggregateType" TEXT NOT NULL DEFAULT 'BOOKING',
    "aggregateId" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "actorRole" TEXT NOT NULL,
    "previousStatus" "BookingStatus",
    "newStatus" "BookingStatus" NOT NULL,
    "correlationId" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "retryCount" INTEGER NOT NULL DEFAULT 0,
    "maxRetries" INTEGER NOT NULL DEFAULT 3,
    "lastError" TEXT,
    "processedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BookingOutboxEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BookingQuote" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "customerId" TEXT,
    "carId" TEXT NOT NULL,
    "tripType" "TripType" NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "durationDays" INTEGER NOT NULL,
    "durationHours" INTEGER NOT NULL,
    "pricingVersion" TEXT NOT NULL DEFAULT 'v1.0',
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "subtotal" DECIMAL(10,2) NOT NULL,
    "discountTotal" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "feesTotal" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "taxTotal" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "depositTotal" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "totalPayable" DECIMAL(10,2) NOT NULL,
    "netToVendor" DECIMAL(10,2) NOT NULL,
    "status" "QuoteStatus" NOT NULL DEFAULT 'ACTIVE',
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "acceptedAt" TIMESTAMP(3),
    "idempotencyKey" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BookingQuote_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BookingQuoteLineItem" (
    "id" TEXT NOT NULL,
    "quoteId" TEXT NOT NULL,
    "type" "QuoteLineItemType" NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "rate" DECIMAL(10,2) NOT NULL,
    "quantity" DECIMAL(10,2) NOT NULL DEFAULT 1,
    "amount" DECIMAL(10,2) NOT NULL,
    "isRefundable" BOOLEAN NOT NULL DEFAULT false,
    "displayOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BookingQuoteLineItem_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "VehicleBlock_carId_idx" ON "VehicleBlock"("carId");

-- CreateIndex
CREATE INDEX "VehicleBlock_vendorId_idx" ON "VehicleBlock"("vendorId");

-- CreateIndex
CREATE INDEX "VehicleBlock_carId_startDate_endDate_idx" ON "VehicleBlock"("carId", "startDate", "endDate");

-- CreateIndex
CREATE INDEX "VehicleBlock_startDate_endDate_idx" ON "VehicleBlock"("startDate", "endDate");

-- CreateIndex
CREATE UNIQUE INDEX "VehicleHold_idempotencyKey_key" ON "VehicleHold"("idempotencyKey");

-- CreateIndex
CREATE INDEX "VehicleHold_carId_idx" ON "VehicleHold"("carId");

-- CreateIndex
CREATE INDEX "VehicleHold_customerId_idx" ON "VehicleHold"("customerId");

-- CreateIndex
CREATE INDEX "VehicleHold_vendorId_idx" ON "VehicleHold"("vendorId");

-- CreateIndex
CREATE INDEX "VehicleHold_carId_startDate_endDate_status_idx" ON "VehicleHold"("carId", "startDate", "endDate", "status");

-- CreateIndex
CREATE INDEX "VehicleHold_status_expiresAt_idx" ON "VehicleHold"("status", "expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "NotificationDelivery_idempotencyKey_key" ON "NotificationDelivery"("idempotencyKey");

-- CreateIndex
CREATE INDEX "NotificationDelivery_notificationId_idx" ON "NotificationDelivery"("notificationId");

-- CreateIndex
CREATE INDEX "NotificationDelivery_channel_status_idx" ON "NotificationDelivery"("channel", "status");

-- CreateIndex
CREATE INDEX "NotificationDelivery_status_createdAt_idx" ON "NotificationDelivery"("status", "createdAt");

-- CreateIndex
CREATE INDEX "NotificationDelivery_providerMessageId_idx" ON "NotificationDelivery"("providerMessageId");

-- CreateIndex
CREATE UNIQUE INDEX "PaymentRefund_gatewayRefundId_key" ON "PaymentRefund"("gatewayRefundId");

-- CreateIndex
CREATE UNIQUE INDEX "PaymentRefund_idempotencyKey_key" ON "PaymentRefund"("idempotencyKey");

-- CreateIndex
CREATE INDEX "PaymentRefund_tenantId_status_idx" ON "PaymentRefund"("tenantId", "status");

-- CreateIndex
CREATE INDEX "PaymentRefund_paymentId_idx" ON "PaymentRefund"("paymentId");

-- CreateIndex
CREATE INDEX "PaymentRefund_bookingId_idx" ON "PaymentRefund"("bookingId");

-- CreateIndex
CREATE INDEX "PaymentRefund_status_idx" ON "PaymentRefund"("status");

-- CreateIndex
CREATE INDEX "PaymentRefund_idempotencyKey_idx" ON "PaymentRefund"("idempotencyKey");

-- CreateIndex
CREATE INDEX "PaymentRefund_gatewayRefundId_idx" ON "PaymentRefund"("gatewayRefundId");

-- CreateIndex
CREATE INDEX "PaymentAuditLog_paymentId_idx" ON "PaymentAuditLog"("paymentId");

-- CreateIndex
CREATE INDEX "PaymentAuditLog_bookingId_idx" ON "PaymentAuditLog"("bookingId");

-- CreateIndex
CREATE INDEX "PaymentAuditLog_tenantId_idx" ON "PaymentAuditLog"("tenantId");

-- CreateIndex
CREATE INDEX "PaymentAuditLog_eventType_idx" ON "PaymentAuditLog"("eventType");

-- CreateIndex
CREATE INDEX "PaymentAuditLog_createdAt_idx" ON "PaymentAuditLog"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "WebhookEvent_eventId_key" ON "WebhookEvent"("eventId");

-- CreateIndex
CREATE INDEX "WebhookEvent_gateway_eventType_idx" ON "WebhookEvent"("gateway", "eventType");

-- CreateIndex
CREATE INDEX "WebhookEvent_eventId_idx" ON "WebhookEvent"("eventId");

-- CreateIndex
CREATE INDEX "WebhookEvent_createdAt_idx" ON "WebhookEvent"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "BookingOutboxEvent_correlationId_key" ON "BookingOutboxEvent"("correlationId");

-- CreateIndex
CREATE INDEX "BookingOutboxEvent_bookingId_idx" ON "BookingOutboxEvent"("bookingId");

-- CreateIndex
CREATE INDEX "BookingOutboxEvent_status_createdAt_idx" ON "BookingOutboxEvent"("status", "createdAt");

-- CreateIndex
CREATE INDEX "BookingOutboxEvent_eventType_idx" ON "BookingOutboxEvent"("eventType");

-- CreateIndex
CREATE INDEX "BookingOutboxEvent_correlationId_idx" ON "BookingOutboxEvent"("correlationId");

-- CreateIndex
CREATE INDEX "BookingOutboxEvent_tenantId_idx" ON "BookingOutboxEvent"("tenantId");

-- CreateIndex
CREATE UNIQUE INDEX "BookingQuote_idempotencyKey_key" ON "BookingQuote"("idempotencyKey");

-- CreateIndex
CREATE INDEX "BookingQuote_tenantId_idx" ON "BookingQuote"("tenantId");

-- CreateIndex
CREATE INDEX "BookingQuote_carId_idx" ON "BookingQuote"("carId");

-- CreateIndex
CREATE INDEX "BookingQuote_customerId_idx" ON "BookingQuote"("customerId");

-- CreateIndex
CREATE INDEX "BookingQuote_status_expiresAt_idx" ON "BookingQuote"("status", "expiresAt");

-- CreateIndex
CREATE INDEX "BookingQuote_idempotencyKey_idx" ON "BookingQuote"("idempotencyKey");

-- CreateIndex
CREATE INDEX "BookingQuoteLineItem_quoteId_idx" ON "BookingQuoteLineItem"("quoteId");

-- CreateIndex
CREATE INDEX "BookingQuoteLineItem_type_idx" ON "BookingQuoteLineItem"("type");

-- CreateIndex
CREATE INDEX "Booking_quoteId_idx" ON "Booking"("quoteId");

-- CreateIndex
CREATE UNIQUE INDEX "Payment_idempotencyKey_key" ON "Payment"("idempotencyKey");

-- CreateIndex
CREATE INDEX "Payment_tenantId_status_idx" ON "Payment"("tenantId", "status");

-- CreateIndex
CREATE INDEX "Payment_gatewayProvider_idx" ON "Payment"("gatewayProvider");

-- CreateIndex
CREATE INDEX "Payment_idempotencyKey_idx" ON "Payment"("idempotencyKey");

-- CreateIndex
CREATE INDEX "UserDevice_userId_deviceId_idx" ON "UserDevice"("userId", "deviceId");

-- AddForeignKey
ALTER TABLE "VehicleBlock" ADD CONSTRAINT "VehicleBlock_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VehicleHold" ADD CONSTRAINT "VehicleHold_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_quoteId_fkey" FOREIGN KEY ("quoteId") REFERENCES "BookingQuote"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationDelivery" ADD CONSTRAINT "NotificationDelivery_notificationId_fkey" FOREIGN KEY ("notificationId") REFERENCES "Notification"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PaymentRefund" ADD CONSTRAINT "PaymentRefund_paymentId_fkey" FOREIGN KEY ("paymentId") REFERENCES "Payment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PaymentAuditLog" ADD CONSTRAINT "PaymentAuditLog_paymentId_fkey" FOREIGN KEY ("paymentId") REFERENCES "Payment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingOutboxEvent" ADD CONSTRAINT "BookingOutboxEvent_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingQuote" ADD CONSTRAINT "BookingQuote_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingQuoteLineItem" ADD CONSTRAINT "BookingQuoteLineItem_quoteId_fkey" FOREIGN KEY ("quoteId") REFERENCES "BookingQuote"("id") ON DELETE CASCADE ON UPDATE CASCADE;

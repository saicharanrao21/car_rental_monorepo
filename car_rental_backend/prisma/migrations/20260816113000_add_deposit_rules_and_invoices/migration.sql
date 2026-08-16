-- CreateTable
CREATE TABLE "DepositRule" (
    "id" TEXT NOT NULL,
    "carCategory" "CarCategory" NOT NULL,
    "city" TEXT,
    "depositAmount" DECIMAL(65,30) NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DepositRule_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Invoice" (
    "id" TEXT NOT NULL,
    "invoiceNumber" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "paymentId" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "baseFare" DECIMAL(65,30) NOT NULL,
    "platformFee" DECIMAL(65,30) NOT NULL,
    "gstRate" DECIMAL(65,30) NOT NULL DEFAULT 18.00,
    "gstAmount" DECIMAL(65,30) NOT NULL,
    "discountAmount" DECIMAL(65,30) NOT NULL DEFAULT 0.00,
    "totalFare" DECIMAL(65,30) NOT NULL,
    "depositAmount" DECIMAL(65,30) NOT NULL DEFAULT 0.00,
    "pdfUrl" TEXT,
    "issuedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Invoice_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CreditNote" (
    "id" TEXT NOT NULL,
    "creditNoteNumber" TEXT NOT NULL,
    "invoiceId" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "amount" DECIMAL(65,30) NOT NULL,
    "reason" TEXT NOT NULL,
    "issuedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "pdfUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CreditNote_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "DepositRule_carCategory_isActive_idx" ON "DepositRule"("carCategory", "isActive");

-- CreateIndex
CREATE INDEX "DepositRule_city_idx" ON "DepositRule"("city");

-- CreateIndex
CREATE UNIQUE INDEX "DepositRule_carCategory_city_key" ON "DepositRule"("carCategory", "city");

-- CreateIndex
CREATE UNIQUE INDEX "Invoice_invoiceNumber_key" ON "Invoice"("invoiceNumber");

-- CreateIndex
CREATE UNIQUE INDEX "Invoice_bookingId_key" ON "Invoice"("bookingId");

-- CreateIndex
CREATE INDEX "Invoice_customerId_idx" ON "Invoice"("customerId");

-- CreateIndex
CREATE INDEX "Invoice_vendorId_idx" ON "Invoice"("vendorId");

-- CreateIndex
CREATE INDEX "Invoice_issuedAt_idx" ON "Invoice"("issuedAt");

-- CreateIndex
CREATE UNIQUE INDEX "CreditNote_creditNoteNumber_key" ON "CreditNote"("creditNoteNumber");

-- CreateIndex
CREATE INDEX "CreditNote_invoiceId_idx" ON "CreditNote"("invoiceId");

-- CreateIndex
CREATE INDEX "CreditNote_bookingId_idx" ON "CreditNote"("bookingId");

-- AddForeignKey
ALTER TABLE "Invoice" ADD CONSTRAINT "Invoice_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Invoice" ADD CONSTRAINT "Invoice_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Invoice" ADD CONSTRAINT "Invoice_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CreditNote" ADD CONSTRAINT "CreditNote_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "Invoice"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CreditNote" ADD CONSTRAINT "CreditNote_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "IntegrationExecution" (
    "id" TEXT NOT NULL,
    "correlationId" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "capability" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "finalProviderId" TEXT,
    "fallbackOccurred" BOOLEAN NOT NULL DEFAULT false,
    "environment" TEXT NOT NULL DEFAULT 'SANDBOX',
    "tenantId" TEXT,
    "vendorId" TEXT,
    "branchId" TEXT,
    "region" TEXT,
    "currency" TEXT,
    "idempotencyKey" TEXT,
    "requestPayload" JSONB,
    "responsePayload" JSONB,
    "errorClassification" TEXT,
    "errorMessage" TEXT,
    "latencyMs" INTEGER NOT NULL DEFAULT 0,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "IntegrationExecution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "IntegrationAttempt" (
    "id" TEXT NOT NULL,
    "executionId" TEXT NOT NULL,
    "attemptNumber" INTEGER NOT NULL,
    "providerId" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "errorClassification" TEXT,
    "errorMessage" TEXT,
    "latencyMs" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "IntegrationAttempt_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderIncident" (
    "id" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'INVESTIGATING',
    "severity" TEXT NOT NULL DEFAULT 'MEDIUM',
    "circuitState" TEXT NOT NULL DEFAULT 'CLOSED',
    "errorRate" DOUBLE PRECISION,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt" TIMESTAMP(3),
    "reason" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProviderIncident_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "IntegrationExecution_correlationId_key" ON "IntegrationExecution"("correlationId");

-- CreateIndex
CREATE INDEX "IntegrationExecution_correlationId_idx" ON "IntegrationExecution"("correlationId");

-- CreateIndex
CREATE INDEX "IntegrationExecution_category_capability_idx" ON "IntegrationExecution"("category", "capability");

-- CreateIndex
CREATE INDEX "IntegrationExecution_providerId_status_idx" ON "IntegrationExecution"("providerId", "status");

-- CreateIndex
CREATE INDEX "IntegrationExecution_vendorId_createdAt_idx" ON "IntegrationExecution"("vendorId", "createdAt");

-- CreateIndex
CREATE INDEX "IntegrationExecution_idempotencyKey_idx" ON "IntegrationExecution"("idempotencyKey");

-- CreateIndex
CREATE INDEX "IntegrationExecution_createdAt_idx" ON "IntegrationExecution"("createdAt");

-- CreateIndex
CREATE INDEX "IntegrationAttempt_executionId_idx" ON "IntegrationAttempt"("executionId");

-- CreateIndex
CREATE INDEX "IntegrationAttempt_providerId_status_idx" ON "IntegrationAttempt"("providerId", "status");

-- CreateIndex
CREATE INDEX "IntegrationAttempt_createdAt_idx" ON "IntegrationAttempt"("createdAt");

-- CreateIndex
CREATE INDEX "ProviderIncident_providerId_category_idx" ON "ProviderIncident"("providerId", "category");

-- CreateIndex
CREATE INDEX "ProviderIncident_status_idx" ON "ProviderIncident"("status");

-- CreateIndex
CREATE INDEX "ProviderIncident_createdAt_idx" ON "ProviderIncident"("createdAt");

-- AddForeignKey
ALTER TABLE "IntegrationAttempt" ADD CONSTRAINT "IntegrationAttempt_executionId_fkey" FOREIGN KEY ("executionId") REFERENCES "IntegrationExecution"("id") ON DELETE CASCADE ON UPDATE CASCADE;

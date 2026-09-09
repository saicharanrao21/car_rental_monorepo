-- CreateTable
CREATE TABLE "ProviderChangeEvent" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "changeType" TEXT NOT NULL,
    "environment" TEXT NOT NULL DEFAULT 'SANDBOX',
    "actorId" TEXT NOT NULL,
    "actorRole" TEXT NOT NULL,
    "reason" TEXT,
    "beforeSnapshot" JSONB,
    "afterSnapshot" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProviderChangeEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderRoutingPolicy" (
    "id" TEXT NOT NULL,
    "policyId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "tenantScope" TEXT NOT NULL DEFAULT 'PLATFORM',
    "scopeId" TEXT,
    "strategy" TEXT NOT NULL DEFAULT 'PRIORITY',
    "primaryProviderId" TEXT NOT NULL,
    "fallbackChain" JSONB NOT NULL,
    "weights" JSONB,
    "rules" JSONB,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProviderRoutingPolicy_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderRecommendation" (
    "id" TEXT NOT NULL,
    "recommendationId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "targetProviderId" TEXT NOT NULL,
    "suggestedProviderId" TEXT,
    "severity" TEXT NOT NULL DEFAULT 'MEDIUM',
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "estimatedImpact" JSONB,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "reviewedBy" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProviderRecommendation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderOperationalMetric" (
    "id" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "environment" TEXT NOT NULL DEFAULT 'SANDBOX',
    "windowStart" TIMESTAMP(3) NOT NULL,
    "windowEnd" TIMESTAMP(3) NOT NULL,
    "requestCount" INTEGER NOT NULL DEFAULT 0,
    "successCount" INTEGER NOT NULL DEFAULT 0,
    "failureCount" INTEGER NOT NULL DEFAULT 0,
    "timeoutCount" INTEGER NOT NULL DEFAULT 0,
    "p50LatencyMs" INTEGER NOT NULL DEFAULT 0,
    "p95LatencyMs" INTEGER NOT NULL DEFAULT 0,
    "p99LatencyMs" INTEGER NOT NULL DEFAULT 0,
    "errorDistribution" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProviderOperationalMetric_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ProviderChangeEvent_eventId_key" ON "ProviderChangeEvent"("eventId");

-- CreateIndex
CREATE INDEX "ProviderChangeEvent_providerId_category_idx" ON "ProviderChangeEvent"("providerId", "category");

-- CreateIndex
CREATE INDEX "ProviderChangeEvent_changeType_idx" ON "ProviderChangeEvent"("changeType");

-- CreateIndex
CREATE INDEX "ProviderChangeEvent_actorId_idx" ON "ProviderChangeEvent"("actorId");

-- CreateIndex
CREATE INDEX "ProviderChangeEvent_createdAt_idx" ON "ProviderChangeEvent"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "ProviderRoutingPolicy_policyId_key" ON "ProviderRoutingPolicy"("policyId");

-- CreateIndex
CREATE INDEX "ProviderRoutingPolicy_category_tenantScope_scopeId_idx" ON "ProviderRoutingPolicy"("category", "tenantScope", "scopeId");

-- CreateIndex
CREATE INDEX "ProviderRoutingPolicy_isActive_idx" ON "ProviderRoutingPolicy"("isActive");

-- CreateIndex
CREATE UNIQUE INDEX "ProviderRecommendation_recommendationId_key" ON "ProviderRecommendation"("recommendationId");

-- CreateIndex
CREATE INDEX "ProviderRecommendation_category_status_idx" ON "ProviderRecommendation"("category", "status");

-- CreateIndex
CREATE INDEX "ProviderRecommendation_targetProviderId_idx" ON "ProviderRecommendation"("targetProviderId");

-- CreateIndex
CREATE INDEX "ProviderRecommendation_createdAt_idx" ON "ProviderRecommendation"("createdAt");

-- CreateIndex
CREATE INDEX "ProviderOperationalMetric_providerId_category_environment_idx" ON "ProviderOperationalMetric"("providerId", "category", "environment");

-- CreateIndex
CREATE INDEX "ProviderOperationalMetric_windowStart_windowEnd_idx" ON "ProviderOperationalMetric"("windowStart", "windowEnd");

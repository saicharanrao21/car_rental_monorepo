# Phase K: Enterprise Integration Runtime, Routing & Intelligent Failover

## 1. Executive Summary

Phase K elevates the DriveGo / PlayHub mobility platform into an enterprise-grade, provider-agnostic, resilient integration platform.
Building on the Phase I integration architecture and Phase J provider catalog/marketplace, Phase K establishes a centralized, intelligent **Integration Runtime** capable of:
- Routing requests across **11 dynamic routing strategies**
- Negotiating capabilities, currencies, regions, and environment constraints
- Automatically executing **fallback chains** with zero business service disruption
- Guarding upstream availability with **3-state circuit breakers** (`CLOSED`, `OPEN`, `HALF_OPEN`)
- Token bucket **rate limiting** and concurrency guards
- 11-category **failure classification** with exponential backoff & jitter
- Strict **idempotency deduplication** (preventing duplicate charges, refunds, or messages)
- **Rolling telemetry & latency analytics** (p50, p95, p99)
- Structured **secret-sanitized telemetry** and Prisma persistence
- Sandbox **simulation engine** for failure testing without real provider credentials
- Dedicated **Flutter Admin Command Centre** with live gauges, circuit switches, and simulation runners.

```
+-------------------------------------------------------------------------+
|                              BUSINESS LAYER                             |
|          (PaymentsService, NotificationOrchestrator, Uploads)           |
+-------------------------------------------------------------------------+
                                     |
                       execute({ category, capability })
                                     v
+-------------------------------------------------------------------------+
|                        INTEGRATION RUNTIME ENGINE                       |
|  - Idempotency Deduplication Check                                      |
|  - Capability Negotiation (Currency, Region, Env)                       |
|  - Policy Engine Evaluation (Tenant / Vendor / Branch rules)            |
|  - Dynamic Provider Routing Engine (11 Strategies)                      |
|  - Circuit Breaker Check (CLOSED / OPEN / HALF_OPEN)                    |
|  - Token Bucket Rate Limiter & Concurrency Slot                         |
|  - Attempt & Safe Retry Engine (Exponential backoff + jitter)           |
|  - Automated Fallback Failover Execution Loop                           |
|  - Secret Sanitization & Structured Telemetry Audit                     |
|  - Database Persistence (IntegrationExecution, Incident)                |
+-------------------------------------------------------------------------+
        |                    |                    |                   |
        v                    v                    v                   v
 [Razorpay Adapter]   [Stripe Adapter]   [Cashfree Adapter]   [Mock Adapter]
```

---

## 2. Architecture & Components

### 2.1 Integration Execution Engine (`IntegrationRuntimeService`)
Exposes a unified execution contract:
```typescript
execute<TInput, TOutput>(request: IntegrationExecutionRequest<TInput>): Promise<IntegrationExecutionResult<TOutput>>
```
The caller receives a normalized response without needing to know which provider processed the transaction.

### 2.2 Provider Routing Engine (`ProviderRoutingService`)
Supports 11 first-class routing strategies:
1. `PRIMARY`: Uses configured active gateway.
2. `PRIORITY`: Dispatches by provider priority ascending.
3. `ROUND_ROBIN`: Cycles healthy providers sequentially.
4. `WEIGHTED`: Random distribution proportional to provider weight.
5. `LEAST_LATENCY`: Selects provider with lowest p50 latency.
6. `HEALTH_BASED`: Selects provider with highest success rate and lowest failure streak.
7. `REGION_BASED`: Selects providers dedicated to the destination country.
8. `CURRENCY_BASED`: Selects native currency processors (e.g. INR for UPI, AED for Emirates).
9. `CAPABILITY_BASED`: Matches exact required sub-capabilities.
10. `COST_OPTIMIZED`: Evaluates lowest cost model for transaction volume.
11. `CUSTOM_RULE`: Applies tenant/vendor/branch policy overrides.

### 2.3 Circuit Breakers (`CircuitBreakerService`)
- States: `CLOSED`, `OPEN`, `HALF_OPEN`.
- Failure threshold: Trips to `OPEN` when consecutive or windowed failures exceed threshold.
- Open cooldown: Automatically probes via `HALF_OPEN` after configured cooldown duration.
- Success threshold: Closes circuit once trial probes succeed.
- Administrative controls: Manual trip and manual reset endpoints exposed in Admin API and UI.

### 2.4 Rate Limiting & Concurrency (`ProviderRateLimiterService`)
- Token bucket algorithm for RPS and RPM enforcement.
- Active concurrency counters per provider to prevent thread/socket exhaustion.
- Scoped by provider, tenant, vendor, or capability.

### 2.5 Failure Classification & Safe Retries (`FailureClassifierService`)
Classifies errors into 11 categories:
- `TRANSIENT`: 503, 502, socket drop. Retryable and fallback-eligible.
- `RATE_LIMITED`: 429 quota. Fallback-eligible; respects `Retry-After`.
- `TIMEOUT`: 504 gateway timeout. Fallback-eligible.
- `NETWORK`: ECONNRESET, ECONNREFUSED. Retryable and fallback-eligible.
- `AUTHENTICATION`: 401/403 credentials invalid. Fallback-eligible; non-retryable on same provider.
- `INVALID_REQUEST`: 400 bad schema. Non-retryable and non-fallback-eligible (aborts to prevent cascade).
- `PROVIDER_DECLINED`: 402 card declined. Fallback-eligible (try secondary gateway).
- `DUPLICATE`: Idempotency collision.
- `NOT_SUPPORTED`: Capability mismatch.
- `CONFIGURATION`: Misconfigured credentials.
- `PERMANENT`: Fatal unrecoverable error.

**Safe Retry Invariant**: Non-idempotent operations are never blindly retried on the same provider unless explicitly declared idempotent or secured by an `idempotencyKey`.

### 2.6 Simulation & Sandbox Engine (`ProviderSimulationService`)
Allows zero-credential end-to-end verification of failovers:
- `SUCCESS`
- `TIMEOUT`
- `NETWORK_FAILURE`
- `AUTH_FAILURE`
- `RATE_LIMIT`
- `PROVIDER_DECLINED`
- `SLOW_RESPONSE`
- `MALFORMED_RESPONSE`

---

## 3. Database Persistence & Prisma Schema

Added models:
1. `IntegrationExecution`: Records correlation ID, category, capability, status, primary provider, final provider, fallback indicator, sanitized payloads, latency, and tenant/vendor/branch scoping.
2. `IntegrationAttempt`: Captures every attempt in the fallback chain, attempt number, provider ID, status, failure classification, error message, and latency.
3. `ProviderIncident`: Tracks open outages, degraded circuit states, start times, and resolution timestamps.

---

## 4. Admin Operations Control Centre

The Flutter Admin Panel features an operational Command Centre:
- **Live Circuit Grid**: Real-time state badges (`CLOSED`, `OPEN`, `HALF_OPEN`) with Reset/Trip actions.
- **Rolling Health Gauges**: Displays live success rate %, p50/p95/p99 latencies, and failure streaks.
- **Fallback Visualizer**: Displays multi-hop failover chains visually per category.
- **Failover Simulator**: Interactive runner testing timeouts, rate limits, and network errors.

---

## 5. Operational Runbook & Incident Handling

1. **Investigating an Incident**:
   - Check `GET /admin/integrations/runtime/incidents` or the Admin UI alert banner.
   - Inspect circuit state via `GET /admin/integrations/runtime/circuits`.
2. **Tripping an Unhealthy Provider**:
   - Call `POST /admin/integrations/runtime/circuits/:providerId/trip`.
   - The runtime immediately bypasses that provider and fails over to configured secondary gateways.
3. **Resetting a Recovered Provider**:
   - Call `POST /admin/integrations/runtime/circuits/:providerId/reset`.
   - The circuit returns to `CLOSED` and the incident is marked `RESOLVED`.

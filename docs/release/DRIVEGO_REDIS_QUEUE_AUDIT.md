# DriveGo — Redis, Queues & Concurrency Audit (Phase 5)

**Audit Execution Date:** October 28, 2026  
**Auditor:** Principal Systems Architect & SRE Lead  
**Scope:** Distributed Caching, BullMQ Job Queues, Concurrency Locks, and Provider Quotas  

---

## 1. Redis Connection & Provider Architecture

### A. Environment Configuration & Connection Semantics
- **Connection Variable:** `REDIS_URL` (e.g. `redis://...` for unencrypted local or `rediss://...` for TLS-encrypted managed providers).
- **Client Library:** `ioredis` 5.11.1.
- **Fail-Safe Startup Guard (`src/common/env.validation.ts`):**
  - In `production`: `REDIS_URL` is strictly mandatory and cannot use `ioredis-mock`.
  - In `development` / `test`: Defaults to `ioredis-mock` when `REDIS_USE_MOCK === 'true'`.

### B. Upstash Free-Tier Quota Reality & Recommendation
In earlier staging deployments, Upstash serverless Redis exceeded its daily command rate limit (10,000 commands/day on free tier) due to:
1. BullMQ worker polling loops (`brpoplpush` / stream polling).
2. Vehicle availability search caching and TTL refreshes.
3. Fast-interval rate-limiting checks.

**Architectural Recommendation:**
Serverless Redis providers with command-count billing are **ill-suited** for high-frequency BullMQ queue workers. Production DriveGo requires a dedicated, persistent Redis instance:
- **Primary Recommendation:** Render Dedicated Redis or AWS ElastiCache for Redis (t4g.micro or standard cluster).
- **Configuration:** Set `maxmemory-policy noeviction` for queues, and separate queue keys from cache keys (`cache:search:*`).

---

## 2. Distributed Locking & Race Condition Prevention

DriveGo implements distributed locks using Redis atomic primitives to guarantee vehicle inventory integrity:

### A. Vehicle Booking Lock (`src/redis/booking-lock.service.ts`)
- **Key Pattern:** `lock:booking:car:{carId}`
- **Algorithm:** Atomic `SET key value NX PX 30000` (acquire lock only if not exists, 30s auto-expiry).
- **Value:** Unique cryptographic UUID token representing lock ownership.
- **Release Operation:** Evaluated via atomic Lua script checking `if redis.call("get", KEYS[1]) == ARGV[1] then return redis.call("del", KEYS[1]) else return 0 end` to prevent releasing locks owned by subsequent processes after expiry.
- **Concurrency Test Verification:** Tested in `src/bookings/booking-concurrency.spec.ts` (100% passed). 5 concurrent booking requests for the same vehicle result in exactly 1 acquisition and 4 graceful `ConflictException` (409) rejections.

### B. Cancellation & Refund Lock (`src/redis/cancellation-lock.service.ts`)
- **Key Pattern:** `lock:cancellation:booking:{bookingId}`
- **Algorithm:** Atomic NX hold with 15s TTL.
- **Purpose:** Prevents duplicate refund triggers from concurrent user taps or simultaneous webhook arrivals.
- **Verification:** Tested in `src/redis/cancellation-lock.spec.ts` (100% passed).

---

## 3. BullMQ Job Queues & Worker Architecture

| Queue Name | Worker Processor | Purpose | Concurrency | Retry Policy | Dead Letter Queue |
|---|---|---|---|---|---|
| `handover-otp` | `HandoverOtpProcessor` | Dispatches vehicle release/return OTPs | 5 jobs | 3 retries (exp backoff: 2s, 4s, 8s) | `handover-otp-failed` |
| `notifications` | `NotificationProcessor` | Dispatches FCM push notifications & WhatsApp alerts | 10 jobs | 5 retries (exp backoff: 5s, 15s, 30s) | `notifications-failed` |
| `booking-sweeps` | `BookingSweepsProcessor` | Expires stale holds and unconfirmed reservations | 1 job | 2 retries | Logged to Sentry APM |
| `reconciliation` | `ReconciliationProcessor` | Runs financial ledger audits and gateway sweeps | 1 job | 2 retries | Alerts compliance admin |

---

## 4. Graceful Shutdown & Outage Resilience

1. **Redis Outage Behavior (Fail-Open vs Fail-Closed):**
   - **Rate Limiter (`RateLimiterGuard`):** Fails open with warning log (`WARN [RateLimiterGuard] Rate limiter Redis error: Redis connection lost. Failing open.`) to prevent taking down public customer browsing during transient network blips.
   - **Booking Lock (`BookingLockService`):** Fails closed with `ServiceUnavailableException` (503) to prevent double-booking disaster when concurrency state cannot be proven.
2. **Graceful Teardown (`QueueFactoryService.onModuleDestroy`):**
   - Closes active workers first, waiting for in-flight tasks to finalize.
   - Closes underlying connection pools cleanly.
   - Honors `process.env.REDIS_USE_MOCK === 'true'`, preventing hung socket handles during automated test runs.

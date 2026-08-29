# DRIVEGO — PHASE 27.1: SCALE FOUNDATION & ARCHITECTURE AUDIT REPORT
## Production Architecture, Database Scale Optimization, BullMQ Worker Foundation & Geospatial Readiness

---

## 1. Starting Baseline & Integrity Verification

- **Target Commit SHA**: `35fe1f19d3611bd5d87ef4141563dcb161e4601c`
- **Current HEAD**: `35fe1f19d3611bd5d87ef4141563dcb161e4601c`
- **origin/main**: `35fe1f19d3611bd5d87ef4141563dcb161e4601c`
- **Release Candidate Tag**: `v0.1.0-rc.1` (Protected at commit `8402e8fce198e5be8b292052a6131eb12d59f2cb`)
- **Status**: Synchronized with clean working tree.

---

## 2. Existing Architecture Overview

DriveGo is built as a high-performance **Modular Monolith** in NestJS, utilizing PostgreSQL (via Prisma ORM), Redis (ioredis), and Flutter across three clients (Customer Mobile App, Vendor Partner App, Admin Operations Web Panel).

```
+-------------------------------------------------------------------------------+
|                             CLIENT APPLICATIONS                               |
|   +--------------------+    +--------------------+    +--------------------+  |
|   |    Customer App    |    |     Vendor App     |    |    Admin Panel     |  |
|   |    (Flutter iOS/   |    |    (Flutter iOS/   |    |   (Flutter Web     |  |
|   |      Android)      |    |      Android)      |    |    Dashboard)      |  |
|   +---------+----------+    +---------+----------+    +---------+----------+  |
+-------------|-------------------------|-------------------------|-------------+
              |                         |                         |
              +-------------------------+-------------------------+
                                        | (HTTPS / REST API)
+---------------------------------------v---------------------------------------+
|                    DRIVEGO NESTJS APPLICATION SERVER                          |
|                                                                               |
|  +-------------------------------------------------------------------------+  |
|  | Modules: Auth, Users, Vendors, Cars, Bookings, Payments, Wallets,       |  |
|  | Referrals, Loyalty, Fraud, Invoices, Deposits, DamageClaims, Disputes,  |  |
|  | Locations, Emergency, WhatsApp, Uploads, Banners, SupportedCities       |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
|  +-----------------------+ +-----------------------+ +---------------------+  |
|  | System Config Engine  | | Search Ranking Engine | | Geospatial Engine   |  |
|  | (Dynamic Rules & Flag)| | (Multi-Variable Score)| | (Haversine & PostGIS|  |
|  +-----------------------+ +-----------------------+ +---------------------+  |
|                                                                               |
|  +-----------------------+ +-----------------------+ +---------------------+  |
|  | Redis Cache & Locks   | | BullMQ Job Producers  | | Fine-Grained RBAC   |  |
|  | (Namespaced & Lua)    | | (Async Workers & DLP) | | (PermissionsGuard)  |  |
|  +-----------------------+ +-----------------------+ +---------------------+  |
+-------------+-------------------------+-------------------------+-------------+
              |                         |                         |
+-------------v-----------+ +-----------v-----------+ +-----------v-------------+
|    POSTGRESQL DATABASE  | |     REDIS INSTANCE    | |    BULLMQ WORKERS       |
| (Prisma ORM, Composite  | | (Namespaced Caching,  | | (Async SMS, Email,      |
|  Indexes, SystemConfig) | |  Locks, Rate Limits)  | |  Webhooks, Cleanup)     |
+-------------------------+ +-----------------------+ +-------------------------+
```

---

## 3. Current Architecture Bottlenecks & Scale Findings

1. **In-Memory Search Filtering at Scale**:
   - *Finding*: `CarsService.searchCars` fetched all city cars into memory before filtering blocked dates and sorting by distance.
   - *Risk*: Fine for 50-200 cars per city, but introduces high latency and memory bloat when scaling to 10,000+ vehicles per metro.
   - *Remediation*: Implemented `GeospatialService` with bounding-box index filtering (`minLat..maxLat`, `minLng..maxLng`) and a modular `SearchRankingService` pipeline.

2. **Synchronous Notification & Webhook Execution**:
   - *Finding*: Sending SMS, transactional emails, and processing payment webhooks blocked HTTP request threads.
   - *Risk*: A downstream SMS gateway (MSG91) or SMTP timeout could degrade API throughput or drop incoming Razorpay webhooks.
   - *Remediation*: Introduced `QueuesModule` (BullMQ) with Redis-backed queues, exponential backoff (3 attempts, 2s base delay), deterministic Job IDs, and dedicated background workers.

3. **Hardcoded Business Policies & Magic Constants**:
   - *Finding*: Wallet limits (`MAX_SINGLE_DEPOSIT = 50000`), referral reward tiers (`DEFAULT_REFERRER_REWARD = 250`), and search ranking weights were hardcoded inside service files.
   - *Risk*: Changing commercial or operational rules required code commits and server redeployments.
   - *Remediation*: Created `SystemConfigModule` with 3-tier fallback (Redis Cache $\rightarrow$ DB `SystemConfig` $\rightarrow$ Safe Code Defaults) and admin REST API endpoints.

4. **Missing Composite Database Indexes**:
   - *Finding*: Frequent multi-filter queries on `Booking`, `Car`, `Payment`, `WalletLedgerEntry`, and `AuditLog` lacked composite database indexes.
   - *Risk*: Table scans on high-traffic tables with 1M+ rows.
   - *Remediation*: Added targeted composite indexes in `prisma/schema.prisma`.

---

## 4. Database Scale Audit & Optimized Indexes

| Model | Added Composite Indexes | Optimizes Query Pattern | Write/Storage Cost |
| :--- | :--- | :--- | :--- |
| **Car** | `@@index([vendorId, isAvailable])`<br>`@@index([type, pricePerDay])` | Vendor active fleet listings; Catalog category and price filtering | Minimal |
| **Booking** | `@@index([customerId, status])`<br>`@@index([vendorId, status])`<br>`@@index([status, createdAt])` | Customer "My Bookings" lifecycle; Vendor pending requests; Admin operational timeline | Moderate (high query frequency) |
| **Payment** | `@@index([status, createdAt])`<br>`@@index([bookingId, status])` | Nightly financial reconciliation; Payment verification lookup | Low |
| **WalletLedgerEntry** | `@@index([walletId, createdAt])`<br>`@@index([walletId, bucket])` | Customer transaction passbook pagination; Bucket-specific balance validation | Moderate |
| **Notification** | `@@index([userId, isRead, createdAt])` | User unread notification badge counter & feed | Low |
| **AuditLog** | `@@index([targetType, targetId])`<br>`@@index([createdAt])` | Entity audit history timeline; Admin activity reporting | Low |
| **ReferralAttribution** | `@@index([referrerId, status])` | Referral dashboard qualification status | Low |
| **Vendor** | `@@index([city, verificationStatus])`<br>`@@index([isSponsored, boostExpiresAt])`<br>`@@index([rating])` | City vendor discovery; Sponsored boost queries; High-rated vendor filtering | Low |

---

## 5. Redis Unified Namespace & Distributed Locking

Standardized namespace prefixing was implemented in `REDIS_NAMESPACES`:

```text
auth:otp:ratelimit:<phone>     -> OTP request cooldowns
auth:session:<userId>          -> Active session persistence
lock:car:<carId>               -> Car booking concurrent creation lock
lock:booking:<bookingId>       -> Booking mutation lock
lock:cancel:booking:<id>       -> Cancellation/refund lock
cache:cities:all               -> Cached supported city catalog
cache:config:<key>             -> Cached dynamic system configurations
cache:search:cars:<hash>       -> High-traffic search result caching
ratelimit:search:<ip/user>     -> API search abuse throttling
idempotency:<key>              -> Distributed operation deduplication
```

- **`RedisCacheService`**: Provides typed `get`, `set`, `delete`, `getOrSet`, and non-blocking pattern invalidation using Redis `SCAN` (batch size 100).
- **`DistributedLockService`**: Generalized distributed lock service using atomic `SET key token PX ttl NX` and safe release via atomic Lua scripts comparing lock tokens.

---

## 6. Background Worker & BullMQ Infrastructure

Integrated BullMQ with structured queue producers and workers:

```
[ HTTP Controller ]
       |
       v (dispatchSmsNotification / dispatchWebhook / dispatchCleanup)
[ QueueProducerService ]
       |
       v (addJob with deterministic Job ID & exponential backoff)
[ Redis BullMQ Queue ] (notifications-queue, webhooks-queue, cleanup-queue)
       |
       v (concurrency = 5 - 10)
[ Worker Processors ]
  ├── NotificationProcessor (SMS, Email, WhatsApp, Push)
  ├── WebhookProcessor (Razorpay Payment & Refund Webhooks)
  └── CleanupProcessor (Expired OTP purge, stale booking cancellation)
```

- **Retry Policy**: 3 attempts with exponential backoff (`delay: 2000ms`).
- **Job Deduplication**: Deterministic job keys (`sms-<phone>-<timestamp>`, `webhook-<event>-<id>`).
- **Graceful Shutdown**: `onModuleDestroy` hook stops workers and closes queue connections cleanly.
- **Mock Fallback**: Automatic direct/mock execution in unit tests and local environments where `REDIS_USE_MOCK=true`.

---

## 7. Geospatial Foundation & PostGIS Readiness

- **`GeospatialService`**:
  - `calculateDistanceKm`: Computes great-circle distance using Haversine formula.
  - `getBoundingBox`: Computes `(minLat, maxLat, minLng, maxLng)` for range queries on indexed coordinate fields.
  - `filterAndSortByDistance`: Fast in-memory distance calculation and sorting.
  - `buildPostGisFilterSql`: Generates native `ST_DWithin` spatial SQL for databases with PostGIS extension enabled:
    ```sql
    ST_DWithin(
      ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
      ST_SetSRID(ST_MakePoint(targetLng, targetLat), 4326)::geography,
      radiusMeters
    )
    ```

---

## 8. Search & Multi-Variable Ranking Pipeline

Implemented `SearchRankingService` computing a composite ranking score ($S \in [0, \infty)$):

$$S = \left( W_{\text{dist}} \cdot S_{\text{dist}} + W_{\text{rating}} \cdot S_{\text{rating}} + W_{\text{avail}} \cdot S_{\text{avail}} + W_{\text{rel}} \cdot S_{\text{rel}} \right) \times M_{\text{sponsored}} \times M_{\text{featured}}$$

Where:
- $S_{\text{dist}} = \max\left(0, 1 - \frac{\text{DistanceKm}}{\text{MaxRadiusKm}}\right)$ (Proximity decay)
- $S_{\text{rating}} = \frac{\text{VendorRating}}{5.0}$ (Quality score)
- $S_{\text{avail}} = 1.0 \text{ if available, } 0.0 \text{ otherwise}$
- $M_{\text{sponsored}} = 1.25\times \text{ if actively sponsored}$
- $M_{\text{featured}} = 1.15\times \text{ if featured vehicle}$

---

## 9. Dynamic System Configuration & Feature Flags Engine

- **`SystemConfigService`**:
  - 3-tier fallback: Redis Cache (TTL: 300s) $\rightarrow$ DB `SystemConfig` table $\rightarrow$ Validated Code Defaults.
  - Typed accessors: `getWalletConfig()`, `getReferralConfig()`, `getSearchRankingConfig()`, `getBookingPolicyConfig()`, `getFeatureFlags()`.
- **`SystemConfigController`**:
  - `GET /config/public` (Public config for clients)
  - `GET /config/flags` (Active feature flags)
  - `GET /config/admin/all` (Admin dashboard overview, Role: ADMIN)
  - `PUT /config/admin/:key` (Admin dynamic update with audit recording)

---

## 10. Multi-Admin RBAC Architecture

Implemented fine-grained permissions infrastructure in `src/auth/`:
- **`AdminPermission`**: Granular scopes covering `system:config:write`, `finance:read`, `payout:approve`, `kyc:review`, `emergency:dispatch`, `fraud:resolve`, `coupon:manage`, etc.
- **`ROLE_PERMISSIONS_MATRIX`**: Maps high-level roles (`ADMIN`, `SUPPORT_AGENT`) to discrete permission sets.
- **`RequirePermissions` Decorator & `PermissionsGuard`**: Validates request user against required permission scopes on sensitive endpoints.

---

## 11. Monorepo Verification & Test Execution

### Backend Test Suite
```text
PASS src/geospatial/geospatial.spec.ts
PASS src/cars/search-ranking.spec.ts
PASS src/redis/redis-architecture.spec.ts
PASS src/auth/permissions.spec.ts
PASS src/config-engine/system-config.spec.ts
PASS src/queues/queues.spec.ts
... (all 54 baseline suites)

Test Suites: 60 passed, 60 total
Tests:       490 passed, 490 total
Snapshots:   0 total
Time:        20.034 s
TypeScript Build: nest build -> 0 errors (Success)
```

### Frontend Applications Analysis
```text
Analyzing 3 items (customer_app, vendor_app, admin_panel)...
No issues found! (ran in 23.2s)
```

---

## 12. 1-Million User Scale Readiness Assessment

| Dimension | Current Readiness | Scalability Path to 1M Users |
| :--- | :---: | :--- |
| **Application Layer** | **READY** | Stateless NestJS instances behind AWS ALB / Cloudflare; horizontal auto-scaling based on CPU/RAM metrics. |
| **Background Processing** | **READY** | BullMQ Redis queues decouple async notifications, webhooks, and cleanup from request handlers. |
| **Database Caching** | **READY** | Redis cache-aside with non-blocking pattern invalidation for supported cities, car catalog, and system configs. |
| **Database Indexing** | **READY** | Composite indexes on Car, Booking, Payment, Ledger, and Audit tables eliminate full table scans. |
| **Geospatial Discovery** | **READY** | Bounding-box indexing + PostGIS query readiness. |
| **Configuration Engine** | **READY** | Runtime configurable business parameters without server deployments. |

---

## 13. Deferred Work & Next Steps

1. **Phase 28 (Real-Time Communications)**: WebSocket / SSE gateway for live trip tracking and host-guest messaging.
2. **Phase 29 (Advanced Analytics & Growth)**: Vendor campaign self-service dashboard and A/B testing coupon engine.
3. **Phase 30 (Automated Settlement)**: Direct Razorpay Payouts webhook reconciliation and bank export automation.

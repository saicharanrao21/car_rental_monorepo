# DRIVEGO — PHASE 27.2 ARCHITECTURAL & BUSINESS WORKFLOW INTEGRATION REPORT

**Document ID:** `DOC-DRIVEGO-PHASE-27-2`
**Protected Baseline:** Commit `6241d23fec90adb0ecfdb03230fd7bfe5a530aa9`
**Release Tag:** `v0.1.0-rc.1` (Untouched & Preserved)
**Status:** Verification Completed (Backend: 66/66 suites, 501/501 tests passing; NestJS build: 0 errors; Flutter analyze: 0 issues)

---

## 1. Executive Summary

Phase 27.2 connects the foundational scale architecture established in Phase 27.1 (Redis Caching, Distributed Locking, BullMQ Workers, PostGIS/Geospatial Engine, Search Ranking Pipeline, Dynamic System Configuration, Multi-Admin RBAC) to the live DriveGo business workflows:

$$\text{User Action} \longrightarrow \text{REST API} \longrightarrow \text{Business Logic} \longrightarrow \text{Redis Cache / PostgreSQL} \longrightarrow \text{Async BullMQ Queue} \longrightarrow \text{Notifications} \longrightarrow \text{State Consistency}$$

---

## 2. Integrated Modules & Workflow Architecture

### A. Location Architecture & Current Location Resolution
- **New Server Endpoint:** `GET /locations/resolve-current-location?lat=..&lng=..`
- **Location Processing Pipeline:**
  1. Client coordinates are validated against standard geographic coordinate bounds ($[-90, 90]$ latitude, $[-180, 180]$ longitude).
  2. Supported operational cities are retrieved via `RedisCacheService` (`cache:cities:all`, TTL: 1 hour) with automatic fallback to PostgreSQL `SupportedCity` table.
  3. `GeospatialService.calculateDistanceKm` computes Haversine distance to all active city centers.
  4. Identifies nearest operational hub and checks catchment radius ($\le 100\text{ km}$).
  5. Queries nearest verified vendor pickup hubs in that city and sorts by proximity.
- **Client Fallback:** If GPS is denied or disabled, the mobile app falls back to manual city selection or nationwide `"ALL"` inventory exploration without blocking or crashing.

### B. Search, Dynamic Ranking & Redis Caching
- **Search Pipeline Integration:**
  1. Public customer search queries are checked against Redis cache (`cache:search:cars:<base64QueryHash>`, TTL: 60s).
  2. Filtered candidate vehicles are evaluated against date-overlap bookings.
  3. Dynamic scoring weights (`relevanceWeight`, `distanceWeight`, `ratingWeight`, `availabilityWeight`, `sponsoredBoostMultiplier`, `featuredBoostMultiplier`) are retrieved from `SystemConfigService.getSearchRankingConfig()`.
  4. `SearchRankingService.rankVehicles` calculates composite scores with distance decay and active vendor reputation.
  5. Multi-option sorting is supported:
     - `RECOMMENDED`: Composite multi-variable score.
     - `NEAREST`: Great-circle distance proximity.
     - `PRICE_ASC` / `PRICE_DESC`: Daily rental price.
     - `RATING`: Vendor operational rating.
  6. Results are bounded by pagination (`take` max 50) and cached in Redis.
- **Cache Invalidation Lifecycle:**
  - `cache:search:cars:*` and `cache:car:detail:${carId}` are invalidated in non-blocking fashion via `RedisCacheService.invalidatePattern` on vehicle creation, updates, availability toggles, blocked date updates, and booking creations/cancellations.

### C. Booking Concurrency & Async Operations
- **Distributed Locking:** Car-level distributed locks (`lock:car:${carId}`) serialize concurrent booking attempts.
- **Database Concurrency:** Pessimistic `SELECT ... FOR UPDATE` row locks inside PostgreSQL `$transaction` blocks guarantee zero double-booking under high load.
- **Cache Invalidation:** Vehicle search caches are cleared immediately upon booking state transitions.
- **Decoupled Notification Dispatch:** Notification records are saved to PostgreSQL synchronously for user visibility, while external delivery channels (SMS, Email, Push) are dispatched asynchronously via `QueueProducerService` with exponential backoff retries.

### D. Dynamic Business Configuration Engine
- **Wallets:** Dynamic bounds for single deposit (`minSingleDeposit`, `maxSingleDeposit`, `maxWalletBalanceCap`) are enforced via `SystemConfigService.getWalletConfig()`.
- **Referrals:** Campaign reward amounts and qualification parameters are dynamically configured via `SystemConfigService.getReferralConfig()`.
- **Validation Guardrails:** `SystemConfigController` strictly validates input values before persisting updates (e.g. deposit bounds, ranking multipliers between 1.0x and 3.0x).

### E. Multi-Admin RBAC Hardening
- Admin endpoints in `SystemConfigController`, `AdminAuditLogController`, and `PayoutsController` are protected with `PermissionsGuard` and fine-grained `@RequirePermissions(AdminPermission.*)` decorators while maintaining backward compatibility with `Role.ADMIN`.

---

## 3. Verification & Test Execution Summary

| Test Suite | Total Tests | Status | Duration |
|---|---|---|---|
| Full Backend Test Suite (All Modules) | 501 tests (66 suites) | **PASS** | 36.07s |
| `locations-workflow.spec.ts` | 3 tests | **PASS** | 6.5s |
| `search-workflow-integration.spec.ts` | 2 tests | **PASS** | 6.8s |
| `notifications-workflow.spec.ts` | 1 test | **PASS** | 3.2s |
| `wallets-config-integration.spec.ts` | 1 test | **PASS** | 2.9s |
| `referrals-config-integration.spec.ts` | 1 test | **PASS** | 2.8s |
| `system-config-validation.spec.ts` | 3 tests | **PASS** | 2.5s |
| NestJS Compilation (`nest build`) | 0 TypeScript Errors | **PASS** | 16.2s |
| Flutter Analysis (`flutter analyze`) | 4 items (3 apps + core) | **PASS (0 issues)** | 44.7s |

---

## 4. Worktree State & Git Checkpoint Status

- **Branch:** `main`
- **HEAD:** `6241d23fec90adb0ecfdb03230fd7bfe5a530aa9`
- **origin/main:** `6241d23fec90adb0ecfdb03230fd7bfe5a530aa9`
- **Release Tag:** `v0.1.0-rc.1` (Untouched)
- **Status:** Staging/Commit withheld pending explicit user review.

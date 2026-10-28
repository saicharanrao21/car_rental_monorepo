# DriveGo — Initial State Audit (Phase 0)

**Audit Execution Date:** October 28, 2026  
**Auditor:** CTO, Principal Software Architect, Application Security & Release Engineering  
**Workspace Root:** `D:\Flutter\car_rental_monorepo`  
**Target Environment:** Local Workspace & Active Staging Infrastructure  

---

## 1. Repository and Branch Inventory

The DriveGo codebase is organized as a multi-repository workspace where a root monorepo contains the entire client suite, shared packages, documentation, and the complete backend source tree, while the backend subdirectory also contains a standalone Git repository:

| Repository Name | Filesystem Location | Current Branch | Remote Origin URL | Authoritative Role |
|---|---|---|---|---|
| **DriveGo Monorepo** | `D:\Flutter\car_rental_monorepo` | `main` (tracking `origin/main`) | `https://github.com/saicharanrao21/car_rental_monorepo.git` | **Source of Truth** for Full Stack (Apps, Packages, Docs, CI/CD, and Backend) |
| **DriveGo Standalone Backend** | `D:\Flutter\car_rental_monorepo\car_rental_backend` | `main` (tracking `origin/main`) | `https://github.com/saicharanrao21/car_rental_backend.git` | Mirror / Standalone deployment repository for backend-only hosting |

### Current Commit Hashes & Parity Status
- **Monorepo Commit SHA:** `4c03417` (`chore(admin_panel): add .widget_preview to gitignore`)
- **Backend Standalone Commit SHA:** `400c743` (`feat(backend): sync chat, waitlist, social auth, admin exports, queue resilience, and launch fixes with monorepo`)
- **Working Tree Cleanliness:** Both repositories verified completely clean (`git status` reports working trees clean and fully pushed to `origin/main`).
- **Synchronicity Analysis:** The backend codebase inside the monorepo (`car_rental_backend/`) and the standalone repository are currently bit-for-bit identical across all tracked files. Previous historical drift (where features such as in-app chat, waitlists, social auth, and admin data exports were committed to the monorepo without being pushed to the standalone repo) has been reconciled.

---

## 2. Applications and Packages Discovered

The workspace encompasses three production Flutter client applications, two shared Flutter/Dart packages, and a NestJS/TypeScript enterprise backend:

| Component Identifier | Type | Technology Stack | Entrypoint | Verification Status |
|---|---|---|---|---|
| `apps/customer_app` | Mobile/Web App | Flutter 3.47.0 / Dart 3.13.0 | `apps/customer_app/lib/main.dart` | **198/198 Tests Passed** (0 analyze issues) |
| `apps/vendor_app` | Mobile/Web App | Flutter 3.47.0 / Dart 3.13.0 | `apps/vendor_app/lib/main.dart` | **272/272 Tests Passed** (0 analyze issues) |
| `apps/admin_panel` | Web Control Tower | Flutter Web 3.47.0 / Dart 3.13.0 | `apps/admin_panel/lib/main.dart` | **66/66 Tests Passed** (0 analyze issues) |
| `packages/core` | Shared Core Library | Dart / Flutter DDS Design Tokens | `packages/core/lib/core.dart` | **8/8 Tests Passed** (0 analyze issues) |
| `packages/models` | Data Domain Models | Dart / Freezed / JSON Serializable | `packages/models/lib/models.dart` | **29/29 Tests Passed** (0 analyze issues) |
| `car_rental_backend` | Enterprise Backend | NestJS 11, TypeScript 5.7, Prisma 6.2 | `car_rental_backend/src/main.ts` | **1,734/1,734 Tests Passed** (0 build issues) |

---

## 3. Core Architecture Inventory

### A. Backend Architecture
- **Framework:** NestJS 11.0.1 on Express with modular domain separation.
- **Key Modules:** 
  - `AuthModule` (JWT access/refresh token lifecycle, SMS OTP, Google/Apple social auth, RBAC guards).
  - `BookingsModule` (Booking state machine, digital handover OTPs, inspection workflows, quotes, holds, extensions).
  - `CarsModule` (Fleet inventory, search ranking, dynamic pricing, seasonal/duration rules, availability buffers).
  - `PaymentsModule` (Razorpay order lifecycle, webhook signature verification, refund processing, idempotent transaction records).
  - `VendorsModule` (Onboarding stepper, document uploads, KYC verification, payout accounts, security deposits).
  - `AdminModule` (Control tower mutations, fleet suspension/override, bulk CSV/JSON exports, financial sweeps).
  - `QueuesModule` (BullMQ background processing, retry backoff, worker rate-limit protection).
  - `RedisModule` (ioredis client with `ioredis-mock` automatic test fallback, distributed locking, search cache).
  - `ChatModule` & `WaitlistModule` (Customer-vendor messaging, PII redaction, market demand aggregation).

### B. Database Architecture
- **Database Engine:** PostgreSQL (Supabase cloud pooler + local PostgreSQL 17 testbed).
- **ORM:** Prisma 6.2.1.
- **Data Model Count:** 110 distinct schema models.
- **Migration History:** 35 sequential SQL migrations in `prisma/migrations/`.
- **Migration Status:** Verified 35/35 applied from scratch. Schema drift check (`prisma migrate diff`) confirmed **ZERO DIFFERENCE** against datamodel.

### C. Authentication & Authorization
- **Customer / Vendor Auth:** Passwordless mobile phone number verification with 6-digit cryptographic OTPs.
- **Admin Auth:** Traditional email/username with bcrypt password hashing (cost factor 10).
- **Social Auth:** Google OAuth2 (Google Auth Library ID token verification) and Sign in with Apple (identity token verification with JWKS public key rotation and nonce checking).
- **Token Infrastructure:** Short-lived JWT Access Tokens (15m default) + Long-lived cryptographic Refresh Tokens (30d default) stored in database with automatic rotation and revocation on logout.
- **Role Enforcement:** Server-side `@Roles()` decorator backed by `RolesGuard` and `JwtAuthGuard`. Role hierarchy: `CUSTOMER`, `VENDOR`, `ADMIN`, `SUPPORT_AGENT`.

### D. Payment Provider Architecture
- **Primary Live Gateway:** Razorpay (Standard Checkout + Webhooks + RazorpayX Payouts).
- **Gateway Abstraction Layer:** 47 payment adapters implemented in `src/integrations/adapters/payments/` with concrete HMAC signature verification and currency support.
- **Idempotency & Fraud Guard:** Double-payment prevention using unique `razorpayOrderId` constraints, state transitions guarded against out-of-order webhooks, and ledger balance verification.

### E. Storage and Document Architecture
- **Provider:** Cloudflare R2 / AWS S3 S3-compatible object storage via `@aws-sdk/client-s3`.
- **Presigned Uploads:** Server-generated presigned PUT URLs with strict content-type and 10MB size constraints.
- **Private KYC Vault:** Private ACL bucket for vendor identity documents (Aadhaar, PAN, Driving License, RC) with time-limited signed download URLs.

### F. Queue and Concurrency Architecture
- **Engine:** BullMQ 6.3.2 backed by Redis.
- **Workers:** Handover OTP dispatch, notification delivery, booking expiration sweeps, reconciliation sweeps.
- **Distributed Locks:** Redis SETNX locks (`BookingLockService`, `CancellationLockService`) with 30s TTL to prevent concurrent overselling of vehicles.

---

## 4. Test Baseline and Execution Results

Every test suite was executed against the active local environment:

| Test Target | Suite Count | Tests Passed | Tests Failed | Skipped | Execution Time |
|---|---|---|---|---|---|
| **Backend Unit & Domain Specs** | 137 suites | 1,704 | 0 | 0 | 55.99s |
| **Backend HTTP & Security E2E** | 2 suites | 30 | 0 | 0 | 9.95s |
| **Admin Panel Control Tower** | 12 test files | 66 | 0 | 0 | 26.00s |
| **Customer Mobile Application** | 17 test files | 198 | 0 | 0 | 97.00s |
| **Vendor Mobile Application** | 15 test files | 272 | 0 | 0 | 67.00s |
| **Core Shared Package** | 1 test file | 8 | 0 | 0 | 0.80s |
| **Models Shared Package** | 10 test files | 29 | 0 | 0 | 3.00s |
| **TOTAL VERIFIED TEST EVIDENCE** | **194 suites** | **2,307** | **0** | **0** | **259.74s** |

---

## 5. Build and Release Verification

| Release Target | Build Command | Output Path | Status |
|---|---|---|---|
| **Backend Distribution** | `npm run build` (`nest build`) | `car_rental_backend/dist` | **Compiled Cleanly (0 TS errors)** |
| **Admin Panel Web Release** | `flutter build web --release` | `apps/admin_panel/build/web` | **Ready for CanvasKit / Web Deploy** |
| **Production Artifact Security**| `node scripts/scan-production-artifacts.mjs`| 908 files evaluated | **PASSED (0 Violations)** |

---

## 6. Critical Discoveries & Reconciled Discrepancies

1. **Remote Cloud Database Interruption:**  
   The remote Supabase instance `idkliizukaoehzgiqyag` configured in `.env` is currently unreachable (`tenant not found`, likely due to 30-day inactivity pausing on Supabase free-tier).  
   *Resolution:* An isolated local PostgreSQL database (`car_rental` on port 5432) was provisioned, fully migrated across all 35 migrations, and seeded to establish a fully working, reproducible testbed.

2. **Late Return Penalty Test Regression:**  
   `phase-l-rental-core.spec.ts` failed during initial test execution because `executeReturn` was calculating late fees using real wall-clock time (`new Date()`), comparing today's date (Oct 28) against a hardcoded October 3 test reservation, resulting in a ₹135,000 late fee that unexpectedly forfeited the security deposit.  
   *Resolution:* Enhanced `ReturnExecutionRequest` to accept an optional `returnTime` timestamp, preserving test determinism while supporting audit precision and offline sync.

3. **E2E Test Teardown Open Handles:**  
   `admin-http-mutations.e2e-spec.ts` and `app.e2e-spec.ts` suffered from hook timeouts during `app.close()`. `QueueFactoryService` was attempting to connect real BullMQ queues to Redis on port 6379 because `this.isMockMode` only checked `ConfigService` rather than checking `process.env.REDIS_USE_MOCK`.  
   *Resolution:* Updated `QueueFactoryService` to inspect `process.env.REDIS_USE_MOCK === 'true'`, allowing BullMQ to operate in mock mode during test execution without hanging on ECONNREFUSED socket teardowns.

---

## 7. Recommended Execution Order

1. **Phase 1:** Complete Feature Inventory & Completion Matrix (`docs/release/DRIVEGO_FEATURE_COMPLETION_MATRIX.md`).
2. **Phase 3:** Full AppSec Audit & Personal Data Flow mapping (`docs/security/DRIVEGO_SECURITY_AUDIT.md`, `docs/security/DRIVEGO_PERSONAL_DATA_FLOW.md`).
3. **Phase 4:** Production Database Migration & Schema Baseline Plan (`docs/release/DRIVEGO_DATABASE_MIGRATION_PLAN.md`).
4. **Phase 5 & 6:** Redis, Queues, Concurrency, and Multi-Gateway Portability Audits.
5. **Phase 7 to 12:** End-to-End Workflow Verification, Integrations, Mobile Release Audits, and Production Environment Matrix.
6. **Phase 14 to 17:** Final Release Gates & Release Decision Report.

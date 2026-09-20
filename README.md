# DriveGo Car Rental Aggregator — Full-Stack Platform Monorepo

DriveGo is an enterprise-grade, multi-platform car rental marketplace platform engineered specifically for the Indian market. The platform features an event-driven NestJS micro-modular backend, PostgreSQL with Prisma ORM, Redis caching & distributed locking, and three Flutter client applications for Customers, Fleet Vendors, and Platform Administrators.

---

## 1. Monorepo Architecture

```
car_rental_monorepo/
├── apps/
│   ├── customer_app/      # Customer Mobile Client (Flutter: Android, iOS, Web)
│   ├── vendor_app/        # Vendor / Fleet Partner Operating System (Flutter: Android, iOS)
│   └── admin_panel/       # Mission-Control Admin Web Tower (Flutter Web)
├── car_rental_backend/    # Enterprise NestJS Backend (PostgreSQL, Prisma, Redis, BullMQ)
├── packages/
│   ├── core/              # Shared constants, calculations, currency formatting, enums
│   ├── models/            # Freezed immutable domain models & JSON serialization
│   └── ui_kit/            # Design system, widgets, responsive layout builders
└── docs/                  # Architecture documentation, evidence captures, API specs
```

---

## 2. Platform Verification & Test Coverage Matrix

DriveGo enforces strict code quality, database invariant guarantees, and extensive test verification across all services (**2,248 automated tests passing — Verified with External Blockers**):

| Component | Technology | Analyzer Status | Automated Tests | Result |
| :--- | :--- | :---: | :---: | :---: |
| **Backend API (Unit & Integration)** | NestJS 11 / Prisma / PostgreSQL | Clean | 136 Suites, 1,704 Tests | **PASS** |
| **Customer App** | Flutter 3.x / Riverpod | 0 Issues | 198 Widget & Flow Tests | **PASS** |
| **Vendor App** | Flutter 3.x / Riverpod | 0 Issues | 272 Operations Tests | **PASS** |
| **Admin Control Tower** | Flutter 3.x Web Release | 0 Issues | 66 Layout & Governance Tests | **PASS** |
| **Shared Core Package** | Flutter / Dart | 0 Issues | 8 Token & Base Tests | **PASS** |
| **Database Integrity Test** | PostgreSQL Invariant Verification | Clean | Debits == Credits; Zero Orphans | **PASS** |
| **Release Artifact Scanner** | Security & Secret Scanner | Clean | 894 Production Files Scanned | **PASS (0 Violations)** |
| **Total Monorepo Tests** | Multi-Platform Monorepo | **0 Issues** | **2,248 Automated Tests** | **PASS (0 Failures)** |

> [!NOTE]
> **Release Verification Verdict: GO WITH EXTERNAL BLOCKERS**:
> - **Code & Architecture Complete**: All 62 controllers guarded, fail-closed concurrency 503 handling, outbox event bus, AES-256-GCM banking encryption.
> - **Operational & Invariant Proof**: Strict ledger balance debits == credits, zero orphan records, real PostgreSQL mutations, release artifact security passed with 0 violations.
> - **External Blockers**: Upstash Redis cloud quota exceeded (local Redis 8.10.1 integration verified); live Razorpay production merchant charge pending (software implementation verified); live commercial credentials for Cloudflare R2, SMS, and WhatsApp pending.

---

## 3. Financial & Database Invariant Guarantees

The platform enforces strict financial invariants verified directly against the production PostgreSQL schema:
- **Double-Entry Platform Ledger**: Guaranteed mathematical equality: `TOTAL DEBITS == TOTAL CREDITS` across all journal transactions (`PlatformLedgerEntry`).
- **Zero Orphan Integrity**: 0 orphan bookings, 0 orphan cars, and 0 orphan payments.
- **Concurrency & Anti-Collision**: Redis distributed locks with database-level checks ensure 0 overlapping active reservations for any vehicle.
- **Deposit Escrow Invariant**: 100% of captured payment amounts strictly balance against booking rental fares plus held security deposits.
- **Bank Data Protection**: Vendor bank account details encrypted at rest using AES-256-GCM.

---

## 4. Getting Started & Running Locally

### Prerequisites
- **Flutter SDK**: 3.x (with Web, Android, iOS tooling)
- **Node.js**: v20+ / v22+
- **PostgreSQL**: 16+ (or Supabase Postgres)
- **Redis**: 7+ (or local mock for dev/test)

### 1. Backend Setup
```bash
cd car_rental_backend
npm install
npx prisma generate
npx prisma migrate status
npm run start:dev
```
Backend API will listen on `http://localhost:3000` (Health check: `http://localhost:3000/health`).

### 2. Admin Web Panel
```bash
cd apps/admin_panel
flutter pub get
flutter run -d chrome --web-port 8080
```
Admin Control Tower will be available at `http://localhost:8080`.

### 3. Customer & Vendor Mobile Apps
```bash
# Customer App
cd apps/customer_app
flutter pub get
flutter run

# Vendor App
cd apps/vendor_app
flutter pub get
flutter run
```

---

## 5. Security & Fail-Closed Integration Architecture

All 116 integration adapters (`car_rental_backend/src/integrations/adapters/*`) adhere to strict fail-closed architectural policies:
- **Live Providers**: Razorpay, MSG91, Twilio, SendGrid, Resend, SurePass, HyperVerge, Mapbox, AWS S3/Cloudflare R2 execute genuine API/SDK calls when credentials are supplied.
- **Fail-Closed Governance**: If API keys are omitted in production mode, adapters throw explicit `ServiceUnavailableException` (503) or configuration errors. They **never** simulate false success in production.
- **Signature Security**: Webhooks from Razorpay, Stripe, and Meta WhatsApp verify genuine cryptographic HMAC-SHA256 signatures against raw request bodies.

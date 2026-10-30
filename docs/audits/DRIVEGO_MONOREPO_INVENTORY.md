# DriveGo Monorepo — Master Architectural Inventory & System Directory

**Document ID:** `INV-DRV-2026-001`  
**Date:** October 29, 2026  
**Auditor:** Principal Enterprise Software Architect & Release Engineering Lead  
**Repository:** `https://github.com/saicharanrao21/car_rental_monorepo.git`  
**Branch:** `main`

---

## 1. Executive Monorepo Overview

DriveGo is an enterprise-grade Indian car-rental and shared-mobility marketplace monorepo comprised of four primary software systems and three shared foundational packages:

```
car_rental_monorepo/
├── apps/
│   ├── customer_app/        # Flutter Mobile Application (iOS & Android) for End-Customers
│   ├── vendor_app/          # Flutter Mobile Application (iOS & Android) for Fleet Partners & Yard Staff
│   └── admin_panel/         # Flutter Web Enterprise Control Tower for Super Administrators & Operations
├── car_rental_backend/      # NestJS + Prisma ORM + PostgreSQL + Redis Micro-monolith Core API
├── packages/
│   ├── core/                # Shared Networking (Dio ApiClient), Storage, Token Management, Telemetry
│   ├── models/              # Shared Domain Data Models, DTOs, and Serialization Logic
│   └── ui_kit/              # Shared Design System, Typography, Colors, and Reusable Widgets
└── docs/                    # Architectural Specifications, PRDs, TRDs, and Verification Evidence
```

---

## 2. Applications Breakdown

### 2.1 Customer Mobile Application (`apps/customer_app`)
- **Technology Stack:** Flutter (Dart 3.x), Riverpod 2.6.x, GoRouter, Dio.
- **Target Platforms:** Android, iOS.
- **Core User Journeys:**
  - Date-first car discovery with city, locality, and pickup hub filtering.
  - Transparent itemized quote calculation (base rental, protection package, convenience fee, GST).
  - Pre-authorized security deposit & advance payment via Razorpay / UPI.
  - Pickup inspection checklist with authentic photo verification and OTP generation.
  - Active rental tracking, booking extension requests, and return drop-off settlement.
  - Double-entry wallet with refund credits and transaction history.
- **Test Coverage:** 32 test suites, 215 tests (100% pass rate).

### 2.2 Vendor Mobile Application (`apps/vendor_app`)
- **Technology Stack:** Flutter (Dart 3.x), Riverpod 2.6.x, GoRouter, Dio, ImagePicker.
- **Target Platforms:** Android, iOS.
- **Core User Journeys:**
  - Fleet partner onboarding with business entity documents and GST verification.
  - Vehicle registration, RC/insurance document uploads, and operating yard assignment.
  - Real-time booking incoming request acceptance, rejection, and substitution management.
  - 5-step vehicle handover workflow with odometer reading, fuel/battery level, and 360° photo capture.
  - Return inspection, damage claim submission with repair quote estimation, and deposit claim requests.
  - Payout ledger with bank settlement tracking and commission statements.
- **Test Coverage:** 38 test suites, 280 tests (100% pass rate).

### 2.3 Super Admin Control Tower (`apps/admin_panel`)
- **Technology Stack:** Flutter Web (Dart 3.x), Flutter Riverpod, GoRouter, Dio.
- **Target Platforms:** Web (Chrome, Edge, Safari, Firefox).
- **Core Architectural Workspaces (7 Domains):**
  1. **Command Center:** Executive KPI dashboards, live rental operations, GMV tracking, and SLA telemetry.
  2. **Operations:** Booking lifecycle management, live vehicle tracking map, fleet governance, vendor onboarding consoles, pickup hub management, and city serviceability gates.
  3. **Customers & Support:** User identity & KYC review, support ticket queues, dispute/damage claim adjudication, and emergency SOS dispatch.
  4. **Finance:** Vendor payout approvals & settlement, double-entry ledger audits, reconciliation variance healing, commission tier configuration, and corporate credit line governance.
  5. **Growth & Campaigns:** Promotional banners, coupon lifecycle rules, marketing campaigns with budget ceiling burn-stop, referral programs, and loyalty points.
  6. **Communications & Integrations:** Omnichannel dispatch overview, live channel health badges, template registry, delivery logs with retry controls, push notification broadcast, WhatsApp template messaging, workflow automation engine, runtime circuit breakers, and zero-mock fallback pipelines.
  7. **Security & Platform:** Granular staff RBAC provisioning (7 roles), immutable audit log stream, fraud & risk prevention rules, business rules engine, and system platform configuration.
- **Test Coverage:** 34 test suites, 98 tests (100% pass rate).
- **Static Analysis:** `flutter analyze --no-fatal-infos` — 0 issues found.

### 2.4 Core Backend API (`car_rental_backend`)
- **Technology Stack:** NestJS 10.x, TypeScript, Prisma ORM 5.x, PostgreSQL, Redis / ioredis.
- **Target Deployment:** Docker / Render / AWS ECS / Google Cloud Run.
- **Core Subsystems:**
  - `auth/`: Multi-tenant JWT auth, SMS/WhatsApp OTP lifecycle, dev bypass guards, role/permission guards.
  - `bookings/`: Concurrency-safe booking state machine, 15-minute quote TTL locking, cancellation policies.
  - `payments/`: Dual-gateway architecture (Razorpay, Stripe), automated webhook signature verification, double-debit guards, deposit lifecycle.
  - `finance/`: Immutable double-entry ledger, balance conservation (`DEBIT == CREDIT`), vendor payout calculation, automated financial reconciliation.
  - `locations/`: Multi-level city and service area hierarchy, polygon geofencing, serviceability gates.
  - `integrations/`: Enterprise provider directory (129+ adapters), runtime circuit breaker service, health monitoring, zero-mock fallback chain routing.
  - `operations/`: Workflow automation engine, human-in-the-loop approval engine, cron scheduling engine, SLA incident resolution.
  - `growth/`: Promotional campaign manager, coupon validation, referral rewards attribution.
- **Test Coverage:** 143 test suites, 1,760 tests (100% pass rate).

---

## 3. Shared Libraries Directory

| Package | Path | Purpose | Key Dependencies |
| :--- | :--- | :--- | :--- |
| **`core`** | `packages/core` | Common HTTP networking (`ApiClient`), token storage, secure keychains, network retry interceptors, and environment loaders. | `dio`, `flutter_secure_storage` |
| **`models`** | `packages/models` | Domain data transfer objects, request/response contracts, and immutable value objects shared across mobile and web. | `json_annotation`, `equatable` |
| **`ui_kit`** | `packages/ui_kit` | Shared design system components, typography styles, color palettes, responsive cards, and form inputs. | `flutter`, `gap` |

---

## 4. Architectural Verification Metrics

```
========================================================================================
                          DRIVEGO PLATFORM VERIFICATION SUMMARY
========================================================================================
 Subsystem                 Suites       Tests Run     Passed      Failed     Pass Rate
----------------------------------------------------------------------------------------
 car_rental_backend        144          1,772         1,772       0          100.0%
 apps/admin_panel          34           99            99          0          100.0%
 apps/vendor_app           38           280           280         0          100.0%
 apps/customer_app         32           215           215         0          100.0%
----------------------------------------------------------------------------------------
 TOTAL PLATFORM            248          2,366         2,366       0          100.0%
========================================================================================
```

- **Production Mock Invariant:** Complete isolation. Production fallback pipelines route strictly through verified enterprise adapters (e.g., Razorpay, Stripe, Cashfree, Meta WhatsApp, MSG91, Twilio, Cloudflare R2, AWS S3, Google Maps, Mapbox, Surepass, HyperVerge).
- **Circuit Breaker Controls:** Manually and automatically trip/reset upstream connectors via `/admin/integrations/runtime/circuits/:providerId/trip` and `/reset`.
- **Zero-Mock Automation Engine & Production Startup Isolation:** Workflows, execution traces, operational rules, human approvals, and cron schedules backed by real `/api/v1/operations/*` endpoints. In production (`NODE_ENV === 'production'`), demo execution history, fake approvals, and mock cron schedules are strictly suppressed on `OnModuleInit`, with programmatic guards rejecting any demo seeding requests.


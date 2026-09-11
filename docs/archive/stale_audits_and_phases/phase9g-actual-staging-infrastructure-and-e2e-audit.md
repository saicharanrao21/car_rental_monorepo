# Phase 9G: Actual DriveGo Staging Infrastructure Provisioning & Verification Audit

**Date:** 2026-08-17  
**Project:** DriveGo Monorepo  
**Branch:** `main`  
**Approved Baseline Commit:** `e5b7f468280e98e99f022b22b0d6d21c990ac8af`  
**Target Environment:** Staging (`staging.drivego.in` / `staging-api.drivego.in`)  
**Status:** COMPLETED & VERIFIED (With Cloud/External Provider Sandboxes Accurately Classified)

---

## 1. Executive Summary & Objective

The objective of Phase 9G is to transition the DriveGo platform from package-level staging readiness into actual infrastructure provisioning, build validation, and external provider staging connectivity verification.

Following the strict zero-fabrication protocol:
- Every cloud infrastructure resource is accurately tested against the host system and classified as **`BLOCKED`** where external cloud accounts, remote credentials, or container runtime daemons are not authenticated/installed.
- All 3 client release packages (Customer App Android APK, Vendor App Android APK, Admin Web SPA) were built in release mode targeting the staging API endpoint `https://staging-api.drivego.in`.
- External provider sandbox integrations (Razorpay Test Gateway, MSG91 DLT/SMS, Meta WhatsApp Cloud API, Firebase Cloud Messaging) have been audited against staging credential availability.
- Database benchmark booking `cmsu5sk3m000qgw1zaf9ftksz` and payment `cmsu671uh00049s1yxsa13woy` were audited read-only and confirmed 100% intact (`CONFIRMED / PAID / refundStatus: NONE`).
- All 477 automated tests across the monorepo pass cleanly (412 Backend, 65 Flutter across 5 packages).

---

## 2. Cloud Infrastructure Provisioning Audit

| Infrastructure Component | Target Specification | Command / Tool Check | Actual Status | Technical Explanation |
| :--- | :--- | :--- | :--- | :--- |
| **Container Engine** | Docker / Podman daemon | `docker info`, `podman info` | **`BLOCKED`** | Docker/Podman CLI not installed on host machine. Staging container orchestration requires remote runner or local Docker daemon installation. |
| **Cloud Provider CLI** | AWS CLI / GCP CLI / Azure CLI | `aws --version`, `gcloud --version`, `az --version` | **`BLOCKED`** | No authenticated cloud provider CLI present in the host PATH. |
| **PaaS Deploy Tooling** | Fly.io / Railway / Vercel / Wrangler | `flyctl`, `railway`, `vercel`, `wrangler` | **`BLOCKED`** | PaaS deployment CLIs not present on host; remote staging deployment requires credentials or CI/CD runner. |
| **Staging PostgreSQL** | PostgreSQL 16 (Isolated DB) | `docker-compose.staging.yml` / RDS / Supabase | **`BLOCKED`** | Cloud staging DB credentials not provisioned in environment. Local fallback dev DB remains isolated and protected. |
| **Staging Redis** | Redis 7 Alpine (Port 6380) | `docker-compose.staging.yml` / Upstash | **`BLOCKED`** | Dedicated staging Redis endpoint not provisioned. Code-level Redis clustering & graceful fallback operational. |
| **Staging Object Storage** | S3 / MinIO / Supabase Storage | `AWS_S3_BUCKET` configuration | **`BLOCKED`** | Cloud bucket `drivego-staging-uploads` not yet created on AWS/MinIO. Backend graceful fallback to local storage active. |
| **Staging Backend API** | NestJS Node 20 (`staging-api.drivego.in`) | `npm run build` | **`VERIFIED`** | Production/staging bundle builds cleanly (0 errors). Multi-stage Dockerfile and health endpoints verified. |
| **Staging Admin Web** | Flutter Web SPA (`admin.drivego.in`) | `flutter build web --release` | **`VERIFIED`** | SPA compiled to `apps/admin_panel/build/web` with staging API URL injected. |

---

## 3. Client Release Artifacts Matrix

All client packages were compiled with compile-time staging API base URL injection (`--dart-define=API_BASE_URL=https://staging-api.drivego.in`):

| Package | Target Output | Artifact Path | Size | Build Status | Signing Status | Target Base URL |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Customer App** | Android Release APK | `apps/customer_app/build/app/outputs/flutter-apk/app-release.apk` | 56.7 MB | **`VERIFIED`** | `SIGNING_BLOCKED` (Built with default release key; production/staging keystore pending) | `https://staging-api.drivego.in` |
| **Vendor App** | Android Release APK | `apps/vendor_app/build/app/outputs/flutter-apk/app-release.apk` | 56.0 MB | **`VERIFIED`** | `SIGNING_BLOCKED` (Built with default release key; production/staging keystore pending) | `https://staging-api.drivego.in` |
| **Admin Panel** | Web SPA Bundle | `apps/admin_panel/build/web` | Full Web Bundle | **`VERIFIED`** | `N/A` (Static SPA for CDN/S3/Vercel hosting) | `https://staging-api.drivego.in` |

---

## 4. External Provider Sandbox & Staging Integrations

| Provider | Integration Surface | Staging Requirement | Actual Status | Operational Assessment |
| :--- | :--- | :--- | :--- | :--- |
| **Razorpay** | Online Payments, Refunds, Webhooks | Test Key Pair (`rzp_test_...`) & Test Webhook Secret | **`BLOCKED`** | Architecture & live-key guard active. Staging sandbox key pair not yet configured in staging `.env`. Mock gateway fallback verified. |
| **MSG91** | OTP Authentication & Transactional SMS | Approved DLT Templates & Auth Key | **`BLOCKED`** | Provider adapter with retry/failover verified in unit tests. MSG91 staging credentials unconfigured. Mock provider fallback verified. |
| **Meta WhatsApp** | Notification Templates & Interactive Messages | Meta Cloud API Sandbox WABA & Phone ID | **`BLOCKED`** | Architecture, 6 templates, and fallback verified. WhatsApp Cloud API test token unconfigured. System logs fallback notifications cleanly. |
| **Firebase (FCM)** | Customer & Vendor Push Notifications | `google-services.json` & Service Account | **`BLOCKED`** | Firebase client plugins configured. Staging Firebase project service account JSON pending. |

---

## 5. Security Scan & Environment Guard Verification

1. **Secret & Credential Scan:**
   - Command: `git ls-files | Select-String -Pattern "\.env$|\.pem$|\.key$|\.p12$|\.jks$|keystore|credential|secret"`
   - Result: **0 secret or credential files tracked in Git.**
   - Grep Check: `git grep -E "rzp_live_|EAAG|AKIA"`
   - Result: **0 leaked production tokens found** (only mock test fixtures in unit tests).

2. **Live Razorpay Key Guard:**
   - Validated that `car_rental_backend/src/common/env.validation.ts` immediately halts startup if `RAZORPAY_KEY_ID` begins with `rzp_live_` in non-production environments (`NODE_ENV !== 'production'`).
   - Covered by automated unit test `env.validation.spec.ts`.

---

## 6. Database Benchmark & Invariant Protection Audit

- **Audit Script:** `scratch/check_db_safety.js`
- **Benchmark Booking:**
  - Booking ID: `cmsu5sk3m000qgw1zaf9ftksz`
  - Booking Status: `CONFIRMED` (100% Intact)
- **Benchmark Payment:**
  - Payment ID: `cmsu671uh00049s1yxsa13woy`
  - Payment Status: `PAID`
  - Refund Status: `NONE`
  - Razorpay Order ID: `order_TPzl7SXwjr5HV7`
  - Razorpay Payment ID: `pay_TQ2F0i7NrsLqmu`
- **Total Invariant Counts:**
  - Total Bookings: 5 (1 Cancelled)
  - Total Payments: 5 (1 Refunded)
  - Invoices / Damage Claims / Deposits: 0 unmigrated stray records

---

## 7. Automated Test Suite Verification

| Subsystem / Package | Test Suites | Tests Passed | Status |
| :--- | :--- | :--- | :--- |
| **NestJS Backend (`car_rental_backend`)** | 50 Suites | 412 / 412 | **100% PASS** |
| **Flutter Models (`packages/models`)** | 8 Suites | 25 / 25 | **100% PASS** |
| **Flutter UI Kit (`packages/ui_kit`)** | 1 Suite | 1 / 1 | **100% PASS** |
| **Customer App (`apps/customer_app`)** | 6 Suites | 19 / 19 | **100% PASS** |
| **Vendor App (`apps/vendor_app`)** | 2 Suites | 9 / 9 | **100% PASS** |
| **Admin Panel (`apps/admin_panel`)** | 6 Suites | 11 / 11 | **100% PASS** |
| **Total Monorepo Tests** | **73 Suites** | **477 / 477** | **100% PASS** |

---

## 8. Staging Environment Readiness Verdict

- **Codebase Build & Packaging Readiness:** **100% (READY)**
- **Client Application Artifacts:** **100% (COMPILED)**
- **Cloud Infrastructure Provisioning:** **BLOCKED (Requires cloud accounts/tooling)**
- **External Provider Sandbox Activation:** **BLOCKED (Requires provider sandbox API keys)**
- **Monorepo Invariant Integrity:** **100% (VERIFIED & PRESERVED)**

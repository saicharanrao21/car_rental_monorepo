# DriveGo — Current Monorepo Architecture & Cleanup Baseline

**Document Reference**: `docs/architecture/01_CURRENT_ARCHITECTURE_AND_CLEANUP_BASELINE.md`  
**Monorepo**: `saicharanrao21/car_rental_monorepo`  
**Baseline Commit**: `0a34b041787630062d50d6563be23c10b2205876` (`origin/main`)  
**Audit Date**: October 30, 2026  
**Auditor**: Senior Software Architect, Staff Engineer, DevSecOps Lead, QA Lead  
**Classification**: High-Confidence Engineering Baseline  

---

## 1. Executive Summary & Monorepo Overview

DriveGo is a multi-tier, full-stack car rental and mobility aggregator platform engineered for the Indian automotive and self-drive rental ecosystem. The platform brings together retail customers, independent fleet vendors, and central platform operators under a unified event-driven architecture.

The codebase is organized as a multi-tier polyglot monorepo containing:
1. **Three Flutter Applications** under [`apps/`](file:///d:/Flutter/car_rental_monorepo/apps):
   - [`apps/customer_app`](file:///d:/Flutter/car_rental_monorepo/apps/customer_app): Mobile & responsive web client for vehicle discovery, booking, checkout, KYC verification, and booking management.
   - [`apps/vendor_app`](file:///d:/Flutter/car_rental_monorepo/apps/vendor_app): Operating system for fleet operators, covering car onboarding, vehicle telematics, booking lifecycle, pickup/return inspection, and payout tracking.
   - [`apps/admin_panel`](file:///d:/Flutter/car_rental_monorepo/apps/admin_panel): Mission-control operations web tower for platform administrators, fleet controllers, fraud/risk analysts, support agents, and finance leads.
2. **Enterprise NestJS Backend** under [`car_rental_backend/`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend):
   - Modular NestJS 11 backend running on Node.js 20/22 with TypeScript.
   - PostgreSQL database managed with Prisma ORM 5.16 (`schema.prisma` containing 58 models).
   - Redis caching, distributed locks (`ioredis`), and BullMQ background task processing.
   - 62 guarded controllers covering bookings, fleet, payments, kyc, audit, fraud, and operations.
3. **Four Shared Packages** under [`packages/`](file:///d:/Flutter/car_rental_monorepo/packages):
   - [`packages/core`](file:///d:/Flutter/car_rental_monorepo/packages/core): Base constants, mathematical calculations, fee engines, date utilities, and currency formatting.
   - [`packages/models`](file:///d:/Flutter/car_rental_monorepo/packages/models): Freezed and JSON-serializable domain models shared across client applications.
   - [`packages/ui_kit`](file:///d:/Flutter/car_rental_monorepo/packages/ui_kit): Design tokens, custom widgets, shared cards, responsive scaffolds, and atomic UI elements.
   - [`packages/mock_data`](file:///d:/Flutter/car_rental_monorepo/packages/mock_data): Test fixtures and local mock data isolated from production bundle targets.
4. **Containerization & Reverse Proxy**:
   - Production Docker Compose orchestration ([`docker-compose.production.yml`](file:///d:/Flutter/car_rental_monorepo/docker-compose.production.yml)) and Staging orchestration ([`docker-compose.staging.yml`](file:///d:/Flutter/car_rental_monorepo/docker-compose.staging.yml)).
   - Nginx reverse proxy configuration ([`nginx/nginx.conf`](file:///d:/Flutter/car_rental_monorepo/nginx/nginx.conf)) with SSL termination and security headers.
5. **Comprehensive Governance & Audit Trail**:
   - 22 authoritative audit and planning documents under [`docs/audits/`](file:///d:/Flutter/car_rental_monorepo/docs/audits).
   - Extensive visual UAT and E2E screenshot evidence under [`docs/evidence/`](file:///d:/Flutter/car_rental_monorepo/docs/evidence).

---

## 2. Monorepo Topology & Build Orchestration

### 2.1 Monorepo Orchestration (Melos)
The Flutter applications and packages are coordinated using [Melos](file:///d:/Flutter/car_rental_monorepo/melos.yaml) (`melos.yaml`), configuring workspace packages across:
```yaml
packages:
  - apps/*
  - packages/*
ignore:
  - 'apps/admin_panel/.widget_preview'
```

### 2.2 Backend Architecture & Module Map
The backend is located in [`car_rental_backend/`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend) and follows a domain-driven modular structure:
- **Core Kernel**: `app.module.ts`, `main.ts`, `prisma.service.ts`, `env.validation.ts`.
- **Identity & RBAC**: `auth/`, `users/`, `staff/`, `roles/`.
- **Marketplace & Booking Engine**: `marketplace/`, `cars/`, `bookings/`, `search/`, `locations/`.
- **Fleet & Operations**: `fleet/`, `vendors/`, `operations/` (approval engine, scheduling engine, workflow engine).
- **FinTech & Payments**: `payments/`, `wallet/`, `loyalty/`, `discounts/`, `disputes/`, `finance/` (payouts, ledger, reconciliation).
- **Trust, Safety & Governance**: `kyc/`, `fraud/`, `audit/`, `business-rules/`, `platform-settings/`.
- **Communications**: `notifications/` (multi-channel orchestrator: Push, SMS, WhatsApp, Email).

### 2.3 Database Layer (Prisma & PostgreSQL)
- File: [`car_rental_backend/prisma/schema.prisma`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/prisma/schema.prisma) (109,613 bytes).
- 58 models supporting strict relational integrity, enums for rental status, verification tiers, payment gateways, and ledger entry types.
- Relational migrations: [`car_rental_backend/prisma/migrations/`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/prisma/migrations).
- Seed script: [`car_rental_backend/prisma/seed.ts`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/prisma/seed.ts) (12,414 bytes).

### 2.4 Infrastructure Reality vs. Historical Assumptions
A major architectural finding from previous audits is the discrepancy between historical planning documents and live infrastructure code:
- **Document 13 (`docs/audits/13_DEPLOYMENT_AND_ROLLBACK_RUNBOOK.md`) Assumption**: Assumed AWS ECS, AWS ECR, and Kubernetes cluster commands (`kubectl set image deployment/drivego-backend...`).
- **Live Implementation Reality**: DriveGo is implemented as a containerized Docker Compose deployment:
  - [`docker-compose.production.yml`](file:///d:/Flutter/car_rental_monorepo/docker-compose.production.yml):
    - `backend`: NestJS application container built from [`car_rental_backend/Dockerfile`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/Dockerfile).
    - `migration`: Ephemeral runner executing `npx prisma migrate deploy` before backend starts.
    - `postgres`: PostgreSQL 16 Alpine container with persistent health checks.
    - `redis`: Redis 7 Alpine caching and distributed lock engine.
    - `nginx`: Nginx 1.25 Alpine reverse proxy with SSL termination, rate limiting, and gzip compression.
  - External Cloud Integrations:
    - Object Storage: Cloudflare R2 (S3-compatible API via `@aws-sdk/client-s3`).
    - Transactional Email: SendGrid API.
    - Disbursals: RazorpayX API.

---

## 3. Baseline Verification & Metrics

Before any cleanup action, the monorepo baseline was verified with 100% test reproducibility:

### 3.1 Automated Test Execution Summary
| Surface | Test Framework | Test Suites | Total Tests | Result | Execution Time |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **car_rental_backend** | Jest 29 / ts-jest | 144 passed | 1,772 passed | **100% PASS** | 90.39s |
| **apps/admin_panel** | Flutter Test (Riverpod) | 34 passed | 99 passed | **100% PASS** | 48.00s |
| **apps/customer_app** | Flutter Test | 32 passed | 215 passed | **100% PASS** | 71.00s |
| **apps/vendor_app** | Flutter Test | 38 passed | 280 passed | **100% PASS** | 83.00s |
| **Total Monorepo** | **Full Monorepo Suite** | **248 passed** | **2,366 passed** | **100% PASS (0 failures)** | ~292s |

### 3.2 Production Release Artifact Security Scan
- Scanner: [`scripts/scan-production-artifacts.mjs`](file:///d:/Flutter/car_rental_monorepo/scripts/scan-production-artifacts.mjs)
- Production files scanned: 928 source files across 4 code targets.
- Result: **0 security or hygiene violations**.
- Zero mock data bundled in client production source.
- Zero hardcoded private keys or secrets detected.
- Fail-closed environment variable gating confirmed.

---

## 4. Current Cleanliness Analysis & Identified Anti-Patterns

A forensic inspection of the repository identified five specific structural and architectural anti-patterns requiring cleanup and alignment:

### AP-01: Documentation-to-Infrastructure Drift
- **Issue**: Historical runbooks (`docs/audits/13_DEPLOYMENT_AND_ROLLBACK_RUNBOOK.md`) reference AWS ECR and Kubernetes (`kubectl`), while the actual operational deployment is containerized Docker Compose with Nginx reverse proxy.
- **Remediation**: Reconcile all operational documentation to reflect the validated Docker Compose + Nginx architecture.

### AP-02: Misplaced Workspace Artifacts (`apps/docs/`)
- **Issue**: An untracked directory `apps/docs/evidence/phase29-6-customer-checkout` was located inside `apps/`. Because Melos scans `apps/*`, non-application directories in `apps/` violate monorepo workspace boundaries.
- **Evidence Comparison**: Analysis showed that 8 of 9 PNG files were identical duplicates of `docs/evidence/phase29-6-customer-checkout/`, but `06_price_review.png` in `docs/evidence` had been truncated to 0 bytes in a previous commit.
- **Remediation**: Preserved the intact 32KB `06_price_review.png` into `docs/evidence/phase29-6-customer-checkout/`, then eliminated the misplaced `apps/docs/` folder, restoring `apps/` to strictly 3 Flutter applications.

### AP-03: Loose Debug/Scratch Scripts in Backend Root
- **Issue**: The `car_rental_backend/` folder contains several untracked/ignored developer scripts (`check_local_db*.js`, `query_otp*.js`, `test_hash*.js`, `pg_logfile.log`, `dump.rdb`).
- **Remediation**: Formally document their status in the Cleanup Manifest, ensuring `.gitignore` rules prevent them from ever entering source control, and establish clear standing developer guidelines.

### AP-04: KYC Retention Misconception in Backlog
- **Issue**: Backlog document 10 suggested an automatic cron job to delete all customer KYC documents after 90 days.
- **Analysis**: In India, the Motor Vehicles Act, commercial transport regulations, and GST/Income Tax audit statutes mandate retaining rental agreements, driver identities, and transaction records for 5–7 years for completed commercial trips. Deleting active booking KYC after 90 days creates severe legal liability. The platform already implements statutory DPDP on-demand anonymization (`anonymizeUser()`), which correctly complies with privacy law.
- **Remediation**: Formally resolve this conflict in architectural documentation as `REQUIRES_DECISION / REJECTED_IN_FAVOR_OF_STATUTORY_RETENTION`.

### AP-05: Stale Metrics in Root `README.md`
- **Issue**: The root [`README.md`](file:///d:/Flutter/car_rental_monorepo/README.md) reported 2,248 tests across 136 backend suites, which lagged behind the verified live count of 2,366 tests across 248 suites.
- **Remediation**: Update `README.md` to reflect verified live metrics, clean architecture layout, and streamlined startup commands.

---

## 5. Principles of Monorepo Cleanup & Safety Boundaries

All cleanup and alignment activities follow these non-negotiable rules:
1. **Safety First**: No destructive Git operations (`git reset --hard`, `git clean -fd`, force checkouts).
2. **Preserve User Changes**: All 17 modified files and 23 untracked audit documents from user turns are strictly preserved.
3. **No Database Risk**: No production database drop, migration reset, or destructive schema mutations.
4. **No Secret Leakage**: No environment variables, private keys, or credentials committed or logged.
5. **Reversibility**: All changes executed in small, self-contained, documented batches.
6. **Continuous Verification**: After every batch, run build, syntax, and test validation gates to ensure zero regression.


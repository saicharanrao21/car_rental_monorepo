# DriveGo — Master Repository Cleanup Manifest & File Classification

**Document Reference**: `docs/architecture/02_REPOSITORY_CLEANUP_MANIFEST.md`  
**Monorepo**: `saicharanrao21/car_rental_monorepo`  
**Target Commit Baseline**: `0a34b041787630062d50d6563be23c10b2205876`  
**Date**: October 30, 2026  
**Status**: Comprehensive File-by-File Disposition Manifest  

---

## 1. Classification Taxonomy & Evaluation Criteria

Every file, directory, and artifact in the DriveGo repository is evaluated against a six-tier classification system designed to guarantee architectural purity while enforcing zero risk to production stability and legal compliance:

| Classification | Definition & Criteria | Action Mandate |
| :--- | :--- | :--- |
| **`KEEP`** | Essential production code, domain logic, database migrations, unit/integration tests, CI/CD pipelines, design system assets, and active configuration. | Strictly preserve without alteration unless enhancing functionality or fixing bugs. |
| **`KEEP_AND_REORGANIZE`** | Valid, essential documentation or assets currently located in suboptimal paths, non-standard directories, or lacking standard navigation links. | Relocate to target path, update relative links, and maintain backwards compatibility. |
| **`SAFE_TO_REMOVE`** | Accidental duplicates, redundant copies of tracked assets, orphaned debug screenshots, or obsolete temporary scripts that have no operational dependency. | Safely purge after verifying identical content exists in authoritative location. |
| **`REQUIRES_DECISION`** | Architectural proposals or features that introduce potential legal, regulatory, or business conflicts (e.g., automated KYC purging vs. statutory audit retention). | Flag for architectural committee and stakeholder governance sign-off. |
| **`GENERATED_OR_IGNORED`** | Build artifacts, compiled bytecode, dependency trees, local database snapshots, and developer scratch files covered by `.gitignore`. | Maintain `.gitignore` rules; exclude from version control; clean local scratch during hygiene. |
| **`LEGACY_REQUIRES_MIGRATION`** | Historical reports, legacy audit memos, or outdated checklists that contain historical context superseded by current authoritative documents. | Retain in `docs/archive/` or maintain with a clear deprecation/superseded disclaimer. |

---

## 2. Exhaustive Directory & File Manifest

### 2.1 Monorepo Root Directory

| Path / Pattern | Type | Classification | Size / Details | Disposition & Safety Justification |
| :--- | :---: | :---: | :---: | :--- |
| `melos.yaml` | File | `KEEP` | 493 B | **Preserve**: Melos workspace configuration orchestrating Flutter apps and packages. |
| `pubspec.yaml` | File | `KEEP` | 177 B | **Preserve**: Monorepo root workspace pubspec. |
| `pubspec.lock` | File | `KEEP` | 8.1 KB | **Preserve**: Root Dart dependency lockfile. |
| `analysis_options.yaml` | File | `KEEP` | 189 B | **Preserve**: Global Dart analyzer rules for the monorepo. |
| `package-lock.json` | File | `KEEP` | 104 B | **Preserve**: Tracked root npm lockfile. |
| `docker-compose.production.yml` | File | `KEEP` | 5.0 KB | **Preserve**: Authoritative turnkey multi-container production deployment definition. |
| `docker-compose.staging.yml` | File | `KEEP` | 2.1 KB | **Preserve**: Authoritative staging deployment definition. |
| `README.md` | File | `KEEP_AND_REORGANIZE` | 5.5 KB | **Update**: Refresh test metrics (2,366 tests), verify commands, and document clean layout. |
| `PRODUCTION_STATUS.md` | File | `KEEP` | 29.5 KB | **Preserve**: Forensic production audit report detailing controller security and invariants. |
| `PRODUCTION_HARDENING_CHANGELOG.md`| File | `KEEP` | 13.9 KB | **Preserve**: Historical changelog of Phase 1 hardening and RBAC standardization. |
| `admin_web.png` | File | `SAFE_TO_REMOVE` | 23.6 KB | **Safe to Purge**: Root debug screenshot, gitignored by `*.png`. Preserved in `scratch/` if needed. |
| `.latest_otp.json` | File | `GENERATED_OR_IGNORED` | 59 B | **Generated**: Local test OTP state file. Covered by `.gitignore`. |
| `melos_car_rental_monorepo.iml` | File | `GENERATED_OR_IGNORED` | 517 B | **Ignored**: IntelliJ IDEA module configuration. Covered by `.gitignore`. |
| `.idea/` | Dir | `GENERATED_OR_IGNORED` | Tree | **Ignored**: IDE configuration directory. Covered by `.gitignore`. |
| `.dart_tool/` | Dir | `GENERATED_OR_IGNORED` | Tree | **Generated**: Dart/Flutter build tool state. Re-created automatically by `flutter pub get`. |
| `node_modules/` | Dir | `GENERATED_OR_IGNORED` | Tree | **Generated**: Root npm dependencies. Covered by `.gitignore`. |
| `scratch/` | Dir | `GENERATED_OR_IGNORED` | Tree | **Ignored Developer Scratch**: Local scripts, dumps, and visual scratch. Covered by `.gitignore`. |
| `tools/` | Dir | `GENERATED_OR_IGNORED` | Tree | **Ignored Local Binaries**: Local Redis binaries (`redis/`, `redis8/`). Covered by `.gitignore`. |
| `scripts/scan-production-artifacts.mjs`| File | `KEEP` | 4.2 KB | **Preserve**: Production release artifact security scanner (zero-secret & fail-closed verification). |

---

### 2.2 Client Applications Directory (`apps/`)

| Path | Type | Classification | Details & Safety Justification |
| :--- | :---: | :---: | :--- |
| [`apps/customer_app/`](file:///d:/Flutter/car_rental_monorepo/apps/customer_app) | Dir | `KEEP` | **Preserve**: Production Flutter Customer App (Android, iOS, Web). 140 source files, 32 test suites, 215 tests. |
| [`apps/vendor_app/`](file:///d:/Flutter/car_rental_monorepo/apps/vendor_app) | Dir | `KEEP` | **Preserve**: Production Flutter Fleet Partner App (Android, iOS). 74 source files, 38 test suites, 280 tests. |
| [`apps/admin_panel/`](file:///d:/Flutter/car_rental_monorepo/apps/admin_panel) | Dir | `KEEP` | **Preserve**: Production Flutter Admin Control Tower (Web). 156 source files, 34 test suites, 99 tests. |
| `apps/docs/` | Dir | `SAFE_TO_REMOVE` | **Purged in Batch A**: Misplaced duplicate folder containing `evidence/phase29-6-customer-checkout`. The corrupted 0-byte file `06_price_review.png` in `docs/evidence` was restored from this directory (32KB), and the redundant folder removed to ensure `apps/` contains strictly Flutter packages. |

---

### 2.3 Backend API Service (`car_rental_backend/`)

| Path | Type | Classification | Disposition & Safety Justification |
| :--- | :---: | :---: | :--- |
| `src/` | Dir | `KEEP` | **Preserve**: 558 production source files across 62 guarded controllers, services, guards, and domain logic. |
| `prisma/schema.prisma` | File | `KEEP` | **Preserve**: Production database schema (58 models, 109 KB). |
| `prisma/migrations/` | Dir | `KEEP` | **Preserve**: Full PostgreSQL migration history. Under no circumstances should migrations be deleted. |
| `prisma/seed.ts` | File | `KEEP` | **Preserve**: Deterministic database seeding script for tests, staging, and demo environments. |
| `Dockerfile` | File | `KEEP` | **Preserve**: Multi-stage production container build definition for NestJS backend. |
| `docker-entrypoint.sh` | File | `KEEP` | **Preserve**: Container startup script with migration execution and health checks. |
| `docker-compose.yml` | File | `KEEP` | **Preserve**: Local backend container service configuration (Postgres, Redis). |
| `package.json` | File | `KEEP` | **Preserve**: Backend dependency declarations and scripts. |
| `package-lock.json` | File | `KEEP` | **Preserve**: Backend npm lockfile (511 KB). |
| `tsconfig.json` & `build.json` | Files | `KEEP` | **Preserve**: TypeScript compiler configurations. |
| `.env.example` | File | `KEEP` | **Preserve**: Production template for environment configuration with fail-closed documentation. |
| `.env` | File | `GENERATED_OR_IGNORED` | **Ignored**: Local environment configuration. Covered by `.gitignore`. Never committed. |
| `check_*.js` & `query_*.js` | Files | `GENERATED_OR_IGNORED` | **Local Scratch**: Ad-hoc database inspection scripts. Ignored by `.gitignore` rules (`check_*.js`, `query_*.js`). |
| `test_hash*.js` | Files | `GENERATED_OR_IGNORED` | **Local Scratch**: Ad-hoc bcrypt verification scripts. Ignored by `test_*.js`. |
| `pg_logfile.log` | File | `GENERATED_OR_IGNORED` | **Generated Log**: Local PostgreSQL query log. Ignored by `*.log`. |
| `dump.rdb` | File | `GENERATED_OR_IGNORED` | **Generated State**: Local Redis persistence dump. Ignored by `.gitignore`. |

---

### 2.4 Shared Packages Directory (`packages/`)

| Path | Type | Classification | Details & Safety Justification |
| :--- | :---: | :---: | :--- |
| [`packages/core/`](file:///d:/Flutter/car_rental_monorepo/packages/core) | Dir | `KEEP` | **Preserve**: Shared constants, date utilities, fee engines, and currency formatters. |
| [`packages/models/`](file:///d:/Flutter/car_rental_monorepo/packages/models) | Dir | `KEEP` | **Preserve**: Freezed immutable domain models shared across client applications. |
| [`packages/ui_kit/`](file:///d:/Flutter/car_rental_monorepo/packages/ui_kit) | Dir | `KEEP` | **Preserve**: Design system tokens, reusable widgets, responsive scaffolds. |
| [`packages/mock_data/`](file:///d:/Flutter/car_rental_monorepo/packages/mock_data) | Dir | `KEEP` | **Preserve**: Test mock providers. Verified by scanner to never leak into production bundles. |

---

### 2.5 Documentation Directory (`docs/`)

| Path / Document | Classification | Disposition & Safety Justification |
| :--- | :---: | :--- |
| `docs/architecture/` (01–06) | `KEEP` | **Authoritative Architecture Blueprint**: Baseline, Manifest, Target Structure, Doc Cleanup, Execution Log, and Final Report. |
| `docs/audits/` (01–22) | `KEEP` | **Authoritative Governance Records**: Complete operating model, role matrix, PRD/TRD registers, journey matrices, audit logs, and release verifications. |
| `docs/evidence/` | `KEEP` | **Authoritative Release Evidence**: UAT and E2E visual screenshot evidence across all phases. Includes newly restored `phase29-6-customer-checkout/06_price_review.png`. |
| `docs/product/` | `KEEP` | **Preserve**: Product requirement specs, user personas, and feature definitions. |
| `docs/security/` | `KEEP` | **Preserve**: Threat modeling, vulnerability scans, and security policies. |
| `docs/incidents/` | `KEEP` | **Preserve**: Forensic incident logs and post-mortem analysis. |
| `docs/release/` | `KEEP` | **Preserve**: Production release checklists and staging verification logs. |
| `docs/admin/` | `KEEP` | **Preserve**: Admin panel operational specifications and navigation maps. |
| `docs/design/` | `KEEP` | **Preserve**: UX design specifications, tokens, and flowcharts. |
| `docs/reports/` | `KEEP` | **Preserve**: Verification test reports and invariant calculation proofs. |
| `docs/archive/` | `KEEP` | **Historical Archive**: Superseded audit notes preserved for historical reference. |
| Root-level markdown in `docs/` (`ADMIN_ROUTE_...`, `DRIVEGO_CURRENT_...`, etc.) | `KEEP_AND_REORGANIZE` | **Cataloged**: Important historical matrices. Kept accessible; cross-referenced in `04_DOCUMENTATION_CLEANUP_REPORT.md`. |

---

### 2.6 Requirements & Infrastructure Directories

| Path | Type | Classification | Disposition & Safety Justification |
| :--- | :---: | :---: | :--- |
| [`requirements/`](file:///d:/Flutter/car_rental_monorepo/requirements) | Dir | `KEEP` | **Preserve**: 6 original DOCX requirements files defining Location Fulfillment PRD, TRD, App Flow, UI/UX Brief, Backend Schema, and Plan. |
| [`nginx/`](file:///d:/Flutter/car_rental_monorepo/nginx) | Dir | `KEEP` | **Preserve**: Production reverse proxy configuration (`nginx.conf`) and documentation (`README.md`). |

---

## 3. Decision-Required Items Register

| Item / Proposal | Origin | Conflict / Consideration | Recommended Architectural Decision |
| :--- | :--- | :--- | :--- |
| **Automatic 90-Day KYC Deletion Cron** | `docs/audits/10_IMPLEMENTATION_BACKLOG_PRIORITIES.md` | Indian Motor Vehicles Act, commercial transport liability, and GST/Income Tax statutes require 5–7 years record retention for commercial rental agreements and verified driver licenses. Auto-deleting active trip KYC creates severe corporate liability. | **REJECT AUTOMATIC 90-DAY DELETION**: Preserve statutory 7-year audit retention for completed bookings. Maintain existing DPDP on-demand anonymization (`anonymizeUser()`) for customer account closure requests. |
| **Kubernetes vs. Docker Compose Production Model** | `docs/audits/13_DEPLOYMENT_AND_ROLLBACK_RUNBOOK.md` | Document 13 specifies AWS ECR/Kubernetes commands, while codebase implements turnkey Docker Compose + Nginx. | **ADOPT DOCKER COMPOSE + NGINX AS AUTHORITATIVE**: Align runbook to active Docker Compose reality. Treat Kubernetes migration as an enterprise scaling milestone for Phase 2. |
| **External Live Cloud Credentials** | Monorepo root / `.env` | Upstash Redis quota, Razorpay live payment merchant onboarding, Cloudflare R2 bucket keys, MSG91 SMS gateway. | **EXTERNAL PREREQUISITES**: Fully decoupled via fail-closed architecture and local fallback testing; require corporate account provisioning prior to public production traffic. |


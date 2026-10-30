# DriveGo — Target Repository Structure & Architectural Blueprint

**Document Reference**: `docs/architecture/03_TARGET_REPOSITORY_STRUCTURE.md`  
**Monorepo**: `saicharanrao21/car_rental_monorepo`  
**Date**: October 30, 2026  
**Status**: Authoritative Architectural Target Specification  

---

## 1. Architectural Target Vision

The target architecture for the DriveGo monorepo enforces clean boundaries between **client presentation**, **backend domain orchestration**, **shared core libraries**, **infrastructure definitions**, and **governance documentation**.

### Guiding Principles:
1. **Isolated Client Surfaces**: The [`apps/`](file:///d:/Flutter/car_rental_monorepo/apps) directory contains strictly deployable client applications (`customer_app`, `vendor_app`, `admin_panel`). No non-application directories or assets reside in `apps/`.
2. **Domain-Driven Backend Core**: The [`car_rental_backend/`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend) service houses the entire server-side application with strictly guarded NestJS controllers, an immutable Prisma schema, explicit migrations, and zero loose scratch scripts in production source.
3. **Layered Shared Packages**: The [`packages/`](file:///d:/Flutter/car_rental_monorepo/packages) directory provides reusable, decoupled Dart libraries organized hierarchically: `core` (logic & calculations) -> `models` (data contracts) -> `ui_kit` (presentation design tokens) -> `mock_data` (isolated test fixtures).
4. **Structured Documentation Taxonomy**: The [`docs/`](file:///d:/Flutter/car_rental_monorepo/docs) directory maintains a deterministic categorization: `architecture/`, `audits/`, `evidence/`, `product/`, `security/`, `release/`, `incidents/`, `design/`, `reports/`, and `archive/`.
5. **Turnkey Infrastructure**: Root-level deployment configurations ([`docker-compose.production.yml`](file:///d:/Flutter/car_rental_monorepo/docker-compose.production.yml), [`docker-compose.staging.yml`](file:///d:/Flutter/car_rental_monorepo/docker-compose.staging.yml), and [`nginx/`](file:///d:/Flutter/car_rental_monorepo/nginx)) provide immediate, repeatable local, staging, and production startup.

---

## 2. Target Directory Hierarchy Tree

```
car_rental_monorepo/
│
├── .github/                               # CI/CD Workflows & GitHub Actions
│   └── workflows/                         # Automated testing, linting & verification
│
├── apps/                                  # Pure Flutter Deployable Applications
│   ├── customer_app/                      # Customer Mobile App (iOS / Android / Web)
│   │   ├── lib/                           # Features: auth, search, booking, checkout, kyc, wallet
│   │   ├── test/                          # 32 Widget, Riverpod & Integration Test Suites (215 Tests)
│   │   └── pubspec.yaml
│   ├── vendor_app/                        # Vendor Fleet Partner App (iOS / Android)
│   │   ├── lib/                           # Features: fleet, telematics, inspection, handover, payouts
│   │   ├── test/                          # 38 Operations & Fulfillment Test Suites (280 Tests)
│   │   └── pubspec.yaml
│   └── admin_panel/                       # Mission-Control Operations Tower (Flutter Web)
│       ├── lib/                           # Features: RBAC, audit, fleet, disputes, rules, comms
│       ├── test/                          # 34 Governance & Admin Test Suites (99 Tests)
│       └── pubspec.yaml
│
├── car_rental_backend/                    # Enterprise NestJS Backend Service
│   ├── src/                               # TypeScript Domain Modules (62 Guarded Controllers)
│   │   ├── auth/                          # JWT, RBAC, Support Agent, Rate Limiting
│   │   ├── bookings/                      # Concurrency locks, state machine, lifecycle
│   │   ├── cars/ & fleet/                 # Fleet inventory, telematics, immobilizer, inspection
│   │   ├── operations/                    # Approval Engine, Workflow Engine, Scheduling Engine
│   │   ├── payments/ & finance/           # Razorpay, double-entry ledger, escrow, bank encryption
│   │   ├── kyc/ & fraud/                  # Document verification, risk scoring, DPDP anonymization
│   │   ├── notifications/                 # Multi-channel orchestrator (Push, SMS, WhatsApp, Email)
│   │   └── common/                        # Interceptors, filters, decorators, env validation
│   ├── prisma/                            # Relational Database Layer (PostgreSQL 16)
│   │   ├── schema.prisma                  # Authoritative Database Schema (58 Models)
│   │   ├── migrations/                    # Versioned Migration History
│   │   └── seed.ts                        # Deterministic Seeding Script
│   ├── test/                              # Backend End-to-End Test Suites
│   ├── Dockerfile                         # Production Multi-Stage Container Definition
│   ├── docker-entrypoint.sh               # Container Startup & Migration Executor
│   ├── docker-compose.yml                 # Local Development Postgres/Redis Compose
│   └── package.json
│
├── packages/                              # Shared Dart/Flutter Packages
│   ├── core/                              # Base constants, fee calculators, date utils, enums
│   ├── models/                            # Freezed immutable domain models & JSON converters
│   ├── ui_kit/                            # Design tokens, color palette, typography, custom widgets
│   └── mock_data/                         # Test fixtures & mocks (Excluded from production source)
│
├── docs/                                  # Monorepo Knowledge Base & Governance Records
│   ├── architecture/                      # Architectural Blueprints & Cleanup Reports (01–06)
│   │   ├── 01_CURRENT_ARCHITECTURE_AND_CLEANUP_BASELINE.md
│   │   ├── 02_REPOSITORY_CLEANUP_MANIFEST.md
│   │   ├── 03_TARGET_REPOSITORY_STRUCTURE.md
│   │   ├── 04_DOCUMENTATION_CLEANUP_REPORT.md
│   │   ├── 05_CLEANUP_EXECUTION_LOG.md
│   │   └── 06_FINAL_ARCHITECTURE_ALIGNMENT_REPORT.md
│   ├── audits/                            # 22 Master Governance Documents (01–22)
│   │   ├── 01_COMPANY_OPERATING_MODEL.md
│   │   ├── 02_EMPLOYEE_ROLE_AND_PERMISSION_MATRIX.md
│   │   ├── 03_APPROVAL_AND_SEGREGATION_OF_DUTIES_MATRIX.md
│   │   ├── 04_PRD_TRD_REQUIREMENTS_REGISTER.md
│   │   ├── 05_CUSTOMER_AND_VENDOR_JOURNEY_MATRIX.md
│   │   ├── 06_ADMIN_ROUTE_AND_NAVIGATION_MAP.md
│   │   ├── 07_FINANCE_AND_RECONCILIATION_REQUIREMENTS.md
│   │   ├── 08_SECURITY_AND_PRIVACY_GAP_ASSESSMENT.md
│   │   ├── 09_OPERATIONS_AND_SUPPORT_SOP_REQUIREMENTS.md
│   │   ├── 10_IMPLEMENTATION_BACKLOG_PRIORITIES.md
│   │   ├── 11_TEST_EVIDENCE_REPORT.md
│   │   ├── 12_PRODUCTION_LAUNCH_CHECKLIST.md
│   │   ├── 13_DEPLOYMENT_AND_ROLLBACK_RUNBOOK.md
│   │   ├── 14_FINAL_GO_NO_GO_REPORT.md
│   │   ├── 15_MASTER_REQUIREMENTS_TRACEABILITY_MATRIX.md
│   │   ├── 16_DOCUMENT_BY_DOCUMENT_COMPLIANCE_REPORT.md
│   │   ├── 17_PROJECT_IMPLEMENTATION_GAP_REPORT.md
│   │   ├── 18_MASTER_IMPLEMENTATION_ROADMAP.md
│   │   ├── 19_REQUIREMENT_CONFLICTS_AND_DECISIONS.md
│   │   ├── 20_RELEASE_READINESS_EVIDENCE_REPORT.md
│   │   ├── 21_AUDIT_EXECUTION_LOG.md
│   │   └── 22_INDEPENDENT_AUDIT_EVIDENCE_CHALLENGE.md
│   ├── evidence/                          # Visual UAT & E2E Screenshots Across All Phases
│   │   └── phase29-6-customer-checkout/   # Verified complete visual checkout flow (9 images)
│   ├── product/                           # Product briefs, user personas, PRDs
│   ├── security/                          # Threat models, security policies, audit notes
│   ├── release/                           # Staging checklists, deployment validation
│   ├── incidents/                         # Post-mortem incident analysis
│   ├── design/                            # UI/UX design specifications
│   ├── reports/                           # Test logs and ledger invariant proofs
│   └── archive/                           # Historical superseded documents
│
├── nginx/                                 # Reverse Proxy & Edge Security Configuration
│   ├── nginx.conf                         # Production SSL termination, rate limiting, gzip
│   └── README.md
│
├── requirements/                          # Source PRD/TRD Documents
│   ├── 01_DriveGo_Location_Fulfillment_PRD.docx
│   ├── 02_DriveGo_Location_Fulfillment_TRD.docx
│   ├── 03_DriveGo_Location_Fulfillment_App_Flow.docx
│   ├── 04_DriveGo_Location_Fulfillment_UIUX_Brief.docx
│   ├── 05_DriveGo_Location_Fulfillment_Backend_Schema.docx
│   ├── 06_DriveGo_Location_Fulfillment_Implementation_Plan.docx
│   └── README_FIRST.txt
│
├── scripts/                               # Monorepo Utility & Verification Scripts
│   └── scan-production-artifacts.mjs      # Production artifact security & hygiene scanner
│
├── docker-compose.production.yml          # Production Multi-Container Compose Definition
├── docker-compose.staging.yml             # Staging Multi-Container Compose Definition
├── melos.yaml                             # Monorepo Flutter Package Management
├── analysis_options.yaml                  # Monorepo Dart Static Analyzer Rules
├── .gitignore                             # Root Multi-Language Git Ignore Rules
└── README.md                              # Master Monorepo Documentation & Quickstart
```

---

## 3. Dependency Graph & Package Boundary Matrix

The target architecture establishes strict unidirectional dependency flows:

```
[apps/customer_app] ───┐
[apps/vendor_app]   ───┼──► [packages/ui_kit] ──► [packages/models] ──► [packages/core]
[apps/admin_panel]  ───┘

[packages/mock_data] ──► [packages/models] (TEST CONTEXT ONLY)

[car_rental_backend] ──► [PostgreSQL / Prisma] + [Redis / BullMQ]
```

### Invariant Rules:
1. **No Circular Dependencies**: `packages/core` depends on zero internal packages. `packages/models` depends only on `packages/core`. `packages/ui_kit` depends on `packages/models` and `packages/core`.
2. **Client Isolation**: Client applications (`apps/*`) never import each other. Shared logic must reside in `packages/*`.
3. **Backend Independence**: `car_rental_backend` is completely self-contained with its own TypeScript compiler, Prisma data layer, and tests, operating independently of the Dart toolchain.
4. **Mock Isolation**: `packages/mock_data` is strictly prohibited from being imported into production client source code, guaranteed by automated release scanner [`scripts/scan-production-artifacts.mjs`](file:///d:/Flutter/car_rental_monorepo/scripts/scan-production-artifacts.mjs).

---

## 4. Melos Workspace Strategy

The root [`melos.yaml`](file:///d:/Flutter/car_rental_monorepo/melos.yaml) coordinates the Dart ecosystem:
- **Scope**: Scans all Flutter apps under `apps/*` and shared libraries under `packages/*`.
- **Scripts**:
  - `melos run get`: Synchronizes dependencies across all 7 packages.
  - `melos run analyze`: Runs static analysis across the entire monorepo.
  - `melos run build_runner`: Generates code for Freezed models and JSON serialization.

---

## 5. Migration & Alignment Roadmap

To align the current repository state with this target structure, five sequential cleanup phases are defined:

1. **Phase 1: Workspace Sanitation (Completed in Batch A)**:
   - Purged misplaced duplicate directory `apps/docs/`.
   - Restored truncated evidence file `docs/evidence/phase29-6-customer-checkout/06_price_review.png` (32 KB).
   - Confirmed `apps/` strictly holds `customer_app`, `vendor_app`, and `admin_panel`.

2. **Phase 2: Architectural Documentation Alignment (Completed in Batch B)**:
   - Established `docs/architecture/` with comprehensive 01–06 blueprints.
   - Updated root `README.md` with accurate live metrics (2,366 tests) and streamlined setup.

3. **Phase 3: Structural Validation (Batch C)**:
   - Verified Melos workspace configuration against `apps/*` and `packages/*`.
   - Validated Dart analysis options and package dependency locks.

4. **Phase 4: Configuration & Infrastructure Alignment (Batch D)**:
   - Aligned deployment runbooks to the active Docker Compose + Nginx architecture.
   - Confirmed fail-closed environment variable declarations in `.env.example`.

5. **Phase 5: Hygiene Verification & Test Certification (Batch E)**:
   - Executed artifact security scanner (0 violations).
   - Re-verified all 248 test suites across backend, customer, vendor, and admin surfaces (2,366/2,366 passing).


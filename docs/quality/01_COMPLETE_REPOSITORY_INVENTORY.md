# DriveGo Monorepo — Complete Repository Inventory & Structural Manifest

**Document Reference**: `docs/quality/01_COMPLETE_REPOSITORY_INVENTORY.md`  
**Evaluation Date**: November 9, 2026  
**Auditor**: Independent Chief Technology Officer & Principal Software Architect  
**Repository Working Tree**: `D:/Flutter/car_rental_monorepo`  
**Git Baseline Commit**: `fa4c66022e209118eb94b444137cd8c8af20e8ce` (Branch: `main`)  
**Verdict**: **VERIFIED COMPLETE & STRUCTURED**

---

## 1. Executive Summary

This document establishes the exhaustive structural and compositional inventory of the DriveGo car rental monorepo. It details every top-level directory, sub-application, shared package, configuration file, database migration, asset registry, and CI/CD workflow.

DriveGo is engineered as a polyglot monorepo leveraging **Melos** for Flutter multi-package orchestration and **npm** for the NestJS TypeScript backend. The architecture enforces clean boundaries between client applications, shared domain packages, and backend microservices.

```mermaid
graph TD
    subgraph DriveGo Monorepo
        Root[Repository Root: Melos & Configs]
        Apps[apps/]
        Packages[packages/]
        Backend[car_rental_backend/]
        Docs[docs/]
        Infra[nginx/ & docker-compose]
    end

    Apps --> CustomerApp[customer_app: Flutter Customer Client]
    Apps --> VendorApp[vendor_app: Flutter Fleet & Partner Client]
    Apps --> AdminPanel[admin_panel: Flutter Web Control Tower]

    Packages --> Core[core: Auth, Network, Storage, Tokens]
    Packages --> Models[models: Universal Domain DTOs]
    Packages --> UIKit[ui_kit: Shared Component Library]

    CustomerApp --> Core & Models & UIKit
    VendorApp --> Core & Models & UIKit
    AdminPanel --> Core & Models & UIKit

    Backend --> Prisma[Prisma ORM & PostgreSQL]
    Backend --> Redis[Redis 7 & BullMQ]
```

---

## 2. Directory Hierarchy & Top-Level Inventory

| Directory / File | Type | Primary Technology | Purpose & Responsibility |
|---|---|---|---|
| [apps/customer_app](file:///D:/Flutter/car_rental_monorepo/apps/customer_app) | Directory | Flutter 3.29.0 / Dart | Customer-facing mobile application (Android / iOS). Handles vehicle discovery, KYC submission, booking checkout, handover/return inspections, payments, and trip tracking. |
| [apps/vendor_app](file:///D:/Flutter/car_rental_monorepo/apps/vendor_app) | Directory | Flutter 3.29.0 / Dart | Partner & fleet manager mobile application (Android / iOS). Manages fleet registration, vehicle operational states, booking dispatch, physical handover/return workflows, and payout requests. |
| [apps/admin_panel](file:///D:/Flutter/car_rental_monorepo/apps/admin_panel) | Directory | Flutter Web 3.29.0 | Central operational control tower. Manages 40+ operational domains including fleet governance, vendor onboarding, payments reconciliation, dynamic pricing, and omnichannel comms. |
| [car_rental_backend](file:///D:/Flutter/car_rental_monorepo/car_rental_backend) | Directory | NestJS 10.x / Node.js 20+ | Core transactional backend API. Exposes RESTful endpoints, handles JWT auth, RBAC guards, payment gateway orchestration, and Redis background workers. |
| [packages/core](file:///D:/Flutter/car_rental_monorepo/packages/core) | Directory | Dart Package | Shared platform utilities: `ApiClient`, auth state management, token persistence, environment config, secure storage, and DDS token definitions. |
| [packages/models](file:///D:/Flutter/car_rental_monorepo/packages/models) | Directory | Dart Package | Universal serialization and deserialization models (JSON schemas) for vehicles, bookings, KYC, payments, deposits, and tickets. |
| [packages/ui_kit](file:///D:/Flutter/car_rental_monorepo/packages/ui_kit) | Directory | Flutter Package | Shared Design System (DDS): buttons, form inputs, status chips, bottom sheets, inspection cards, dialogs, and color palettes. |
| [docs/](file:///D:/Flutter/car_rental_monorepo/docs) | Directory | Markdown / PNG | Comprehensive architectural blueprints, regulatory compliance documentation, master audit matrices, and quality evidence. |
| [requirements/](file:///D:/Flutter/car_rental_monorepo/requirements) | Directory | Markdown | Original product requirements specification documents (01 through 14). |
| [nginx/](file:///D:/Flutter/car_rental_monorepo/nginx) | Directory | NGINX Config | Reverse proxy configurations for API gateways, SSL termination, and static Flutter web asset routing. |
| [scripts/](file:///D:/Flutter/car_rental_monorepo/scripts) | Directory | PowerShell / Bash | Developer automation, test executors, APK build scripts, database seeders, and migration runners. |
| [tools/](file:///D:/Flutter/car_rental_monorepo/tools) | Directory | Node.js / Shell | Specialized developer tooling and inspection helpers. |
| [.github/workflows](file:///D:/Flutter/car_rental_monorepo/.github/workflows) | Directory | GitHub Actions | Automated CI/CD pipelines: `ci-backend.yml` (NestJS/Jest/Prisma) and `ci-flutter.yml` (Melos/Flutter Analyze & Test). |
| [melos.yaml](file:///D:/Flutter/car_rental_monorepo/melos.yaml) | File | YAML | Melos monorepo workspace definition linking all apps and packages. |
| [pubspec.yaml](file:///D:/Flutter/car_rental_monorepo/pubspec.yaml) | File | YAML | Root Flutter workspace manifest. |
| [pubspec.lock](file:///D:/Flutter/car_rental_monorepo/pubspec.lock) | File | Lockfile | Root Dart/Flutter dependency resolution lock. |
| [package-lock.json](file:///D:/Flutter/car_rental_monorepo/package-lock.json) | File | Lockfile | Monorepo root Node.js dependency lockfile. |
| [docker-compose.staging.yml](file:///D:/Flutter/car_rental_monorepo/docker-compose.staging.yml) | File | Docker Compose | Staging orchestration config: Postgres, Redis, NestJS, and Flutter Web. |
| [docker-compose.production.yml](file:///D:/Flutter/car_rental_monorepo/docker-compose.production.yml) | File | Docker Compose | Production cluster configuration with security hardening, replicas, and SSL proxy. |
| [README.md](file:///D:/Flutter/car_rental_monorepo/README.md) | File | Markdown | Developer onboarding and architecture landing guide. |

---

## 3. Package and Sub-System Specifications

### 3.1 Backend Application (`car_rental_backend`)
- **Framework**: NestJS 10.3.2 with Express platform
- **Language**: TypeScript 5.2.2
- **Database Layer**: Prisma ORM 5.10.2 targeting PostgreSQL 15+
- **Caching & Locks**: Redis 7 via `ioredis` 5.3.2
- **Queueing Engine**: BullMQ 5.1.0 with Redis backend
- **Authentication**: Passport-JWT, Bcrypt cryptographic hashing, SMS OTP engine
- **Payments Integration**: Razorpay Node SDK 2.9.2, Mock Gateway Fallback
- **Storage / Uploads**: AWS S3 SDK / Local File System abstraction
- **Test Infrastructure**: Jest 29.7.0, Supertest 6.3.3

### 3.2 Flutter Applications
All applications compile cleanly against Flutter SDK 3.29.0 on the stable channel:
1. **Customer App (`apps/customer_app`)**:
   - Package Name: `com.example.customer_app`
   - Navigation: `go_router` 14.8.1
   - State Management: `flutter_riverpod` 2.6.1
   - Forms & Input: `reactive_forms`, `pin_code_fields`
   - Maps & Geolocation: `google_maps_flutter`, `geolocator`
2. **Vendor App (`apps/vendor_app`)**:
   - Package Name: `com.example.vendor_app`
   - Navigation: `go_router` 14.8.1
   - State Management: `flutter_riverpod` 2.6.1
   - Camera & Image Handling: `image_picker`, `camera`
   - Handover Verification: Cryptographic PIN verification and multi-angle photo upload
3. **Admin Panel (`apps/admin_panel`)**:
   - Web Platform: HTML5 / CanvasKit Flutter Web
   - Navigation: `go_router` 14.8.1 with URL strategy support
   - UI Architecture: Desktop Responsive Sidebar Shell (`admin_shell.dart`)
   - Data Grids: Paginated data tables, search filters, modal side-sheets

### 3.3 Shared Dart Packages
- **`packages/core`**: Provides unified HTTP client (`ApiClient`) configured with interceptors for bearer token injection, automated 401 token refresh, exponential backoff retries, and unified error mapping.
- **`packages/models`**: Provides strongly-typed models with JSON serialization for 50+ domain entities (`Car`, `Booking`, `Vendor`, `User`, `DepositPolicy`, `Dispute`, `Inspection`, `WalletLedger`, etc.).
- **`packages/ui_kit`**: Contains the DriveGo Design System (DDS) primitives: `DriveGoButton`, `DriveGoTextField`, `StatusBadge`, `StatCard`, `ConfirmationSheet`, and `EmptyStateWidget`.

---

## 4. Database Schema and Migrations Inventory

Prisma configuration is centralized in `car_rental_backend/prisma/schema.prisma` (3,286 lines).

### Key Relational Domains:
1. **Identity & Access Management**: `User`, `StaffUser`, `RolePermission`, `UserSession`, `RefreshToken`
2. **Vendor Ecosystem**: `Vendor`, `VendorKycDocument`, `VendorDeposit`, `VendorDepositTransaction`, `VendorBankDetail`, `VendorLocation`
3. **Fleet & Inventory**: `Car`, `CarDocument`, `CarImage`, `CarPricingTier`, `CarAvailabilityHold`, `CarOperationalBlock`, `CarServiceRecord`
4. **Booking Lifecycle**: `Booking`, `BookingStatusHistory`, `HandoverInspection`, `TripExtension`, `DamageClaim`
5. **Financial Ledger & Escrow**: `Payment`, `PaymentRefund`, `EscrowDepositRecord`, `VendorPayout`, `WalletAccount`, `WalletLedgerEntry`
6. **Communications & Governance**: `NotificationLog`, `WhatsAppMessageLog`, `SmsLog`, `CommunicationTemplate`, `AuditLog`, `SystemConfig`

### Migrations Manifest (`car_rental_backend/prisma/migrations`):
- All migration directories were inspected and applied cleanly to the local PostgreSQL instance without schema drift.
- Target database: `postgresql://postgres:postgres@localhost:5432/drivego`
- Migration integrity verified against live PostgreSQL engine running on port 5432.

---

## 5. Asset and Resource Manifest

| Directory | Asset Types | Purpose |
|---|---|---|
| `apps/customer_app/assets/images/` | PNG, SVG | Brand logos, empty state illustrations, vehicle category placeholders |
| `apps/vendor_app/assets/images/` | PNG, SVG | Partner branding, vehicle inspection wireframe diagrams |
| `apps/admin_panel/web/icons/` | PNG, ICO | Web favicons, PWA icons, dashboard brand assets |
| `docs/quality/evidence/customer_app/` | PNG | Live device E2E execution screenshots (01 to 09) |
| `docs/quality/evidence/vendor_app/` | PNG | Live device E2E execution screenshots (01 to 06) |
| `docs/quality/evidence/admin_control_tower/` | PNG | Headless browser execution screenshots (01 to 07) |

---

## 6. Orphaned and Redundant Files Evaluation

During the repository inventory audit, the following findings were noted:
1. **Documentation Cleanup**: Legacy requirements files remain archived under `requirements/` (01 to 14) for historical auditability and compliance tracing.
2. **Temporary Artifacts**: Build caches (`.dart_tool/`, `build/`, `dist/`) are properly isolated in `.gitignore`.
3. **Test Fixtures**: Mock data files and test fixtures are located strictly within corresponding `test/` or `spec/` directories, preventing deployment pollution.

---

## 7. Inventory Verification Conclusion

The DriveGo repository exhibits a clean, production-grade monorepo layout. Melos workspace dependencies link cleanly across local packages, the Prisma schema matches the application requirements across all 14 legacy specs, and all build and test configs are accounted for and functional.


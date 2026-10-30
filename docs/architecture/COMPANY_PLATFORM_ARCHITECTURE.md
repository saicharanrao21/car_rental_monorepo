# DRIVEGO — COMPANY PLATFORM ARCHITECTURE
## End-to-End System Topology, Domain Boundaries & Server Authority Invariant

> **Document Reference**: `docs/architecture/COMPANY_PLATFORM_ARCHITECTURE.md`  
> **Classification**: Authoritative Platform Architecture  
> **Status**: APPROVED — PRODUCTION BLUEPRINT  
> **Author**: DriveGo Technical Governance Board (CTO, Principal Architect, Senior Engineers)  
> **Target Release Baseline**: `0a34b041787630062d50d6563be23c10b2205876`  

---

## 1. SYSTEM TOPOLOGY & WORKSPACE ARCHITECTURE

DriveGo is engineered as an enterprise-grade monorepo orchestrating three client Flutter applications, a high-concurrency NestJS backend, a PostgreSQL relational database layer managed via Prisma ORM, Redis distributed caching and queues, and shared multi-platform Dart packages.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                            DRIVEGO MONOREPO TOPOLOGY                             │
├───────────────────────┬──────────────────────────┬───────────────────────────────┤
│ CLIENT APPLICATIONS   │ SHARED PACKAGES          │ BACKEND SERVICE & DATA        │
├───────────────────────┼──────────────────────────┼───────────────────────────────┤
│ apps/customer_app     │ packages/core            │ car_rental_backend/           │
│ (Android, iOS, Web)   │ (Tokens, Theme, Utils)   │ (NestJS 10, TypeScript 5)     │
│                       ├──────────────────────────┼───────────────────────────────┤
│ apps/vendor_app       │ packages/models          │ PostgreSQL 16 (Alpine)        │
│ (Android, iOS)        │ (Freezed Immutable DTOs) │ (Prisma ORM, 58 Models)       │
│                       ├──────────────────────────┼───────────────────────────────┤
│ apps/admin_panel      │ packages/ui_kit          │ Redis 7 (Alpine) & BullMQ     │
│ (Desktop Web, Tablet) │ (Automotive UI Widgets)  │ (Distributed Caching & Queues)│
│                       ├──────────────────────────┼───────────────────────────────┤
│                       │ packages/mock_data       │ Nginx Edge Reverse Proxy      │
│                       │ (Testing Fixtures Only)  │ (SSL Termination, Rate Limit) │
└───────────────────────┴──────────────────────────┴───────────────────────────────┘
```

### 1.1 Server-Side Authority Invariant
A foundational architectural rule governs the DriveGo platform: **The Backend is the Single Source of Truth.**
1. **Financial Calculations**: Client applications are strictly forbidden from calculating final rental prices, platform commissions, security deposit requirements, wallet deductions, or refund amounts. All calculations are executed server-side via `CarPricingEngine`, `PlatformFeeService`, and `LedgerCoreService`.
2. **State Transitions**: Client applications cannot arbitrarily transition booking or deposit statuses. All mutations must pass through backend state machines (`BookingLifecycleService`, `DepositsService`, `VendorSecurityDepositService`) enforcing optimistic concurrency locks and permission checks.
3. **Immutability of Historical Terms**: At booking confirmation, an immutable `BookingPolicySnapshot` is persisted. Future changes to platform commission, vendor pricing, or deposit rules do not affect existing bookings.

---

## 2. DOMAIN BOUNDARIES & COMPONENT INTERFACES

### 2.1 Backend Modules (`car_rental_backend/src/`)
The backend is architected into modular, decoupled bounded contexts:
- **`auth/`**: JWT issuance, Refresh Token rotation, OTP bcrypt verification, RBAC guards (`RolesGuard`, `PermissionsGuard`).
- **`users/`**: Customer profiles, DPDP Act on-demand anonymization (`anonymizeUser()`), privacy requests.
- **`vendors/`**: Fleet partner profiles, 13-stage onboarding engine, document collection, bank account encryption.
- **`cars/`**: Fleet catalog, vehicle verification, operational status (`ACTIVE`, `MAINTENANCE`, `IMPOUNDED`), telematics integration.
- **`bookings/`**: 23-stage customer journey, concurrency locking (`BookingLockService`), pre-trip/post-trip inspections, Handover OTP validation, Transactional Outbox pattern.
- **`deposits/`**: Centralized deposit policy engine, Tri-Option customer collateral management (Monetary, Yard Vehicle, Safe Vault Document, DigiLocker High-Trust), automated 24h post-trip refund cron.
- **`finance/`**: Double-entry ledger (`LedgerCoreService`), journal entries, vendor payables, weekly payout batches via RazorpayX, reconciliation.
- **`notifications/`**: Omnichannel notification orchestrator (WhatsApp Meta Cloud API, MSG91 DLT SMS, SendGrid Email, FCM Push).
- **`operations/`**: Workflow engine, approval engine with maker-checker controls, scheduling engine.
- **`admin/`**: Audit logging service, KPI analytics, dispute tribunal adjudication.

### 2.2 Shared Client Packages (`packages/`)
- **`packages/core`**: Automotive Design System (DDS) design tokens (colors, spacing, elevation, motion, typography), responsive breakpoints, and date/currency formatters.
- **`packages/models`**: Strongly typed, immutable Freezed models guaranteeing contract parity between backend API responses and Flutter presentation layers.
- **`packages/ui_kit`**: Standardized automotive widgets (buttons, status badges, price tags, inspection cameras, location cards).

---

## 3. DUAL-MARKETPLACE OPERATING MODEL

DriveGo bridges individual fleet operators and institutional transport hubs:
1. **Marketplace Model (Independent Fleet Partners)**:
   - Targets micro-operators and independent rental agencies with 1 to 50 vehicles.
   - Vendors maintain their own inspected physical yards.
   - Protected by tiered vendor onboarding deposits (₹25,000 to ₹1,00,000) and a 10% 30-day rolling reserve.
2. **Managed Fleet Hubs (Company-Supervised Operating Yards)**:
   - High-density transportation hubs (airports, railway terminals, metro stations).
   - Standardized physical facilities with dedicated customer vehicle collateral parking slots and fire-rated safe-deposit lockers for physical document collateral.
   - On-site yard attendants conducting digital check-in/check-out.

---

## 4. CONCURRENCY CONTROL & STATE MACHINE INTEGRITY

To prevent race conditions, double bookings, and duplicate payouts, the architecture enforces:
1. **Distributed Mutex Locks**: Powered by Redis for high-frequency operations (booking checkout, vehicle allocation).
2. **Atomic Database Compare-and-Swap (CAS)**: All deposit settlements and booking status transitions update state conditionally:
   ```sql
   UPDATE "SecurityDeposit"
   SET "status" = 'REFUNDED', "releasedAt" = NOW()
   WHERE "id" = $1 AND "status" = 'HELD';
   ```
3. **Transactional Outbox Pattern**: State mutations and corresponding operational event triggers are written inside a single PostgreSQL database transaction, guaranteeing zero message loss if background workers restart.

---
*Ratified by DriveGo Technical Governance Board.*


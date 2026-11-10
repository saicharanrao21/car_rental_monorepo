# DriveGo — Corrected Prioritized Implementation Backlog

**Document Reference**: `docs/product/DRIVEGO_CORRECTED_IMPLEMENTATION_BACKLOG.md`  
**Classification**: Authoritative Engineering Work Breakdown  
**Effective Date**: November 9, 2026  
**Author**: Chief Technology Officer & Technical Delivery Lead  
**Repository**: `https://github.com/saicharanrao21/car_rental_monorepo`  
**Git Baseline Commit**: `b87cfe90527c801172529290b96f3d7c0200b941` (Branch: `main`)  
**Status**: APPROVED PRIORITIZED WORK REGISTER — IMPLEMENTATION STATUS: PENDING EXPLICIT FOUNDER APPROVAL  

---

> [!CAUTION]
> **Implementation Authorization Directive**: This backlog specifies the prioritized technical and architectural work breakdown recommended for future sprints. **NO IMPLEMENTATION AUTHORIZATION HAS BEEN GRANTED**. All engineering implementation remains strictly `PENDING EXPLICIT FOUNDER APPROVAL`.

---

## 1. Backlog Governance Standard (Phase 12)

Engineering tasks are strictly prioritized based on business criticality and operational dependencies:
- **Priority 0 — Marketplace Foundation**: Essential onboarding, verification, and dealer fleet core.
- **Priority 1 — Booking & Rental Lifecycle**: Discovery, reservations, payments, and handovers.
- **Priority 2 — Finance & Governance**: Configurable policies, snapshots, settlements, and maker-checker.
- **Priority 3 — Reliability & Operational Maturity**: Staff delegation, security, telemetry, and regression tests.
- **Priority 4 — Growth & Expansion**: Promotions, loyalty, analytics, and geographical rollout.

> [!IMPORTANT]
> **Workflow Focus Directive**: Administrative navigation consolidation will run as an operational support task and must **never displace unfinished Priority 0 or Priority 1 marketplace workflows**.

---

## 2. Priority 0 — Marketplace Foundation

### [TASK-P0-01] Commercial Business Entity Types Expansion
- **Objective**: Extend `enum BusinessType` in `schema.prisma` to include `PROPRIETORSHIP`, `PARTNERSHIP`, `LLP`, `PRIVATE_LIMITED`, `PUBLIC_LIMITED`.
- **Files**: `car_rental_backend/prisma/schema.prisma`, `apps/vendor_app/lib/features/registration/presentation/pages/registration_stepper_page.dart`.
- **Dependencies**: None.
- **DoD**: Dealer registration wizard allows selecting from the 5 commercial entity structures; schema compiles cleanly.

### [TASK-P0-02] Statutory Vehicle Document Types Expansion
- **Objective**: Extend `enum DocumentType` in `schema.prisma` to support `FITNESS_CERTIFICATE`, `POLLUTION_UNDER_CONTROL`, `COMMERCIAL_PERMIT`, `GST_CERTIFICATE`, `BANK_CANCELLED_CHEQUE`, `RENT_A_CAB_LICENSE`.
- **Files**: `car_rental_backend/prisma/schema.prisma`.
- **Dependencies**: None.
- **DoD**: Backend accepts and strongly types all 5 mandatory vehicle statutory documents.

### [TASK-P0-03] Partner App Mandatory Document Upload Step
- **Objective**: Add Step 4 to `add_edit_car_page.dart` requiring dealers to upload Commercial RC, Insurance, and Fitness Certificate.
- **Files**: `apps/vendor_app/lib/features/fleet/presentation/pages/add_edit_car_page.dart`.
- **Dependencies**: TASK-P0-02.
- **DoD**: Client-side validation blocks vehicle submission without at least RC Book and Commercial Insurance.

### [TASK-P0-04] Admin Control Tower Side-by-Side Ownership Audit UI
- **Objective**: Implement structured review workspace comparing dealer entity name with RC registered owner name.
- **Files**: `apps/admin_panel/lib/core/widgets/admin_shell.dart`, `apps/admin_panel/lib/features/fleet/`.
- **Dependencies**: TASK-P0-03.
- **DoD**: Admin can view vehicle RC image side-by-side with dealer legal profile, execute 5-point checklist, and record review notes.

### [TASK-P0-05] Backend Approval Enforcement & Status Guards
- **Objective**: Verify and tighten API guards preventing unapproved, suspended, or draft vehicles/dealers from executing operational actions.
- **Files**: `car_rental_backend/src/cars/cars.service.ts`, `car_rental_backend/src/bookings/bookings.service.ts`.
- **Dependencies**: None.
- **DoD**: Automated integration test asserts that direct API calls to book unapproved or suspended vehicles fail with HTTP 400/403.

### [TASK-P0-06] Safe Deprecation of Legacy Collateral Code across Backend & Partner App
- **Objective**: Remove `'COLLATERAL:'` bypass check from `deposits.service.ts` line 227, deprecate collateral controller endpoints, remove tri-option selector from `handover_inspection_page.dart` (lines 740–860), and clean customer deposit badge.
- **Priority Rationale**: **P0 Launch-Critical Safety & Debt Remediation**. The founder strictly mandated pure monetary deposit holding: DriveGo prohibits physical custody of original identity documents, physical cash, and customer vehicles as part of its security-deposit mechanism. Any statutory liability implications under the DPDP Act or Motor Vehicles Act remain PENDING WRITTEN LEGAL COUNSEL CONFIRMATION. Removing physical custody options from the Partner App handover wizard and backend deposit services eliminates architectural debt and aligns runtime flows with the approved business model.
- **Files**: `car_rental_backend/src/deposits/deposits.service.ts`, `car_rental_backend/src/deposits/deposits.controller.ts`, `apps/vendor_app/lib/features/bookings/presentation/pages/handover_inspection_page.dart`, `apps/customer_app/lib/features/my_bookings/presentation/widgets/booking_detail_deposit_card.dart`, `packages/models/lib/src/security_deposit_model.dart`.
- **Dependencies**: None.
- **DoD**: Partner App handover wizard enforces monetary deposit verification only; backend deposit release invokes payment gateway refunds exclusively; zero collateral references in active logic; unit tests pass 100%.

---

## 3. Priority 1 — Booking and Rental Lifecycle

### [TASK-P1-01] Availability Conflict & Double-Booking Regression Test
- **Objective**: Formalize automated concurrency suite validating Redis locks, PostgreSQL `FOR UPDATE` row locks, and overlap detection.
- **Files**: `car_rental_backend/src/bookings/tests/booking-concurrency.spec.ts`.
- **Dependencies**: None.
- **DoD**: Concurrency test simulates 50 concurrent requests for the same vehicle time slot; exactly 1 succeeds, 49 fail with HTTP 409 Conflict.

### [TASK-P1-02] Live Payment Webhook Production Hardening
- **Objective**: Enforce production cryptographic webhook signature verification and eliminate mock bypasses.
- **Files**: `car_rental_backend/src/payments/payments.service.ts`.
- **Dependencies**: External Razorpay credentials.
- **DoD**: Webhooks without valid cryptographic HMAC SHA256 signatures are rejected; mock signatures fail in production mode.

### [TASK-P1-03] Three-Stage Customer KYC Gate Enforcement
- **Objective**: Enforce mandatory customer KYC verification prior to booking confirmation (Stage 2) and verify physical driving licence / identity at on-ground vehicle release (Stage 3), while preserving unrestricted browsing without KYC (Stage 1) (Founder Dec 1.D / FND-CONF-11).
- **Files**: `car_rental_backend/src/kyc/kyc.service.ts`, `car_rental_backend/src/bookings/bookings.service.ts`, `apps/customer_app/lib/features/checkout/`, `apps/customer_app/lib/features/profile/`.
- **Dependencies**: External KYC provider keys.
- **DoD**: Customer can freely browse vehicles; checkout blocks booking confirmation if `CustomerKyc` is not `VERIFIED`; Partner App handover wizard verifies identity before physical vehicle key release.

### [TASK-P1-04] Handover and Return Inspection Telemetry & 7-Point Checklist
- **Objective**: Implement and verify the mandatory 7-point vehicle handover verification checklist (Customer ID, Driving Licence, Booking Confirmation, Vehicle condition photos, Damage acknowledgement, Customer handover acknowledgement, Keys & docs record) in Partner App and backend API (`FND-CONF-16`). Technical implementation mechanisms (such as capturing 4 exterior photos, live condition photos, customer OTP exchange, cryptographic OTP validation, or digital signature capture) are proposed engineering options in the mobile app, NOT founder-mandated rules.
- **Files**: `apps/vendor_app/lib/features/bookings/presentation/pages/handover_inspection_page.dart`, `car_rental_backend/src/inspections/`.
- **Dependencies**: None.
- **DoD**: End-to-end trip execution verified with 7-point auditable checklist completion before vehicle release (incorporating proposed mobile options such as condition photos and OTP verification).

### [TASK-P1-05] Hybrid Booking Acceptance State Machine (6-Point Eligibility Engine)
- **Objective**: Implement dual-path booking acceptance state machine supporting instant booking when all six confirmed eligibility conditions pass (`FND-CONF-14`) and manual dealer approval otherwise (`FND-CONF-08`).
- **Files**: `car_rental_backend/src/bookings/bookings.service.ts`, `apps/vendor_app/lib/features/bookings/`, `apps/customer_app/lib/features/checkout/`.
- **Dependencies**: None.
- **DoD**: Instant booking creates `CONFIRMED` booking immediately upon payment capture when all 6 conditions pass (Dealer ACTIVE, Car VERIFIED & ACTIVE, full trip available, pricing configured, instant enabled, zero holds); manual pathway creates `AWAITING_DEALER_ACCEPTANCE` with dealer accept/reject endpoints; manual response handling preserved; exact dealer response SLA duration remains pending operational definition (`FND-UNRES-01`); Admin controls eligibility policies without arbitrary numeric thresholds.

### [TASK-P1-06] Customer & Dealer Cancellation and Refund Policy Engine (Rental Fare Only)
- **Objective**: Implement approved 7-tier cancellation refund schedule applied strictly to rental fare only (`FND-CONF-12`), pre-acceptance cancellation priority over all time tiers (`FND-CONF-13`), distinct customer vs dealer cancellation workflows (dealer cancellation provides 100% rental fare refund; non-rental-fare components distinguished for founder/CA review; deposits decoupled), delivery fee parameterization in cancellation refund base (`FND-UNRES-02`), immutable cancellation policy snapshots on `Booking`, and 100% decoupled refundable security deposits (`FND-CONF-09`).
- **Files**: `car_rental_backend/src/bookings/`, `car_rental_backend/src/payments/`, `apps/customer_app/lib/features/my_bookings/`.
- **Dependencies**: None.
- **DoD**: Automated refund worker computes refund on rental fare only (`rentalFare * refundPercentage`); pre-acceptance cancellation guarantees 100% rental fare refund overriding all time tiers; platform fee and additional services are excluded; deposit governed separately by active deposit policy (subject to deferred CA/legal review); dealer cancellation issues 100% refund of rental fare (platform fee and additional services distinguished for review; deposit governed separately by deposit policy); parameterize delivery fee treatment (`FND-UNRES-02`); immutable snapshot stored on booking.

### [TASK-P1-07] Phased Multi-City Telangana Serviceability & City Onboarding
- **Objective**: Extend location search, dealer yard dispatch, and serviceability filters to support the approved 3-phase rollout across Telangana: Phase 1: Hyderabad; Phase 2: Karimnagar & Warangal; Phase 3: Nizamabad & Khammam (`FND-CONF-10`, `FND-CONF-15`).
- **Files**: `car_rental_backend/src/pickup-hubs/`, `apps/admin_panel/lib/features/locations/`, `apps/customer_app/lib/features/search/`.
- **Dependencies**: None (Phased roster confirmed in `FND-CONF-15`).
- **DoD**: Admin can onboard and service the approved Telangana cities sequentially across Phase 1, Phase 2, and Phase 3; customer search filters vehicles by active Telangana cities; yard dispatch respects regional hubs; zero unapproved cities added.

---

## 4. Priority 2 — Finance and Governance

### [TASK-P2-01] Admin-Configurable Security Deposit Policy Engine (Global + Dealer Overrides)
- **Objective**: Implement versioned `DepositPolicyConfig` and `VendorDepositPolicyOverride` models with field-level inheritance, quote TTL/revalidation gates, and immutable `depositPolicySnapshot` on `Booking` (see [DRIVEGO_SECURITY_DEPOSIT_CONFIG_SPEC.md](file:///D:/Flutter/car_rental_monorepo/docs/product/DRIVEGO_SECURITY_DEPOSIT_CONFIG_SPEC.md)).
- **Files**: `car_rental_backend/prisma/schema.prisma`, `car_rental_backend/src/deposits/`, `apps/admin_panel/lib/features/deposits/`.
- **Dependencies**: None.
- **DoD**: Admin can configure global default policy and dealer-specific overrides with field-level inheritance; booking confirms with immutable `depositPolicySnapshot`; historical bookings and settled refunds remain untouched.

### [TASK-P2-02] Admin-Configurable Commission Engine & Negotiated Dealer Agreements
- **Objective**: Implement versioned `CommissionPolicyConfig`, `DealerNegotiatedCommissionAgreement`, and 4-tier precedence resolution engine with agreement evidence tracking and maker-checker approval (see [DRIVEGO_COMMISSION_CONFIG_SPEC.md](file:///D:/Flutter/car_rental_monorepo/docs/product/DRIVEGO_COMMISSION_CONFIG_SPEC.md)).
- **Files**: `car_rental_backend/prisma/schema.prisma`, `car_rental_backend/src/admin/admin-commission.controller.ts`, `car_rental_backend/src/finance/`, `apps/admin_panel/lib/features/commission/`.
- **Dependencies**: None.
- **DoD**: Admin can set global commission, volume tiers, and negotiate dealer-specific agreements taking Tier 1 precedence; contract PDF URLs and acknowledgement timestamps tracked; immutable commission snapshot stored on `Booking.priceSnapshot`.

### [TASK-P2-03] Admin Maker-Checker Dispute Adjudication
- **Objective**: Enforce secondary supervisor approval for damage deductions exceeding ₹10,000.
- **Files**: `apps/admin_panel/lib/features/disputes/`, `car_rental_backend/src/disputes/`.
- **Dependencies**: None.
- **DoD**: High-value damage deductions require two separate admin signatures before debiting the holding ledger.

---

## 5. Priority 3 — Reliability and Operational Maturity

### [TASK-P3-01] Multi-User Dealer Staff Architecture (`VendorStaff`)
- **Objective**: Introduce `VendorStaff` join table and staff invitation UI in Partner App.
- **Files**: `car_rental_backend/prisma/schema.prisma`, `car_rental_backend/src/vendors/`, `apps/vendor_app/`.
- **Dependencies**: TASK-P0-01.
- **DoD**: Dealer owner can invite yard staff and fleet managers with scoped permissions; tenant isolation strictly verified.

### [TASK-P3-02] Admin Control Tower 7-Cluster Navigation Consolidation
- **Objective**: Restructure `admin_shell.dart` and `app_router.dart` into the 7 operational clusters without breaking existing sub-views.
- **Files**: `apps/admin_panel/lib/core/widgets/admin_shell.dart`, `apps/admin_panel/lib/core/router/app_router.dart`.
- **Dependencies**: None.
- **DoD**: All 7 clusters navigate cleanly; widget tests pass 100%.

### [TASK-P3-03] Admin RFC 6238 TOTP MFA Hardening
- **Objective**: Implement Google Authenticator TOTP challenge for `SUPER_ADMIN` with emergency recovery codes.
- **Files**: `car_rental_backend/src/auth/`, `apps/admin_panel/lib/features/auth/`.
- **Dependencies**: None.
- **DoD**: Admin logins require valid 6-digit TOTP; backup codes enable owner recovery without lockout risk.

---

## 6. Priority 4 — Growth and Expansion

### [TASK-P4-01] Partner Performance Scorecards & Automated Tier Upgrades
- **Objective**: Automate tier progression based on monthly trip counts and ratings.
- **Dependencies**: P2-02.

### [TASK-P4-02] Peer-to-Peer (P2P) Private Host Exploration
- **Status**: **STRICTLY DEFERRED**. Zero engineering allocation in active sprints.

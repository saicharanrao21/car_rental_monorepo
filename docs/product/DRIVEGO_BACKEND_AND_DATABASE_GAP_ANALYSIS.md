# DriveGo — Backend & Database Gap Analysis (Dealer & Financial Policy Architecture)

**Document Reference**: `docs/product/DRIVEGO_BACKEND_AND_DATABASE_GAP_ANALYSIS.md`  
**Classification**: Authoritative Database & Technical Architecture  
**Effective Date**: November 9, 2026  
**Author**: Chief Technology Officer, Principal NestJS Architect & PostgreSQL Specialist  
**Repository**: `https://github.com/saicharanrao21/car_rental_monorepo`  
**Target Codebase**: `car_rental_backend/prisma/schema.prisma`  
**Git Baseline Commit**: `b87cfe90527c801172529290b96f3d7c0200b941` (Branch: `main`)  
**Status**: APPROVED RECONCILED GAP & SECURITY ANALYSIS — IMPLEMENTATION STATUS: PENDING EXPLICIT FOUNDER APPROVAL  

---

## 1. Executive Summary & Safety Directive

This document provides a line-by-line audit of the existing Prisma schema (`car_rental_backend/prisma/schema.prisma`), NestJS service layers, and REST API controllers against the founder-confirmed **Dealer-Only**, **Dealer-Owned Fleet**, and **Configurable Financial Policies (Global + Dealer-Specific Overrides)**.

> [!CAUTION]
> **Strict Execution Boundaries & Implementation Authorization Control**: No application code or Prisma schemas have been modified, and zero database migrations have been executed. **NO IMPLEMENTATION AUTHORIZATION HAS BEEN GRANTED**. This document establishes technical ground truth and defines architectural specifications. Implementation remains strictly `PENDING EXPLICIT FOUNDER APPROVAL`.

---

## 2. Answers to the 12 Mandatory Architecture & Security Verification Questions

| # | Mandatory Verification Question | Verified Code Finding | Source Code Evidence Reference |
| :-: | :--- | :--- | :--- |
| **1** | **Can a dealer create a vehicle through a direct API call without approval?** | **NO.** While a dealer can invoke `POST /api/v1/cars`, the backend forcibly sets `isAvailable = false`, `operationalStatus = DRAFT`, and `verificationStatus = PENDING`. It cannot be activated without Admin approval. | [`cars.service.ts#L922-L925`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/cars/cars.service.ts#L922-L925) |
| **2** | **Can an unapproved vehicle appear in customer search?** | **NO.** `searchCars()` strictly enforces: `where.isAvailable = true`, `where.operationalStatus = ACTIVE`, `where.verificationStatus = VERIFIED`, and `where.vendor.verificationStatus = VERIFIED` for non-admin callers. | [`cars.service.ts#L162-L170`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/cars/cars.service.ts#L162-L170) |
| **3** | **Can a suspended partner receive new bookings?** | **NO.** `createBooking()` validates: `if (car.vendor?.verificationStatus !== VerificationStatus.VERIFIED)` and throws `BadRequestException('Cannot book a vehicle from an unverified vendor.')`. | [`bookings.service.ts#L149-L153`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/bookings/bookings.service.ts#L149-L153) |
| **4** | **Can a dealer access another dealer's vehicle, booking, or financial policy?** | **NO.** Vehicle mutations invoke `verifyOwnership()` (`car.vendorId !== vendor.id` throws HTTP 403). Booking detail checks `booking.vendor.userId === requestingUser.userId`. List bookings filters strictly by `vendorId`. Negotiated financial agreements are strictly scoped to the calling session's `vendorId`. | [`cars.service.ts#L43-L60`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/cars/cars.service.ts#L43-L60), [`bookings.service.ts#L798-L808`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/bookings/bookings.service.ts#L798-L808) |
| **5** | **Can two customers book the same vehicle for overlapping periods?** | **NO.** Three concurrency layers prevent double bookings: (1) Redis distributed lock `bookingLockService.acquireLock(carId)`; (2) PostgreSQL row-level pessimistic lock `SELECT ... FOR UPDATE`; (3) Overlapping booking/block/hold check. | [`bookings.service.ts#L117`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/bookings/bookings.service.ts#L117), [`bookings.service.ts#L488-L511`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/bookings/bookings.service.ts#L488-L511) |
| **6** | **Can an admin or dealer change deposit policy without authorization?** | **NO.** All policy mutations are guarded by `@UseGuards(JwtAuthGuard, RolesGuard)` requiring `Role.ADMIN`. Dealers have zero write permissions. Booking-level snapshots ensure existing bookings are untouched. | [`admin-commission.controller.ts#L20-L22`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/admin/admin-commission.controller.ts#L20-L22) |
| **7** | **Can an admin change commission without an audit record?** | **NO.** Commission mutation endpoints explicitly call `AuditLogService.log(...)` recording the admin ID, action, target entity, timestamp, and change delta. | [`admin-commission.controller.ts#L84-L90`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/admin/admin-commission.controller.ts#L84-L90) |
| **8** | **Do historical bookings preserve their original financial calculations?** | **YES.** Every `Booking` row stores an immutable record of `baseFare`, `platformFee`, `gstAmount`, `totalFare`, `netToVendor`, and a full JSON `priceSnapshot`. Global or dealer-specific policy mutations never alter historical records. | [`bookings.service.ts#L575-L594`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/bookings/bookings.service.ts#L575-L594) |
| **9** | **Are document uploads protected against unauthorized access?** | **YES.** Documents (KYC, commercial RC, licenses, damage inspection photos) reside in private Cloudflare R2 / S3 storage and are accessed exclusively through short-lived (15-minute / 900-second) pre-signed download URLs. | [`inspections.service.ts#L189`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/bookings/inspections.service.ts#L189), [`uploads.service.ts#L60-L70`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/uploads/uploads.service.ts#L60-L70) |
| **10** | **Are payment webhooks cryptographically verified?** | **YES.** Razorpay webhooks are validated via `Razorpay.validateWebhookSignature()`. Cashfree and Stripe use HMAC SHA256 verification. Mock signatures are strictly prohibited in production (`NODE_ENV === 'production'`). | [`payments.service.ts#L77-L80`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/payments/payments.service.ts#L77-L80), [`payments.service.ts#L920-L950`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/payments/payments.service.ts#L920-L950) |
| **11** | **Are mocked integrations clearly identified?** | **YES.** `RAZORPAY_USE_MOCK`, `R2_USE_MOCK`, `SMS_USE_MOCK` flags exist across backend services. Server startup crashes with a `CRITICAL SECURITY CONFIGURATION ERROR` if any mock is enabled when `NODE_ENV === 'production'`. | [`payments.service.ts#L77-L80`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/payments/payments.service.ts#L77-L80), [`uploads.service.ts#L31-L34`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/uploads/uploads.service.ts#L31-L34) |
| **12** | **Are sensitive financial operations idempotent?** | **YES.** Double-entry ledger journals require unique `idempotencyKey` (e.g. `jrn_dep_rel_${deposit.id}`). Deposit releases use atomic SQL transitions (`status: HELD` check) to prevent concurrent double-refunds. | [`deposits.service.ts#L210-L225`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/deposits/deposits.service.ts#L210-L225), [`deposits.service.ts#L278`](file:///D:/Flutter/car_rental_monorepo/car_rental_backend/src/deposits/deposits.service.ts#L278) |

---

## 3. Legacy Collateral Code Audit & Trace Analysis

An exhaustive trace across the monorepo identified all references to `COLLATERAL:`:

### 3.1 Trace Findings
1. **Creation Point**: `car_rental_backend/src/deposits/deposits.service.ts` line 579 inside `recordCollateral()`:
   ```ts
   razorpayPaymentId: `COLLATERAL:${dto.collateralType}:${Date.now()}`
   ```
2. **Storage Location**: Stored as a pseudo-string in `SecurityDeposit.razorpayPaymentId`.
3. **Read Points**: `deposits.service.ts` line 227 (`if (!isCollateral)`), line 320, line 607, line 656.
4. **API Endpoints**: `POST /api/v1/deposits/bookings/:bookingId/collateral` and `GET /api/v1/deposits/bookings/:bookingId/collateral` in `deposits.controller.ts`.
5. **Database Records**: Executed database query confirms **exactly 0 records** with `COLLATERAL:` exist in PostgreSQL.
6. **Flutter Client Applications & Shared Models**: Comprehensive scan revealed references to collateral in:
   - `apps/vendor_app/.../handover_inspection_page.dart` (36 occurrences): Tri-option collateral selector UI.
   - `apps/customer_app/.../booking_detail_deposit_card.dart` (14 occurrences): Collateral type status chip.
   - `packages/models/.../security_deposit_model.dart` (32 occurrences): `CollateralType` enum and fields.
7. **Test Coverage**: Tested in `deposits.spec.ts` lines 285–440, `security_deposit_card_test.dart`, and `deposit_and_damage_claim_test.dart`.

### 3.2 Safe Deprecation Plan (Sprint 1)
- DriveGo operates exclusively with digital KYC and monetary security deposit holding.
- Remove tri-option selector from `handover_inspection_page.dart`; enforce monetary online deposit verification only.
- Deprecate `recordCollateral` controller route (return HTTP 410 Gone).
- Remove line 227 bypass check (`isCollateral`) so all deposit releases invoke payment gateway refunds.
- Zero database migration or data remediation required since 0 database records exist.

---

## 4. Gap-by-Gap Mapping: Existing Implementation vs Proposed Design

### 4.1 Gap 1: Business Entity Classification (`enum BusinessType`)
- **Current State**: `schema.prisma` lines 18–21 supports only `INDIVIDUAL` and `CONSULTANCY`.
- **Proposed Design**: Expand to commercial rental business types: `PROPRIETORSHIP`, `PARTNERSHIP`, `LLP`, `PRIVATE_LIMITED`, `PUBLIC_LIMITED`.
- **Migration**: Non-destructive enum expansion: `ALTER TYPE "BusinessType" ADD VALUE ...`.

### 4.2 Gap 2: Statutory Compliance Documents (`enum DocumentType`)
- **Current State**: `schema.prisma` lines 34–38 contains only `RC_BOOK`, `TRADE_LICENSE`, `INSURANCE`.
- **Proposed Design**: Add commercial compliance documents: `FITNESS_CERTIFICATE`, `POLLUTION_UNDER_CONTROL`, `COMMERCIAL_PERMIT`, `GST_CERTIFICATE`, `BANK_CANCELLED_CHEQUE`, `RENT_A_CAB_LICENSE`.

### 4.3 Gap 3: Multi-User Dealer Staff Model (`VendorStaff`)
- **Current State**: Unique 1-to-1 relation (`Vendor.userId`). Multi-user dealer delegation is impossible.
- **Proposed Design**: Introduce `VendorStaff` join model linking multiple users to one dealer organization with roles: `DEALER_OWNER`, `DEALER_ADMIN`, `FLEET_MANAGER`, `OPERATIONS_STAFF`, `FINANCE_STAFF`.

### 4.4 Gap 4: Commission Configuration Architecture Gap & Service Unification
- **Current State**:
  - `CommissionConfig` (`schema.prisma` lines 1047–1057): Mutable table with `city`, `carCategory`, `tripType`, `percentage`, `effectiveFrom`. Has no `vendorId`, no versioning, no approval status, no maker-checker, and no audit log relation.
  - `CommissionResolverService` (`commission-resolver.service.ts` lines 13–75): Resolves city/category/tripType specificity scores, falling back to 10% constant or `SystemConfigService`. Does not accept `vendorId`.
  - `MarketplaceCommissionService` (`marketplace-commission.service.ts` lines 50–140): Handles multilateral splits with arbitrary hardcoded defaults (15% platform, 80% vendor, 5% branch) and queries `MarketplaceCommissionRule`.
  - `AdminCommissionController` (`admin-commission.controller.ts` lines 19–100): Performs basic CRUD on mutable `CommissionConfig` without versioning or maker-checker approval.
- **Proposed Unified Architecture**:
  - **Single Authoritative Resolver (`MarketplaceCommissionEngine`)**: Replaces both legacy services. `CommissionResolverService`'s specificity scoring is absorbed into Tier 3.
  - **Elimination of Arbitrary 5% Branch Split**: DriveGo operates a commercial dealer fleet model where vehicles are 100% dealer-owned and operated from dealer yards. DriveGo does not operate branches taking a 5% split. The revenue split is strictly: $\text{Taxable Fare} = \text{Platform Fee} + \text{Net Dealer Rental Earnings}$.
  - **Fleet-Volume Tier Calculation**: Dynamic database aggregation evaluates verified dealer inventory (`where: { vendorId, verificationStatus: VERIFIED, operationalStatus: ACTIVE }`). Vehicles currently out on rental trips or in scheduled turnaround maintenance count toward active fleet capacity; only soft-deleted, retired, or draft/unapproved vehicles are excluded. Filtering by `isAvailable = true` is explicitly prohibited because it would unfairly demote dealers whose fleet is actively rented.
  - **Private Object Storage for Contract Documents**: The negotiated dealer agreement stores `agreementDocumentKey String` referencing a private Cloudflare R2 / AWS S3 object key. Storing expiring presigned URLs (`agreementDocumentUrl`) in persistent database tables is strictly prohibited. Access is granted exclusively via short-lived (15-minute) signed URLs generated on-demand by authorized Admin sessions.
  - **Audit Log Cascade Deletion Prevention**: Audit tables (`CommissionPolicyAuditLog`, `DepositPolicyAuditLog`, `VendorDepositAuditLog`) must enforce `onDelete: Restrict` in Prisma schema. Using `onDelete: Cascade` is strictly prohibited because administrative deletions of configuration records must never erase immutable compliance and financial audit trails.
  - **Controlled Error Gate**: If no approved global policy is active, the system produces `CRITICAL_CONFIGURATION_ERROR: NO_ACTIVE_COMMISSION_POLICY`, never falling back to invented constants.
  - **Unambiguous 4-Tier Precedence**: (1) Active Dealer Negotiated Agreement > (2) Fleet-Volume Tier > (3) Localized Rule > (4) Global Default. No arbitrary priority integer can override Tier 1.

### 4.5 Gap 5: Deposit Configuration Architecture Gap (Zero Business Defaults)
- **Current State**:
  - `DepositRule` (`schema.prisma` lines 1605–1617): Mutable table storing `carCategory`, `city`, `depositAmount`. Has no release window timing, no schedule types, no deduction caps, no maker-checker.
  - `VendorDepositPolicy` (`schema.prisma` lines 2386–2406): Flat table with `version`, `isRequired`, `amount`, `refundPolicy`. Lacks `vendorId` relation, field-level inheritance, release schedule types (`POST_TRIP_HOURS`, `SPLIT_TWO_STAGE`), and dispute holds.
  - `DepositRulesService` (`deposit-rules.service.ts` lines 6–13): Contains hardcoded fallback constant `DEFAULT_DEPOSIT_AMOUNTS` (Hatchback ₹3k, Sedan ₹4k, SUV ₹5k, Luxury ₹10k). Lacks dealer-specific resolution.
- **Proposed Design & Zero Business Defaults**:
  - `DepositPolicyConfig`: Versioned platform-wide default deposit policy (`version: N+1`). **Zero business defaults in database schema**: all category amounts, release schedules, and window hours must be explicitly configured and approved by Admin.
  - **Controlled Error Gate**: If no approved global deposit policy is active, backend throws `CRITICAL_CONFIGURATION_ERROR: NO_ACTIVE_DEPOSIT_POLICY`, never an invented fallback amount.
  - `VendorDepositPolicyOverride`: Dealer-specific override linked to `vendorId` with nullable fields. Non-null fields override global policy; null fields inherit directly from active global policy.
  - `DepositPolicyAuditLog` & `VendorDepositAuditLog`: Comprehensive audit trail tracking previous/new payloads, admin ID, reason, and timestamp. Enforces `onDelete: Restrict` in Prisma schema so audit history can never be wiped out.

### 4.6 Gap 6: Booking Model Snapshot Fields & Quote Lifecycle
- **Current State**:
  - `Booking` (`schema.prisma` line 874) has `priceSnapshot Json?`, `baseFare`, `platformFee`, `gstAmount`, `netToVendor`.
  - `Booking` does **NOT** have an explicit `depositPolicySnapshot Json?` column. Currently stores only `securityDeposit SecurityDeposit?` relation.
  - `BookingQuote` (`schema.prisma` lines 2240–2276) has `expiresAt DateTime`, `metadata Json?`, `depositTotal Decimal`, but lacks explicit deposit policy version references.
- **Proposed Design & Exact Snapshot Lifecycle**:
  - **15-Minute Quote TTL**: Quotes generated via `POST /api/v1/bookings/quotes` store provisional calculations in `quote.metadata` with `expiresAt = now() + 15m`. Provisional quotes are **NEVER** used directly as final booking records.
  - **Checkout Atomic Revalidation Gate**: At `POST /api/v1/bookings`, backend validates `now() <= quote.expiresAt` and checks if policy versions mutated. If terms changed, returns `HTTP 409 Conflict: POLICY_UPDATED_REQUOTE_REQUIRED` with delta.
  - **Freezing Final Snapshots**: At booking confirmation, the finalized deposit policy and price split are permanently committed to `Booking.depositPolicySnapshot Json?` and `Booking.priceSnapshot Json?`.
  - **Subsequent Immutability**: Deposit refunds and vendor payout settlements execute strictly from the booking snapshots. Subsequent policy updates never touch existing bookings.
  - **Concurrency & Webhook Idempotency**: Redis locks (`lock:booking:quote:${quoteId}`) prevent race conditions. Payment gateway webhook retries verify HMAC SHA256 and idempotently acknowledge duplicate events.

---

## 5. Security Architecture, Tenant Isolation & RBAC Controls

```mermaid
flowchart TD
    subgraph Client Layer
        CustApp["Customer App"]
        PartnerApp["Partner App (Dealer A)"]
        PartnerAppB["Partner App (Dealer B)"]
        AdminUI["Admin Control Tower"]
    end

    subgraph API Gateway & Auth Guards
        JWT["JwtAuthGuard (Passport JWT)"]
        Roles["RolesGuard (@Roles)"]
        Tenant["TenantScopingGuard (vendorId validation)"]
    end

    subgraph Backend Services
        AdminSvc["Admin Financial Config Services"]
        VendorSvc["Vendor Scoped Services"]
        BookingsSvc["Bookings & Pricing Engine"]
    end

    AdminUI --> JWT --> Roles -->|Role.ADMIN only| AdminSvc
    PartnerApp --> JWT --> Roles --> Tenant -->|Scaped to Dealer A| VendorSvc
    PartnerAppB --> JWT --> Roles --> Tenant -->|Scoped to Dealer B| VendorSvc
    CustApp --> JWT --> BookingsSvc

    Tenant -.->|Cross-tenant read/write blocked (HTTP 403)| Block[Tenant Boundary Violation]
```

1. **Cross-Dealer Isolation**: Dealer A cannot read, query, infer, or view Dealer B's deposit policy overrides, negotiated commission rates, or contract documents. Every vendor query enforces `where: { vendorId: session.vendorId }`.
2. **Dealer Mutation Prohibition**: Dealers have zero write permissions on commission or deposit policy tables (`HTTP 403 Forbidden`). Only authorized Admin roles can create, negotiate, or approve financial policies.
3. **Backend Authorization Enforcement**: All Admin endpoints enforce role validation via `@UseGuards(JwtAuthGuard, RolesGuard)` with `@Roles(Role.ADMIN)`. Frontend route guards or hidden UI elements are strictly secondary.
4. **Maker-Checker Protocol**: Authoring (`createdByAdminId`) and approving (`approvedByAdminId`) must be performed by distinct administrators for all financial policy activations.

---

## 6. Migration and Backward-Compatibility Considerations

1. **Non-Destructive Additions**: The proposed schema changes introduce new versioned tables (`DepositPolicyConfig`, `VendorDepositPolicyOverride`, `CommissionPolicyConfig`, `CommissionPolicyRule`, `DealerNegotiatedCommissionAgreement`) alongside existing tables. Existing `CommissionConfig` and `DepositRule` remain readable during Phase 1 transition.
2. **Nullable Booking Column**: Adding `depositPolicySnapshot Json?` to `Booking` is an `ALTER TABLE "Booking" ADD COLUMN "depositPolicySnapshot" JSONB` operation requiring zero downtime and zero backfill for historical completed bookings (which continue using their legacy immutable `priceSnapshot` and `SecurityDeposit` records).
3. **Zero Impact on Active Deposits**: Database query confirms 0 records with `COLLATERAL:` exist, ensuring zero risk of holding ledger corruption during transition to pure monetary gateway refunds.

---

## 7. The Five-Category Financial & Legal Boundary Classification

To maintain absolute compliance and regulatory integrity, all architectural components are partitioned across 5 explicit operational categories:

```
+---------------------------------------------------------------------------------------------------------+
|                               FIVE-CATEGORY GOVERNANCE CLASSIFICATION                                   |
+----+-----------------------------+-----------------------------------+---------------------------------+
| #  | Governance Category         | Scope & Items Included            | Technical & Operational Rule    |
+----+-----------------------------+-----------------------------------+---------------------------------+
| 1  | Confirmed Product Decisions | Dealer-only, dealer-owned (1+ car)| Hard architectural invariants;  |
|    | (Founder Invariant)         | Admin configurable deposit & comm | Zero debate or deviation.       |
|    |                             | Snapshots, 15m quote TTL, holding |                                 |
+----+-----------------------------+-----------------------------------+---------------------------------+
| 2  | Technical Design            | Double-entry ledger journals      | Engineering best-practices;     |
|    | Assumptions                 | Redis locks, PostgreSQL FOR UPDATE| Implemented by software team    |
|    |                             | Maker-checker dual control        | under CTO supervision.          |
+----+-----------------------------+-----------------------------------+---------------------------------+
| 3  | CA Written Approval         | Rental fare GST, platform GST,     | STRICTLY BLOCKED from code      |
|    | Required (Statutory Tax)    | deposit GST, forfeiture GST,       | implementation until written    |
|    |                             | Section 9(5) vs 52, Section 194-O  | CA determination is received.   |
|    |                             | (No tax exemption is assumed)     |                                 |
+----+-----------------------------+-----------------------------------+---------------------------------+
| 4  | Transport Legal Written     | Rent a Cab Scheme 1989 licensing  | Tier B pending legal counsel   |
|    | Approval Required           | Commercial plate standards, speed | confirmation; Tier A statutory  |
|    |                             | governor scope, agreement clauses | compliance enforced in audits.  |
+----+-----------------------------+-----------------------------------+---------------------------------+
| 5  | External Provider           | Razorpay live gateway credentials | System supports mock mode for   |
|    | Dependencies                | RazorpayX automated payouts       | development; crashes if mocks   |
|    |                             | Msg91 TRAI DLT SMS credentials    | are enabled in production.      |
|    |                             | Google Maps API keys with billing |                                 |
|    |                             | VAHAN vehicle verification API    |                                 |
+----+-----------------------------+-----------------------------------+---------------------------------+
```

---

## 8. Booking & Payment Transactional Safety Specifications

To ensure absolute financial and operational consistency under concurrent network conditions, edge-case failures, and payment gateway retry storms, the backend enforces rigorous transactional guarantees:

### 8.1 Webhook Idempotency & Replay Protection
1. **Signature Verification Gate**: Every inbound payment webhook (Razorpay / Cashfree / Stripe) is verified against the webhook secret using cryptographic HMAC SHA256 before any payload parsing or transaction processing.
2. **Idempotency Key & Event Deduplication**: Webhook delivery events are tracked in a dedicated `PaymentWebhookEvent` table with unique constraint on `(gateway, eventId)`. 
3. **Idempotent Acknowledgment**: If a duplicate webhook event arrives (common during network blips or gateway retries), the engine detects the existing processed record, emits an audit log entry (`DUPLICATE_WEBHOOK_RECEIVED`), and immediately returns `HTTP 200 OK` without re-executing booking confirmation, ledger entries, or notifications.

### 8.2 Atomic Concurrency & Overlapping Conflict Prevention
1. **Redis Distributed Lock**: Checkout revalidation and booking creation acquire a distributed mutex lock `lock:car:${carId}:dates:${startDate}_${endDate}` with a 10-second TTL.
2. **PostgreSQL Pessimistic Row Locking**: Inside the database transaction, the vehicle row is acquired using `SELECT id FROM "Car" WHERE id = $1 FOR UPDATE`.
3. **Overlapping Date Range Check**: An atomic query checks existing confirmed or active bookings:
   ```sql
   SELECT id FROM "Booking"
   WHERE "carId" = $1
     AND "status" NOT IN ('CANCELLED', 'REJECTED', 'EXPIRED')
     AND "startDate" < $3 AND "endDate" > $2
   FOR UPDATE;
   ```
   If any row matches, the transaction aborts with `HTTP 409 Conflict: VEHICLE_UNAVAILABLE_FOR_REQUESTED_DATES`.

### 8.3 Partial Failures, Post-Payment Compensation & Automatic Refunds
1. **Post-Payment Failure Scenario**: In edge cases where customer payment succeeds at the gateway, but downstream booking creation fails (e.g. database timeout, server restart during webhook execution):
   - The payment record is captured in `Payment` with status `CAPTURED_ORPHAN`.
   - An automated compensation job (`OrphanPaymentCompensationWorker`) detects captured payments lacking a confirmed `bookingId`.
   - The worker triggers an automated gateway refund (`Razorpay.refunds.create({ payment_id, amount, notes: { reason: 'ORPHAN_BOOKING_FAILURE' } })`).
   - A critical alert is emitted to the Admin Control Tower incident dashboard.
2. **Distributed Transaction Integrity**: Database mutations across `Booking`, `Payment`, `LedgerJournal`, and `CarHold` are wrapped in atomic `prisma.$transaction()` with `isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted` (or PostgreSQL `SERIALIZABLE` for financial balance mutations). If any step fails, the entire transaction rolls back cleanly.


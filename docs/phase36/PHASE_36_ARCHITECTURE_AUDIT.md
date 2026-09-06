# Phase 36: Architecture Audit
## Payment & Financial Transaction Integrity Engine

**Document Status:** Complete & Verified  
**Baseline Commit:** `15481ff` (Phase 35 Complete, `HEAD == origin/main`, Clean Working Tree)  
**Author:** Senior Principal Engineer / CTO  
**Date:** September 2026  

---

## 1. Executive Summary

This architecture audit establishes the empirical baseline of the DriveGo car-rental monorepo immediately prior to the execution of **Phase 36: Payment & Financial Transaction Integrity Engine**.

The DriveGo platform processes high-value automotive rental transactions comprising multi-day vehicle bookings, security deposits, protection packages, delivery/relocation surcharges, coupon discounts, wallet credits, and vendor commission disbursements. Financial operations must be mathematically deterministic, server-authoritative, auditable, and resilient to network timeouts, malicious client tampering, gateway out-of-order webhooks, and retry storms.

This audit evaluates the actual state of `car_rental_backend/`, `packages/models/`, `apps/customer_app/`, `apps/vendor_app/`, and `apps/admin_panel/`. It identifies architectural gaps and financial integrity risks, defines the canonical payment state machine, and details the non-regressive Phase 36 implementation blueprint.

---

## 2. Inventory of Existing Financial & Payment Infrastructure

### A. Database Models (`car_rental_backend/prisma/schema.prisma`)

1. **`Payment` Model (lines 988–1016)**:
   - Fields: `id`, `bookingId` (@unique), `razorpayOrderId` (@unique), `razorpayPaymentId`, `razorpayRefundId` (@unique), `amount` (Decimal 10,2), `refundAmount` (Decimal 10,2), `currency` (default "INR"), `status` (`PaymentStatus`), `refundStatus` (`RefundStatus`), `gatewayProvider` (default "RAZORPAY"), `gatewaySignature`, `capturedAt`, `failedAt`, `failureReason`, `idempotencyKey` (@unique), `createdAt`, `updatedAt`.
   - Relations: `booking` (1:1 with `Booking`), `refunds` (1:N with `PaymentRefund`).
   - Indexes: `[razorpayRefundId]`, `[razorpayOrderId]`, `[status, createdAt]`, `[bookingId, status]`, `[gatewayProvider]`, `[idempotencyKey]`.
   - **Gaps**: Missing explicit `tenantId` field for strict multi-tenant isolation, missing `gatewayAmountPaise` integer field, missing `metadata` JSON field, and missing relation to an append-only `PaymentAuditLog`.

2. **`PaymentRefund` Model (lines 1018–1041)**:
   - Fields: `id`, `paymentId`, `bookingId`, `gatewayRefundId` (@unique), `idempotencyKey` (@unique), `requestedAmount` (Decimal 10,2), `processedAmount` (Decimal 10,2), `currency` (default "INR"), `reason`, `requestedByUserId`, `status` (`RefundStatus`), `failureReason`, `metadata` (Json), `createdAt`, `updatedAt`.
   - Relations: `payment` (N:1 with `Payment`).
   - Indexes: `[paymentId]`, `[bookingId]`, `[status]`, `[idempotencyKey]`, `[gatewayRefundId]`.

3. **`WebhookEvent` Model (lines 1043–1058)**:
   - Fields: `id`, `gateway` (default "RAZORPAY"), `eventId` (@unique), `eventType`, `payload` (Json), `signature`, `status` (default "PROCESSED"), `processedAt`, `failureReason`, `createdAt`.
   - Indexes: `[gateway, eventType]`, `[eventId]`, `[createdAt]`.

4. **`ReconciliationRecord` & `ReconciliationException` Models (lines 940–986)**:
   - Models designed to capture discrepancies between internal database records and gateway external states (`MISSING_GATEWAY_RECORD`, `MISSING_INTERNAL_RECORD`, `AMOUNT_MISMATCH`, `STATUS_MISMATCH`, `DUPLICATE_GATEWAY_RECORD`).

5. **`PaymentStatus` Enum (lines 147–157)**:
   - Values: `CREATED`, `PENDING`, `AUTHORIZED`, `CAPTURED`, `PAID`, `FAILED`, `CANCELLED`, `PARTIALLY_REFUNDED`, `REFUNDED`.
   - **Gap**: Missing `EXPIRED` status for orders that timed out or bookings that lapsed before payment.

6. **`RefundStatus` Enum (lines 159–165)**:
   - Values: `NONE`, `REQUESTED`, `PENDING`, `PROCESSED`, `FAILED`.

---

### B. Backend Services & Controllers (`car_rental_backend/src/payments/`)

1. **`PaymentsController` (`payments.controller.ts`)**:
   - `POST /payments/create-order` (Guards: `JwtAuthGuard`, `RolesGuard` [Role.CUSTOMER], `RateLimiterGuard` [15 req / 60s]).
   - `POST /payments/verify` (Guards: `JwtAuthGuard`, `RolesGuard` [Role.CUSTOMER], `RateLimiterGuard` [15 req / 60s]).
   - `POST /payments/webhook` (Public, `RateLimiterGuard` [120 req / 60s], verifies `x-razorpay-signature`).
   - `GET /payments/:bookingId` (Guards: `JwtAuthGuard`, `RolesGuard` [Role.CUSTOMER, Role.ADMIN, Role.SUPPORT_AGENT]).
   - `POST /payments/:bookingId/refund` (Guards: `JwtAuthGuard`, `RolesGuard` [Role.ADMIN]).
   - **Gap**: No sanitized endpoint for `Role.VENDOR` to inspect the payment status, gateway gross, net vendor payable, and refund deduction for bookings on their own fleet.

2. **`PaymentsService` (`payments.service.ts`)**:
   - `createOrder`: Validates customer booking ownership, checks booking status (`PENDING`), verifies authoritative quote price snapshot (Phase 35 invariant), calculates wallet split deduction, generates Razorpay order (or wallet mock), and persists `Payment` in `CREATED` status.
   - `verifyPayment`: Verifies Razorpay HMAC signature (`validatePaymentVerification`), cross-checks payment entity on Razorpay API, debits wallet balance if split checkout was requested, transitions `Payment` to `PAID`, updates `SecurityDeposit` to `HELD`, increments coupon usage, and triggers invoice generation.
   - `handleWebhook`: Validates HMAC webhook signature using `Razorpay.validateWebhookSignature`, deduplicates against `WebhookEvent` table, handles `payment.captured`, `order.paid`, `payment.failed`, `refund.created`, `refund.processed`, `refund.failed`.
   - `refund`: Allocates refund across Gateway and Wallet (gateway first, remainder to wallet), calls Razorpay refund API with idempotency key, tracks status in `PaymentRefund`, updates `Payment` refund status.
   - `adminRefund`: Administrative manual override with role check and audit logging via `AuditLogService`.

3. **`FinancialReconciliationService` (`reconciliation.service.ts`)**:
   - Distributed Redis-locked cron job running every 15 minutes (`lock:reconciliation:cron`).
   - Rule 1: Orphaned refund recovery.
   - Rule 2: Unconfirmed paid bookings.
   - Rule 3: Stale payment orders.
   - Rule 4: Financial state inconsistencies.
   - Rule 5: Wallet ledger integrity reconciliation.

---

### C. Frontend Architecture

1. **Customer App (`apps/customer_app/`)**:
   - `PaymentFlowService`: Encapsulates `getOrCreatePaymentOrder`, `launchRazorpayCheckout`, `verifyPayment`, and `pollBookingConfirmation`.
   - `BookingDetailPage`: Listens to Razorpay checkout events (`EVENT_PAYMENT_SUCCESS`, `EVENT_PAYMENT_ERROR`, `EVENT_EXTERNAL_WALLET`), calls `verifyPayment`, and refetches authoritative booking state.
   - `BookingDetailPricingCard`: Displays payment status badge (`PAID`, `PENDING`, `REFUNDED`, etc.).
   - `BookingRefundTrackerCard`: Displays refund breakdown and progress when booking is cancelled.

2. **Vendor App (`apps/vendor_app/`)**:
   - `EarningsPage`: Renders earnings overview, 30-day daily earnings bar chart, and completed booking earnings list (`netToVendor`).
   - `VendorNotificationsPage`: Renders notifications under `PAYMENT` and `PAYOUT` categories.
   - **Gap**: Vendor lacks a dedicated view to inspect booking payment status, gateway settlement status, and refund deductions directly linked to their active and completed bookings.

3. **Admin Panel (`apps/admin_panel/`)**:
   - `AdminBookingManagementPage`: Contains full payment inspection card showing `razorpayOrderId`, `razorpayPaymentId`, `amount`, `status`, `refunds` list, and `_showRefundDialog` for authoritative admin refunds with idempotency keys.
   - `RevenueReportsPage`: Authoritative platform revenue metrics and financial reconciliation breakdown.

4. **Shared Models (`packages/models/`)**:
   - `PaymentOrderModel`: Strongly typed model handling amounts, paise conversion, wallet deductions, refund statuses, and JSON serialization.
   - `PaymentRefundModel`: Strongly typed representation of individual refund attempts.
   - **Gap**: Missing `PaymentAuditLogModel` for recording and rendering fine-grained financial audit trail entries.

---

## 3. Financial Integrity Risks & Architectural Deficiencies Discovered

| # | Severity | Finding / Risk | Architectural Cause | Phase 36 Resolution |
|---|---|---|---|---|
| 1 | **CRITICAL** | **Destructive Deletion of Existing Payment Orders** | In `payments.service.ts` (lines 135–138), when a customer retries a payment for a booking with an existing `CREATED` or `FAILED` payment, the code executes `prisma.payment.delete({ where: { id: existingPayment.id } })`. Deleting rows destroys historical gateway order IDs, audit trails, and causes foreign key cascades on refunds/audit logs. | **Eliminate `payment.delete` completely.** If an existing payment is in `CREATED`, `FAILED`, or `EXPIRED` status, update the existing record or reuse the active gateway order if parameters match; log a state transition event to `PaymentAuditLog`. |
| 2 | **HIGH** | **Missing Append-Only Payment Audit Ledger** | State transitions (e.g. `CREATED -> AUTHORIZED -> PAID -> REFUND_PENDING -> REFUNDED`) only overwrite the `Payment.status` column. Historical transitions, transition actors (customer vs admin vs webhook vs cron), event sources, and verification payload hashes cannot be reconstructed. | **Introduce `PaymentAuditLog` table** in Prisma schema with `[paymentId, bookingId, tenantId, eventType, fromStatus, toStatus, amount, gatewayReference, actorId, actorRole, source, payloadHash, metadata, createdAt]`. |
| 3 | **HIGH** | **Missing `EXPIRED` Payment State** | When a quote or booking expires or payment order times out (>30 min), `PaymentStatus` has no `EXPIRED` enum value. Payment records remain indefinitely in `CREATED`, leading to ambiguous stale states. | **Add `EXPIRED` to `PaymentStatus` enum**; harden reconciliation rule 3 to transition stale `CREATED` payments to `EXPIRED` with audit logging. |
| 4 | **MEDIUM** | **Vendor Financial Authorization Gap & Information Exposure** | `GET /payments/:bookingId` is restricted to `CUSTOMER`, `ADMIN`, `SUPPORT_AGENT`. Vendors cannot view payment verification for their vehicles' bookings. If the endpoint were opened to vendors without filtering, vendors would see customer payment secrets. | **Add `GET /payments/vendor/:bookingId`** with vendor ownership verification (`booking.vendorId === vendor.id`), returning a sanitized `VendorPaymentDto` (net vendor earnings, payment confirmation status, gateway provider, refund deduction; omitting customer payment IDs, signatures, or wallet internals). |
| 5 | **MEDIUM** | **Absence of Multi-Tenant Isolation on Payments & Refunds** | `Payment` and `PaymentRefund` models do not have explicit `tenantId` fields with database indexes. Multi-tenant queries rely solely on booking relations. | **Add `tenantId String @default("default")`** to `Payment`, `PaymentRefund`, and `PaymentAuditLog` with explicit compound indexes `@@index([tenantId, status])`. |
| 6 | **MEDIUM** | **Out-of-Order Webhook Protection Incomplete** | Webhook processing for `refund.processed` assumes `refund.created` arrived first. If `refund.processed` arrives before `refund.created`, `refundStatus` is set to `PROCESSED`, but subsequent arrival of `refund.created` could downgrade it to `PENDING`. | **Enforce non-regressive state transitions**: reject any transition that attempts to downgrade `PROCESSED` -> `PENDING` or `PAID` -> `CREATED`. |
| 7 | **LOW** | **Missing Strongly Typed Frontend Audit Models** | `packages/models` lacks `PaymentAuditLogModel`, requiring frontend admin or vendor views to inspect unstructured maps. | **Export `PaymentAuditLogModel`** and updated `PaymentStatus` enum in `packages/models`. |

---

## 4. Canonical Payment State Machine

The DriveGo payment engine implements a deterministic, finite state machine governed by the following server-authoritative rules:

```
                  [INITIATE CHECKOUT]
                           │
                           ▼
                      ┌─────────┐
         ┌───────────│ CREATED │───────────┐
         │            └─────────┘           │
         │ (Razorpay       │ (Timeout /     │ (Customer Cancel /
         │  Order Exp)     │  Quote Exp)    │  Aborted Flow)
         ▼                 ▼                ▼
    ┌─────────┐      ┌─────────┐      ┌───────────┐
    │ FAILED  │      │ EXPIRED │      │ CANCELLED │
    └─────────┘      └─────────┘      └───────────┘
         │                 │
         │ (Retry Checkout)│ (Re-quote)
         └───────┬─────────┘
                 ▼
          [NEW ORDER]
                 │
                 ▼ (Gateway Authorized)
          ┌────────────┐
          │ AUTHORIZED │
          └────────────┘
                 │
                 ▼ (HMAC Verification / Webhook Capture)
          ┌─────────────┐
          │ PAID        │ ◄──────────────────────┐
          │ (CAPTURED)  │                        │
          └─────────────┘                        │
                 │                               │ (Gateway Refund Failed)
                 ▼ (Refund Requested)            │
        ┌──────────────────┐                     │
        │  REFUND_PENDING  │─────────────────────┘
        └──────────────────┘
           │             │
           │ (Partial)   │ (Full)
           ▼             ▼
    ┌──────────────┐ ┌──────────┐
    │  PARTIALLY_  │ │ REFUNDED │
    │   REFUNDED   │ └──────────┘
    └──────────────┘
```

### Allowed Transitions Matrix

| Current State | Allowed Next States | Trigger / Actor | Rejection Conditions |
|---|---|---|---|
| `CREATED` | `AUTHORIZED`, `PAID`, `FAILED`, `CANCELLED`, `EXPIRED` | Customer / Webhook / Gateway / Cron | Cannot transition to `REFUNDED`, `PARTIALLY_REFUNDED`, `REFUND_PENDING` |
| `AUTHORIZED` | `PAID`, `FAILED`, `CANCELLED`, `EXPIRED` | Gateway Capture / Webhook / Gateway Void | Cannot transition directly to `REFUNDED` |
| `PAID` | `PARTIALLY_REFUNDED`, `REFUNDED` | Admin Refund / Cancellation Engine / Webhook | Cannot transition to `CREATED`, `AUTHORIZED`, `FAILED`, `EXPIRED`, `CANCELLED` |
| `FAILED` | `CREATED` (via new order attempt) | Customer Retry | Cannot transition to `PAID` without fresh gateway order |
| `EXPIRED` | `CREATED` (via new quote & order) | Customer Re-quote | Terminal; cannot mutate in-place |
| `CANCELLED` | `CREATED` (via new booking) | Customer | Terminal; cannot mutate in-place |
| `PARTIALLY_REFUNDED` | `REFUNDED`, `PARTIALLY_REFUNDED` (further partials) | Admin / Webhook | Cannot transition to `PAID` or `CREATED` |
| `REFUNDED` | *None (Terminal)* | None | Immutable terminal state |

---

## 5. What Can Be Reused vs What Must Be Changed

### A. Reused Without Modification
- **Phase 35 Quote & Price Snapshot Invariant**: `booking.quoteId`, `booking.priceSnapshot`, and authoritative quote price verification in `PaymentsService.createOrder` (`Math.abs(quoteTotal - totalAmount) < 0.05`).
- **Phase 34 Vehicle Availability & Locking**: Reservation intervals and distributed locks.
- **Phase 23A Owner Confirmation Gate**: Payment transitions payment to `PAID`, booking remains in `PENDING` awaiting host approval.
- **Cryptographic Signature Utilities**: `Razorpay.validateWebhookSignature` and `validatePaymentVerification`.
- **Distributed Redis Cron Lock**: `FinancialReconciliationService` Lua evaluation and distributed mutex.

### B. Must Be Modified & Hardened
- **`car_rental_backend/prisma/schema.prisma`**:
  - Add `EXPIRED` to `PaymentStatus` enum.
  - Add `tenantId`, `gatewayAmountPaise`, `metadata` to `model Payment`.
  - Add `tenantId` to `model PaymentRefund`.
  - Add new model `PaymentAuditLog`.
- **`car_rental_backend/src/payments/payments.service.ts`**:
  - **Remove `this.prisma.payment.delete`**. Update existing row or update status to `CANCELLED`/`EXPIRED`.
  - Integrate `PaymentAuditLog` record creation on all state changes (`ORDER_CREATED`, `PAYMENT_VERIFIED`, `PAYMENT_CAPTURED`, `PAYMENT_FAILED`, `REFUND_INITIATED`, `REFUND_PROCESSED`).
  - Add state machine transition validator (`assertValidTransition(from, to)`).
  - Add vendor-safe payment details resolver (`getVendorPaymentByBookingId`).
- **`car_rental_backend/src/payments/payments.controller.ts`**:
  - Add `GET /payments/vendor/:bookingId` for `Role.VENDOR`.
- **`car_rental_backend/src/payments/reconciliation.service.ts`**:
  - Update Rule 3 (stale payment orders) to transition timed-out `CREATED` payments to `EXPIRED` with audit logging.
- **`packages/models/`**:
  - Add `PaymentAuditLogModel`.
  - Update `PaymentStatus` enum and `PaymentOrderModel`.
- **Apps**:
  - Customer app: Add pending payment recovery / polling state tests.
  - Vendor app: Verify earnings view reflects server-authoritative payment deductions.
  - Admin panel: Enhance governance view to display payment audit logs and reconciliation exceptions.

---

## 6. Exact Implementation Plan

1. **Step 1: Schema & Migration**
   - Update `car_rental_backend/prisma/schema.prisma`.
   - Execute `npx prisma validate` and `npx prisma generate`.
2. **Step 2: Backend Core Services Hardening**
   - Implement `assertValidTransition` in `PaymentsService`.
   - Refactor `createOrder` to eliminate `payment.delete` and log `ORDER_CREATED` audit entry.
   - Harden `verifyPayment` and `handleWebhook` with non-regressive state checks and `PaymentAuditLog` persistence.
   - Implement `getVendorPaymentByBookingId` and register endpoint in `PaymentsController`.
   - Update `FinancialReconciliationService` with `EXPIRED` transitions and audit logging.
3. **Step 3: Shared Models Update**
   - Add `PaymentAuditLogModel` in `packages/models/lib/src/payment_order_model.dart`.
   - Export models and verify serialization.
4. **Step 4: Frontend Alignment & Verification**
   - Ensure customer checkout, vendor earnings, and admin governance views correctly handle all canonical payment states (`EXPIRED`, `PARTIALLY_REFUNDED`, etc.).
5. **Step 5: Comprehensive Automated Testing**
   - Write `car_rental_backend/src/payments/phase36-payment-integrity.spec.ts` covering orders, webhooks, state machine, refunds, reconciliation, security.
   - Add Flutter unit and widget tests in customer, vendor, and admin apps.
6. **Step 6: Static Analysis & Builds**
   - Run `flutter analyze packages/models apps/customer_app apps/vendor_app apps/admin_panel` (0 issues).
   - Build Customer APK, Vendor APK, Admin Web.
   - Run `npx tsc --noEmit` and all backend tests.
7. **Step 7: Documentation, Evidence & Final Git Checkpoint**
   - Produce all required Phase 36 docs and evidence screenshots.
   - Stage, commit, push to `origin/main`, and confirm clean working tree.

# Phase 30: Payment Gateway Webhook Reconciliation, Escrow Security & Idempotent Refunds Architecture Audit

**Author**: Senior Backend Architect, Principal Flutter Engineer & Payment Security Lead
**Date**: 2026-09-04
**Monorepo**: DriveGo (`saicharanrao21/car_rental_monorepo`)
**Scope**: Full Stack — NestJS/Prisma Backend, PostgreSQL Schema, Customer App, Vendor App, Admin Control Tower, and Shared Models.

---

## 1. Existing Payment Architecture

The payment architecture in DriveGo is centered around the NestJS `PaymentsModule` (`car_rental_backend/src/payments/`), interacting with:
- **Prisma Schema**: `Payment` model linked 1:1 with `Booking`, `Payout` linked to `Vendor`, `FinancialAdjustment` for accounting overrides, `ReconciliationRecord` / `ReconciliationException` for batch integrity checks, `SecurityDeposit` for refundable deposits, and `Wallet` / `WalletLedgerEntry` for split-tender payments.
- **Gateway Abstraction**: Primary gateway integration is Razorpay via official Node SDK (`razorpay`), with mock fallback enabled in non-production environments when `RAZORPAY_USE_MOCK=true`.
- **Controllers & Services**:
  - `PaymentsController`: Exposes `POST /payments/create-order`, `POST /payments/verify`, `POST /payments/webhook`, and `GET /payments/:bookingId`.
  - `PaymentsService`: Handles server-side order generation, cryptographic signature validation, wallet debit settlement, webhook handling, and refund orchestration.
  - `FinancialReconciliationService`: Runs scheduled cron checks (every 15 min with Redis distributed lock) to identify and heal transaction discrepancies between gateway state and database state.
  - `PayoutsService`: Calculates vendor earnings, enforces hold periods (`settlementHoldDays: 2`), and processes payouts via Manual, RazorpayX, or Cashfree.

---

## 2. Existing Payment Lifecycle

```
[Customer Checkout]
       │
       ▼
POST /payments/create-order
       │  (Server validates booking, applies wallet balance, calculates amount in paise)
       ▼
Payment row created: status = CREATED, razorpayOrderId = order_xxx
       │
       ▼
[Razorpay Checkout Sheet on Client]
       │
  ┌────┴──────────────────────────────┐
  ▼                                   ▼
Payment Succeeded                   Payment Failed
  │                                   │
  ├──────────────────────┐            ▼
  ▼                      ▼          Client callback / webhook
POST /payments/verify   Webhook     Payment row: status = FAILED
(Client callback)       (Async)
  │                      │
  └──────────┬───────────┘
             ▼
Cryptographic HMAC-SHA256 verification
             │
             ▼
Payment row: status = PAID, razorpayPaymentId = pay_xxx
Booking remains PENDING (or awaits Vendor Confirmation to transition to CONFIRMED)
```

---

## 3. Current Booking ↔ Payment Relationships

- In `schema.prisma`, `Booking` has a 1:1 relation to `Payment` (`payment Payment?` on `Booking`, `bookingId String @unique` on `Payment`).
- **Booking Status Gate**: In `BookingsService.updateStatus`, transitioning a booking to `CONFIRMED` requires `payment && payment.status === PaymentStatus.PAID`. Non-admins cannot confirm an unpaid booking.
- **Lifecycle Separation**: Payment status (`PaymentStatus`: `CREATED`, `PAID`, `FAILED`, `REFUNDED`) and Booking status (`BookingStatus`: `PENDING`, `CONFIRMED`, `HANDOVER_READY`, `ONGOING`, `RETURN_PENDING`, `COMPLETED`, `CANCELLED`, etc.) are separated.
- **Cancellation & Refunds**: When a customer or vendor cancels a booking via `BookingsService.cancelBooking`, it fetches `payment` and invokes `PaymentsService.refund` with the policy-calculated refund amount.

---

## 4. Current Gateway Integrations

- **Razorpay**:
  - Node SDK: `new Razorpay({ key_id, key_secret })`.
  - Orders: `razorpay.orders.create({ amount, currency: 'INR', receipt: bookingId })`.
  - Verification: `validatePaymentVerification({ order_id, payment_id, signature }, key_secret)`.
  - Webhook validation: `Razorpay.validateWebhookSignature(rawBody, signature, webhookSecret)`.
  - Refunds: `razorpay.payments.refund(paymentId, { amount, speed: 'normal', notes, receipt })`.
- **Mock Mode**:
  - Guarded against production: if `RAZORPAY_USE_MOCK=true` and `NODE_ENV=production`, server throws fatal error on startup.
  - In non-production, simulates order creation (`order_mock_...`), verifies test signatures (`mock_signature`), and generates simulated refund IDs (`rfnd_mock_...`).

---

## 5. Existing Refund Behavior

- `PaymentsService.refund(bookingId, refundAmountInPaise, reason, cancellationTier)`:
  - Validates `payment.status === PaymentStatus.PAID`.
  - Rejects if `refundAmountInPaise > maxRefundPaise`.
  - Prioritizes Gateway refund (refund to source), remaining portion refunded to customer's wallet.
  - Detects if gateway returns "already refunded" error and recovers idempotently by listing refunds from Razorpay.
  - Updates `Payment` with `status = PaymentStatus.REFUNDED`, `refundStatus = RefundStatus.PROCESSED`, `refundAmount`.

---

## 6. Existing Webhook Behavior

- `POST /payments/webhook` accepts raw JSON payload and `x-razorpay-signature` header.
- Validates HMAC-SHA256 signature using `RAZORPAY_WEBHOOK_SECRET`.
- Handled events:
  - `payment.captured` / `order.paid`: Updates `Payment.status = PAID`, records `razorpayPaymentId`, notifies customer.
  - `payment.failed`: Updates `Payment.status = FAILED`.
  - `refund.processed`: Updates `Payment.refundStatus = PROCESSED`, `Payment.status = REFUNDED`.
  - `refund.created`: Updates `Payment.refundStatus = PENDING`.
  - `refund.failed`: Updates `Payment.refundStatus = FAILED`.

---

## 7. Existing Concurrency Protections

- Database transactions (`prisma.$transaction`) are used when updating payment and booking records.
- In `reconciliation.service.ts`, Redis distributed lock (`lock:reconciliation:cron` with TTL 10m) prevents concurrent scheduled reconciliation.
- `PaymentsService.verifyPayment` contains idempotency check: if already `PAID` with matching `paymentId`, returns idempotent success without duplicate processing.
- Pessimistic locking (`SELECT FOR UPDATE`) on `Car` record during booking creation prevents double-booking.

---

## 8. Existing Security Controls

- JWT authentication & RolesGuard on all user endpoints (`@Roles(Role.CUSTOMER)`).
- Webhook signature verification is mandatory in non-mock mode.
- Customer ownership check: `booking.customerId !== customerId` throws `ForbiddenException`.
- Raw body preservation via NestJS raw-body middleware for accurate HMAC-SHA256 calculation.
- Rate limiting guards (`RateLimiterGuard`) on create-order, verify, and webhook routes.

---

## 9. Identified Gaps

1. **No Persistent Webhook Event Store (`WebhookEvent`)**:
   - Webhooks are currently processed in-memory without persisting raw events or event IDs (`x-razorpay-event-id` / `payload.event_id`).
   - Duplicate concurrent webhook deliveries rely on state checks rather than a persistent database unique constraint on `eventId`.
2. **Single Refund Tracking on `Payment` Record**:
   - `Payment` only has a single `razorpayRefundId` and `refundAmount` column.
   - Partial refunds, multiple refund attempts, or failed retries cannot be tracked with individual refund audit records.
   - No dedicated `PaymentRefund` model with an explicit caller-supplied `idempotencyKey String @unique`.
3. **Vendor Settlement Lacks Dispute & Damage Hold Gate**:
   - `PayoutsService.getVendorEarnings` sums all `COMPLETED` bookings with `PAID` payments without checking `booking.disputeFlag`.
   - A damaged vehicle with an active dispute could inadvertently release funds into eligible payout balance before dispute resolution.
4. **Payment State Granularity**:
   - `PaymentStatus` enum only contains `CREATED`, `PAID`, `FAILED`, `REFUNDED`.
   - Cannot natively distinguish `AUTHORIZED`, `CAPTURED`, `CANCELLED`, `PARTIALLY_REFUNDED`, or explicit refund request stages (`REQUESTED`, `PENDING`).
5. **Customer UI Verification State**:
   - In `payment_step.dart`, if verification takes time, UI does not show a distinct "Reconciling Payment with Bank / Gateway" state with safe retry; it either succeeds or presents an error dialog.
6. **Admin Financial Governance Visibility**:
   - Admin panel lacks a dedicated payment timeline drawer displaying immutable gateway order ID, payment ID, webhook receipt events, refund idempotency keys, and raw gateway references for auditability.

---

## 10. Exact Implementation Plan for Phase 30

1. **Schema Enhancements**:
   - Extend `enum PaymentStatus` with `PENDING`, `AUTHORIZED`, `CAPTURED`, `CANCELLED`, `PARTIALLY_REFUNDED` while maintaining 100% backward compatibility with `PAID`, `CREATED`, `FAILED`, `REFUNDED`.
   - Extend `enum RefundStatus` with `REQUESTED`.
   - Add `model WebhookEvent` with `eventId String @unique`, gateway, eventType, payload, signature, and processing status.
   - Add `model PaymentRefund` with `idempotencyKey String @unique`, requestedAmount, processedAmount, gatewayRefundId, status, and reason.
   - Update `model Payment` to link `refunds PaymentRefund[]`, track `capturedAt`, `failedAt`, `gatewayProvider`.
2. **Backend Hardening**:
   - **Persistent Webhook Ingestion**: Insert `WebhookEvent` with unique `eventId` in a transaction. Return `{ received: true, duplicate: true }` gracefully if unique constraint is hit.
   - **Idempotent Refund Service**: Support caller-provided `idempotencyKey`, persist `PaymentRefund` row, guard against duplicate requests, support full and partial refunds, and reconcile via `refund.processed` / `refund.failed` webhooks.
   - **Escrow / Payout Safety**: Update `PayoutsService.getVendorEarnings` to strictly exclude bookings where `disputeFlag == true` or where an open damage claim exists.
3. **Client & Shared Models**:
   - Update `PaymentOrderModel` to parse and expose new payment statuses and refund details.
   - Enhance Customer `PaymentStep` to cleanly represent "Payment Verification / Reconciliation Pending" state with retry capability.
   - Enhance Vendor Earnings to display escrow/dispute holds explicitly.
   - Add Admin Payment Audit & Governance drawer with complete timeline visibility.
4. **Automated Testing & Regressions**:
   - Comprehensive backend Jest test suite for webhook deduplication, concurrent webhook delivery, idempotent refund creation, partial refunds, dispute payout holds, and tenant security.
   - Flutter tests for payment verification states, refund display, and admin timeline.
5. **Android Device Verification**:
   - Test payment flow on Android emulator `emulator-5554` and capture evidence under `docs/evidence/phase30/`.
6. **Documentation & Git Checkpoint**:
   - Write `PHASE_30_WALKTHROUGH.md`, `PHASE_30_REQUIREMENTS_GAP_MATRIX.md`, `PHASE_30_PAYMENT_STATE_MACHINE.md`, `PHASE_30_SECURITY_AUDIT.md`.
   - Commit and push to `origin main`.

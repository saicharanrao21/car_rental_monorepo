# Phase 36: Canonical Payment & Financial Architecture
## Payment & Financial Transaction Integrity Engine

**Document Status:** Complete & Verified  
**System Classification:** Production Financial Core  
**Author:** Senior Principal Engineer / CTO  
**Date:** September 2026  

---

## 1. Architectural Philosophy & Zero-Trust Invariants

The DriveGo Payment Engine is built upon strict financial zero-trust principles:

1. **Zero Client Authority**:
   - The Flutter mobile and web clients never calculate, propose, or dictate payable monetary totals.
   - The client never dictates whether a payment was successful. A client reporting `payment_success` from a local SDK callback is treated strictly as an unverified event notification.
   - Financial state is updated solely upon server-side cryptographic HMAC verification (`Razorpay.validatePaymentVerification`) or server-side webhook signature verification (`Razorpay.validateWebhookSignature`).
2. **Deterministic Monetary Arithmetic**:
   - All gateway-facing amounts are converted to integer **paise** using deterministic rounding (`Math.round(amount.toNumber() * 100)`).
   - Floating-point arithmetic is forbidden on financial ledgers; all database fields use `Decimal @db.Decimal(10, 2)`.
3. **Append-Only Financial Traceability**:
   - Every financial event (`ORDER_CREATED`, `PAYMENT_AUTHORIZED`, `PAYMENT_CAPTURED`, `PAYMENT_FAILED`, `REFUND_INITIATED`, `REFUND_PROCESSED`, `ORDER_EXPIRED`) is appended to the `PaymentAuditLog` table.
   - Deletion of `Payment` or `PaymentRefund` records is strictly prohibited (`prisma.payment.delete` is eliminated).
4. **Phase 35 Immutable Quote Invariant**:
   - Payments can only be initiated against valid bookings linked to immutable, accepted quotes (`BookingQuote`).
   - `PaymentsService.createOrder` strictly asserts that `Math.abs(quote.totalPayable - booking.totalFare - booking.securityDeposit.amount) < 0.05`. Any drift throws `ConflictException` (409).
5. **Multi-Tenant Financial Isolation**:
   - All `Payment`, `PaymentRefund`, and `PaymentAuditLog` entities maintain explicit `tenantId` fields indexed alongside status.
   - Vendors only have access to sanitized payment summaries (`VendorPaymentSummaryModel`) for bookings involving their fleet. Raw payment secrets, customer card numbers, UPI VPAs, and platform credentials are never exposed to vendors.

---

## 2. Canonical Payment State Machine

```
                        [CUSTOMER CHECKOUT]
                                │
                                ▼
                           ┌─────────┐
              ┌────────────│ CREATED │────────────┐
              │            └─────────┘            │
              │ (Payment        │ (Cron Timeout / │ (User Cancel /
              │  Failed)        │  Quote Expiry)  │  Back Nav)
              ▼                 ▼                 ▼
         ┌─────────┐       ┌─────────┐      ┌───────────┐
         │ FAILED  │       │ EXPIRED │      │ CANCELLED │
         └─────────┘       └─────────┘      └───────────┘
              │                 │
              │ (Retry Order)   │ (Re-quote)
              └────────┬────────┘
                       ▼
                 [RENEW ORDER]
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
                       ▼ (Refund Initiated)            │
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

### Transition Enforcement Matrix

| State | Allowed Transitions | Invariants & Rejection Conditions |
|---|---|---|
| `null / none` | `CREATED` | Direct jump to `PAID` or `CAPTURED` rejected with `BadRequestException`. |
| `CREATED` | `AUTHORIZED`, `CAPTURED`, `PAID`, `FAILED`, `CANCELLED`, `EXPIRED` | Pre-authorization or capture; timeout transitions to `EXPIRED`. |
| `AUTHORIZED` | `CAPTURED`, `PAID`, `FAILED`, `CANCELLED`, `EXPIRED` | Capture settles funds; void/cancel transitions to `CANCELLED`/`FAILED`. |
| `PAID / CAPTURED` | `PARTIALLY_REFUNDED`, `REFUNDED` | Cannot transition to `CREATED`, `FAILED`, or `EXPIRED`. Downgrade attempts rejected with `ConflictException`. |
| `FAILED` | `CREATED` | Customer retry renews order; cannot transition to `PAID` without new gateway order. |
| `CANCELLED` | `CREATED` | Customer re-initiates checkout. |
| `EXPIRED` | `CREATED` | Stale order renewal with fresh quote. |
| `PARTIALLY_REFUNDED` | `PARTIALLY_REFUNDED`, `REFUNDED` | Cumulative refund cannot exceed total payment amount. |
| `REFUNDED` | *None* | Terminal state. Completely immutable. |

---

## 3. Financial Data Model

### `Payment` Model
- `id`: String (cuid)
- `tenantId`: String (indexed)
- `bookingId`: String (unique foreign key to `Booking`)
- `razorpayOrderId`: String (unique)
- `razorpayPaymentId`: String (nullable, indexed)
- `razorpayRefundId`: String (nullable, unique)
- `amount`: Decimal(10,2) (total booking fare + security deposit)
- `gatewayAmountPaise`: Int (integer paise sent to Razorpay)
- `refundAmount`: Decimal(10,2) (cumulative refunded amount)
- `currency`: String (default "INR")
- `status`: `PaymentStatus` (`CREATED`, `PENDING`, `AUTHORIZED`, `CAPTURED`, `PAID`, `FAILED`, `CANCELLED`, `EXPIRED`, `PARTIALLY_REFUNDED`, `REFUNDED`)
- `refundStatus`: `RefundStatus` (`NONE`, `REQUESTED`, `PENDING`, `PROCESSED`, `FAILED`)
- `gatewayProvider`: String (default "RAZORPAY")
- `capturedAt`: DateTime (nullable)
- `failedAt`: DateTime (nullable)
- `failureReason`: String (nullable)
- `idempotencyKey`: String (unique)
- `metadata`: Json (nullable)
- `createdAt`, `updatedAt`: DateTime

### `PaymentRefund` Model
- `id`: String (cuid)
- `tenantId`: String (indexed)
- `paymentId`: String (foreign key to `Payment`, cascade delete)
- `bookingId`: String (indexed)
- `gatewayRefundId`: String (unique)
- `idempotencyKey`: String (unique, format: `refund_{bookingId}_{paymentId}`)
- `requestedAmount`: Decimal(10,2)
- `processedAmount`: Decimal(10,2)
- `currency`: String (default "INR")
- `reason`: String (nullable)
- `requestedByUserId`: String (nullable)
- `status`: `RefundStatus` (`REQUESTED`, `PENDING`, `PROCESSED`, `FAILED`)
- `failureReason`: String (nullable)
- `metadata`: Json (nullable)

### `PaymentAuditLog` Model (Append-Only)
- `id`: String (cuid)
- `paymentId`: String (foreign key to `Payment`, cascade delete, indexed)
- `bookingId`: String (indexed)
- `tenantId`: String (indexed)
- `eventType`: String (e.g. `PAYMENT_ORDER_CREATED`, `PAYMENT_VERIFIED`, `WEBHOOK_PAYMENT_CAPTURED`, `REFUND_PROCESSED`)
- `fromStatus`: `PaymentStatus` (nullable)
- `toStatus`: `PaymentStatus`
- `amount`: Decimal(10,2) (nullable)
- `gatewayReference`: String (nullable)
- `actorId`: String (nullable)
- `actorRole`: String (nullable)
- `source`: String (`CUSTOMER`, `VENDOR`, `ADMIN`, `WEBHOOK`, `RECONCILIATION`, `WORKER`)
- `payloadHash`: String (nullable, SHA-256 hash of webhook payload or signature)
- `metadata`: Json (nullable)
- `createdAt`: DateTime (default now, indexed)

---

## 4. Subsystem Pipelines

### A. Order Creation Pipeline (`POST /payments/create-order`)
1. **Authentication & Role Verification**: `JwtAuthGuard`, `RolesGuard(Role.CUSTOMER)`.
2. **Booking Ownership**: `booking.customerId === req.user.userId`.
3. **Status Check**: `booking.status === BookingStatus.PENDING`.
4. **Phase 35 Quote Integrity**: If `booking.quoteId` exists, assert `|quote.totalPayable - totalAmount| < 0.05`.
5. **Wallet Deduction Check**: If `useWallet` is selected, compute `walletApplied` and subtract from `gatewayAmount`.
6. **Order Renewal (No Row Deletion)**: If `Payment` row exists:
   - If `PAID` or `REFUNDED` -> Throw `ConflictException`.
   - If `CREATED`, `FAILED`, `CANCELLED`, or `EXPIRED` -> Update existing record with new `razorpayOrderId`.
7. **Gateway Interaction**: Create order on Razorpay with `receipt: bookingId` and integer paise.
8. **Audit Logging**: Insert `PAYMENT_ORDER_CREATED` or `PAYMENT_ORDER_RENEWED` into `PaymentAuditLog`.

### B. Payment Verification Pipeline (`POST /payments/verify`)
1. **Booking & Payment Lookup**: Verify customer ownership and retrieve `Payment` record.
2. **Order ID Binding Check**: Verify provided `razorpayOrderId` matches `payment.razorpayOrderId`.
3. **Idempotency Check**: If already `PAID`, return cached success idempotently.
4. **State Machine Validation**: `assertValidTransition(payment.status, PaymentStatus.PAID)`.
5. **Cryptographic Signature Verification**: Validate `validatePaymentVerification({ order_id, payment_id }, signature, secret)`.
6. **Razorpay API Verification**: Fetch payment entity from Razorpay API; verify `currency == 'INR'`, `status == 'captured'`, and amount matches paise.
7. **Transactional Settlement (`$transaction`)**:
   - Settle wallet debit if split-payment was used.
   - Update `Payment.status = PAID`, `razorpayPaymentId = paymentId`, `capturedAt = now()`.
   - Update `SecurityDeposit.status = HELD`.
   - Record coupon usage if coupon was applied.
   - Append `PaymentAuditLog` (`eventType: 'PAYMENT_VERIFIED'`).
   - Trigger invoice generation asynchronously.
8. **Customer Notification**: Send transactional push/SMS notification.

### C. Webhook Ingestion Pipeline (`POST /payments/webhook`)
1. **Rate Limiting**: 120 req / 60s.
2. **Signature Verification**: Verify HMAC SHA-256 against `RAZORPAY_WEBHOOK_SECRET`.
3. **Deduplication**: Insert into `WebhookEvent` table (`eventId @unique`). If duplicate, return `{ received: true, duplicate: true }`.
4. **Event Routing**:
   - `payment.authorized`: Set `PaymentStatus.AUTHORIZED` and log audit event.
   - `payment.captured` / `order.paid`: Verify amount & currency; transition to `PAID` atomically; log audit event.
   - `payment.failed`: Update to `FAILED` only if payment is not already `PAID`; log audit event.
   - `refund.created`: Update `refundStatus = PENDING`; log audit event.
   - `refund.processed`: Update `refundStatus = PROCESSED`, `PaymentStatus = REFUNDED` (or `PARTIALLY_REFUNDED`); log audit event.
   - `refund.failed`: Update `refundStatus = FAILED`; log audit event.

### D. Refund Engine (`PaymentsService.refund` & `adminRefund`)
1. **Eligibility Validation**: Payment must be in `PAID`, `PARTIALLY_REFUNDED`, or `REFUNDED`.
2. **Over-Refund Protection**: Assert `requestedAmount <= (payment.amount - payment.refundAmount)`.
3. **Split Allocation**: Gateway source first, remainder to customer wallet.
4. **Gateway Idempotency**: Call `razorpay.payments.refund` with `receipt: idempotencyKey`.
5. **Audit Logging**: Append `REFUND_INITIATED` and `REFUND_PROCESSED` events to `PaymentAuditLog`.

### E. Financial Reconciliation Engine (`FinancialReconciliationService`)
- Runs every 15 minutes with distributed Redis mutex (`lock:reconciliation:cron`).
- **Rule 1 (Orphaned Refunds)**: Detects refunds existing on Razorpay but missing in DB; auto-heals DB state.
- **Rule 2 (Unconfirmed Payments)**: Detects captured gateway payments where DB is still `PENDING`; auto-confirms payment and triggers outbox.
- **Rule 3 (Stale Orders)**: Detects uncaptured `CREATED` orders older than `staleHours`; marks them `FAILED`/`EXPIRED` with audit log.
- **Rule 4 (Financial Discrepancies)**: Detects mismatches between gateway and DB amounts; flags `ReconciliationException` for admin review without blind mutation.
- **Rule 5 (Wallet Ledger Integrity)**: Cross-checks wallet ledger entries against current wallet balances.

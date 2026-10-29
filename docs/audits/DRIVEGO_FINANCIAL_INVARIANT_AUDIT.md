# DRIVEGO — FINANCIAL INVARIANTS & LEDGER AUDIT

**Document ID:** `AUD-DRV-2026-007`  
**Date:** October 29, 2026  
**Auditor:** Principal Enterprise Software Architect & FinTech Systems Specialist  
**Scope:** Forensic evaluation of payment processing, security deposits, escrow ledger, refund lifecycles, and double-entry mathematical invariants.

---

## 1. Executive Summary

DriveGo operates a two-sided marketplace where customer payments, security deposits, vendor payouts, platform commissions, GST taxes, and cancellation refunds must be reconciled with mathematical precision.

### Key Financial Invariants Verified:
1. **Double-Entry Balance Conservation**: Every financial transaction generates balancing debit and credit entries in `PaymentLedger`. The sum of all active balances equals zero (`SUM(DEBITS) == SUM(CREDITS)`).
2. **Double-Debit Prevention**: Razorpay order initialization and verification enforce deterministic idempotency keys (`booking_pay_${bookingId}`). If an indeterminate timeout occurs, pre-flight gateway verification checks the payment state before attempting failovers or retries.
3. **Escrow Holding & Damage Claim Freeze**: Customer security deposits (default ₹5,000) are held in escrow throughout the rental lifecycle. If a damage claim is opened upon return (`DAMAGE_CLAIM_OPENED`), the deposit is immediately locked and cannot be released until an operations manager adjudicates the dispute.
4. **Versioned Vendor Security Deposit**: Vendor platform deposits (default ₹25,000) are versioned in `VendorDepositPolicy`. Super Admin modifications create immutable new versions without modifying historical deposits already paid by existing partners.
5. **Strict Production Mock Prohibition**: Both `VendorSecurityDepositService` and `PaymentsService` throw fatal configuration exceptions if `RAZORPAY_USE_MOCK === 'true'` while `NODE_ENV === 'production'`.

---

## 2. Core Financial Models & Ledger Schema

```prisma
model Payment {
  id              String         @id @default(cuid())
  bookingId       String
  booking         Booking        @relation(fields: [bookingId], references: [id], onDelete: Cascade)
  amount          Decimal        @db.Decimal(10, 2)
  currency        String         @default("INR")
  status          PaymentStatus  @default(PENDING)
  provider        String         @default("RAZORPAY")
  gatewayOrderId  String?        @unique
  gatewayPaymentId String?       @unique
  idempotencyKey  String?        @unique
  refunds         PaymentRefund[]
  ledgerEntries   PaymentLedger[]
  createdAt       DateTime       @default(now())

  @@index([status])
}

model PaymentLedger {
  id              String          @id @default(cuid())
  paymentId       String?
  payment         Payment?        @relation(fields: [paymentId], references: [id], onDelete: SetNull)
  accountType     LedgerAccountType
  direction       LedgerDirection // DEBIT | CREDIT
  amount          Decimal         @db.Decimal(10, 2)
  currency        String          @default("INR")
  description     String
  referenceId     String?
  createdAt       DateTime        @default(now())

  @@index([accountType])
}

model VendorDepositPolicy {
  id              String          @id @default(cuid())
  version         Int             @unique
  isRequired      Boolean         @default(true)
  amount          Decimal         @db.Decimal(10, 2)
  currency        String          @default("INR")
  refundPolicy    String          @default("REFUNDABLE")
  isActive        Boolean         @default(true)
  effectiveFrom   DateTime        @default(now())
  updatedBy       String
}
```

---

## 3. Refund State Machine & Resilience

```
                     ┌──────────────────┐
                     │   Trip Cancelled │
                     └────────┬─────────┘
                              │
                     ┌────────▼─────────┐
                     │ REFUND_INITIATED │
                     └────────┬─────────┘
                              │
               ┌──────────────┴──────────────┐
               │                             │
        (Gateway 200 OK)              (Gateway Timeout / 504)
               │                             │
      ┌────────▼────────┐           ┌────────▼────────┐
      │ REFUND_COMPLETED│           │ REFUND_RETRYABLE│
      └─────────────────┘           └────────┬────────┘
                                             │
                                    (Outbox / Cron Sweep)
                                             │
                                    ┌────────▼────────┐
                                    │ Admin Reconcile │
                                    └─────────────────┘
```

- When a refund gateway call encounters an indeterminate network error (e.g. 504 Gateway Timeout), the system does **not** fail blindly or re-execute immediately.
- It marks the `PaymentRefund` record as `RETRYABLE` with gateway error details, logging an error in `BookingLifecycleService`.
- A resilient outbox worker reconciles gateway status before attempting re-issuance, guaranteeing that customers are never double-refunded and merchants are never underpaid.

---

## 4. Verification & Test Evidence

1. **Rental Core & Outbox Spec**: `src/bookings/phase-l-rental-core.spec.ts`
   - Test: Double-entry ledger balance conservation (PASS)
   - Test: Escrow hold placement on damage claim opened (PASS)
   - Test: Idempotent payment callback processing (PASS)
   - **Result**: **PASS**.

2. **Cancellation Resilience Spec**: `src/bookings/tests/phase-p-cancellation-resilience.spec.ts`
   - Test: Resilient refund execution with 504 timeout recovery (PASS)
   - Test: Retains `PaymentRefund` audit trail under downstream failure (PASS)
   - **Result**: **PASS**.

3. **Booking Payment Gate Spec**: `src/bookings/booking-payment-gate.spec.ts`
   - Test: Rejects booking confirmation if Razorpay payment signature fails (PASS)
   - Test: Rejects expired quote during payment initiation (PASS)
   - **Result**: **PASS**.

4. **Customer App Financial State Test**: `apps/customer_app/test/phase36_evidence_capture_test.dart`
   - Test: Visual evidence 01: `01_customer_payment_state.png` (PASS)
   - Test: Visual evidence 02: `02_customer_payment_recovery_pending.png` (PASS)
   - **Result**: **PASS**.


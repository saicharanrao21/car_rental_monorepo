# DRIVEGO — PHASE P IMPLEMENTATION PLAN
**Enterprise Double-Entry Financial Ledger, Settlement Engine & Control-Plane Integrity**
**Document Reference:** `docs/phase-p-implementation-plan.md`  
**Date:** September 10, 2026  
**Status:** READY FOR USER REVIEW & STAKEHOLDER APPROVAL  
**Prerequisite Baseline:** `fd60a5c170000ac8d524f594ef58768b3d147a5e` (`docs/phase-p-pre-audit.md`)

---

## 1. STRATEGIC VISION & CORE OBJECTIVES

Phase P transitions DriveGo from a feature-rich prototype into an auditable, enterprise-grade marketplace platform. Rather than adding more exploratory features, Phase P resolves the fundamental architectural hazards identified in the forensic pre-audit:

1. **Financial LedgerCore**: Establish an immutable, multi-party double-entry general ledger ensuring that every rupee flowing through the system (customer payment, platform commission, vendor payout, GST tax liability, security deposit, corporate credit) satisfies mathematical conservation of money.
2. **Checkout & Payment Integrity**: Close the gap in `CheckoutOrchestratorService` by atomically creating `Payment` and `SecurityDeposit` records upon confirmation, and eliminate the dual-write cancellation vulnerability.
3. **Administrative Control-Plane Completion**: Equip platform operations staff with full UI capabilities in `admin_panel` to manage and execute vendor payouts, corporate accounts, and reconciliation discrepancies.
4. **Corporate Account Multi-Tenant Security**: Protect corporate credit lines against unauthorized consumption via corporate employee validation and domain whitelisting.
5. **Durable Transactional Outbox**: Guarantee reliable event delivery by replacing in-memory fire-and-forget notification calls with a durable background queue processor.

---

## 2. ARCHITECTURAL BLUEPRINT

```
+-----------------------------------------------------------------------------------------------------------------+
|                                          PHASE P TARGET ARCHITECTURE                                            |
+-----------------------------------------------------------------------------------------------------------------+

                      [ Customer App / B2B Web ]               [ Admin Panel ]
                                  |                                   |
                                  v                                   v
             [ Marketplace Checkout / Quotes ]              [ Payouts & Corporate Control ]
                                  |                                   |
                                  +-----------------+-----------------+
                                                    |
                                                    v
                                    +-------------------------------+
                                    |    NestJS Application Layer   |
                                    |                               |
                                    |   * CheckoutOrchestrator      |
                                    |   * BookingLifecycle          |
                                    |   * CorporateAccountsService  |
                                    |   * PayoutsService            |
                                    +---------------+---------------+
                                                    |
                                                    v
                                    +-------------------------------+
                                    |      LEDGER CORE ENGINE       |
                                    |  (Zero-Sum Double-Entry Rule) |
                                    +---------------+---------------+
                                                    |
                                    +---------------+---------------+
                                    |
                                    v
+-----------------------------------------------------------------------------------------------------------------+
|                                        PRISMA POSTGRESQL TRANSACTION                                            |
+-----------------------------------------------------------------------------------------------------------------+
|                                                                                                                 |
|   1. Mutation State:        Booking(CONFIRMED) | Payment(PAID) | SecurityDeposit(HELD)                          |
|                                                                                                                 |
|   2. Double-Entry Journal:                                                                                     |
|      * DEBIT:  Gateway Clearing / Customer Asset Account       ₹3,540.00                                        |
|      * CREDIT: Platform Commission Revenue Account             ₹  300.00                                        |
|      * CREDIT: GST Tax Liability Account                       ₹   54.00                                        |
|      * CREDIT: Vendor Payable Escrow Account                   ₹2,686.00                                        |
|      * CREDIT: Customer Deposit Escrow Liability Account       ₹  500.00                                        |
|      --------------------------------------------------------------------                                       |
|      NET INVARIANT: Total Debits == Total Credits (Sum == 0)                                                    |
|                                                                                                                 |
|   3. Transactional Outbox:  BookingOutboxEvent(PENDING)                                                         |
|                                                                                                                 |
+-----------------------------------------------------------------------------------------------------------------+
                                                    |
                                                    v (Committed)
                                    +-------------------------------+
                                    |   DURABLE OUTBOX WORKER CRON  |
                                    |   (At-Least-Once Dispatch)    |
                                    +---------------+---------------+
                                                    |
                          +-------------------------+-------------------------+
                          |                                                   |
                          v                                                   v
        [ NotificationOrchestratorService ]                       [ Real-Time SSE Stream ]
        * Real UserDevice FCM Tokens *                            * Customer / Vendor UI *
        * Twilio SMS / Meta WhatsApp *
```

---

## 3. DETAILED COMPONENT CHANGES

### 3.1 Database & Prisma Schema (`car_rental_backend/prisma/schema.prisma`)

#### [NEW MODELS]
```prisma
// 1. Unified Multi-Party General Ledger
enum LedgerAccountType {
  GATEWAY_CLEARING
  CUSTOMER_WALLET
  CUSTOMER_DEPOSIT_ESCROW
  VENDOR_PAYABLE
  PLATFORM_COMMISSION_REVENUE
  TAX_GST_LIABILITY
  CORPORATE_RECEIVABLE
  DISPUTE_HOLD
}

enum LedgerEntrySide {
  DEBIT
  CREDIT
}

model PlatformLedgerEntry {
  id              String             @id @default(cuid())
  journalId       String             // Deterministic UUID grouping balanced debit & credit rows
  accountType     LedgerAccountType
  accountEntityId String?            // vendorId, customerId, or corporateAccountId
  side            LedgerEntrySide    // DEBIT or CREDIT
  amount          Decimal            @db.Decimal(12, 2)
  currency        String             @default("INR")
  bookingId       String?
  booking         Booking?           @relation(fields: [bookingId], references: [id], onDelete: SetNull)
  paymentId       String?
  payment         Payment?           @relation(fields: [paymentId], references: [id], onDelete: SetNull)
  payoutId        String?
  payout          Payout?            @relation(fields: [payoutId], references: [id], onDelete: SetNull)
  referenceType   String             // 'BOOKING_CONFIRMATION', 'CANCELLATION_REFUND', 'VENDOR_PAYOUT', 'DAMAGE_DEDUCTION'
  referenceId     String
  narration       String
  postedAt        DateTime           @default(now())

  @@index([journalId])
  @@index([accountType, accountEntityId])
  @@index([bookingId])
  @@index([referenceType, referenceId])
}

// 2. Corporate Account Employee Affiliation & Hierarchy
model CorporateEmployee {
  id                 String           @id @default(cuid())
  corporateAccountId String
  corporateAccount   CorporateAccount @relation(fields: [corporateAccountId], references: [id], onDelete: Cascade)
  userId             String
  user               User             @relation(fields: [userId], references: [id], onDelete: Cascade)
  employeeCode       String?
  department         String?
  spendingLimitMonthly Decimal?       @db.Decimal(10, 2)
  isActive           Boolean          @default(true)
  createdAt          DateTime         @default(now())
  updatedAt          DateTime         @updatedAt

  @@unique([corporateAccountId, userId])
  @@index([userId])
}

// 3. Corporate Credit Transaction Ledger
model CorporateCreditLedgerEntry {
  id                 String           @id @default(cuid())
  corporateAccountId String
  corporateAccount   CorporateAccount @relation(fields: [corporateAccountId], references: [id], onDelete: Cascade)
  userId             String
  bookingId          String?
  type               String           // 'CREDIT_RESERVATION', 'CREDIT_RELEASE', 'INVOICE_SETTLEMENT'
  amount             Decimal          @db.Decimal(12, 2)
  balanceAfter       Decimal          @db.Decimal(12, 2)
  notes              String?
  createdAt          DateTime         @default(now())

  @@index([corporateAccountId])
  @@index([bookingId])
}
```

---

### 3.2 Backend Service Modifications (`car_rental_backend/src`)

#### A. LedgerCore Engine (`src/finance/ledger-core.service.ts`) [NEW]
- Exposes `recordJournalEntries(entries: JournalEntryDto[], tx?: Prisma.TransactionClient)`.
- Validates that:
  $$\sum \text{Debits} == \sum \text{Credits}$$
- Rejects any transaction where ledger lines do not balance to exactly zero.
- Provides balance retrieval helper:
  `getAccountBalance(accountType, entityId)` derived from $\sum (\text{Credits} - \text{Debits})$.

#### B. Marketplace Checkout Fix (`src/marketplace/checkout-orchestrator.service.ts`) [MODIFY]
- In `verifyAndConfirmPayment`:
  - Atomically create `tx.payment.create(...)` with `status: PaymentStatus.PAID`, storing `razorpayPaymentId`, `orderId`, and signature.
  - Atomically create `tx.securityDeposit.create(...)` with `status: SecurityDepositStatus.HELD` if the quote includes a security deposit line item.
  - Dispatch double-entry journal entries via `LedgerCoreService`:
    - Debit: `GATEWAY_CLEARING`
    - Credit: `PLATFORM_COMMISSION_REVENUE`
    - Credit: `TAX_GST_LIABILITY`
    - Credit: `VENDOR_PAYABLE`
    - Credit: `CUSTOMER_DEPOSIT_ESCROW`

#### C. Cancellation Dual-Write Remediation (`src/bookings/booking-lifecycle.service.ts`) [MODIFY]
- Decouple external payment refund from the initial state transition:
  - Transition status to `CANCELLED` within database transaction.
  - Insert a `PaymentRefund` record with `status: PENDING`.
  - Post reversing journal entries into `PlatformLedgerEntry`.
  - Dispatch the actual gateway refund via an asynchronous reliable worker. If the gateway succeeds, update `PaymentRefund` to `PROCESSED`. If it fails, mark `FAILED` and raise an operational reconciliation incident without compromising database integrity.

#### D. Corporate Credit Protection (`src/corporate/corporate-accounts.service.ts`) [MODIFY]
- In `reserveCredit`:
  - Require caller `userId`.
  - Verify that `userId` exists as an active `CorporateEmployee` associated with `corporateCode`, or that caller email matches the verified corporate domain.
  - Record each credit movement in `CorporateCreditLedgerEntry`.

#### E. Durable Outbox Worker (`src/queues/outbox-worker.service.ts`) [NEW]
- Implement a scheduled worker running every 10 seconds:
  - Fetches batch of `BookingOutboxEvent` where `status == 'PENDING'` with pessimistic locking (`SKIP LOCKED`).
  - Calls `BookingOutboxService.dispatchEvent(event.id)`.
  - Marks `PUBLISHED` on success; increments `retryCount` with exponential backoff on failure; moves to `DEAD_LETTER` after 5 failed attempts.
- In `NotificationOrchestratorService`:
  - Query active device tokens from `UserDevice` where `userId === recipientId` instead of hardcoding `mock_fcm_token_123`.

---

### 3.3 Admin Control-Plane UI (`apps/admin_panel`)

#### A. Vendor Payouts Control Plane (`lib/features/payouts`) [NEW]
- Create `PayoutsRepository` (`ApiPayoutsRepository`) calling backend `/admin/payouts`.
- Implement `AdminPayoutsPage`:
  - Filter by payout status (`PENDING`, `APPROVED`, `PROCESSING`, `PAID`, `REJECTED`).
  - Review payout breakdown (completed bookings, escrow holds, damage deductions).
  - One-click **Approve** (`POST /admin/payouts/:id/approve`).
  - One-click **Execute Settlement** (`POST /admin/payouts/:id/execute`) with reference/UTR input.
  - **Reject** with mandatory reason input.

#### B. Corporate Accounts Control Plane (`lib/features/corporate`) [NEW]
- Create `CorporateRepository` calling `/corporate-accounts`.
- Implement `AdminCorporateAccountsPage`:
  - List corporate clients, credit limits, used credit, and discount percentages.
  - Create new corporate account wizard.
  - Employee whitelist management sheet (assigning employees and monthly spending caps).

#### C. Reconciliation Exception Resolution (`lib/features/reconciliation`) [NEW]
- Expose `/reconciliation/exceptions` in `AdminReconciliationPage`.
- Allow admin operators to view payment/refund mismatches and click "Resolve / Mark Healed".

---

## 4. STEP-BY-STEP IMPLEMENTATION PHASES

```
+-----------------------------------------------------------------------------------+
|                            PHASE P EXECUTION SEQUENCE                             |
+-----------------------------------------------------------------------------------+
|  Step 1: Database Migration (PlatformLedgerEntry, CorporateEmployee, Indexes)     |
|  Step 2: LedgerCore Module & Invariant Unit Tests                                 |
|  Step 3: Checkout Orchestrator Payment & Deposit Creation Fix                     |
|  Step 4: Cancellation Dual-Write Decoupling & Refund State Machine                |
|  Step 5: Corporate Security & Employee Hierarchy Enforcement                      |
|  Step 6: Durable Outbox Poller & Real FCM Device Token Dispatch                   |
|  Step 7: Admin Panel Payouts & Corporate UI Implementation                        |
|  Step 8: End-to-End Multi-Party Accounting Verification                           |
+-----------------------------------------------------------------------------------+
```

---

## 5. VERIFICATION PLAN & AUTOMATED TESTS

### 5.1 Automated Backend Tests
1. **Double-Entry Balance Test (`ledger-core.spec.ts`)**:
   - Assert that any set of journal entries where $\sum \text{Debits} \ne \sum \text{Credits}$ throws `UnbalancedJournalException`.
   - Assert that booking confirmation creates balanced entries summing to zero.
2. **Checkout Payment Creation Integrity (`checkout-orchestrator.spec.ts`)**:
   - Confirm booking via `verifyAndConfirmPayment`.
   - Verify that `Payment` is created with status `PAID`.
   - Verify that `SecurityDeposit` is created with status `HELD`.
   - Verify that `PayoutsService.getVendorEarningsSummary` successfully includes the booking.
3. **Cancellation Dual-Write Resilience (`cancellation-resilience.spec.ts`)**:
   - Simulate database transaction failure during cancellation.
   - Verify that external payment gateway refund is not prematurely dispatched or that reconciliation handles it cleanly.
4. **Corporate Credit IDOR Protection (`corporate-security.spec.ts`)**:
   - Attempt to call `reserveCredit` with an unaffiliated customer account $\to$ Expect `403 Forbidden`.
   - Attempt with affiliated `CorporateEmployee` $\to$ Expect `200 OK`.
5. **Durable Outbox Queue Polling (`outbox-worker.spec.ts`)**:
   - Create pending `BookingOutboxEvent` without triggering in-memory dispatch.
   - Run worker loop $\to$ Verify event transitions to `PUBLISHED` and notification is delivered.

### 5.2 Frontend Widget & E2E Tests
1. **Admin Payouts Flow (`phase_p_admin_payouts_test.dart`)**:
   - Render `AdminPayoutsPage`.
   - Verify list of pending payouts.
   - Tap "Approve" $\to$ verify API call to `/admin/payouts/:id/approve`.
   - Tap "Execute" $\to$ verify dialog and API call with UTR.
2. **Corporate Accounts Management (`phase_p_admin_corporate_test.dart`)**:
   - Render `AdminCorporateAccountsPage`.
   - Verify corporate list, credit line metrics, and employee assignment modal.

---

## 6. ROLLBACK & RISK MITIGATION STRATEGY

1. **Additive Schema Migrations**: All Prisma schema additions (`PlatformLedgerEntry`, `CorporateEmployee`, `CorporateCreditLedgerEntry`) are strictly additive. No existing columns are removed or renamed.
2. **Backwards Compatibility**: Legacy booking routes remain functional while automatically creating double-entry ledger entries in the background.
3. **Database Reversibility**: If any migration fails, rollback SQL scripts can drop the new tables without data loss on core tables (`Booking`, `Car`, `User`, `Payment`).

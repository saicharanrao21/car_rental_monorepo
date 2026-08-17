# DRIVEGO PHASE 3 AUDIT REPORT: SECURITY DEPOSIT & INVOICING

**Date:** August 16, 2026
**Audited Domains:** Security Deposit System, Invoicing & Receipts, Damage Deductions, Financial Document Safety, Multi-City Compatibility
**Verdict:** **AUDIT COMPLETE — READY FOR PHASED IMPLEMENTATION PLAN REVIEW.**

---

## Executive Summary & Benchmark Database Safety

* **Benchmark Booking ID:** `cmsu5sk3m000qgw1zaf9ftksz`
* **Status:** `CONFIRMED` | **Payment:** `PAID` | **Refund:** `NONE`
* **Benchmark Safety Check:** `100% UNTOUCHED` (`node scratch/check_db_safety.js` verified).
* **Audit Finding:**
  1. **Security Deposit:** Foundational database models (`SecurityDeposit`, `DamageClaim`), backend services (`DepositsService`, `DamageClaimsService`), and Admin adjudication panels exist. However, dynamic deposit rule calculation in `createBooking`, customer checkout deposit line-item display, and automated post-trip release triggers are **PARTIAL or MISSING**.
  2. **Invoicing & Receipts:** Completely **MISSING** across database, backend, and all three frontend apps (Customer, Vendor, Admin). No `Invoice` model, no GST invoice number generator, and no PDF generation capability exist.

---

## Master Phase 3 Audit Classification Table

| Feature Domain | Existing DB | Backend Service | Customer UI | Vendor UI | Admin UI | API Endpoints | Security & Concurrency | Status |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Security Deposit Model & State Machine** | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | ✅ (CAS locking) | **PARTIAL** |
| **2. Dynamic Deposit Calculation Engine** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠️ | **MISSING** |
| **3. Checkout Deposit Line Item & Collection** | ⚠️ | ✅ | ❌ | ❌ | ⚠️ | ✅ | ✅ (Order reuse) | **PARTIAL** |
| **4. Post-Trip Deposit Auto-Release** | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | ✅ (Atomic refund) | **NEEDS HARDENING** |
| **5. Damage Claim & Deposit Settlement** | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ | **COMPLETE / HARDENED** |
| **6. Tax Invoice & Credit Note Schema** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **MISSING** |
| **7. Sequential GST Invoice Generation** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **MISSING** |
| **8. Customer PDF Invoice & Receipt View** | ❌ | ❌ | ❌ | N/A | N/A | ❌ | ❌ | **MISSING** |
| **9. Vendor Financial Statement & Invoicing** | ❌ | ❌ | N/A | ❌ | ⚠️ | ❌ | ❌ | **MISSING** |
| **10. Admin Invoice & Deposit Management** | ❌ | ❌ | N/A | N/A | ❌ | ❌ | ❌ | **MISSING** |
| **11. Multi-City Deposit & Tax Isolation** | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ✅ | **PARTIAL** |

---

## Detailed Findings by Domain

### 1. Security Deposit System Audit

#### What Exists Today:
* **Database Schema:**
  - `SecurityDeposit` model in `schema.prisma`:
    ```prisma
    model SecurityDeposit {
      id                String                @id @default(cuid())
      bookingId         String                @unique
      booking           Booking               @relation(fields: [bookingId], references: [id], onDelete: Cascade)
      amount            Decimal               @db.Decimal(10, 2)
      refundedAmount    Decimal               @default(0) @db.Decimal(10, 2)
      deductedAmount    Decimal               @default(0) @db.Decimal(10, 2)
      razorpayPaymentId String?
      razorpayRefundId  String?               @unique
      status            SecurityDepositStatus @default(REQUIRED)
      heldAt            DateTime?
      releasedAt        DateTime?
      createdAt         DateTime              @default(now())
      updatedAt         DateTime              @updatedAt
    }
    ```
  - `SecurityDepositStatus` enum: `REQUIRED`, `HELD`, `REFUNDED`, `PARTIALLY_REFUNDED`, `FORFEITED`, `CANCELLED`.
* **Backend Services:**
  - `DepositsService` (`car_rental_backend/src/deposits/deposits.service.ts`):
    - `getDeposit(bookingId, requestingUser)`: RBAC-filtered deposit retrieval.
    - `holdDeposit(bookingId, amount, razorpayPaymentId)`: Upserts deposit to `HELD` status.
    - `releaseDeposit(bookingId, adminUserId, reason)`: Compare-and-Swap (CAS) atomic transition with Razorpay gateway refund trigger.
    - `settleDeduction(bookingId, deductAmount, adminUserId, reason)`: Deducts approved damage amount from deposit and refunds the remaining balance.
* **Payments Integration:**
  - `PaymentsService.createOrder` & `verifyPayment` (`payments.service.ts` & `payments-deposit-line-item.spec.ts`):
    - Combines `booking.totalFare + (deposit.amount || 0)` into Razorpay order.
    - Marks `SecurityDeposit` as `HELD` upon successful payment verification.

#### What is Missing:
1. **Dynamic Deposit Rules Engine:**
   - Deposit amounts are currently not calculated dynamically during `createBooking`.
   - Need category-based default deposits (Hatchback ₹3,000, Sedan ₹4,000, SUV ₹5,000, Luxury ₹10,000, etc.) with city-specific overrides.
2. **Booking Initialization Hook:**
   - `BookingsService.createBooking` does not create a `SecurityDeposit` record at checkout time.
3. **Automated Post-Trip Release:**
   - When a booking reaches `COMPLETED` and no damage claims are filed within 24 hours (or upon return inspection sign-off), deposit release should be automatically queued.
4. **Customer Checkout UX:**
   - `BookingFlowPage` needs an explicit "Refundable Security Deposit" card separating trip fare from refundable deposit.

---

### 2. Invoicing & Receipts Audit

#### Current State:
* **Completely Missing.** No database models, backend endpoints, or UI screens currently exist for tax invoices or receipts.
* Fares are calculated dynamically by `FareCalculatorService` and stored across `Booking` fields (`baseFare`, `platformFee`, `gstAmount`, `discountAmount`, `totalFare`).
* Platform settings store company tax metadata (`gstNumber: "27AAAAA1111A1Z1"`, `supportEmail`, `supportPhone`).

#### What Must Be Built:
1. **Database Models:**
   - `Invoice` model:
     - `id`: `String @id @default(cuid())`
     - `invoiceNumber`: `String @unique` (Format: `INV-YYYY-MM-XXXXX`)
     - `bookingId`: `String @unique`
     - `paymentId`: `String`
     - `customerId`: `String`
     - `vendorId`: `String`
     - `baseFare`: `Decimal`
     - `platformFee`: `Decimal`
     - `gstRate`: `Decimal @default(18.00)`
     - `gstAmount`: `Decimal`
     - `discountAmount`: `Decimal @default(0)`
     - `totalFare`: `Decimal`
     - `depositAmount`: `Decimal @default(0)`
     - `issuedAt`: `DateTime @default(now())`
     - `pdfUrl`: `String?`
   - `CreditNote` model:
     - For cancellation fee adjustments, damage claim deductions, and deposit refunds.
     - Linked to parent `Invoice`.
2. **Backend Invoicing Module:**
   - `InvoicesService` with sequential number generation, HTML receipt template compilation, and PDF rendering.
   - Endpoints:
     - `GET /bookings/:id/invoice` (Customer / Vendor / Admin)
     - `GET /bookings/:id/invoice/download` (Returns signed PDF download URL)
     - `GET /admin/invoices` (Admin invoice audit table)
3. **UI Integrations:**
   - **Customer App:** "Download Tax Invoice" button in `BookingDetailPage`.
   - **Vendor App:** "Trip Statement & Tax Invoice" in `VendorBookingDetailPage`.
   - **Admin Panel:** "Invoices & Receipts" tab under Financial Management.

---

### 3. Damage Claim & Security Deposit Interaction

* **Existing Implementation:**
  - `DamageClaim` model exists (`claimedAmount`, `approvedAmount`, `status`, `damagePhotos`, `description`, `customerDispute`, `adminNotes`).
  - `DamageClaimsService` allows fleet owners to submit post-trip damage claims.
  - `AdminDisputesPage` provides a dedicated adjudication panel where Admin can:
    - Approve claim: Deducts amount from `SecurityDeposit` via `DepositsService.settleDeduction`, refunds remaining deposit to customer, and marks claim `APPROVED`.
    - Reject claim: Releases 100% of `SecurityDeposit` to customer via `DepositsService.releaseDeposit`, and marks claim `REJECTED`.
* **Hardening Required:**
  - If approved damage amount exceeds the deposit amount: record excess damage liability and flag booking for dispute recovery.
  - Settle damage deductions directly into vendor payout balance.

---

### 4. Financial Immutability & Safety Rules

1. **Tax & Fare Immutability:** Once a payment is confirmed and `Invoice` is created, the financial snapshot (`baseFare`, `platformFee`, `gstAmount`, `discountAmount`, `totalFare`) must be permanently immutable. Subsequent changes to platform commission rates or tax laws must never alter historical invoices.
2. **Unique Sequence Generation:** Invoice numbers (`INV-YYYY-MM-XXXXX`) and Credit Note numbers (`CN-YYYY-MM-XXXXX`) must use PostgreSQL sequence or atomic transactional counter with database `@unique` constraints.
3. **Escrow Separation:** Security deposits are refundable escrow funds held on behalf of customers. They must never be treated as taxable revenue or mixed with platform gross receipts.

---

## Phased Implementation Order for Phase 3

```
┌────────────────────────────────────────────────────────┐
│ Phase 3A: Database Schemas & Migrations                │
│ (Invoice, CreditNote, DepositRule models)              │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ Phase 3B: Deposit Rule Engine & Booking Integration    │
│ (Category defaults, City overrides, createBooking hook)│
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ Phase 3C: Authoritative Invoicing & PDF Generation     │
│ (InvoicesService, Sequential numbering, PDF builder)   │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ Phase 3D: Customer App Invoicing & Deposit UX          │
│ (Checkout line items, Invoice download button)         │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ Phase 3E: Vendor & Admin Financial Workflows           │
│ (Vendor statements, Admin invoice audit, Deposit rule) │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ Phase 3F: Automated Release, Reconciliation & Tests    │
│ (24h auto-release, Invoice reconciliation, unit tests) │
└────────────────────────────────────────────────────────┘
```

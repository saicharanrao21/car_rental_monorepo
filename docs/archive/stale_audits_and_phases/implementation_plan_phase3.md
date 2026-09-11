# DRIVEGO PHASE 3 IMPLEMENTATION PLAN: SECURITY DEPOSIT & INVOICING

## 1. Scope & Objective
Phase 3 implements the complete, end-to-end **Security Deposit Rule Engine** and **Authoritative Invoicing & Receipt System** for DriveGo without modifying existing payment/coupon hardening or benchmark booking safety.

---

## 2. Proposed Database Schema Changes

### A. New Models
1. **`DepositRule`**
   - Configures deposit requirements by `carCategory` and optional `city`.
   - Fields: `id`, `carCategory` (`CarCategory`), `city` (`String?`), `depositAmount` (`Decimal`), `isActive` (`Boolean @default(true)`), `createdAt`, `updatedAt`.
   - Index: `@@unique([carCategory, city])`.

2. **`Invoice`**
   - Immutable historical tax invoice generated upon payment confirmation.
   - Fields:
     - `id`: `String @id @default(cuid())`
     - `invoiceNumber`: `String @unique` (Format: `INV-2026-08-XXXXX`)
     - `bookingId`: `String @unique`
     - `paymentId`: `String`
     - `customerId`: `String`
     - `vendorId`: `String`
     - `baseFare`: `Decimal @db.Decimal(10, 2)`
     - `platformFee`: `Decimal @db.Decimal(10, 2)`
     - `gstRate`: `Decimal @default(18.00) @db.Decimal(5, 2)`
     - `gstAmount`: `Decimal @db.Decimal(10, 2)`
     - `discountAmount`: `Decimal @default(0) @db.Decimal(10, 2)`
     - `totalFare`: `Decimal @db.Decimal(10, 2)`
     - `depositAmount`: `Decimal @default(0) @db.Decimal(10, 2)`
     - `pdfUrl`: `String?`
     - `issuedAt`: `DateTime @default(now())`
     - `createdAt`: `DateTime @default(now())`
   - Relations: `booking`, `payment`, `customer`, `vendor`, `creditNotes`.

3. **`CreditNote`**
   - Immutable adjustment document for refunds, cancellation fee retainers, or damage claim settlements.
   - Fields: `id`, `creditNoteNumber` (`String @unique`), `invoiceId` (`String`), `bookingId` (`String`), `amount` (`Decimal`), `reason` (`String`), `issuedAt`, `pdfUrl`.

---

## 3. Phased Implementation Sequence

### Phase 3A: Schema Migration
- Add `DepositRule`, `Invoice`, and `CreditNote` models in `schema.prisma`.
- Run safe non-destructive migration (`prisma migrate dev`).

### Phase 3B: Authoritative Deposit Rule Engine & Booking Hook
- Create `DepositRulesService` in `car_rental_backend/src/deposits/`.
- Hook deposit calculation into `BookingsService.createBooking`:
  - Determines deposit amount based on car category (Hatchback ₹3,000, Sedan ₹4,000, SUV ₹5,000, Luxury ₹10,000) and city rules.
  - Creates associated `SecurityDeposit` row in `REQUIRED` status.

### Phase 3C: Invoicing Engine & PDF Rendering
- Create `InvoicesModule` (`invoices.service.ts`, `invoices.controller.ts`).
- Method `generateInvoiceForBooking(bookingId, tx)`:
  - Generates sequential invoice number `INV-YYYY-MM-XXXXX`.
  - Freezes exact fare snapshot.
  - Automatically triggered during `PaymentsService.verifyPayment` and `ReconciliationService`.
- PDF generation endpoint `GET /bookings/:id/invoice/pdf`.

### Phase 3D: Customer App Invoicing & Deposit UX
- Update `BookingFlowPage`: display dedicated Refundable Security Deposit line item banner in review step.
- Update `BookingDetailPage`: add "Download Tax Invoice (PDF)" action button and enriched deposit status indicator.

### Phase 3E: Vendor & Admin Financial Workflows
- Vendor App: Add "View Booking Statement & Tax Invoice" in `VendorBookingDetailPage`.
- Admin Panel: Add "Invoices & Tax Reports" page and "Security Deposit Rules" management page in `apps/admin_panel`.

### Phase 3F: Automated Release, Reconciliation & Tests
- Background cron / worker hook to auto-release deposit 24 hours after trip completion if no damage claim is active.
- Comprehensive Jest unit tests (deposit rules, invoice generation, PDF rendering, CAS concurrency).
- Flutter widget tests for customer invoice download & checkout deposit banner.

---

## 4. Verification & Regression Plan
- Run `node scratch/check_db_safety.js` (Verify benchmark booking remains untouched: `CONFIRMED` / `PAID` / `NONE`).
- Run `npx prisma validate`, `npm run build`, `npm test`.
- Run `flutter analyze`, `flutter test`.

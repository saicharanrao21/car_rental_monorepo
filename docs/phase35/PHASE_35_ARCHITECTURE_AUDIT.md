# Phase 35: Read-Only Architecture Audit
## Dynamic Pricing, Quote, Fare Calculation & Price Integrity Engine

---

## 1. Executive Summary
This document establishes the pin-to-pin architectural baseline of the DriveGo monorepo immediately prior to Phase 35 implementation, based on commit `f0f7aec092d1e49eb9186839439b2e39eb1fd8a1` (Phase 34 completed and locked).

The audit systematically reviews all financial calculations, price fields, payment amounts, fee structures, discounts, deposits, taxes, rounding rules, and pricing presentations across both backend (`car_rental_backend/`) and frontend applications (`apps/customer_app/`, `apps/vendor_app/`, `apps/admin_panel/`, `packages/models/`).

---

## 2. Inventory of Existing Pricing Infrastructure

### A. Database Models (`car_rental_backend/prisma/schema.prisma`)
1. **`Car` Model**:
   - `pricePerKm`: `Decimal @db.Decimal(10, 2)`
   - `pricePerDay`: `Decimal @db.Decimal(10, 2)`
   - `pricePerHour`: `Decimal @db.Decimal(10, 2)`
   - `weeklyDiscountPercent`: `Float? @default(0)` (percentage discount applied for rentals $\ge$ 7 days)
   - `monthlyDiscountPercent`: `Float? @default(0)` (percentage discount applied for rentals $\ge$ 30 days)
   - `mileagePackages`: Relation to `MileagePackage[]`
2. **`MileagePackage` Model**:
   - `tripType`: `TripType`
   - `name`: `String`
   - `includedKmPerDay`: `Int?` (null = unlimited)
   - `basePricePerDay`: `Decimal @db.Decimal(10, 2)`
   - `extraKmRate`: `Decimal @default(0) @db.Decimal(10, 2)`
   - `isActive`: `Boolean @default(true)`
3. **`Booking` Model**:
   - `baseFare`: `Decimal @db.Decimal(10, 2)`
   - `platformFee`: `Decimal @db.Decimal(10, 2)`
   - `gstAmount`: `Decimal @db.Decimal(10, 2)`
   - `totalFare`: `Decimal @db.Decimal(10, 2)`
   - `netToVendor`: `Decimal @db.Decimal(10, 2)`
   - `deliveryFee`, `pickupFee`, `returnFee`, `oneWayFee`: `Decimal @default(0) @db.Decimal(10, 2)`
   - `protectionFee`: `Decimal @default(0) @db.Decimal(10, 2)`
   - `protectionDeductible`: `Decimal? @db.Decimal(10, 2)`
   - `discountAmount`: `Decimal? @db.Decimal(10, 2)`
   - `couponId`, `couponCode`: Associated coupon identifiers
   - `walletDeduction`: `Decimal @default(0) @db.Decimal(10, 2)`
   - `cancellationFee`: `Decimal? @db.Decimal(10, 2)`
   - `refundAmount`: `Decimal? @db.Decimal(10, 2)`
4. **`Payment` Model**:
   - `amount`: `Decimal @db.Decimal(10, 2)`
   - `refundAmount`: `Decimal? @db.Decimal(10, 2)`
   - `currency`: `String @default("INR")`
   - `status`: `PaymentStatus` (`CREATED`, `PAID`, `FAILED`, `REFUNDED`)
   - `razorpayOrderId`, `razorpayPaymentId`, `razorpayRefundId`
5. **`SecurityDeposit` Model**:
   - `amount`: `Decimal @db.Decimal(10, 2)`
   - `refundedAmount`, `deductedAmount`: `Decimal`
   - `status`: `SecurityDepositStatus` (`REQUIRED`, `HELD`, `RELEASED`, `FORFEITED`)
6. **`Coupon` & `CouponUsage` Models**:
   - `discountType`: `PERCENTAGE` or `FLAT`
   - `discountValue`: `Decimal @db.Decimal(10, 2)`
   - `maxDiscountAmount`, `minBookingAmount`: `Decimal?`
   - `startDate`, `expiresAt`, `isActive`, `globalUsageLimit`, `perCustomerLimit`, `firstBookingOnly`
7. **`ProtectionPackage` Model**:
   - `code`: `ProtectionPlanCode` (`BASIC`, `STANDARD`, `PREMIUM`)
   - `dailyRate`: `Decimal @db.Decimal(10, 2)`
   - `deductibleAmount`, `maxCoverageAmount`: `Decimal @db.Decimal(10, 2)`
8. **`CommissionConfig` Model**:
   - `city`, `carCategory`, `tripType`: Specificity matching
   - `percentage`: `Decimal @db.Decimal(5, 2)`

---

## 3. Findings & Architectural Deficiencies

| Area | Current Reality | Architectural Deficiency / Risk | Required Phase 35 Fix |
|---|---|---|---|
| **Quote Generation** | Flutter Customer App calculates fares locally in `FareCalculatorService.calculateFare(...)` inside `fare_breakdown_step.dart`. | **Client-Side Financial Authority**: Price shown to user is computed by client code, not an authoritative backend quote. | Introduce `PricingService.generateQuote` and `POST /pricing/quote` returning canonical server quote. |
| **Quote Persistence** | No `BookingQuote` or persistent quote table exists in Prisma. | **Ephemeral Quotes**: No server record of quotes issued before booking submission. Quotes cannot be audited, verified, or expired. | Add `BookingQuote` and `BookingQuoteLineItem` models with 15-minute TTL. |
| **Historical Pricing Immutability** | Booking only stores high-level totals (`baseFare`, `totalFare`, etc.). No itemized snapshot. If vendor modifies vehicle rate, recalculating historical breakdowns yields corrupted values. | **Loss of Financial Auditability**: Line items (discounts, protection, taxes, delivery) are not frozen as an immutable structured snapshot. | Embed `priceSnapshot` JSON on `Booking` and link to immutable `BookingQuote`. |
| **Quote Expiry & Race Protection** | Client views price in UI for hours; when booking is submitted, backend silently computes a potentially different price if vehicle rate changed. | **Silent Price Drift / 409 Gap**: Customer can be charged a different amount than agreed upon during review. | Enforce 15-minute quote TTL; require `quoteId` in `CreateBookingDto`; reject expired/stale quotes. |
| **Client Fee Tampering** | `CreateBookingDto` accepts optional `deliveryFee`, `pickupFee`, `returnFee`, `oneWayFee`. | **BOLA / Manipulation Vector**: If `locationsService` fails or is mocked, client-provided fees could be written to DB. | Ignore client-supplied fees; derive strictly from server-authoritative quote. |
| **Payment Order Binding** | `PaymentsService.createOrder` takes `booking.totalFare + booking.securityDeposit.amount` directly. | **Unverified Payment Order**: No cross-check against the accepted quote to ensure booking total wasn't tampered before payment. | Verify payment order matches immutable quote total; reject discrepancies with `ConflictException`. |
| **Rounding Ambiguity** | Mixed use of `Math.round(val * 100)` and `toDecimalPlaces(2)` across files. | **Sub-paise Floating Point Drift**: Inconsistent rounding between percentage taxes, discounts, and payment gateways. | Establish canonical rounding: all calculations executed in `Decimal` with half-even or standard 2-decimal rounding; gateway in integer paise. |

---

## 4. What Can Be Reused vs What Must Be Changed

### Reused As-Is
- `CommissionResolverService`: Robust multi-level specificity scoring (`city`, `carCategory`, `tripType`).
- `DepositRulesService`: Dynamic category and city-based security deposit amounts.
- `CouponsService.validateCoupon`: Server-side coupon eligibility, limits, and discount calculations.
- `LocationsService.calculateDeliveryQuote`: Authoritative distance, delivery, pickup, return, and one-way surcharge calculations.
- `ProtectionPackagesService`: Active daily rate and deductible resolution.
- `PaymentsService`: Payment gateway order creation, webhook handling, and escrow safety.
- Phase 34 `VehicleAvailabilityService`: Interval availability check and distributed reservation mutex.

### Must Be Changed / Added
- Create dedicated `PricingService` in `src/pricing/` orchestrating all pricing factors into a single canonical engine.
- Create `BookingQuote` and `BookingQuoteLineItem` models in `schema.prisma`.
- Update `CreateBookingDto` to accept optional `quoteId`.
- Update `BookingsService.createBooking` to verify and atomically accept the quote, embedding the immutable financial snapshot.
- Update `PaymentsService.createOrder` to assert price integrity against the accepted quote.
- Update Flutter `BookingDraft` and `FareBreakdownStep` to fetch and render the authoritative backend quote instead of computing prices locally.

### What Must NOT Be Changed
- Do NOT rewrite or modify Phase 33 Booking Lifecycle State Machine or Outbox.
- Do NOT change Phase 34 availability intervals, Redis locks, or VehicleHold TTL logic.
- Do NOT alter existing payment gateway webhook signature validation or refund flows.
- Do NOT break backward compatibility for existing unit tests (support fallback quote generation when `quoteId` is omitted in test mocks).

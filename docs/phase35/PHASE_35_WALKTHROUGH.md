# DriveGo — Phase 35 Implementation Walkthrough

## Executive Summary
Phase 35 implements a canonical, server-authoritative Dynamic Pricing, Quote, Fare Calculation & Price Integrity Engine for the DriveGo car rental monorepo. This eliminates client-side financial authority, seals accepted quotes as immutable financial snapshots, enforces 15-minute quote TTLs, defends against payment amount mismatches, and preserves Phase 33 booking lifecycles and Phase 34 availability/holds invariants.

---

## Key Technical Achievements

### 1. Database Schema Additions
In `car_rental_backend/prisma/schema.prisma`:
- Added enums:
  - `QuoteStatus`: `ACTIVE`, `ACCEPTED`, `EXPIRED`, `CANCELLED`
  - `QuoteLineItemType`: `BASE_RENTAL`, `HOURLY_RENTAL`, `EXTRA_HOURS`, `DISTANCE_PACKAGE`, `EXCESS_KM`, `DOORSTEP_DELIVERY`, `DOORSTEP_COLLECTION`, `ONE_WAY_SURCHARGE`, `PICKUP_HUB_FEE`, `RETURN_HUB_FEE`, `ADDITIONAL_DRIVER`, `PROTECTION_PACKAGE`, `DURATION_DISCOUNT`, `COUPON_DISCOUNT`, `PLATFORM_FEE`, `TAX_GST`, `SECURITY_DEPOSIT`, `ADJUSTMENT`
- Added models:
  - `BookingQuote`: Contains `tenantId`, `carId`, `tripType`, `startDate`, `endDate`, `durationDays`, `durationHours`, `currency`, `pricingVersion`, `subtotal`, `discountTotal`, `feesTotal`, `taxTotal`, `depositTotal`, `tripFare`, `totalPayable`, `netToVendor`, `status`, `expiresAt`, `lineItems`, `metadata`.
  - `BookingQuoteLineItem`: Represents each granular monetary item with `type`, `name`, `rate`, `quantity`, `amount`, `isRefundable`, `displayOrder`.
  - Relations to `Car`, `Booking`, and `Tenant`.
  - Stored frozen JSON `priceSnapshot` and foreign key `quoteId` on `Booking`.

### 2. Backend Pricing Subsystem
- **Module**: `car_rental_backend/src/pricing/`
  - `pricing.types.ts`: Core pricing domain interfaces and DTOs.
  - `create-quote.dto.ts`: Input validation DTO with class-validator.
  - `pricing.service.ts`: Canonical quote calculation engine supporting:
    - Duration computation with fractional-hour rounding and minimum 1-day rental rule.
    - Weekly discount (10% for >= 7 days) and monthly discount (20% for >= 30 days).
    - Mileage package tiers and hourly local trip rates.
    - Doorstep delivery fees, return fees, and one-way relocation surcharges.
    - Protection plans (Standard vs Zero-Dep) with deductible metadata.
    - Statutory 18% GST and convenience platform fee.
    - Vehicle-tiered security deposit held in escrow.
    - 15-minute TTL enforcement and idempotent retrieval.
    - `verifyAndAcceptQuote`: Transactional verification and atomic status transition.
  - `pricing.controller.ts`: Endpoints for `POST /pricing/quote`, `GET /pricing/quote/:id`, `POST /pricing/quote/:id/refresh`.
  - `pricing.module.ts`: Registered in `app.module.ts`.

### 3. Integrated Booking & Payment Integrity
- **Bookings**: `BookingsService.create` verifies `quoteId`, transitions quote to `ACCEPTED`, stores `priceSnapshot`, and derives `totalFare`, `platformFee`, `gstAmount`, and `netToVendor` from the quote.
- **Payments**: `PaymentsService.createOrder` verifies `booking.totalFare` against the accepted quote snapshot, raising `ConflictException` if any discrepancy is detected before Razorpay order initialization.

### 4. Cross-Platform Flutter Integration
- **Shared Models (`packages/models`)**:
  - `BookingQuoteModel` and `BookingQuoteLineItemModel` defined and exported in `packages/models/lib/models.dart`.
- **Customer App (`apps/customer_app`)**:
  - `BookingRepository`, `ApiBookingRepository`, and `MockBookingRepositoryImpl` updated with `getQuote`, `refreshQuote`, `getQuoteById`.
  - `BookingDraftNotifier` fetches authoritative quotes, updates `draft.authoritativeQuote`, and provides `refreshExpiredQuote`.
  - `FareBreakdownStep` displays quote calculation status, 15-minute validity indicator, expired warning banner with refresh action, and passes authoritative quote to `BookingPriceBreakdownCard`.
  - `BookingPriceBreakdownCard` renders each authoritative line item and displays quote ID and pricing version badge.
- **Vendor App (`apps/vendor_app`)**:
  - `AddEditCarPage` incorporates server-authoritative pricing governance banner, clarifying that vehicle base rates establish future quotes and do not mutate accepted historical quotes.
- **Admin Panel (`apps/admin_panel`)**:
  - `_BookingDetailPanel` displays Canonical Pricing & Quote Integrity card, quote status, version `v1.0`, and immutable financial snapshot lock notice.

---

## Test & Verification Summary

### Backend Automated Test Suites (330 Tests Passed)
- `src/pricing/phase35-pricing.spec.ts`: 20/20 passed
- `src/bookings/`: 91/91 passed (all 10 lifecycle, extension, status, and concurrency suites)
- `src/payments/`: 81/81 passed (all 9 payment integrity, refund, reconciliation, and split suites)
- `src/payouts/`, `src/locations/`, `src/notifications/`, `src/cars/phase34-availability.spec.ts`: 138/138 passed (all 15 suites)

### Flutter Automated Test Suites
- `apps/customer_app/test/phase35_customer_pricing_test.dart`: 4/4 passed
- `apps/vendor_app/test/phase35_vendor_pricing_test.dart`: 2/2 passed
- `apps/admin_panel/test/phase35_admin_pricing_test.dart`: 2/2 passed
- `flutter analyze packages/models apps/customer_app apps/vendor_app apps/admin_panel`: **0 issues found**.

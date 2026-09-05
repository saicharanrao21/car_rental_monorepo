# Phase 35: Visual & Verification Evidence Manifest

## Overview
This manifest catalogs the real, verified evidence artifacts captured for Phase 35: Dynamic Pricing, Server-Authoritative Quote Calculation, 15-Minute Guarantee TTL & Price Integrity Engine across backend and Flutter client platforms.

---

## 1. Verified Visual Evidence Artifacts

| File Name | Description | Source / Environment | Size | Verification Status |
|---|---|---|---|---|
| `01_customer_fare_breakdown_guarantee.png` | Customer mobile app checkout flow displaying server-authoritative quote banner ("Active Guarantee • Rate Guaranteed for 15 mins"), authoritative quote badge (`v1.0`), and deterministic line items (Base Rental, Early Bird Promo, Comprehensive Protection, Platform Fee, Statutory GST 18%, and Refundable Security Deposit). | Flutter Widget Testing / Pixel-Accurate RepaintBoundary | 18,469 bytes | **CAPTURED & VERIFIED** |
| `02_customer_quote_expired_refresh.png` | Customer mobile app displaying quote expiration defense: warning banner ("Quote expired. Please refresh to lock latest rates before payment.") with interactive "Refresh" quote trigger preventing stale checkout. | Flutter Widget Testing / Pixel-Accurate RepaintBoundary | 17,065 bytes | **CAPTURED & VERIFIED** |
| `03_vendor_pricing_server_authoritative.png` | Vendor mobile app vehicle commercial configuration (`AddEditCarPage`) displaying "Server-Authoritative Pricing Active" banner and historical quote protection notice ensuring existing accepted bookings remain immutable. | Flutter Widget Testing / Pixel-Accurate RepaintBoundary | 24,886 bytes | **CAPTURED & VERIFIED** |
| `04_admin_quote_integrity_governance.png` | Admin Panel unified operations console (`AdminBookingManagementPage`) showing "Pricing & Quote Integrity Governance (Phase 35)" card with authoritative engine version (`v1.0`), accepted quote status, immutable financial ledger lock, and gateway reconciliation assertion. | Flutter Widget Testing / Pixel-Accurate RepaintBoundary | 22,633 bytes | **CAPTURED & VERIFIED** |

---

## 2. Test Execution Evidence

### A. Backend Test Execution (Car Rental Backend)
- **Phase 35 Canonical Dynamic Pricing & Quote Engine Suite**:
  - Command: `npm test -- src/pricing/phase35-pricing.spec.ts`
  - Result: `PASS` — **20 of 20 tests passed** covering duration rounding, weekly/monthly discounts, tier packages, hourly rates, location surcharges, protection plans, dynamic deposit, 15m TTL expiry, idempotency, transactional quote acceptance, and payment order price integrity defense.
- **Booking Module Regression Suites**:
  - Command: `npm test -- src/bookings/`
  - Result: `PASS` — **10 test suites passed, 91 of 91 tests passed** (including Phase 33 lifecycle transitions and outbox events).
- **Payment & Escrow Regression Suites**:
  - Command: `npm test -- src/payments/`
  - Result: `PASS` — **9 test suites passed, 81 of 81 tests passed** (including reconciliation, refund idempotency, and deposit line items).
- **Payouts Regression Suites**:
  - Command: `npm test -- src/payouts/`
  - Result: `PASS` — **2 test suites passed, 18 of 18 tests passed**.
- **Locations & Fulfillment Regression Suites**:
  - Command: `npm test -- src/locations/`
  - Result: `PASS` — **8 test suites passed, 67 of 67 tests passed**.
- **Notifications Regression Suites**:
  - Command: `npm test -- src/notifications/`
  - Result: `PASS` — **4 test suites passed, 28 of 28 tests passed**.
- **Vehicle Availability & Inventory Holds Suite**:
  - Command: `npm test -- src/cars/phase34-availability.spec.ts`
  - Result: `PASS` — **1 test suite passed, 25 of 25 tests passed**.
- **Total Backend Suites Executed**:
  - **35 test suites passed, 330 tests passed, 0 failures**.

### B. Flutter Static Analysis & Test Execution
- **Static Analysis**:
  - Command: `flutter analyze packages/models apps/customer_app apps/vendor_app apps/admin_panel`
  - Result: **0 issues found across all 4 packages (No issues found!)**.
- **Customer Pricing & Evidence Tests**:
  - Command: `flutter test apps/customer_app/test/phase35_customer_pricing_test.dart`
  - Result: **4 of 4 tests passed**.
  - Command: `flutter test apps/customer_app/test/phase35_evidence_capture_test.dart`
  - Result: **2 of 2 tests passed**.
- **Vendor Pricing & Governance Tests**:
  - Command: `flutter test apps/vendor_app/test/phase35_vendor_pricing_test.dart`
  - Result: **2 of 2 tests passed**.
  - Command: `flutter test apps/vendor_app/test/phase35_evidence_capture_test.dart`
  - Result: **1 of 1 test passed**.
- **Admin Pricing Governance Tests**:
  - Command: `flutter test apps/admin_panel/test/phase35_admin_pricing_test.dart`
  - Result: **2 of 2 tests passed**.
  - Command: `flutter test apps/admin_panel/test/phase35_evidence_capture_test.dart`
  - Result: **1 of 1 test passed**.

---

## 3. Production Build Artifacts

1. **Customer App Debug APK**:
   - Location: `apps/customer_app/build/app/outputs/flutter-apk/app-debug.apk`
   - Build Tool: Flutter 3.29.0 / Android Gradle Plugin 8.11.1
   - Verification: `√ Built build\app\outputs\flutter-apk\app-debug.apk` (assembleDebug completed in 93.3s)
2. **Vendor App Debug APK**:
   - Location: `apps/vendor_app/build/app/outputs/flutter-apk/app-debug.apk`
   - Build Tool: Flutter 3.29.0 / Android Gradle Plugin 8.11.1
   - Verification: `√ Built build\app\outputs\flutter-apk\app-debug.apk` (assembleDebug completed in 82.4s)
3. **Admin Panel Web Production Bundle**:
   - Location: `apps/admin_panel/build/web`
   - Contents: `flutter.js`, `main.dart.js`, `index.html`, canvaskit assets
   - Verification: `√ Built build\web` (completed in 128.8s)

---

## 4. Verification Checklist

- [x] Server-authoritative quote calculation engine active at `POST /pricing/quote`.
- [x] Quote duration calculation with 24-hour day boundary rules and hourly local fallback verified.
- [x] Weekly (10%) and Monthly (20%) volume discounts applied deterministically.
- [x] Location fulfillment surcharges (doorstep delivery, one-way relocate) bound to quote.
- [x] 15-minute quote TTL enforced via database query and runtime validation.
- [x] Idempotent quote creation via `idempotencyKey` supported.
- [x] Mismatch defense in `BookingsService.create`: quote verified, carId confirmed, quote transitioned to `ACCEPTED`, and `priceSnapshot` committed to booking.
- [x] Gateway amount mismatch defense in `PaymentsService.createOrder`: booking total verified against accepted quote snapshot before creating Razorpay/Cashfree order.
- [x] Customer app renders active guarantee banner and handles expired quotes with refresh button.
- [x] Vendor app displays server-authoritative active notice and protects historical bookings.
- [x] Admin console inspects quote ledger and asserts cryptographic financial integrity.
- [x] Zero analyzer errors across all monorepo Flutter packages and apps.

# Phase 36: Requirements Gap Matrix
## Payment & Financial Transaction Integrity Engine

**Document Status:** Complete & Audited  
**Author:** Senior Principal Engineer / CTO  
**Date:** September 2026  

---

## 1. Classification Methodology

To maintain rigorous transparency, every requirement is audited and categorized into one of six canonical classifications:

1. **IMPLEMENTED**: Built new specifically for Phase 36 and verified.
2. **HARDENED**: Existed prior to Phase 36, audited, upgraded, patched, and verified against regressions.
3. **EXISTING & VERIFIED**: Already completely implemented in earlier phases, tested and confirmed operational.
4. **NOT IMPLEMENTED**: Intentionally deferred or out of scope for Phase 36.
5. **EXTERNAL DEPENDENCY**: Requires third-party cloud infrastructure or external merchant credentials.
6. **POLICY DEPENDENCY**: Requires executive business decisions or legal terms beyond technical code.

---

## 2. Comprehensive Requirements Matrix

| Requirement | Category | Status | Implementation Details / Audit Reference |
|---|---|---|---|
| **Prisma Financial Schema Extension** | Data Model | **IMPLEMENTED** | Added `EXPIRED` to `PaymentStatus` enum; added `tenantId`, `gatewayAmountPaise`, `metadata` to `Payment`; added `tenantId` to `PaymentRefund`; created append-only `PaymentAuditLog` model with relational indexes. |
| **Elimination of Payment Row Deletion** | Data Integrity | **IMPLEMENTED** | Removed `prisma.payment.delete` in `PaymentsService.createOrder`; retrying orders updates existing payment record in-place and preserves gateway references. |
| **Canonical Payment State Machine** | Core Domain | **IMPLEMENTED** | Added `assertValidTransition(from, to)` in `PaymentsService`; strictly rejects invalid state transitions (`PAID -> FAILED`, `REFUNDED -> PAID`, `PROCESSED -> PENDING`). |
| **Append-Only Payment Audit Log** | Audit & Governance | **IMPLEMENTED** | Added `recordPaymentAuditLog` in `PaymentsService` tracking `eventType`, `fromStatus`, `toStatus`, `actorId`, `source`, and `payloadHash`. |
| **Vendor-Safe Payment Inspection Endpoint** | API & Security | **IMPLEMENTED** | Added `GET /payments/vendor/:bookingId` in `PaymentsController` and `PaymentsService.getVendorPaymentByBookingId`; provides net vendor earnings while strictly redacting customer secrets. |
| **Admin Payment Audit History Endpoint** | API & Governance | **IMPLEMENTED** | Added `GET /payments/:bookingId/audit-logs` in `PaymentsController` and `PaymentsService.getPaymentAuditLogs` for `Role.ADMIN` and `Role.SUPPORT_AGENT`. |
| **Shared Frontend Payment & Audit Models** | Shared Package | **IMPLEMENTED** | Added `PaymentAuditLogModel`, `VendorPaymentSummaryModel`, and `isExpired`/`isAuthorized` getters in `packages/models/lib/src/payment_order_model.dart`. |
| **Customer App Expired Payment Handling** | Customer App | **HARDENED** | Added `ORDER EXPIRED` badge in `BookingDetailPricingCard` in `apps/customer_app/lib/features/my_bookings/presentation/widgets/booking_detail_pricing_card.dart`. |
| **Admin Governance Panel Flex Resilience** | Admin Panel | **HARDENED** | Wrapped unconstrained detail labels in `Flexible` widgets in `apps/admin_panel/lib/features/bookings/presentation/pages/admin_booking_management_page.dart` to prevent render overflow. |
| **Phase 36 Automated Test Suite (Backend)** | Testing | **IMPLEMENTED** | Created `car_rental_backend/src/payments/phase36-payment-integrity.spec.ts` (27 tests covering orders, webhooks, state machine, refunds, reconciliation, security). |
| **Phase 36 Flutter Test Suites** | Testing | **IMPLEMENTED** | Created `phase36_customer_payment_integrity_test.dart` (Customer), `phase36_vendor_financial_visibility_test.dart` (Vendor), and `phase36_admin_payment_governance_test.dart` (Admin). |
| **Phase 35 Price Integrity & Quote Invariant** | Integrity | **EXISTING & VERIFIED** | Verified `createOrder` enforces quote match (`|quote.totalPayable - totalAmount| < 0.05`). Tested in `phase35-pricing.spec.ts` (20 tests passed). |
| **Phase 34 Vehicle Availability & Mutex** | Concurrency | **EXISTING & VERIFIED** | Interval booking overlaps and Redis reservation locks verified intact. Tested in `phase33-booking-lifecycle.spec.ts` (20 tests passed). |
| **Razorpay HMAC Signature Verification** | Webhook Security | **EXISTING & VERIFIED** | `validatePaymentVerification` and `Razorpay.validateWebhookSignature` verified with test suites. |
| **Webhook Deduplication** | Webhook Security | **EXISTING & VERIFIED** | Unique `WebhookEvent.eventId` constraint intercepts duplicates (`P2002`) and returns `{ received: true, duplicate: true }`. |
| **Refund Over-Refund Protection** | Financial Safety | **EXISTING & VERIFIED** | `PaymentsService.refund` asserts `refundAmount <= payment.amount`. Over-refund rejected with `400 Bad Request`. |
| **Automated Financial Reconciliation Cron** | Operations | **EXISTING & VERIFIED** | `FinancialReconciliationService` runs 15-minute cron with distributed Redis lock; auto-heals orphaned refunds and unconfirmed paid bookings. |
| **Real Razorpay Production Merchant Account** | Gateway | **EXTERNAL DEPENDENCY** | Real production payment capture requires live Razorpay API credentials (`RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`) from Razorpay dashboard. |
| **Cashfree / Secondary Gateway Integration** | Gateway | **NOT IMPLEMENTED** | Architecture supports secondary gateway via `gatewayProvider` string column; active adapter is currently Razorpay. Secondary adapter deferred to multi-gateway expansion phase. |
| **Automated Bank Payout Settlement Policies** | Finance Policy | **POLICY DEPENDENCY** | Schedule for sweeping escrow into vendor bank accounts (e.g. T+2 vs T+7 after trip completion) is defined by business operations. |
| **Cancellation Fee Tier Governance** | Business Policy | **POLICY DEPENDENCY** | Penalty percentages (e.g. 0% for >24h, 25% for 12-24h, 100% for <2h) are governed by terms of service and resolved via project cancellation configuration. |

---

## 3. Summary of Status

- **Implemented & Hardened Capabilities:** 11 items
- **Existing & Verified Invariants:** 6 items
- **External Dependencies:** 1 item (Razorpay live merchant API credentials)
- **Policy Dependencies:** 2 items (Settlement schedule & cancellation percentage tiers)
- **Not Implemented / Deferred:** 1 item (Cashfree secondary gateway adapter)

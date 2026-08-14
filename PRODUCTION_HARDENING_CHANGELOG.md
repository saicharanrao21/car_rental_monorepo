# Production Hardening Changelog

## 2026-08-14 — Phase 1: Production Configuration, Security Baseline & RBAC Standardization

### Task
Implement Phase 1 production hardening focusing strictly on environment validation, security baseline headers, cryptographic JWT verification, rate limiting, and RBAC standardization for the `SUPPORT_AGENT` role.

### Files Changed
- `car_rental_backend/src/common/env.validation.ts` (NEW)
- `car_rental_backend/src/common/decorators/rate-limit.decorator.ts` (NEW)
- `car_rental_backend/src/common/guards/rate-limiter.guard.ts` (NEW)
- `car_rental_backend/src/common/env.validation.spec.ts` (NEW)
- `car_rental_backend/src/auth/jwt-security.spec.ts` (NEW)
- `car_rental_backend/src/common/guards/rate-limiter.guard.spec.ts` (NEW)
- `car_rental_backend/src/auth/rbac-support-agent.spec.ts` (NEW)
- `car_rental_backend/src/app.module.ts` (MODIFIED)
- `car_rental_backend/src/main.ts` (MODIFIED)
- `car_rental_backend/.env.example` (MODIFIED)
- `car_rental_backend/src/cars/cars.controller.ts` (MODIFIED)
- `car_rental_backend/src/vendors/vendors.controller.ts` (MODIFIED)
- `car_rental_backend/src/auth/auth.controller.ts` (MODIFIED)
- `car_rental_backend/src/payments/payments.controller.ts` (MODIFIED)
- `car_rental_backend/src/payments/payments.service.ts` (MODIFIED)
- `car_rental_backend/src/bookings/bookings.controller.ts` (MODIFIED)
- `car_rental_backend/src/bookings/bookings.service.ts` (MODIFIED)
- `car_rental_backend/src/disputes/admin-disputes.controller.ts` (MODIFIED)
- `car_rental_backend/src/disputes/disputes.service.ts` (MODIFIED)
- `car_rental_backend/src/users/users.controller.ts` (MODIFIED)
- `car_rental_backend/package.json` (MODIFIED - added `helmet`)

### Database Changes
`None`

### API Changes
1. Added HTTP security headers (`Helmet`: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Strict-Transport-Security`, etc.) to all HTTP responses.
2. Dynamic environment-configured CORS allowed origins (`CORS_ALLOWED_ORIGINS`).
3. Added rate limiting on sensitive public authentication routes (`/auth/otp/send` [5/min], `/auth/otp/verify` [10/min], `/auth/register` [10/min], `/auth/refresh` [30/min]) and payment routes (`/payments/create-order` [15/min], `/payments/webhook` [120/min]) returning HTTP 429 when exceeded.
4. Cryptographic JWT signature verification (`jwtService.verifyAsync`) enforced on `GET /cars` and `GET /vendors` admin visibility checks.
5. Standardized `SUPPORT_AGENT` role read access on read endpoints.

### Tests Added
- 23 new unit tests across 4 test suites.

### Validation Performed
- `npm test`: 5 test suites passed, 24 tests passed (100% pass rate).
- `npm run build`: Compiled TypeScript with 0 compilation errors.

---

## 2026-08-14 — Phase 2A: Production SMS OTP Integration & OTP Security Hardening

### Task
Implement production MSG91 SMS gateway integration behind the `SmsProviderService` abstraction, dynamic provider selection (MSG91 in production vs Mock in development), strict SMS configuration validation, OTP failure handling with controlled HTTP 502, and OTP lifecycle hardening.

### Files Changed
- `car_rental_backend/src/auth/msg91-sms-provider.service.ts` (NEW)
- `car_rental_backend/src/auth/msg91-sms-provider.spec.ts` (NEW)
- `car_rental_backend/src/auth/sms-provider-selection.spec.ts` (NEW)
- `car_rental_backend/src/auth/otp-lifecycle.spec.ts` (NEW)
- `car_rental_backend/src/auth/sms-provider.service.ts` (MODIFIED)
- `car_rental_backend/src/auth/auth.module.ts` (MODIFIED)
- `car_rental_backend/src/auth/otp.service.ts` (MODIFIED)
- `car_rental_backend/src/common/env.validation.ts` (MODIFIED)
- `car_rental_backend/src/common/env.validation.spec.ts` (MODIFIED)
- `car_rental_backend/.env.example` (MODIFIED)

### Database Changes
`None`

### API Changes
1. `POST /auth/otp/send`: In the event of an upstream SMS gateway dispatch failure, returns controlled `HTTP 502 Bad Gateway` instead of false positive 200, and immediately invalidates the un-dispatched OTP database record.
2. Issuing a new OTP automatically expires all previous active unverified OTPs for that phone number.

### Tests Added
- Total test suite expanded to 8 suites and 41 passing tests.

### Validation Performed
- `npm test`: 8 test suites passed, 41 tests passed (100% pass rate).
- `npm run build`: Compiled TypeScript with 0 compilation errors.

---

## 2026-08-14 — Phase 2B: Production Wiring & Unsafe Production Mock Fallback Removal

### Task
Eliminate silent mock fallback across all production backend services (Razorpay, FCM, R2, Redis) so that failures fail safely and loudly in production while preserving dev/test convenience. Complete Flutter → Backend production wiring by removing test/mock endpoints (`/payments/confirm-test-payment`) and removing `package:mock_data` usage from all user-facing pages and providers.

### Files Changed
- `car_rental_backend/src/payments/payments.service.ts` (MODIFIED)
- `car_rental_backend/src/notifications/fcm.service.ts` (MODIFIED)
- `car_rental_backend/src/uploads/uploads.service.ts` (MODIFIED)
- `car_rental_backend/src/redis/redis.module.ts` (MODIFIED)
- `car_rental_backend/src/common/env.validation.ts` (MODIFIED)
- `car_rental_backend/src/common/env.validation.spec.ts` (MODIFIED)
- `car_rental_backend/src/payments/payments-mock-fallback.spec.ts` (NEW)
- `car_rental_backend/src/uploads/uploads-mock-fallback.spec.ts` (NEW)
- Flutter pages and repositories across `customer_app`, `vendor_app`, and `admin_panel` (MODIFIED).

### Database Changes
`None`

### Validation Performed
- Backend `npm test`: 10 test suites passed, 48 tests passed.
- Backend `npm run build`: Compiled TypeScript with 0 compilation errors.
- Flutter `apps/customer_app` `flutter test`: 3/3 tests passed.

---

## 2026-08-14 — Phase 3A: Razorpay Payment Integrity & Server-Side Booking Confirmation

### Task
Implement strict server-side cryptographic payment verification (`POST /payments/verify`), authoritative amount/currency/booking-order binding checks, idempotent webhook handling, duplicate payment protection, and Flutter client verification wiring without client-side fake success navigation.

### Files Changed
- `car_rental_backend/src/payments/dto/verify-payment.dto.ts` (NEW)
- `car_rental_backend/src/payments/payments-verification.spec.ts` (NEW)
- `car_rental_backend/src/payments/payments.service.ts` (MODIFIED)
- `car_rental_backend/src/payments/payments.controller.ts` (MODIFIED)
- `apps/customer_app/lib/features/booking/presentation/widgets/payment_step.dart` (MODIFIED)
- `apps/customer_app/test/payment_step_test.dart` (MODIFIED)

### Database Changes
`None`

### API Changes
1. `POST /payments/verify`: Added authenticated endpoint for customers to submit Razorpay checkout identifiers with HMAC SHA-256 validation, API verification, and strict `captured` status enforcement.
2. `POST /payments/webhook`: Hardened webhook processing with amount and currency checks, and safe idempotent skipping for already-captured payments.

### Validation Performed
- Backend `npm test`: 11 test suites passed, 64 tests passed.
- Backend `npm run build`: Compiled TypeScript with 0 compilation errors.
- Flutter `apps/customer_app` `flutter test`: 3/3 tests passed.

---

## 2026-08-14 — Phase 3B: Refund & Cancellation Integrity

### Task
Implement production-grade cancellation policy engine, deterministic partial/full refunds with Razorpay `X-Refund-Idempotency`, refund webhook settlement handling (`refund.processed`, `refund.failed`, `refund.created`), cancellation preview endpoint (`GET /bookings/:id/cancellation-preview`), and Flutter cancellation preview breakdown UI.

### Files Changed
- `car_rental_backend/prisma/schema.prisma` (MODIFIED - added `RefundStatus` enum, refund tracking fields to `Payment` and `Booking`)
- `car_rental_backend/src/bookings/cancellation-policy.service.ts` (NEW)
- `car_rental_backend/src/bookings/cancellation-policy.spec.ts` (NEW)
- `car_rental_backend/src/payments/refunds.spec.ts` (NEW)
- `car_rental_backend/src/bookings/bookings.service.ts` (MODIFIED)
- `car_rental_backend/src/bookings/bookings.controller.ts` (MODIFIED)
- `car_rental_backend/src/bookings/bookings.module.ts` (MODIFIED)
- `car_rental_backend/src/payments/payments.service.ts` (MODIFIED)
- `apps/customer_app/lib/features/my_bookings/domain/repositories/my_bookings_repository.dart` (MODIFIED)
- `apps/customer_app/lib/features/my_bookings/data/api_my_bookings_repository.dart` (MODIFIED)
- `apps/customer_app/lib/features/my_bookings/data/mock_my_bookings_repository.dart` (MODIFIED)
- `apps/customer_app/lib/features/my_bookings/presentation/pages/booking_detail_page.dart` (MODIFIED)
- `apps/customer_app/test/cancellation_preview_test.dart` (NEW)

### Database Changes
- Added enum `RefundStatus` (`NONE`, `PENDING`, `PROCESSED`, `FAILED`).
- Added to `Payment`: `razorpayRefundId String? @unique`, `refundAmount Decimal?`, `refundStatus RefundStatus @default(NONE)`, index on `razorpayRefundId`.
- Added to `Booking`: `cancellationFee Decimal?`, `refundAmount Decimal?`, `cancelledAt DateTime?`, `cancelledBy String?`.

### API Changes
1. `GET /bookings/:id/cancellation-preview` (CUSTOMER, VENDOR, ADMIN, SUPPORT_AGENT):
   - Computes authoritative hours remaining, policy tier, cancellation fee percentage & amount, and refund percentage & amount in INR.
2. `POST /bookings/:id/cancel` (CUSTOMER):
   - Evaluates policy engine, executes partial or full refund with Razorpay `X-Refund-Idempotency` header (`refund_${bookingId}_${payment.id}`), persists refund metadata, and transactionally updates booking state.
3. `POST /payments/webhook`:
   - Added handlers for `refund.created` (marks `PENDING`), `refund.processed` (marks `PROCESSED`, updates `PaymentStatus.REFUNDED`, notifies customer), and `refund.failed` (marks `FAILED`).

### Tests Added
- `src/bookings/cancellation-policy.spec.ts` (8 tests)
- `src/payments/refunds.spec.ts` (8 tests)
- `src/redis/cancellation-lock.spec.ts` (3 tests)
- `apps/customer_app/test/cancellation_preview_test.dart` (1 test)
- Total backend test suite: **14 test suites, 83 passing tests (100% pass rate)**.
- Total Flutter customer_app test suite: **4 test suites, 4 passing tests (100% pass rate)**.

### Validation Performed
- Backend `npm test`: 14 test suites passed, 83 tests passed.
- Backend `npm run build`: Compiled TypeScript with 0 compilation errors.
- Flutter `apps/customer_app` `flutter test`: 4/4 tests passed.
- Flutter `apps/customer_app` `flutter analyze`: Verified analysis.

---

## 2026-08-14 — Verified Production Hardening Checkpoint (Phases 2A, 2B, 3A, 3B)

### Checkpoint Summary
- **Phase 2A Complete**: MSG91 production SMS OTP provider behind abstraction, OTP invalidation on new request, controlled 502 on SMS gateway failures, production SMS env validation.
- **Phase 2B Complete**: Eliminated silent mock fallback in production across Razorpay, FCM, R2, and Redis. Removed `/payments/confirm-test-payment` and cleaned mock UI data bindings.
- **Phase 3A Complete**: Server-side cryptographic payment verification (`POST /payments/verify`), authoritative amount/currency validation, order-booking binding, captured-only booking confirmation, idempotent webhooks.
- **Phase 3B Complete**: Authoritative cancellation policy engine, deterministic partial/full refunds with Razorpay `X-Refund-Idempotency`, refund webhook listeners, cancellation preview endpoint, distributed Redis cancellation lock, and Prisma migration SQL (`20260814060900_add_refund_and_cancellation_tracking`).
- **All 14 backend test suites (83 tests) and Flutter customer app test suites (4 tests) passing 100%. Backend TypeScript compilation passes with 0 errors.**


# Out of Scope Findings Log

## Finding 1: Unverified Razorpay Client Success Navigation
- **Location**: `apps/customer_app/lib/features/booking/presentation/widgets/payment_step.dart:107-111`
- **Severity**: Critical
- **Problem**: In the event that payment polling fails or returns unconfirmed, the customer app invokes `widget.onSuccess(bookingId)` and routes to confirmation screen anyway.
- **Why it matters**: A customer could obtain a confirmed booking status on the client side without verified server-side payment capture.
- **Recommended future action**: Prevent navigation to success until server returns confirmed payment status, and show a pending/failed payment screen with retry option.
- **NOT IMPLEMENTED**: Yes

## Finding 2: Razorpay Mock Fallback in Production
- **Location**: `car_rental_backend/src/payments/payments.service.ts:44-46,129-131`
- **Severity**: Critical
- **Problem**: If Razorpay initialization fails on boot, `useMock` is set to `true`, allowing `mock_signature` to simulate payments and bypassing real transactions.
- **Why it matters**: Severe financial loss if production server encounters transient Razorpay SDK initialization failure.
- **Recommended future action**: Throw a fatal initialization exception in production mode and reject mock signatures.
- **NOT IMPLEMENTED**: Yes

## Finding 3: Plaintext Vendor Bank Account Details at Rest
- **Location**: `car_rental_backend/prisma/schema.prisma:135`, `car_rental_backend/src/auth/auth.service.ts:163`
- **Severity**: High
- **Problem**: Vendor bank details are stored as raw unencrypted strings in PostgreSQL.
- **Why it matters**: Violates financial data protection standards (RBI / GDPR / DPDP) and exposes sensitive financial identifiers on database compromise.
- **Recommended future action**: Introduce structured encrypted columns with AES-256-GCM encryption at rest.
- **NOT IMPLEMENTED**: Yes

## Finding 4: Publicly Accessible Vendor KYC Documents on CDN
- **Location**: `car_rental_backend/src/uploads/uploads.service.ts:78`
- **Severity**: High
- **Problem**: Sensitive KYC files (RC Book, Trade License, Insurance) are assigned public Cloudflare R2 URLs directly.
- **Why it matters**: Private identity and regulatory documents can be viewed or enumerated by unauthorized third parties.
- **Recommended future action**: Store KYC documents in a private bucket/prefix and generate time-limited presigned GET URLs with RBAC authorization.
- **NOT IMPLEMENTED**: Yes

## Finding 5: Flawed Redis Date-Range Booking Concurrency Lock
- **Location**: `car_rental_backend/src/redis/booking-lock.service.ts:13`
- **Severity**: Critical
- **Problem**: Redis lock keys use exact date strings (`lock:car:${carId}:${startDate.toISOString()}:${endDate.toISOString()}`), meaning overlapping date ranges generate different keys and do not lock each other.
- **Why it matters**: Two users requesting overlapping dates simultaneously can bypass the Redis lock and cause double bookings.
- **Recommended future action**: Implement car-level Redis distributed locking (`lock:car:${carId}`) and PostgreSQL `SELECT ... FOR UPDATE` row locks.
- **NOT IMPLEMENTED**: Yes

## Finding 6: Unconditional 100% Full Refunds on All Cancellations
- **Location**: `car_rental_backend/src/bookings/bookings.service.ts:475`
- **Severity**: High
- **Problem**: `cancelBooking` unconditionally issues a 100% refund regardless of time remaining before trip start.
- **Why it matters**: Vendors are uncompensated for late customer cancellations (e.g. 1 hour before pickup or no-show).
- **Recommended future action**: Implement a tiered cancellation fee policy engine based on hours remaining until trip pickup.
- **NOT IMPLEMENTED**: Yes

## Finding 7: Mock SMS Provider Hardcoded in AuthModule
- **Location**: `car_rental_backend/src/auth/auth.module.ts:21`
- **Severity**: Critical
- **Problem**: `AuthModule` binds `SmsProviderService` to `MockSmsProvider`, which only logs OTP to `console.log`.
- **Why it matters**: Prevents actual SMS OTP delivery to mobile devices in production.
- **Recommended future action**: Integrate production SMS gateway provider (Twilio, MSG91, 2Factor, or AWS SNS).
- **NOT IMPLEMENTED**: Yes

## Finding 8: Missing Automated Vehicle Inspection & Handover Workflow
- **Location**: `car_rental_backend/src/bookings/bookings.service.ts:427-434`
- **Severity**: High
- **Problem**: Trips transition to `ONGOING` and `COMPLETED` without pre-trip and post-trip odometer readings, fuel gauge level, inspection photo checklist, or handover OTP.
- **Why it matters**: Causes dispute ambiguity regarding mileage overage, fuel refill charges, and vehicle damages.
- **Recommended future action**: Introduce `BookingInspection` model with handover OTP and pre/post-trip checklist.
- **NOT IMPLEMENTED**: Yes

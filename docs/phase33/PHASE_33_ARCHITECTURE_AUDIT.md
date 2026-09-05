# DRIVEGO — PHASE 33 ARCHITECTURE AUDIT
## Canonical Booking Lifecycle Orchestration, Outbox Architecture & State Machine

**Auditor**: Principal Software Architect, CTO, Senior NestJS/Flutter Engineer, Security & QA Lead  
**Baseline**: Phase 30 (Payment/Escrow/Refunds), Phase 31 (Notifications), Phase 32 (Real-Time Subsystem & Device Lifecycle)  
**Date**: September 2026  
**Repository**: `d:\Flutter\car_rental_monorepo`  
**Git Baseline**: Commit `284a2798cc14ca4f1e6e4ced67f4dd7e17914a0b` (Clean, `HEAD == origin/main`)

---

### Executive Summary

Phase 33 addresses the core operational spine of DriveGo: **Canonical Booking Lifecycle Orchestration**. 
While previous phases established vehicle search, booking creation, payment verification, fulfillment snapshots, refund idempotency, multi-channel notifications, and SSE streaming, booking mutations have historically been scattered across multiple controllers, helper methods, and services without a single authoritative lifecycle engine.

This audit evaluates the current booking state machine, payment/escrow coupling, fulfillment dependencies, concurrency risks, event persistence, and client synchronization across Customer, Vendor, and Admin platforms.

---

### 1. Existing Booking Lifecycle

Currently, bookings undergo the following general progression:
1. **Creation**: Customer requests a booking (`POST /bookings`), placing the booking in `PENDING` status and calculating fares, commissions, delivery fees, and mileage tiers.
2. **Payment**: Customer pays via Razorpay (`POST /payments/verify` or webhook `payment.captured`). Payment status moves to `PAID`, security deposit moves to `HELD`, but the booking deliberately remains in `PENDING` status due to the Phase 23A Owner Confirmation Gate.
3. **Vendor Confirmation**: Fleet vendor reviews and accepts the booking (`PATCH /bookings/:id/status` with `status: CONFIRMED`).
4. **Handover Preparation**: Pre-trip vehicle inspection is performed (`POST /bookings/:id/inspections`), pickup OTP is generated and dispatched to customer (`POST /bookings/:id/handover-otp/send`), transitioning to `HANDOVER_READY`.
5. **Rental Activation**: Customer presents pickup OTP; vendor verifies OTP (`PATCH /bookings/:id/status` with `status: ONGOING`). Pre-trip inspection must be finalized.
6. **Return Initiation**: As rental concludes, booking enters `RETURN_PENDING`.
7. **Trip Completion**: Post-trip 360-degree inspection is finalized, return OTP is verified, damage claims/disputes are audited, transitioning to `COMPLETED`.
8. **Cancellation / Expiry**: If cancelled by customer/vendor/admin before trip start, cancellation policy applies tier-based penalties and processes refunds, transitioning to `CANCELLED`. If unconfirmed within timeout, transitions to `EXPIRED`.

---

### 2. Existing States (`enum BookingStatus`)

In `prisma/schema.prisma` (lines 123–135), the authoritative database enum defines 11 statuses:
- `PENDING`: Booking created, awaiting payment and/or vendor confirmation.
- `CONFIRMED`: Payment confirmed and vendor accepted; vehicle reserved.
- `HANDOVER_READY`: Vehicle prepared at hub, pre-trip inspection recorded, pickup OTP issued.
- `ONGOING`: Customer pickup OTP verified, vehicle handed over, rental in progress.
- `RETURN_PENDING`: Rental return initiated, vehicle returned to hub/doorstep, awaiting post-trip inspection.
- `COMPLETED`: Post-trip inspection finalized, return OTP verified, trip concluded cleanly.
- `CANCELLED`: Booking cancelled by customer, vendor, or administrator.
- `REFUND_PENDING`: Cancellation processed, refund awaiting payment gateway clearance.
- `REFUNDED`: Refund fully processed and verified.
- `DISPUTED`: Open dispute or damage claim active against the booking.
- `EXPIRED`: Unconfirmed booking timed out before payment/confirmation.

---

### 3. Existing Transition Logic

Currently housed in `car_rental_backend/src/bookings/bookings.service.ts`:
- **`validateStatusTransition(current, target)`**:
  - `PENDING` $\rightarrow$ `CONFIRMED`, `CANCELLED`, `EXPIRED`
  - `CONFIRMED` $\rightarrow$ `HANDOVER_READY`, `ONGOING`, `CANCELLED`, `REFUND_PENDING`
  - `HANDOVER_READY` $\rightarrow$ `ONGOING`, `CANCELLED`
  - `ONGOING` $\rightarrow$ `RETURN_PENDING`, `COMPLETED`
  - `RETURN_PENDING` $\rightarrow$ `COMPLETED`, `DISPUTED`
  - `REFUND_PENDING` $\rightarrow$ `REFUNDED`, `DISPUTED`
  - `DISPUTED` $\rightarrow$ `COMPLETED`, `REFUND_PENDING`, `REFUNDED`
  - Terminal States: `COMPLETED`, `REFUNDED`, `CANCELLED`, `EXPIRED` have empty transition targets.
- **`getAllowedNextStates(current, role)`**:
  - Customer: Allowed to transition `PENDING` or `CONFIRMED` to `CANCELLED`.
  - Vendor: Allowed to transition `PENDING` $\rightarrow$ `CONFIRMED`/`CANCELLED`; `CONFIRMED` $\rightarrow$ `HANDOVER_READY`/`ONGOING`/`CANCELLED`; `HANDOVER_READY` $\rightarrow$ `ONGOING`/`CANCELLED`; `ONGOING` $\rightarrow$ `RETURN_PENDING`/`COMPLETED`; `RETURN_PENDING` $\rightarrow$ `COMPLETED`.
  - Admin: Full override access with required justification and audit log creation.

---

### 4. Existing Payment Dependencies

1. **Payment Gate on Confirmation**: `updateStatus` checks if payment status is `PAID`. Non-admin cannot confirm an unpaid booking.
2. **Security Deposit Hold**: `SecurityDeposit` record is linked to `Booking`. Upon payment capture, status becomes `HELD`.
3. **Cancellation Refund Coupling**: When transitioning to `CANCELLED`, `cancellationPolicyService.calculateCancellation()` derives refund amounts; `paymentsService.refund()` executes the refund via Razorpay or marks it `REFUND_PENDING`.
4. **Escrow Quarantine on Completion**: In `payouts.service.ts`, vendor earnings are derived only from `status === 'COMPLETED'` bookings where `payment.status === 'PAID'`. Disputed bookings (`disputeFlag === true` or open damage claims) are quarantined in escrow and withheld from payout balance.

---

### 5. Existing Fulfillment Dependencies

1. **Pickup Hub & Delivery Snapshot**: Booking contains 13 immutable fulfillment snapshot fields (`pickupLocation`, `dropLocation`, `pickupHubId`, `returnHubId`, `deliveryAddress`, `deliveryLatitude`, `deliveryLongitude`, `deliveryFee`, `oneWayFee`, etc.).
2. **Pre-Trip Inspection Invariant**: Transition to `ONGOING` strictly requires a `finalized: true` `Inspection` row with `type: PRE_TRIP`.
3. **Pickup OTP Invariant**: Transition to `ONGOING` strictly requires verification of the 6-digit `HandoverOtp` (`type: PICKUP`).
4. **Post-Trip Inspection Invariant**: Transition to `COMPLETED` strictly requires a `finalized: true` `Inspection` row with `type: POST_TRIP` and monotonic odometer validation.
5. **Return OTP Invariant**: Transition to `COMPLETED` strictly requires verification of the 6-digit `HandoverOtp` (`type: RETURN`).

---

### 6. Existing Notification Integration

- In `bookings.service.ts`: Mutations invoke `this.notificationsService.notifyUser(userId, title, body)`.
- **Gap Identified**: Direct calls to `notifyUser()` do not pass structured operational variables (`bookingId`, `vehicleName`, `registrationNumber`, `pickupAddress`, `pickupTime`, `actionUrl`), nor do they create canonical `NotificationDelivery` telemetry records for SMS, WhatsApp, and Push fan-out.
- **Phase 33 Target**: Must bridge through `NotificationOrchestratorService.publishEvent()` using canonical `OperationalEventType` definitions (`BOOKING_CREATED`, `BOOKING_CONFIRMED`, `BOOKING_CANCELLED`, `HANDOVER_READY`, `TRIP_STARTED`, `RETURN_PENDING`, `BOOKING_COMPLETED`).

---

### 7. Existing Event Infrastructure

- **BullMQ Queues**: `drivego-notifications-queue`, `drivego-webhooks-queue`, `drivego-reconciliation-queue`, `drivego-cleanup-queue`, `drivego-analytics-queue`.
- **SSE Real-Time Stream**: `NotificationRealtimeService` provides `@Sse('notifications/stream')` with user-partitioned events and 30s heartbeats.
- **Transactional Outbox**: **MISSING**. No transactional outbox table exists in Prisma. If the database updates successfully but asynchronous network dispatch fails, domain events are lost.

---

### 8. Transaction Boundaries

- Currently, `createBooking` executes inside `this.prisma.$transaction` with a Redis lock.
- However, in `updateStatus`:
  - Fetching the booking occurs outside a transaction.
  - Verification of inspections and OTPs occurs outside a transaction.
  - Payment refund execution occurs outside a transaction.
  - The booking status update occurs as a standalone `this.prisma.booking.update`.
- **Risk**: A network failure during refund or a race condition during status update leaves the system in an inconsistent state.

---

### 9. Idempotency Mechanisms

- Payment refunds enforce a unique `idempotencyKey` on `PaymentRefund`.
- BullMQ queue jobs in Phase 32 enforce deterministic `jobId` from `correlationId`.
- **Gap Identified**: `updateStatus` has no idempotency key or conditional update guard. Submitting the same confirmation or cancellation request twice can trigger redundant processing or duplicate refunds.

---

### 10. Race-Condition Risks

1. **Customer Cancellation vs. Vendor Confirmation**:
   - Customer submits cancellation while vendor clicks accept at the same millisecond.
   - If both read status `PENDING` concurrently, the vendor updates status to `CONFIRMED` while the customer triggers a refund on the gateway, leaving a confirmed booking that has been refunded.
2. **Duplicate Return / Completion**:
   - Double-tapping "Complete Trip" can attempt duplicate settlement or duplicate return OTP verification.
3. **Payment Webhook vs. Cancellation**:
   - Razorpay webhook fires `payment.captured` concurrently with customer cancelling an unpaid booking.

---

### 11. Tenant-Isolation Risks

- In `updateStatus`, tenant authorization checks `booking.vendor.userId === requestingUser.userId`.
- However, vendor staff or multi-branch sub-vendors need strict validation against `booking.vendorId`.
- Admin overrides must be explicitly audited with the actor ID and sanitized justification.
- Notifications and realtime emissions must be strictly tenant-isolated so vendor staff cannot receive customer PII or another vendor's booking data.

---

### 12. Missing Lifecycle Transitions & Operations

1. **`markReadyForHandover`**: Explicit transition from `CONFIRMED` to `HANDOVER_READY` when vehicle inspection is complete and vehicle is positioned at hub/dispatch.
2. **`startRental`**: Explicit transition from `HANDOVER_READY` to `ONGOING` upon verified pickup OTP and pre-trip inspection sign-off.
3. **`initiateReturn`**: Transition from `ONGOING` to `RETURN_PENDING` when return is logged.
4. **`completeBooking`**: Final transition from `RETURN_PENDING` to `COMPLETED` verifying post-trip inspection, return OTP, and settling escrow.
5. **`expireBooking`**: Automated cancellation of stale `PENDING` bookings that remain unconfirmed past expiry cutoff.

---

### 13. Missing Tests

- No integration tests proving concurrent mutation protection (e.g. concurrent cancel vs. confirm).
- No tests verifying that outbox events are inserted atomically with booking status transitions.
- No tests verifying that notification orchestrator events are published with authoritative booking variables.
- No tests verifying cross-platform realtime lifecycle event streaming via SSE.

---

### 14. UI Synchronization Gaps

- Customer App (`booking_detail_page.dart`): Relies on manual page reload or pull-to-refresh to detect vendor confirmation or vehicle readiness.
- Vendor App (`vendor_booking_detail_page.dart`): Actions directly invoke `PATCH /bookings/:id/status` without optimistic locking protection or unified lifecycle action buttons.
- Admin Panel: Lacks a dedicated lifecycle transition history drawer displaying actor, timestamp, previous status, new status, and correlation ID.

---

### 15. Production Blockers

| Blocker ID | Description | Severity | Target Phase 33 Resolution |
| :--- | :--- | :--- | :--- |
| **BLK-33-01** | Non-atomic event dispatch (No transactional outbox). | **CRITICAL** | Introduce `BookingOutboxEvent` model in Prisma; write event in same DB transaction as booking status mutation. |
| **BLK-33-02** | Unprotected race conditions in status transitions. | **HIGH** | Implement conditional update guards (`where: { id, status: expectedCurrentStatus }`) and Redis distributed locks. |
| **BLK-33-03** | Disconnected notification telemetry. | **HIGH** | Route all booking transitions through `NotificationOrchestratorService.publishEvent()` with full operational variables. |
| **BLK-33-04** | Missing operational transition methods (`markReadyForHandover`, `startRental`, `initiateReturn`, `completeBooking`). | **HIGH** | Create `BookingLifecycleService` with explicit, strongly validated methods for each business state. |
| **BLK-33-05** | Lack of comprehensive audit trail for non-admin transitions. | **MEDIUM** | Record all lifecycle transitions in `BookingOutboxEvent` and `AuditLog` with actor ID, role, and sanitized metadata. |

---

### Next Steps: Phase 33 Architecture Definition

Having established the exact state of the repository, Phase 33 will proceed with:
1. Formalizing the canonical transition matrix.
2. Adding `BookingOutboxEvent` to Prisma schema.
3. Implementing `BookingLifecycleService` and `BookingOutboxDispatcher`.
4. Hardening concurrency and race conditions.
5. Integrating with Phase 30 Payments, Phase 31/32 Notifications & Realtime SSE.
6. Updating Customer, Vendor, and Admin Flutter interfaces.
7. Validating full test suites, platform builds, and emulator runs.

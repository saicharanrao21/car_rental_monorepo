# DRIVEGO PHASE 23A — OWNER CONFIRMATION GATE & HOST PRIVACY AUDIT

**Author:** Principal Software Architect, Senior Backend Engineer, Flutter QA Lead
**Date:** August 28, 2026
**Status:** READ-ONLY AUDIT COMPLETE — AWAITING IMPLEMENTATION APPROVAL
**Repository Baseline Commit:** `454910c1d46cc828dac14707b3dde7d451f1d02f` (`main`)

---

## 1. Executive Summary & Problem Statement

Currently in DriveGo, upon payment completion via Razorpay checkout, the backend payment verification routine (`POST /payments/verify`) and the Razorpay asynchronous webhook (`POST /payments/webhook`) automatically transition the booking status directly to `CONFIRMED`:
```ts
// payments.service.ts: lines 457 & 595
await tx.booking.update({
  where: { id: b.id },
  data: { status: BookingStatus.CONFIRMED },
});
```
Simultaneously, the vendor redaction utility (`vendor-redactor.util.ts`) exposes real vendor business details whenever `isPaid` is `true`:
```ts
// vendor-redactor.util.ts: lines 55-58
if (options.isPaid) {
  // Post-payment reveal: reveal real businessName and ownerName, exact coordinates
  return copy;
}
```
In the Customer App, the `BookingDetailPage` unconditionally renders the `BookingDetailHostCard` with a prominent **"Contact Host"** button (which copies host phone to clipboard), and the post-checkout `BookingConfirmationPage` prematurely announces `"Booking Confirmed!"` and invites immediate direct coordination.

### Core Business Vulnerability:
1. **Host Disintermediation & Harassment:** If an owner is not yet aware of the booking or needs to decline due to maintenance/availability, the customer already has direct contact details and pickup coordinates.
2. **Bypassed Fulfillment Gate:** Vehicle availability and physical handover feasibility must be affirmed by the fleet owner before entering the binding `CONFIRMED` contract.
3. **Flawed Conflation of Payment vs. Booking Confirmation:** Payment success signifies *funds held in escrow*, NOT that the vehicle has been reserved and accepted by the host.

---

## 2. Current Booking State Machine Audit

### 2.1 Prisma Schema Statuses (`prisma/schema.prisma`)
```prisma
enum BookingStatus {
  PENDING
  CONFIRMED
  HANDOVER_READY
  ONGOING
  RETURN_PENDING
  COMPLETED
  CANCELLED
  REFUND_PENDING
  REFUNDED
  DISPUTED
  EXPIRED
}
```

### 2.2 Current Transitions in `BookingsService` (`bookings.service.ts`)
```text
PENDING        ──► [CONFIRMED, CANCELLED, EXPIRED]
CONFIRMED      ──► [HANDOVER_READY, ONGOING, CANCELLED, REFUND_PENDING]
HANDOVER_READY ──► [ONGOING, CANCELLED]
ONGOING        ──► [RETURN_PENDING, COMPLETED]
RETURN_PENDING ──► [COMPLETED, DISPUTED]
REFUND_PENDING ──► [REFUNDED, DISPUTED]
DISPUTED       ──► [COMPLETED, REFUND_PENDING, REFUNDED]
```

### 2.3 Role-Based Permissions (`getAllowedNextStates`)
- **`Role.CUSTOMER`:**
  - `PENDING` ──► `CANCELLED`
  - `CONFIRMED` ──► `CANCELLED`
- **`Role.VENDOR`:**
  - `PENDING` ──► `[CONFIRMED, CANCELLED]` (Requires `isPaid == true` to confirm, requires `reason` to cancel)
  - `CONFIRMED` ──► `[HANDOVER_READY, ONGOING, CANCELLED]`
  - `HANDOVER_READY` ──► `[ONGOING, CANCELLED]`
  - `ONGOING` ──► `[RETURN_PENDING, COMPLETED]`
  - `RETURN_PENDING` ──► `[COMPLETED]`
- **`Role.ADMIN`:**
  - Free transition with audit logging for force overrides.

---

## 3. Current Payment State Machine Audit

### 3.1 Prisma Schema Statuses
```prisma
enum PaymentStatus {
  CREATED
  PAID
  FAILED
  REFUNDED
}

enum RefundStatus {
  NONE
  PENDING
  PROCESSED
  FAILED
}
```

### 3.2 Current Flow
```text
1. Customer initiates checkout
   └──► POST /payments/create-order
        └──► Payment created in DB with status: CREATED, Razorpay order created.

2. Customer authorizes payment in Razorpay modal
   └──► Client obtains razorpayPaymentId, razorpayOrderId, razorpaySignature.

3. Verification (Dual-channel)
   ├── Channel A: POST /payments/verify (Synchronous client callback)
   │   ├── Verifies HMAC-SHA256 signature
   │   ├── Updates payment.status = PAID
   │   └── FLAW: Updates booking.status = CONFIRMED
   │
   └── Channel B: POST /payments/webhook (Asynchronous Razorpay webhook)
       ├── Verifies X-Razorpay-Signature
       ├── Idempotency check: if payment.status == PAID, skips duplicate processing
       ├── Updates payment.status = PAID
       └── FLAW: Updates booking.status = CONFIRMED
```

---

## 4. Existing Owner Acceptance Flow Audit

### 4.1 Backend Engine (`BookingsService.updateStatus`)
- Backend already has explicit vendor confirmation gating in `updateStatus`:
  - Enforces `booking.vendor.userId === requestingUser.userId`.
  - When target status is `CONFIRMED`:
    ```ts
    const payment = await this.prisma.payment.findUnique({ where: { bookingId } });
    const isPaid = payment && payment.status === PaymentStatus.PAID;
    if (!isAdmin && !isPaid) {
      throw new BadRequestException('Cannot confirm booking: Payment has not been captured...');
    }
    ```
  - When target status is `CANCELLED`:
    - Requires non-empty `reason`.
    - Acquires Redis cancellation lock `acquireCancellationLock(bookingId)`.
    - Evaluates `cancellationPolicyService.calculateCancellation({ actorRole: Role.VENDOR })`.
    - By DriveGo policy (`cancellation-policy.service.ts` line 61): Vendor cancellation yields `tier = 'VENDOR_CANCELLED'`, `feePercent = 0`, `refundPercent = 100` (100% full refund).
    - Calls `paymentsService.refund(bookingId, refundAmountInPaise, reason, 'VENDOR_CANCELLED')`.
    - Dispatches notifications to customer.

### 4.2 Vendor App Interface
- `apps/vendor_app/lib/features/bookings/presentation/pages/vendor_bookings_page.dart`:
  - Renders "New Requests" tab with **"Accept"** (`updateStatus(req.id, 'confirmed')`) and **"Reject"** (`_showRejectBottomSheet`).
- `apps/vendor_app/lib/features/bookings/presentation/pages/vendor_booking_detail_page.dart`:
  - **DEFECT:** Does not render Accept/Reject CTA when `status == 'pending'`. Only renders Handover/Inspection flow when `status == 'confirmed'`.

---

## 5. API Endpoints Returning Booking / Vendor Data to Customers

| Endpoint | Method | Role | Redaction Mechanism | Current Exposure |
| :--- | :--- | :--- | :--- | :--- |
| `/bookings/:id` | `GET` | `CUSTOMER` | `redactVendorInBooking` | Exposes `businessName`, `ownerName`, coordinates as soon as `payment.status == PAID`. |
| `/bookings/me` | `GET` | `CUSTOMER` | `redactVendorInBooking` | Exposes `businessName`, `ownerName` for paid bookings. |
| `/bookings` | `POST` | `CUSTOMER` | Returns created booking | Redacted pre-payment (`PENDING`, `CREATED`). |
| `/bookings/:id/cancel` | `POST` | `CUSTOMER` | `redactVendorInBooking` | Redacts vendor details. |
| `/bookings/:id/cancellation-preview` | `GET` | `CUSTOMER` | Pure financial DTO | No vendor personal details. |
| `/cars/:id` | `GET` | Public | `redactVendor` (isPaid: false) | Properly redacted (`displayName: "Partner in <City>"`). |

---

## 6. Customer UI Locations Exposing Host Information

### 6.1 `BookingDetailPage` (`apps/customer_app/lib/features/my_bookings/presentation/pages/booking_detail_page.dart`)
1. **Header Card (`BookingDetailHeaderCard.dart` lines 141-153):**
   - Renders `'Host: ${vendor.businessName}'` for any status if `vendor` is non-null.
2. **Host Card (`BookingDetailHostCard.dart` lines 26-160):**
   - Unconditionally rendered at line 417 of `booking_detail_page.dart`.
   - Displays real `vendor.businessName` (or 'Fleet Host'), `VERIFIED` badge, rating, city.
   - Line 114: Renders **"Contact Host"** button (`Icons.phone_outlined`) with clipboard copy of `vendor.phone`.
3. **Actions Card (`BookingDetailActionsCard.dart` lines 48-69):**
   - If `status == 'pending'`, shows **"Complete Payment"** button even if payment was already captured!
   - If `status == 'confirmed'`, shows **"View Pickup Handover PIN"**.

### 6.2 `BookingConfirmationPage` (`apps/customer_app/lib/features/booking/presentation/pages/booking_confirmation_page.dart`)
1. **Headline (lines 23 & 116):**
   - Announces `"Booking Confirmed!"` immediately after Razorpay modal completes.
2. **Coordination Card (lines 174-181):**
   - Announces `'${vendor.businessName} will contact you shortly to coordinate vehicle handover & delivery.'`

### 6.3 `BookingListItemCard` (`apps/customer_app/lib/features/my_bookings/presentation/widgets/booking_list_item_card.dart`)
1. **Header Row (line 139):**
   - Shows `vendor.businessName` next to `#shortId`.

---

## 7. Security & Privacy Threat Assessment

| Threat Vector | Severity | Mechanism | Impact |
| :--- | :--- | :--- | :--- |
| **Off-Platform Disintermediation** | **CRITICAL** | Customer obtains host phone/business name immediately upon payment; cancels or coordinates directly to bypass platform commission. | Revenue leakage, loss of platform protection. |
| **Harassment Post-Rejection** | **HIGH** | Owner rejects booking (e.g. car in maintenance); angry customer has owner's personal name, phone number, and physical coordinates. | Safety & privacy violation for hosts. |
| **Premature Renter Expectation** | **HIGH** | Customer shows up at pickup location believing booking is confirmed before vendor accepted the reservation. | Host dispute, customer stranded, negative brand reputation. |
| **Client-Side Security Illusion** | **CRITICAL** | If Flutter only hides the UI widget but `/bookings/:id` JSON exposes `businessName`, `ownerName`, `phone`, any tech-savvy user can read the network tab. | Complete privacy control bypass. |

---

## 8. Architectural State Transition Design

### 8.1 State Separation Architecture
We maintain clean separation between **Payment Status** and **Booking Status**:

```
                ┌──────────────────────────────────────────────────────────┐
                │                     PAYMENT STATUS                       │
                │  [CREATED] ──► [PAID] ──► (if rejected) [REFUNDED]       │
                └──────────────────────────────────────────────────────────┘
                                             │
                                             ▼
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                           BOOKING STATUS                                             │
│                                                                                                      │
│  [PENDING] (Payment: CREATED)                                                                        │
│       │                                                                                              │
│       ▼ (Payment captures successfully via verify/webhook)                                           │
│  [PENDING] (Payment: PAID) ◄─── "WAITING FOR OWNER CONFIRMATION" GATE                                │
│       │                         (Host details strictly REDACTED on server)                           │
│       │                         (No "Contact Host", no pickup PIN)                                   │
│       │                                                                                              │
│       ├───► OWNER ACCEPTS (PATCH /bookings/:id/status -> CONFIRMED)                                  │
│       │          │                                                                                   │
│       │          ▼                                                                                   │
│       │     [CONFIRMED] ◄─── "BOOKING CONFIRMED"                                                     │
│       │                      (Server REVEALS host details, coordinates, Contact Host enabled)        │
│       │                                                                                              │
│       └───► OWNER REJECTS (PATCH /bookings/:id/status -> CANCELLED, reason: "...")                   │
│                  │                                                                                   │
│                  ▼                                                                                   │
│             [CANCELLED] ◄─── "BOOKING REQUEST NOT ACCEPTED"                                          │
│                              (Host details remain REDACTED, 100% refund processed automatically)     │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

> [!NOTE]
> **Prisma Enum Compatibility:**
> Reusing `BookingStatus.PENDING` when coupled with `Payment.status === PAID` is 100% backward compatible with the database schema and does NOT require risky database migrations on the live production PostgreSQL database.
> The booking remains in `PENDING` status while payment is `PAID`, precisely defining the state: **"Paid, Waiting for Owner Confirmation"**.
> Once the owner accepts, it transitions to `CONFIRMED`. If the owner rejects, it transitions to `CANCELLED` with automatic 100% refund.

---

## 9. Comprehensive Implementation Plan

### 9.1 Backend Changes

#### 1. `car_rental_backend/src/payments/payments.service.ts`
- **Modify `verifyPayment` (lines 450-465):**
  - Keep `payment.status = PaymentStatus.PAID`.
  - **DO NOT** update `booking.status = BookingStatus.CONFIRMED`.
  - Leave `booking.status = BookingStatus.PENDING`.
  - Update customer notification: `"Payment Received — Waiting for host confirmation for booking ${booking.id}"`.
  - Notify vendor: `"New Booking Request — You have received a paid booking request for ${booking.car.make} ${booking.car.model}. Please review and confirm."`
- **Modify `handleWebhook` (lines 585-615):**
  - Keep `payment.status = PaymentStatus.PAID`.
  - **DO NOT** update `booking.status = BookingStatus.CONFIRMED`.
  - Preserve idempotent retry semantics.

#### 2. `car_rental_backend/src/common/vendor-redactor.util.ts`
- **Update `VendorRedactionOptions`:**
  ```ts
  export interface VendorRedactionOptions {
    isAdmin?: boolean;
    isOwner?: boolean;
    isConfirmed?: boolean; // Replaces isPaid for host contact reveal
  }
  ```
- **Update `redactVendor`:**
  - Only reveal `businessName`, `ownerName`, and exact coordinates when:
    `options.isAdmin || options.isOwner || options.isConfirmed`
  - When `isConfirmed` is false:
    - Replace `businessName` with computed generic `displayName` (`"Partner in ${locality || city}"`).
    - Delete `ownerName`.
    - Round coordinates to ~1km precision (2 decimals).
    - Strip all contact details (`phone`, `user.phone`, `email`).

#### 3. `car_rental_backend/src/bookings/bookings.service.ts`
- **Update `redactVendorInBooking`:**
  - Derive `isConfirmed`:
    ```ts
    const isConfirmed = [
      BookingStatus.CONFIRMED,
      BookingStatus.HANDOVER_READY,
      BookingStatus.ONGOING,
      BookingStatus.RETURN_PENDING,
      BookingStatus.COMPLETED,
    ].includes(booking.status);
    ```
  - Pass `{ isAdmin, isOwner: isVendor, isConfirmed }` into `redactVendor`.
- **Ensure Vendor Authorization & Idempotency:**
  - Prevent duplicate accept/reject.
  - Reject transitions from already cancelled/rejected or completed bookings.

### 9.2 Customer Flutter App Changes

#### 1. `booking_detail_page.dart` & `booking_detail_actions_card.dart`
- **State Evaluation:**
  ```dart
  final isPaid = item.paymentStatus?.toUpperCase() == 'PAID';
  final isPendingApproval = status == 'pending' && isPaid;
  final isPendingPayment = status == 'pending' && !isPaid;
  final isConfirmed = status == 'confirmed';
  ```
- **When `isPendingApproval` (Waiting for Owner Confirmation):**
  - Render dedicated **"Waiting for Owner Confirmation"** banner card:
    - Title: `"Waiting for Owner Confirmation"`
    - Subtitle: `"Your payment has been received successfully. The vehicle owner is reviewing your booking request. You will be notified once the booking is confirmed."`
  - Hide "Complete Payment" button.
  - Hide "Pickup PIN".
  - Hide "Contact Host" button and host phone details.
- **When `isConfirmed` (Owner Accepted):**
  - Render **"Booking Confirmed"** badge.
  - Render Host card with approved business name and enabled "Contact Host" / "Help & Support" options.
  - Render Pickup PIN / Inspection checklist options.
- **When `isCancelled` (Owner Rejected):**
  - Display "Booking Request Not Accepted" with `BookingRefundTrackerCard` explaining the 100% refund.

#### 2. `booking_confirmation_page.dart` (Post-Checkout)
- Change Title and Headline to: `"Booking Request Received"` / `"Payment Successful"`.
- Card Message: `"Your payment was processed. Your booking request has been sent to the fleet owner for confirmation. You will receive an update shortly."`
- Replace direct handover coordination text with waiting expectation.

#### 3. `booking_detail_header_card.dart` & `booking_list_item_card.dart`
- If not confirmed, display generic locality (`"Partner in ${item.car?.city ?? 'City'}"`) rather than private host identity.

### 9.3 Vendor Flutter App Changes

#### 1. `vendor_booking_detail_page.dart`
- Add **"Booking Request Decision"** Action Card if `status == 'pending'`:
  - Shows **"Accept Booking"** and **"Reject Booking"** with reason selection sheet.

---

## 10. Verification & Test Suite Strategy

### Backend Tests
1. Unit test: `POST /payments/verify` marks payment as `PAID` but leaves booking in `PENDING` status.
2. Unit test: `GET /bookings/:id` for customer returns redacted vendor (`displayName: "Partner in ..."`) when payment is `PAID` but booking is `PENDING`.
3. Unit test: `GET /bookings/:id` returns real `businessName` and coordinates ONLY after vendor executes `PATCH /bookings/:id/status` to `CONFIRMED`.
4. Unit test: Vendor cannot confirm unpaid booking.
5. Unit test: Non-assigned vendor cannot accept/reject booking.
6. Unit test: Vendor rejection triggers 100% refund calculation and cancels booking.
7. Webhook test: `handleWebhook` idempotent payment capture leaves booking `PENDING`.

### Flutter Tests
1. `apps/customer_app`:
   - Test `BookingDetailPage` displays "Waiting for Owner Confirmation" card when `booking.status == 'pending'` and `payment.status == 'PAID'`.
   - Test "Contact Host" button is absent when awaiting confirmation.
   - Test "Contact Host" button and confirmed banner appear when `booking.status == 'confirmed'`.
   - Test `BookingConfirmationPage` displays "Payment Successful - Waiting for Host Confirmation".
2. `apps/vendor_app`:
   - Test `vendor_booking_detail_page.dart` displays Accept & Reject CTAs for pending requests.

---

## 11. Architectural Recommendation

**PROCEED TO IMPLEMENTATION FOLLOWING AUDIT APPROVAL.**

The audit confirms that the foundation (vendor authorization, role checks, cancellation policy, 100% vendor rejection refund) is already solidly implemented in DriveGo. The required correction cleanly decouples payment capture from booking confirmation, enforces host privacy at the backend serialization layer, and harmonizes customer and vendor user interfaces.

*(Audit completed. No code modifications made during Phase 0).*

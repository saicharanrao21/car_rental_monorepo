# Phase 36: Payment & Financial Engine API Contract

**Document Status:** Complete & Verified  
**API Version:** v1.0 (Production Hardened)  
**Author:** Senior Principal Engineer / CTO  
**Date:** September 2026  

---

## Overview

This contract documents all HTTP endpoints exposed by `PaymentsController` (`car_rental_backend/src/payments/payments.controller.ts`), detailing authentication, role authorization, payload schemas, state machine transitions, and idempotency guarantees.

---

## 1. POST `/payments/create-order`

Creates or renews a gateway payment order for a `PENDING` booking.

- **Authentication:** Bearer JWT (`JwtAuthGuard`)
- **Authorization:** `Role.CUSTOMER` (`RolesGuard`)
- **Rate Limit:** 15 requests / 60 seconds
- **Idempotency:** Yes (safe retry reuses or renews order without deleting historical rows)

### Request Body
```json
{
  "bookingId": "bk_abc12345",
  "useWallet": false
}
```

### Success Response (`201 Created`)
```json
{
  "orderId": "order_rzp_abc12345",
  "amount": 550000,
  "currency": "INR",
  "keyId": "rzp_live_key_xyz",
  "isFullWallet": false,
  "breakdown": {
    "tripFare": 4000.0,
    "securityDeposit": 1500.0,
    "totalAmount": 5500.0,
    "walletApplied": 0.0,
    "promoApplied": 0.0,
    "realApplied": 0.0,
    "gatewayAmount": 5500.0
  }
}
```

### State Machine Transition
- `null / FAILED / EXPIRED / CANCELLED -> CREATED`
- Appends `PaymentAuditLog`: `PAYMENT_ORDER_CREATED` or `PAYMENT_ORDER_RENEWED`.

### Error Responses
- `400 Bad Request`: Booking is not in `PENDING` status.
- `403 Forbidden`: Customer does not own the booking.
- `404 Not Found`: Booking does not exist.
- `409 Conflict`: Booking has already been paid for, or price drifts from accepted quote.

---

## 2. POST `/payments/verify`

Cryptographically verifies Razorpay payment signature and transitions payment to `PAID`.

- **Authentication:** Bearer JWT (`JwtAuthGuard`)
- **Authorization:** `Role.CUSTOMER` (`RolesGuard`)
- **Rate Limit:** 15 requests / 60 seconds
- **Idempotency:** Yes (repeated calls for already `PAID` payment return cached success)

### Request Body
```json
{
  "bookingId": "bk_abc12345",
  "razorpayOrderId": "order_rzp_abc12345",
  "razorpayPaymentId": "pay_rzp_xyz987",
  "razorpaySignature": "4a7c8e9f...6b"
}
```

### Success Response (`200 OK`)
```json
{
  "success": true,
  "bookingId": "bk_abc12345",
  "paymentId": "pay_internal_cuid",
  "status": "PAID"
}
```

### State Machine Transition
- `CREATED / AUTHORIZED -> PAID`
- Appends `PaymentAuditLog`: `PAYMENT_VERIFIED` with payload HMAC SHA-256 hash.
- Atomically updates `SecurityDeposit.status` to `HELD` if deposit exists.

### Error Responses
- `400 Bad Request`: Invalid signature, order ID mismatch, or currency mismatch.
- `403 Forbidden`: Access denied (not booking owner).
- `404 Not Found`: Payment order record not found.
- `409 Conflict`: Booking paid with different payment ID or invalid transition.

---

## 3. POST `/payments/webhook`

Gateway webhook receiver for real-time transactional events.

- **Authentication:** Public (Protected by cryptographic HMAC SHA-256 signature)
- **Headers:** `x-razorpay-signature` (required), `x-razorpay-event-id` (optional)
- **Rate Limit:** 120 requests / 60 seconds
- **Idempotency:** Yes (deduplicated via unique `WebhookEvent.eventId` constraint)

### Handled Events & Transitions
| Event | Transition | Action |
|---|---|---|
| `payment.authorized` | `CREATED -> AUTHORIZED` | Pre-authorization recorded. |
| `payment.captured` / `order.paid` | `CREATED/AUTH -> PAID` | Settle payment, confirm booking, generate invoice. |
| `payment.failed` | `CREATED/AUTH -> FAILED` | Mark failed; ignored if already `PAID`. |
| `refund.created` | `refundStatus = PENDING` | Track pending gateway refund. |
| `refund.processed` | `PAID -> REFUNDED / PARTIALLY_REFUNDED` | Mark refund processed. |
| `refund.failed` | `refundStatus = FAILED` | Flag gateway refund failure. |

### Success Response (`200 OK`)
```json
{
  "received": true,
  "alreadyProcessed": false
}
```

---

## 4. GET `/payments/vendor/:bookingId`

Retrieves sanitized financial details and net earnings for a vehicle owner.

- **Authentication:** Bearer JWT (`JwtAuthGuard`)
- **Authorization:** `Role.VENDOR` (or `Role.ADMIN`)
- **Privacy Guarantee:** Customer cards, UPI VPAs, and gateway secrets are **omitted**.

### Success Response (`200 OK`)
```json
{
  "bookingId": "bk_abc12345",
  "paymentStatus": "PAID",
  "isPaid": true,
  "currency": "INR",
  "tripFare": 8000.0,
  "netVendorEarnings": 6800.0,
  "platformCommission": 1200.0,
  "securityDepositHeld": 2000.0,
  "refundStatus": "NONE",
  "refundAmount": 0.0,
  "settlementStatus": "ELIGIBLE_FOR_SETTLEMENT",
  "updatedAt": "2026-09-01T12:00:00.000Z"
}
```

### Error Responses
- `403 Forbidden`: Vendor does not own the vehicle involved in this booking.
- `404 Not Found`: Booking not found.

---

## 5. GET `/payments/:bookingId`

Retrieves payment details for customer or administrative support lookup.

- **Authentication:** Bearer JWT (`JwtAuthGuard`)
- **Authorization:** `Role.CUSTOMER` (owner), `Role.ADMIN`, `Role.SUPPORT_AGENT`

### Success Response (`200 OK`)
```json
{
  "id": "pay_cuid_123",
  "bookingId": "bk_abc12345",
  "razorpayOrderId": "order_rzp_abc12345",
  "razorpayPaymentId": "pay_rzp_xyz987",
  "amount": 5500.0,
  "amountInPaise": 550000,
  "currency": "INR",
  "status": "PAID",
  "refundStatus": "NONE",
  "gatewayProvider": "RAZORPAY",
  "capturedAt": "2026-09-01T10:35:00.000Z",
  "refunds": []
}
```

---

## 6. GET `/payments/:bookingId/audit-logs`

Retrieves complete chronological financial audit events for administrative governance.

- **Authentication:** Bearer JWT (`JwtAuthGuard`)
- **Authorization:** `Role.ADMIN`, `Role.SUPPORT_AGENT`

### Success Response (`200 OK`)
```json
[
  {
    "id": "audit_1",
    "paymentId": "pay_cuid_123",
    "bookingId": "bk_abc12345",
    "tenantId": "default",
    "eventType": "PAYMENT_VERIFIED",
    "fromStatus": "CREATED",
    "toStatus": "PAID",
    "amount": 5500.0,
    "gatewayReference": "pay_rzp_xyz987",
    "actorId": "cust_123",
    "actorRole": "CUSTOMER",
    "source": "CUSTOMER",
    "payloadHash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "createdAt": "2026-09-01T10:35:00.000Z"
  },
  {
    "id": "audit_0",
    "paymentId": "pay_cuid_123",
    "bookingId": "bk_abc12345",
    "tenantId": "default",
    "eventType": "PAYMENT_ORDER_CREATED",
    "fromStatus": null,
    "toStatus": "CREATED",
    "amount": 5500.0,
    "gatewayReference": "order_rzp_abc12345",
    "actorId": "cust_123",
    "actorRole": "CUSTOMER",
    "source": "CUSTOMER",
    "createdAt": "2026-09-01T10:30:00.000Z"
  }
]
```

---

## 7. POST `/payments/:bookingId/refund`

Issues an administrative manual or override refund with audit logging.

- **Authentication:** Bearer JWT (`JwtAuthGuard`)
- **Authorization:** `Role.ADMIN` only
- **Idempotency:** Supported via client-provided or deterministic `idempotencyKey`

### Request Body
```json
{
  "amountInPaise": 250000,
  "reason": "Administrative goodwill refund for delayed handover",
  "idempotencyKey": "admin_rfnd_bk_abc12345_manual_1"
}
```

### Success Response (`200 OK`)
```json
{
  "success": true,
  "bookingId": "bk_abc12345",
  "paymentId": "pay_cuid_123",
  "refundId": "rfnd_rzp_goodwill_1",
  "refundAmount": 2500.0,
  "refundStatus": "PROCESSED"
}
```

### Error Responses
- `400 Bad Request`: Requested refund exceeds remaining refundable balance.
- `403 Forbidden`: Requesting user is not an administrator.
- `404 Not Found`: Booking or payment record not found.

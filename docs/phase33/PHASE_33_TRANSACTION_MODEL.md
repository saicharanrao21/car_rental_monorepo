# Phase 33: Transaction Model & Concurrency Guard Invariants

## 1. The Core Transaction Boundary

In DriveGo Phase 33, any operation that alters a booking's lifecycle state MUST execute within an ACID-compliant PostgreSQL transaction managed by Prisma:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       PRISMA TRANSACTION BOUNDARY                          │
│                                                                             │
│  1. Optimistic Concurrency Read: SELECT status FROM "Booking" WHERE id = ?  │
│  2. Invariant Preconditions Check:                                          │
│     - Payment status check (e.g. CONFIRMED requires payment.status == PAID) │
│     - Inspection verification (e.g. ONGOING requires PICKUP inspection)     │
│  3. Conditional Mutation:                                                   │
│     UPDATE "Booking" SET status = newStatus WHERE id = ? AND status = old   │
│  4. Vehicle State Alignment:                                                │
│     UPDATE "Car" SET isAvailable = false WHERE id = carId                   │
│  5. Outbox Event Persistence:                                                │
│     INSERT INTO "BookingOutboxEvent" (id, bookingId, eventType, ...)        │
│                                                                             │
│  ──> COMMIT TRANSACTION (Atomic write of state + outbox event)              │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ (Post-Commit Async Handover)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       POST-COMMIT ASYNCHRONOUS PIPELINE                     │
│                                                                             │
│  1. Redis Mutex Release: `lock:booking:transition:{bookingId}`              │
│  2. Asynchronous Outbox Dispatch:                                           │
│     - NotificationOrchestratorService (FCM, SMS, WhatsApp, Email, In-app)   │
│     - NotificationRealtimeService (Server-Sent Events streaming to clients) │
│  3. Financial Consequences:                                                 │
│     - Quarantine release (COMPLETED -> triggers vendor payout release)      │
│     - Escrow refund processing (CANCELLED -> triggers gateway refund)       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Invariant: Atomicity of State & Outbox

A foundational flaw in naive architectures is:
```typescript
// ANTI-PATTERN (DO NOT USE)
await db.booking.update({ ... });
await eventBus.publish(event); // If this crashes or network times out, the event is LOST forever!
```

DriveGo Phase 33 guarantees that:
1. If the database transaction rolls back, **NO outbox event is persisted**, preventing ghost notifications or false realtime broadcasts.
2. If the database transaction commits, the event is **guaranteed to be on disk** in `BookingOutboxEvent`.
3. If downstream notification infrastructure (FCM, Twilio, SendGrid) experiences an outage, the booking transition remains **100% intact and valid**.
4. The `BookingOutboxService` background poller will retry failed events with exponential backoff until delivered or flagged for operator inspection in `DEAD_LETTER` state.

---

## 3. Concurrency Defense Matrix

| Attack / Race Vector | Potential Consequence Without Guard | DriveGo Phase 33 Defensive Mechanism |
|---|---|---|
| Customer Cancels while Vendor Confirms | Inconsistent status: DB marked Confirmed while customer sees Cancelled; double refund/charge | `UPDATE WHERE id = ? AND status = 'PENDING'` ensures only one query succeeds. The slower query fails with `P2025` -> `409 ConflictException`. |
| Concurrent Staff Action (Two agents confirm simultaneously) | Duplicate notification dispatch, duplicate fleet lock | Redis mutex `lock:booking:transition:{id}` serializes access + Prisma conditional update. |
| Webhook Replay (Duplicate Razorpay `payment.captured`) | Duplicate transition to `CONFIRMED` | Lifecycle transition check: if `status == 'CONFIRMED'`, service returns existing booking without creating duplicate outbox events or notifications. |
| Stale Frontend Mutation (Customer attempts return while already completed) | Illegal backward or duplicate transition | Status transition validation matrix validates `allowedPreviousStatus.includes(currentStatus)`. Throws `BadRequestException` (`400`). |

---

## 4. Financial & Fulfillment Guard Invariants

### A. Payment Precondition
- `confirmBooking` explicitly queries the latest `Payment` record for the booking.
- If `payment.status !== 'PAID'` (or amount < totalFare), the transition is rejected with:
  `BadRequestException: "Cannot confirm booking without a completed payment."`

### B. Fulfillment & Inspection Precondition
- `startRental` (`HANDOVER_READY` -> `ONGOING`) queries `Inspection` records for `type: 'PICKUP'`.
- If missing:
  `BadRequestException: "Cannot start rental without an authorized pickup inspection."`
- `completeBooking` (`RETURN_PENDING` -> `COMPLETED`) queries `Inspection` records for `type: 'RETURN'`.
- If missing:
  `BadRequestException: "Cannot complete booking without a completed return inspection."`

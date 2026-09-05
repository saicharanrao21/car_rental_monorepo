# Phase 33: Canonical Booking Lifecycle Orchestration Architecture

## Executive Summary

Phase 33 establishes the **server-authoritative, transaction-atomic Booking Lifecycle Orchestration Engine** for the DriveGo production monorepo. It eliminates distributed state divergence, prevents concurrent race conditions, guarantees atomic persistence via a Transactional Outbox pattern, and integrates deterministically with Phase 30 (Payments/Escrow), Phase 29 (Fulfillment/Inspections), Phase 31/32 (Notification Orchestrator & Realtime SSE), and Flutter clients (Customer, Vendor, Admin).

---

## 1. Architectural Principles

1. **Server Authority**: Neither Flutter clients, gateway webhooks, nor vendor staff can unilaterally advance booking states. Every lifecycle mutation flows through `BookingLifecycleService`.
2. **Atomic State & Outbox Persistence**: Booking state mutations and their corresponding `BookingOutboxEvent` records are committed within the **exact same PostgreSQL transaction boundary** (`prisma.$transaction`).
3. **Decoupled Notification & Realtime Delivery**: Downstream notification fan-out (FCM, SMS, WhatsApp, Email) and realtime SSE streaming are triggered asynchronously by `BookingOutboxService`. A notification delivery failure will **never** roll back or corrupt a valid state transition.
4. **Optimistic & Pessimistic Concurrency Defense**:
   - **Prisma Conditional Updates**: `tx.booking.update({ where: { id, status: previousStatus } })` ensures that any concurrent mutation will throw a `P2025` error, translating to a `409 ConflictException`.
   - **Distributed Mutex (Redis)**: Short-lived distributed locks on `lock:booking:transition:{id}` serialize concurrent operations (e.g. customer cancellation vs. vendor confirmation).
5. **Strict Tenant Isolation**: All transitions, outbox events, realtime SSE channels, and audit histories enforce `tenantId` boundaries. Cross-tenant leakage is strictly prevented.

---

## 2. Canonical State Machine

DriveGo defines 8 authoritative booking states:

| Status | Business Meaning |
|---|---|
| `PENDING` | Initial booking created, awaiting customer payment and vendor confirmation. |
| `CONFIRMED` | Paid booking accepted by vendor or auto-confirmed. Vehicle reserved. |
| `HANDOVER_READY` | Vehicle prepped, staged, and verified ready for customer handover/pickup. |
| `ONGOING` | Pickup inspection completed, OTP/keys verified, active rental in progress. |
| `RETURN_PENDING` | Customer delivered vehicle back; pending vendor return check-in & inspection. |
| `COMPLETED` | Return inspection verified, fuel/damages reconciled, escrow released for payout. |
| `CANCELLED` | Booking terminated before handover; refund policy evaluated. |
| `EXPIRED` | Unpaid or unconfirmed booking timed out by system TTL. |

```
                 ┌───────────────┐
                 │    PENDING    │
                 └───────┬───────┘
           ┌─────────────┼─────────────┐
           │ (Paid)      │ (Cancel)    │ (TTL)
           ▼             ▼             ▼
    ┌─────────────┐┌───────────┐ ┌───────────┐
    │  CONFIRMED  ││ CANCELLED │ │  EXPIRED  │
    └──────┬──────┘└───────────┘ └───────────┘
           │ (Prepped)
           ▼
    ┌───────────────┐
    │ HANDOVER_READY│
    └──────┬────────┘
           │ (Pickup Inspection + Handover)
           ▼
    ┌───────────────┐
    │    ONGOING    │
    └──────┬────────┘
           │ (Vehicle Return)
           ▼
    ┌───────────────┐
    │ RETURN_PENDING│
    └──────┬────────┘
           │ (Return Inspection + Settlement)
           ▼
    ┌───────────────┐
    │   COMPLETED   │
    └───────────────┘
```

---

## 3. Transition Matrix & Guard Conditions

| Transition | Allowed Roles | Preconditions & Invariants | Downstream Consequence |
|---|---|---|---|
| `createBooking` → `PENDING` | `CUSTOMER`, `ADMIN` | Vehicle available, valid dates, pricing calculated. | Outbox event `BOOKING_CREATED`, Customer notification. |
| `confirmBooking` (`PENDING` → `CONFIRMED`) | `VENDOR`, `ADMIN`, `SYSTEM` | `payment.status == 'PAID'`. Vehicle locked. | Outbox event `BOOKING_CONFIRMED`, Realtime SSE, Vendor & Customer push notifications. |
| `rejectBooking` (`PENDING` → `CANCELLED`) | `VENDOR`, `ADMIN` | Vendor rejection note required. | Outbox event `BOOKING_REJECTED`, Triggers full refund flow if paid. |
| `cancelBooking` (`PENDING`/`CONFIRMED` → `CANCELLED`) | `CUSTOMER`, `ADMIN` | Rental must not have started (`ONGOING`). | Outbox event `BOOKING_CANCELLED`, Cancellation fee calculation, Escrow refund trigger. |
| `expireBooking` (`PENDING` → `EXPIRED`) | `SYSTEM`, `ADMIN` | Booking unpaid or unconfirmed past timeout window. | Outbox event `BOOKING_EXPIRED`, Frees vehicle fleet lock. |
| `markReadyForHandover` (`CONFIRMED` → `HANDOVER_READY`) | `VENDOR`, `ADMIN` | Vehicle washed, fueled, parked at handover point / dispatched for doorstep delivery. | Outbox event `BOOKING_HANDOVER_READY`, Customer notification with pickup instructions. |
| `startRental` (`HANDOVER_READY` → `ONGOING`) | `VENDOR`, `ADMIN` | Completed **PICKUP Inspection** required. Keys handed over. | Outbox event `BOOKING_RENTAL_STARTED`, Rental timer begins. |
| `initiateReturn` (`ONGOING` → `RETURN_PENDING`) | `CUSTOMER`, `VENDOR`, `ADMIN` | Vehicle returned to designated location or collected doorstep. | Outbox event `BOOKING_RETURN_INITIATED`, Vendor notified to conduct check-in. |
| `completeBooking` (`RETURN_PENDING` → `COMPLETED`) | `VENDOR`, `ADMIN` | Completed **RETURN Inspection** required. Excess km/fuel/damage settled. | Outbox event `BOOKING_COMPLETED`, Escrow released, Vendor payout queued. |

---

## 4. Concurrency Hardening & Isolation

### A. Prisma Atomic Conditional Updates
Every transition executes inside `prisma.$transaction`:
```typescript
const updatedBooking = await tx.booking.update({
  where: {
    id: bookingId,
    status: previousStatus, // Optimistic concurrency check
  },
  data: {
    status: targetStatus,
    updatedAt: new Date(),
  },
});
```
If two requests execute concurrently (e.g., Customer cancels while Vendor confirms), only the first to commit succeeds; the second receives Prisma error `P2025` ("Record to update not found") and throws NestJS `ConflictException` (`HTTP 409`).

### B. Redis Distributed Lock
```typescript
const lockKey = `lock:booking:transition:${bookingId}`;
const acquired = await redis.set(lockKey, actorId, 'PX', 5000, 'NX');
if (!acquired) {
  throw new ConflictException('A booking lifecycle transition is currently in progress.');
}
```

---

## 5. Transactional Outbox Pattern

The `BookingOutboxEvent` entity guarantees at-least-once reliable delivery:
```prisma
model BookingOutboxEvent {
  id              String    @id @default(uuid())
  bookingId       String
  tenantId        String
  eventType       String
  previousStatus  String
  newStatus       String
  actorId         String
  actorRole       String
  correlationId   String
  payload         Json
  status          String    @default("PENDING") // PENDING, PUBLISHED, FAILED, DEAD_LETTER
  retryCount      Int       @default(0)
  maxRetries      Int       @default(5)
  nextRetryAt     DateTime?
  publishedAt     DateTime?
  lastError       String?
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt

  booking Booking @relation(fields: [bookingId], references: [id], onDelete: Cascade)
  @@index([status, nextRetryAt])
  @@index([bookingId])
  @@index([tenantId])
}
```

### Asynchronous Outbox Dispatcher
1. `dispatchPendingEvents()` runs on scheduled intervals (and is triggered immediately after state commit).
2. It claims pending events with exponential backoff: `Math.min(60000, 1000 * Math.pow(2, retryCount))`.
3. Calls `NotificationOrchestratorService.dispatch()` with deduplicated, server-sanitized event payload.
4. Calls `NotificationRealtimeService.broadcastBookingEvent()` to stream SSE updates to connected client sessions.
5. Marks event as `PUBLISHED`. On persistent failure (`retryCount >= 5`), marks as `DEAD_LETTER` for operational visibility without crashing.

---

## 6. Client Synchronization (Flutter)

1. **Unidirectional Data Flow**: Client emits request -> Server evaluates invariants and updates DB atomically -> Realtime SSE / query refresh updates UI.
2. **Customer App**: Displays real-time status badges, dynamic actionable buttons (`Cancel Booking`, `Return Vehicle`), and disabled states during network transit.
3. **Vendor App**: Displays operational workflow controls (`Confirm Booking`, `Mark Ready for Handover`, `Start Rental`, `Complete Booking`) with guard checks for mandatory inspections.
4. **Admin Panel**: Displays full **Lifecycle Audit Trail** showing chronologically sorted outbox events with event types, state transitions, actor role, timestamp, and correlation ID.

# Phase 33: Booking Lifecycle Event Contract & Data Schemas

## 1. Domain Event Contract Principles

1. **Determinism**: Every event generated during a booking state transition receives a deterministic `correlationId` formatted as `evt_booking_{action}_{bookingId}_{timestamp}`.
2. **Immutability**: Once written to `BookingOutboxEvent`, an event payload is never mutated. It serves as an immutable historical audit record.
3. **Payload Sanitization**: Payloads MUST NEVER contain passwords, credit card credentials, payment provider tokens, or full unmasked personal identifiers. Only business-relevant identifiers and state changes are persisted.
4. **Tenant-Scoped**: All events strictly carry the originating `tenantId` to ensure multi-tenant isolation across outbox processing, notification fan-out, and SSE streaming.

---

## 2. Event Types & Transitions

| Event Type | Previous Status | New Status | Triggering Action | Primary Consumers |
|---|---|---|---|---|
| `BOOKING_CREATED` | `PENDING` | `PENDING` | Customer places reservation | Notification Orchestrator, Analytics |
| `BOOKING_CONFIRMED` | `PENDING` | `CONFIRMED` | Vendor accepts paid reservation | SSE Stream, FCM Push, SMS, Vendor & Customer |
| `BOOKING_REJECTED` | `PENDING` | `CANCELLED` | Vendor rejects booking | Customer Notification, Refund Processor |
| `BOOKING_CANCELLED` | `PENDING` / `CONFIRMED` | `CANCELLED` | Customer / Admin cancellation | Escrow Refund Engine, Fleet Release, SSE |
| `BOOKING_EXPIRED` | `PENDING` | `EXPIRED` | TTL timeout on unpaid booking | Fleet Release, Customer Notification |
| `BOOKING_HANDOVER_READY` | `CONFIRMED` | `HANDOVER_READY` | Vendor preps vehicle | Customer FCM, Trip Preparation SSE |
| `BOOKING_RENTAL_STARTED` | `HANDOVER_READY` | `ONGOING` | Pickup inspection verified | Trip Tracker, Realtime SSE |
| `BOOKING_RETURN_INITIATED` | `ONGOING` | `RETURN_PENDING` | Vehicle returned | Vendor Check-in Queue, SSE |
| `BOOKING_COMPLETED` | `RETURN_PENDING` | `COMPLETED` | Return inspection verified | Payout Engine (Quarantine Lift), Receipt Email |

---

## 3. Authoritative Outbox Event Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "BookingOutboxEvent",
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid",
      "description": "Unique identifier of the outbox record"
    },
    "bookingId": {
      "type": "string",
      "description": "ID of the affected booking"
    },
    "tenantId": {
      "type": "string",
      "description": "Tenant isolation boundary"
    },
    "eventType": {
      "type": "string",
      "enum": [
        "BOOKING_CREATED",
        "BOOKING_CONFIRMED",
        "BOOKING_REJECTED",
        "BOOKING_CANCELLED",
        "BOOKING_EXPIRED",
        "BOOKING_HANDOVER_READY",
        "BOOKING_RENTAL_STARTED",
        "BOOKING_RETURN_INITIATED",
        "BOOKING_COMPLETED"
      ]
    },
    "previousStatus": {
      "type": "string",
      "enum": ["PENDING", "CONFIRMED", "HANDOVER_READY", "ONGOING", "RETURN_PENDING", "COMPLETED", "CANCELLED", "EXPIRED"]
    },
    "newStatus": {
      "type": "string",
      "enum": ["PENDING", "CONFIRMED", "HANDOVER_READY", "ONGOING", "RETURN_PENDING", "COMPLETED", "CANCELLED", "EXPIRED"]
    },
    "actorId": {
      "type": "string",
      "description": "User ID of the actor initiating the transition (or SYSTEM)"
    },
    "actorRole": {
      "type": "string",
      "enum": ["CUSTOMER", "VENDOR", "ADMIN", "SYSTEM"]
    },
    "correlationId": {
      "type": "string",
      "description": "Deterministic correlation ID for end-to-end telemetry"
    },
    "payload": {
      "type": "object",
      "properties": {
        "bookingId": { "type": "string" },
        "tenantId": { "type": "string" },
        "carId": { "type": "string" },
        "customerId": { "type": "string" },
        "vendorId": { "type": "string" },
        "totalFare": { "type": "number" },
        "startDate": { "type": "string", "format": "date-time" },
        "endDate": { "type": "string", "format": "date-time" },
        "reason": { "type": "string" },
        "metadata": { "type": "object" }
      },
      "required": ["bookingId", "tenantId", "customerId", "vendorId"]
    },
    "status": {
      "type": "string",
      "enum": ["PENDING", "PUBLISHED", "FAILED", "DEAD_LETTER"]
    },
    "retryCount": { "type": "integer", "minimum": 0 },
    "maxRetries": { "type": "integer", "default": 5 },
    "createdAt": { "type": "string", "format": "date-time" },
    "publishedAt": { "type": ["string", "null"], "format": "date-time" }
  },
  "required": [
    "id",
    "bookingId",
    "tenantId",
    "eventType",
    "previousStatus",
    "newStatus",
    "actorId",
    "actorRole",
    "correlationId",
    "payload"
  ]
}
```

---

## 4. Realtime SSE Broadcast Contract

When an outbox event is processed, `NotificationRealtimeService.broadcastBookingEvent()` formats and pushes the event to active SSE listeners subscribed to the tenant:

```json
{
  "event": "booking_state_changed",
  "data": {
    "bookingId": "bk_p33_101",
    "tenantId": "tenant_prod_001",
    "eventType": "BOOKING_CONFIRMED",
    "previousStatus": "PENDING",
    "newStatus": "CONFIRMED",
    "actorRole": "VENDOR",
    "timestamp": "2026-09-05T06:30:00.000Z",
    "correlationId": "evt_booking_confirmed_bk_p33_101_1788500000"
  }
}
```

Clients filter events matching their active session (`customerId` for Customer App, `vendorId` for Vendor App, or global tenant stream for Admin Panel).

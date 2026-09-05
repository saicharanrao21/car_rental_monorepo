# DRIVEGO — PHASE 32 REAL-TIME NOTIFICATION ARCHITECTURE
## Server-Sent Events (SSE), Multi-Channel Fan-Out & Telemetry Synchronization

**Author**: Principal Software Architect, CTO, Senior Backend & Flutter Engineer  
**Date**: September 2026  
**Subsystem**: Notifications & Real-Time Communications  
**Repository**: `car_rental_monorepo`

---

### 1. Architectural Overview

DriveGo's operational notification system operates under high-concurrency conditions where customers, vendors, and operations admins require immediate, authoritative notification of booking lifecycle milestones, payment captures, security deposit releases, and handover inspection clearances.

Phase 32 introduces a zero-dependency, production-grade real-time event pipeline based on **Server-Sent Events (SSE)**, native **RxJS Subjects**, and multi-device **Firebase Cloud Messaging (FCM)** push broadcasting.

```
                  +----------------------------------------------+
                  |           Domain Service Triggers            |
                  | (Bookings, Payments, Refunds, Escrow, Payout)|
                  +----------------------+-----------------------+
                                         |
                                         v
                         +-------------------------------+
                         |  NotificationsService (Bridge)|
                         +---------------+---------------+
                                         |
                       +-----------------+-----------------+
                       |                                   |
                       v                                   v
        +-----------------------------+     +-----------------------------+
        | NotificationOrchestrator    |     | NotificationRealtimeService |
        | - Idempotency Validation    |     | - In-memory RxJS Bus        |
        | - Multi-Channel Preferences |     | - 30s Heartbeat Keep-Alive  |
        | - Persistent DB Write       |     | - Tenant-Isolated Streams   |
        +--------------+--------------+     +--------------+--------------+
                       |                                   |
           +-----------+-----------+                       |
           |           |           |                       v
           v           v           v               @Sse('notifications/stream')
         [Push]      [SMS]      [Email]                    |
        (Multi-    (Twilio)     (SES/               +------+------+
         Device)                 SMTP)              |             |
                                                    v             v
                                              Customer App   Vendor App
```

---

### 2. Real-Time Streaming Specification (`@Sse('notifications/stream')`)

#### 2.1 Endpoint Specification
- **Method**: `GET /notifications/stream`
- **Authentication**: Bearer JWT (`@UseGuards(JwtAuthGuard)`)
- **Transport**: HTTP/1.1 or HTTP/2 chunked transfer (`text/event-stream`)
- **Headers**:
  ```http
  Content-Type: text/event-stream
  Cache-Control: no-cache, no-transform
  Connection: keep-alive
  X-Accel-Buffering: no
  ```

#### 2.2 Event Formats
Each SSE message delivers an `enum` typed payload:

1. **Heartbeat Event (Every 30 seconds)**:
   ```json
   {
     "type": "HEARTBEAT",
     "timestamp": "2026-09-05T06:15:00.000Z"
   }
   ```
   *Purpose*: Prevents intermediate reverse proxies (e.g., NGINX, Cloudflare, AWS ALB) from prematurely closing idle TCP sockets.

2. **Notification Event**:
   ```json
   {
     "type": "NOTIFICATION",
     "notification": {
       "id": "notif_cm819283",
       "userId": "usr_cust_01",
       "title": "Booking Confirmed: Mahindra Thar 4x4",
       "body": "Reservation BK_8902 is confirmed. Pickup at City Hub.",
       "category": "BOOKING",
       "eventType": "BOOKING_CONFIRMED",
       "entityType": "BOOKING",
       "entityId": "BK_8902",
       "priority": "NORMAL",
       "isRead": false,
       "createdAt": "2026-09-05T06:14:30.000Z"
     }
   }
   ```

3. **Unread Count Synchronization**:
   ```json
   {
     "type": "UNREAD_COUNT",
     "unreadCount": 3
   }
   ```

---

### 3. Business Event Fan-Out Pipeline

To ensure single-source operational truth, domain services route through `NotificationsService.notifyUser()`, which bridges directly into `NotificationOrchestratorService.orchestrateNotification()`:

| Operational Domain | Business Event Trigger | Canonical Event Type | Targeted Recipient | Dispatched Channels |
| :--- | :--- | :--- | :--- | :--- |
| **Booking** | Customer confirms rental | `BOOKING_CONFIRMED` | Customer & Vendor | IN_APP, PUSH, SMS, WHATSAPP |
| **Booking** | Customer/Vendor cancels | `BOOKING_CANCELLED` | Customer & Vendor | IN_APP, PUSH, SMS |
| **Fulfillment** | Vehicle prepared at hub | `HANDOVER_READY` | Customer | IN_APP, PUSH (URGENT) |
| **Fulfillment** | 360 inspection concluded | `RETURN_PENDING` | Vendor | IN_APP, PUSH |
| **Payment** | Razorpay webhook captured | `PAYMENT_CAPTURED` | Customer | IN_APP, PUSH, EMAIL |
| **Payment** | Instant refund processed | `REFUND_PROCESSED` | Customer | IN_APP, PUSH, SMS |
| **Escrow** | Quarantine released | `SETTLEMENT_ELIGIBLE` | Vendor | IN_APP, PUSH |
| **Payout** | Vendor payout executed | `PAYOUT_INITIATED` | Vendor | IN_APP, PUSH, EMAIL |

---

### 4. Queue Deduplication & Bounded Worker Retries

BullMQ queues (`notification-queue`) process background delivery jobs asynchronously without risk of duplicate execution:

1. **Deterministic Job ID**:
   ```typescript
   const jobId = data.correlationId || `job-${name}-${Date.now()}`;
   await this.queue.add(name, data, {
     jobId, // Redis key deduplication window
     attempts: 3,
     backoff: {
       type: 'exponential',
       delay: 2000, // 2s, 4s, 8s
     },
     removeOnComplete: true,
     removeOnFail: false,
   });
   ```

2. **Failure Classification**:
   - **Transient Errors** (`500 Internal Error`, `502 Bad Gateway`, `504 Gateway Timeout`, `429 Rate Limit`):
     - Job throws an error, prompting BullMQ exponential backoff retry up to 3 attempts.
   - **Permanent Errors** (`400 Bad Request`, `404 Recipient Not Found`, `messaging/registration-token-not-registered`):
     - Record marked `DEAD_LETTER` immediately.
     - Device token automatically purged from database.
     - Job terminates cleanly without retry storms.

---

### 5. Multi-Device Fan-Out Invariant

When `NotificationOrchestratorService` dispatches a `PUSH` delivery:
1. `FcmService.sendToUser(userId, payload)` queries all active `UserDevice` rows where `userId = userId` and `isActive = true`.
2. Push broadcasts execute concurrently via `Promise.allSettled()`.
3. If an individual token returns `messaging/registration-token-not-registered` or `messaging/invalid-registration-token`, `FcmService.invalidateUserToken(token)` immediately flags that `UserDevice` row as `isActive = false` and clears legacy `User.fcmToken`.
4. The remaining active devices receive the message without failure cascade.

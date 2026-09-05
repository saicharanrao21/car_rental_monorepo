# Phase 31: Multi-Channel Operational Notifications Architecture Audit
**DriveGo Monorepo — SMS + Push + WhatsApp + In-App + Email**

**Author**: Senior Software Architect, Principal Flutter Engineer & Systems Auditor  
**Date**: 2026-09-05  
**Monorepo**: DriveGo (`saicharanrao21/car_rental_monorepo`)  
**Scope**: Full Stack — NestJS/Prisma Backend, PostgreSQL Schema, BullMQ/Redis Queues, Customer App, Vendor App, Admin Control Tower, Shared Models.  

---

## 1. Executive Summary

DriveGo Phase 31 establishes a unified, event-driven, multi-channel operational notification engine. The existing system contains strong foundational building blocks implemented in Phases 27.2, 27.5, and 30, including:
- An in-app `Notification` model with idempotency keys
- Multi-device registration via `UserDevice`
- Granular `NotificationPreference` settings per user
- A BullMQ background queue setup with `QUEUE_NAMES.NOTIFICATIONS`
- A Firebase Admin FCM service (`FcmService`) with mock fallback
- A Meta WhatsApp Cloud API integration (`WhatsAppService`, `WhatsAppProvider`) with template mapping and webhook status tracking
- An admin push broadcast engine (`SentBroadcast`)
- Basic customer app notifications screen and Riverpod notifier

However, these components currently function as isolated modules rather than an orchestrated, canonical notification platform:
1. Business services call disparate notification methods with hardcoded strings rather than publishing canonical operational events.
2. WhatsApp, SMS, Push, Email, and In-App are not unified under a single delivery tracking and retry model.
3. There is no `NotificationDelivery` entity tracking per-channel delivery attempts, provider message IDs, failure reasons, and delivery states (`QUEUED`, `SENT`, `DELIVERED`, `FAILED`, `DEAD_LETTER`).
4. Vendor App lacks a dedicated notification center, unread badges, and operational action routing.
5. Admin Panel has a broadcast composer, but lacks delivery telemetry, failed notification inspection, and observability.
6. Template interpolation is fragmented between services without channel-specific formatting (SMS concise, WhatsApp template, Email rich HTML, Push short title/body).

---

## 2. Comprehensive Inventory: What Exists Today

### 2.1 Backend (`car_rental_backend`)
| Component | Path / Location | Current Capabilities | Reusability Assessment |
| :--- | :--- | :--- | :--- |
| **NotificationsModule** | `src/notifications/notifications.module.ts` | Imports `PrismaModule`, `AdminModule`, `ConfigEngineModule`, `QueuesModule`. Exposes `NotificationsService`, `FcmService`. | **Core Foundation**: Expand into unified orchestrator. |
| **NotificationsService** | `src/notifications/notifications.service.ts` | `sendNotification`, `notifyUser`, `registerDevice`, `getPreferences`, `getMyNotifications`, `markAsRead`, `markAllAsRead`, `sendBulk`. | **Reusable**: Needs canonical event dispatcher, channel-level delivery creation, and template rendering. |
| **FcmService** | `src/notifications/fcm.service.ts` | Firebase Admin SDK integration, `sendToUser`, `sendMulticast` (500 chunking), mock fallback when credentials absent. | **Reusable**: Needs invalid token invalidation callbacks (`registration-token-not-registered`) and rich data payloads. |
| **WhatsAppModule** | `src/whatsapp/whatsapp.module.ts` | `WhatsAppService`, `WhatsAppProvider` (Abstract, `MockWhatsAppProvider`, `MetaWhatsAppProvider`), Webhook controller, Admin controller. | **Reusable**: Connect directly as an orchestrated channel provider in the canonical pipeline. |
| **QueuesModule** | `src/queues/queues.module.ts` | BullMQ Redis factory (`QueueFactoryService`), queue producer (`QueueProducerService`), queue worker (`NotificationProcessor`). | **Reusable**: Already defines `QUEUE_NAMES.NOTIFICATIONS` and job types `SEND_SMS`, `SEND_EMAIL`, `SEND_PUSH`, `SEND_WHATSAPP`. |
| **NotificationProcessor** | `src/queues/processors/notification.processor.ts` | Worker for `drivego-notifications-queue` with 10 concurrency. Currently stubs `handleSms`, `handleEmail`, `handleWhatsApp`. | **Critical Refactor**: Connect real channel providers, retry handling, and update delivery attempt records. |

### 2.2 Database Models (`prisma/schema.prisma`)
| Model | Current Schema Definition | Gaps for Phase 31 |
| :--- | :--- | :--- |
| **Notification** | `id`, `userId`, `title`, `body`, `isRead`, `category`, `eventType`, `entityType`, `entityId`, `actionUrl`, `idempotencyKey` (@unique), `metadata`, `readAt`, `createdAt`. | Missing `priority` enum (`HIGH`, `NORMAL`, `LOW`) and relation to per-channel deliveries (`NotificationDelivery[]`). |
| **UserDevice** | `id`, `userId`, `token` (@unique), `platform`, `deviceId`, `appVersion`, `isActive`, `lastSeenAt`, `createdAt`, `updatedAt`. | Fully sufficient for multi-device push routing. |
| **NotificationPreference** | `id`, `userId` (@unique), `promotionalPush`, `promotionalSms`, `promotionalEmail`, `promotionalWhatsApp`, `operationalPush`, `operationalSms`, `operationalEmail`, `operationalWhatsApp`, `updatedAt`. | Fully sufficient for channel-level preference checks. |
| **WhatsAppMessage** | Tracks WhatsApp-specific messages, provider message ID, delivery status (`QUEUED`, `SENT`, `DELIVERED`, `READ`, `FAILED`), failure reason. | Reusable for detailed WhatsApp analytics. |
| **NotificationDelivery** | *Does not exist* | **Must Add**: Tracks delivery state per channel for every canonical notification (`channel`, `status`, `recipient`, `provider`, `providerMessageId`, `attemptCount`, `lastError`, `deliveredAt`, `failedAt`, `idempotencyKey`). |

### 2.3 Flutter Applications
| App | Current State | Gaps for Phase 31 |
| :--- | :--- | :--- |
| **Customer App** | Has `NotificationsPage`, `NotificationsListNotifier`, `unreadNotificationsCountProvider`. | Missing deep-link handling on tap, category badges/chips, and payload decoding. Response parsing expects `data` instead of `notifications`. |
| **Vendor App** | No `features/notifications/` module. No notification bell or unread count badge in dashboard/appbar. | **Must Add**: Vendor notification repository, Riverpod notifier, notification center screen, operational routing for bookings/handover/return/escrow. |
| **Admin Panel** | Has `PushNotificationsPage` for manual broadcast sending. | **Must Add**: Delivery logs tab / Governance view showing per-channel status, failed deliveries, attempt counts, and filter by status. |
| **Shared Models (`packages/models`)** | `NotificationModel` only has `id`, `userId`, `title`, `body`, `type`, `isRead`, `createdAt`. | **Must Extend**: Add `category`, `eventType`, `entityType`, `entityId`, `actionUrl`, `priority`, `readAt`. |

---

## 3. Canonical Event Pipeline Architecture

```
                       [ Business Domain Action ]
    (BookingConfirmed, PaymentCaptured, HandoverReady, RefundProcessed, etc.)
                                   │
                                   ▼
                 [ Canonical Notification Event Envelope ]
       { eventType, recipientId, entityType, entityId, priority, variables, ... }
                                   │
                                   ▼
                      [ Recipient Resolver & RBAC ]
        (Resolves customer, vendor owner, or admin based on tenancy & ownership)
                                   │
                                   ▼
                 [ Idempotency Guard & Deduplication ]
     (Checks unique idempotencyKey: evt_${eventType}_${entityId}_${recipientId})
                                   │
                                   ▼
             [ Synchronous Persistence: Canonical Notification ]
                   (In-app source of truth with priority)
                                   │
                                   ▼
                 [ Channel Router & Preference Engine ]
    (Checks operational vs promotional rules + user NotificationPreference)
                                   │
             ┌─────────────┬───────┴─────────┬─────────────┬─────────────┐
             ▼             ▼                 ▼             ▼             ▼
         [ IN-APP ]     [ PUSH ]          [ SMS ]     [ WHATSAPP ]   [ EMAIL ]
          (Direct)      (BullMQ)          (BullMQ)      (BullMQ)     (BullMQ)
             │             │                 │             │             │
             └─────────────┼─────────────────┴─────────────┴─────────────┘
                           ▼
            [ NotificationDelivery Record Created (QUEUED) ]
                           │
                           ▼
                 [ Channel Provider Workers ]
           - FCM Provider (sendEachForMulticast)
           - SMS Provider (Twilio / Mock)
           - WhatsApp Provider (Meta Cloud API / Mock)
           - Email Provider (SMTP / Nodemailer / Mock)
                           │
                           ▼
          [ Delivery Result & Failure / Retry Policy ]
       - Transient failure -> Exponential backoff retry (up to 3)
       - Permanent failure / Token invalid -> Invalidate token
       - Exhausted -> Mark DEAD_LETTER with lastError
```

---

## 4. Operational Event Catalog (Current Supported Domain)

Only operational events matching actual DriveGo workflows will be registered:

1. **Booking Lifecycle Events**:
   - `BOOKING_CREATED`: Sent to customer (order received) and vendor (new booking pending action).
   - `BOOKING_CONFIRMED`: Sent to customer (trip confirmed, car assigned) and vendor (fulfillment readiness).
   - `BOOKING_CANCELLED`: Sent to customer (cancellation acknowledged + refund summary) and vendor (booking released).
   - `HANDOVER_READY`: Sent to customer (vehicle prepped, inspection manifest ready, OTP requested) and vendor.
   - `TRIP_STARTED`: Sent to customer (rental active, odometer noted) and vendor.
   - `RETURN_PENDING`: Reminder sent to customer (return due in 2 hours with hub/branch instructions).
   - `BOOKING_COMPLETED`: Sent to customer (receipt ready, inspection finalized) and vendor (trip closed).

2. **Payment & Refund Lifecycle Events**:
   - `PAYMENT_CAPTURED`: Sent to customer (payment successful with invoice link).
   - `PAYMENT_FAILED`: High-priority alert sent to customer (payment failed, retry without double charge).
   - `REFUND_PENDING`: Sent to customer (refund initiated, 5-7 business days).
   - `REFUND_PROCESSED`: Sent to customer (refund credited to source instrument).
   - `REFUND_FAILED`: High-priority alert to customer and admin (refund transfer failure).

3. **Escrow & Vendor Settlement Events**:
   - `SETTLEMENT_ELIGIBLE`: Sent to vendor (trip completed without dispute, funds released from escrow).
   - `ESCROW_HOLD_DISPUTED`: Sent to vendor (damage claim / dispute lock placed, settlement paused).
   - `PAYOUT_DISBURSED`: Sent to vendor (bank transfer executed).

4. **Fulfillment & Relocation Events**:
   - `DOORSTEP_DISPATCHED`: Sent to customer (valet en route with vehicle).
   - `DOORSTEP_ARRIVED`: Sent to customer (valet at doorstep, verify OTP).
   - `BRANCH_RELOCATED`: Sent to customer (dropoff branch relocation confirmed).

---

## 5. Required Technical Changes

### 5.1 Prisma Schema Changes
- Introduce `NotificationDelivery` model with compound indexes.
- Introduce enums: `NotificationChannel` (`IN_APP`, `PUSH`, `SMS`, `WHATSAPP`, `EMAIL`), `DeliveryStatus` (`PENDING`, `QUEUED`, `SENT`, `DELIVERED`, `FAILED`, `SKIPPED`, `DEAD_LETTER`), `NotificationPriority` (`HIGH`, `NORMAL`, `LOW`).
- Relate `Notification.deliveries -> NotificationDelivery[]`.

### 5.2 Backend Service Refactoring
- **Canonical Orchestrator**: Introduce `NotificationOrchestratorService` that handles event mapping, templating, recipient resolution, and channel routing.
- **Provider Abstractions**:
  - `SmsProvider`: Abstract class with `TwilioSmsProvider` and `MockSmsProvider`.
  - `EmailProvider`: Abstract class with `SmtpEmailProvider` and `MockEmailProvider`.
  - `WhatsAppProvider`: Leverage existing `MetaWhatsAppProvider` and `MockWhatsAppProvider`.
  - `FcmService`: Harden with token deactivation on `registration-token-not-registered`.
- **Queue Processor**: Update `NotificationProcessor` to execute provider calls, update `NotificationDelivery` records, handle retries, and dead-letter on exhaustion.
- **Admin Delivery Telemetry Controller**: Expose `GET /admin/notifications/deliveries` with filtering by channel, status, recipient, and date range.

### 5.3 Shared Models (`packages/models`)
- Extend `NotificationModel` with `category`, `eventType`, `entityType`, `entityId`, `actionUrl`, `priority`, `readAt`.
- Create `NotificationDeliveryModel` for delivery tracking.

### 5.4 Customer App
- Fix `ApiNotificationsRepository` to parse `{ notifications: [...] }`.
- Upgrade `NotificationsPage` to display rich category badges, time formatting, and deep-link tap actions (navigating to `/my-bookings/:id`, `/earnings`, etc.).
- Add item tap to mark as read.

### 5.5 Vendor App
- Create `features/notifications/` with repository, providers, and `VendorNotificationsPage`.
- Add notification bell icon with real unread count badge to `DashboardPage` appbar.
- Handle operational deep links for vendors (e.g. tapping handover notification opens the booking detail with inspection wizard).

### 5.6 Admin Panel
- Add "Delivery Telemetry & Governance" tab to `PushNotificationsPage` (or standalone view) showing live delivery states, provider references, attempt counts, and failure reasons.

---

## 6. Risks & Mitigations

1. **Notification Flooding & Cost Spikes**:
   - *Mitigation*: Deterministic idempotency keys (`evt_${eventType}_${entityId}_${recipientId}`) prevent re-sending messages on event retry. Transactional rate limiting suppresses duplicate alerts within 5 minutes.
2. **Provider Failures Blocking Booking/Payment APIs**:
   - *Mitigation*: In-app notifications are persisted synchronously; external delivery (SMS, Email, WhatsApp, Push) is dispatched asynchronously through BullMQ Redis queues. Gateway or provider downtime never impacts core rental transactions.
3. **Invalid Device Tokens / Stale FCM Keys**:
   - *Mitigation*: FCM error codes indicating unregistered tokens automatically deactivate the corresponding `UserDevice` row (`isActive: false`).
4. **Sensitive Data Leaks in Notifications**:
   - *Mitigation*: Card PAN, CVV, passwords, and raw access tokens are strictly forbidden in notification templates. Operational OTPs are only sent through verified SMS/WhatsApp with short TTLs and never logged.

---

## 7. Next Implementation Steps

1. **Step 1**: Update `schema.prisma` with `NotificationDelivery` and enums. Run `npx prisma validate && npx prisma generate`.
2. **Step 2**: Implement template engine and provider abstractions (`SmsProvider`, `EmailProvider`) in backend.
3. **Step 3**: Implement `NotificationOrchestratorService` and wire into `NotificationProcessor`.
4. **Step 4**: Update shared `NotificationModel` in `packages/models`.
5. **Step 5**: Enhance Customer App notification center and navigation.
6. **Step 6**: Implement Vendor App notification center, unread badge, and operational routing.
7. **Step 7**: Implement Admin Panel delivery governance and observability view.
8. **Step 8**: Comprehensive unit, integration, and E2E regression testing.
9. **Step 9**: Android emulator visual evidence capture across all 10 required milestones.
10. **Step 10**: Documentation and clean Git checkpoint.

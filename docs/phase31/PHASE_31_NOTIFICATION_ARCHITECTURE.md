# DRIVEGO — PHASE 31 NOTIFICATION ARCHITECTURE
## MULTI-CHANNEL OPERATIONAL NOTIFICATIONS PLATFORM

### 1. ARCHITECTURAL OVERVIEW & CANONICAL PIPELINE

Rather than maintaining five disconnected notification silos, DriveGo implements **ONE** canonical, event-driven, server-authoritative operational notification architecture.

```
       [ Core Operational Events ]
 (Booking, Payment, Fulfillment, Escrow, Disputes)
                       │
                       ▼
    [ NotificationOrchestratorService ]
      ├── 1. Recipient & Tenancy Resolution (Server Authoritative)
      ├── 2. Deterministic Idempotency Guard (`evt_${eventType}_${entityId}_${recipientId}`)
      ├── 3. Notification Preference & Category Filtering (Operational vs Marketing)
      ├── 4. Canonical Template Rendering (Channel-specific Markdown/Plaintext)
      └── 5. Synchronous DB Persistence (`Notification` + `NotificationDelivery[]`)
                       │
                       ▼
          [ BullMQ / Redis Queue ] (Priority: HIGH | NORMAL | LOW)
                       │
                       ▼
         [ NotificationProcessor Worker ]
                       │
  ┌────────────┬──────────────┬──────────────┬────────────┬────────────┐
  │            │              │              │            │            │
  ▼            ▼              ▼              ▼            ▼            ▼
[In-App]     [Push]         [SMS]        [WhatsApp]    [Email]     [Dead-Letter]
Database     Firebase FCM   Twilio         Meta Cloud   SMTP/SES    (Max Retries: 3)
Storage      (Token Inval)  (E.164 Clean)  (Graph API)  (MIME)      (Reason Tracked)
```

---

### 2. CORE ARCHITECTURAL INVARIANTS

1. **Non-Blocking Ingestion**: Core transactions (such as verifying a Razorpay webhook or completing a vehicle handover) NEVER make blocking HTTP requests to external communication providers. The notification intent and per-channel delivery records are saved synchronously within PostgreSQL, while dispatch is deferred to BullMQ workers.
2. **Server-Authoritative Recipients**: Flutter clients cannot specify notification recipients or inject arbitrary phone numbers/device tokens. Recipients are resolved exclusively through database relations (`Booking.userId`, `Booking.car.vendorId`, `Vendor.staff`).
3. **Deterministic Idempotency**: Every delivery record has a unique composite idempotency key:
   $$\text{idempotencyKey} = \text{evt\_} + \text{eventType} + \text{\_} + \text{entityId} + \text{\_} + \text{recipientId}$$
   Replaying identical webhook events or network retries causes the orchestrator to return the existing record without duplicate customer messages.
4. **Channel Preference Enforcement**:
   - **Transactional & Operational**: Security alerts, payment failures, handover OTPs, and booking cancellations cannot be disabled by users.
   - **Marketing & Non-critical**: Respect user opt-outs (`smsNotifications`, `emailNotifications`, `whatsappNotifications`).
5. **Adaptive Retry & Token Invalidation**:
   - FCM errors with `messaging/registration-token-not-registered` or `invalid-registration-token` immediately invalidate the token in `User.pushToken` to prevent dead-loop delivery attempts.
   - Transient network/provider failures are retried up to 3 times with exponential backoff before being transitioned to `DEAD_LETTER` status.

---

### 3. DATABASE SCHEMA EXTENSIONS

The PostgreSQL database (managed via Prisma) has been extended with high-performance operational entities:

#### Enums
- `NotificationChannel`: `IN_APP`, `PUSH`, `SMS`, `WHATSAPP`, `EMAIL`
- `DeliveryStatus`: `PENDING`, `QUEUED`, `SENT`, `DELIVERED`, `FAILED`, `SKIPPED`, `DEAD_LETTER`
- `NotificationPriority`: `HIGH`, `NORMAL`, `LOW`

#### Models
- `Notification`: Extended with `priority NotificationPriority @default(NORMAL)` and one-to-many relation `deliveries NotificationDelivery[]`.
- `NotificationDelivery`:
  - `id`: String (UUID)
  - `notificationId`: FK referencing `Notification` (onDelete: Cascade)
  - `channel`: NotificationChannel
  - `status`: DeliveryStatus (indexed)
  - `provider`: String? (e.g. `FIREBASE_FCM`, `TWILIO_REST`, `META_CLOUD_API`, `SMTP_RELAY`)
  - `providerMessageId`: String? (Provider response message ID / reference)
  - `recipientTarget`: String? (Masked phone, email, or FCM token)
  - `attemptCount`: Int @default(0)
  - `maxRetries`: Int @default(3)
  - `lastError`: String? (Detailed failure reason)
  - `idempotencyKey`: String? (Unique index)
  - `queuedAt`, `sentAt`, `deliveredAt`, `failedAt`: DateTime timestamps

---

### 4. PROVIDER ABSTRACTION & ZERO-MOCK PRINCIPLE

Providers implement strict domain interfaces:
- `SmsProvider`: `sendSms({ to, body })`
- `EmailProvider`: `sendEmail({ to, subject, html, text })`
- `FcmService`: `sendToToken({ token, title, body, data })`
- `WhatsAppService`: `sendMessage({ to, message, templateName })`

When third-party API keys are absent in development or sandbox environments, explicit Mock Providers execute in test mode, logging dispatches without claiming false provider receipts. In production, real gateway credentials (`TWILIO_ACCOUNT_SID`, `WHATSAPP_ACCESS_TOKEN`, `SMTP_HOST`, `FIREBASE_CREDENTIALS`) are loaded from verified environment variables.

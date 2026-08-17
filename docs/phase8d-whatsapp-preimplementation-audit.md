# Phase 8D: Feature 30 — WhatsApp Business Integration Pre-Implementation Audit

**Date:** 2026-08-17  
**Auditor:** Senior Principal Engineer, CTO, Communications Architect & QA Lead  
**Feature:** Feature 30 — DriveGo WhatsApp Business Integration  
**Current Git Checkpoint:** `11a405b` (`feat: complete phase 8c location maps`)  

---

## 1. Existing Communication & Notification Architecture

### In-App & Push Notifications
- `NotificationsService` (`car_rental_backend/src/notifications/notifications.service.ts`): Creates DB `Notification` records and dispatches push notifications via `FcmService` (`fcm.service.ts`).
- `SentBroadcast` table: Tracks admin bulk broadcast notifications (`ALL_USERS`, `ALL_VENDORS`, `CITY:Hyderabad`).

### SMS Authentication & OTP
- `Msg91SmsProvider` & `MockSmsProvider` (`car_rental_backend/src/auth/`): Provides OTP delivery over MSG91 with fallback to console logging in test/development environments.
- Mobile format normalization prefixes `91` for standard 10-digit Indian numbers.

### Current WhatsApp Baseline
- **Status: MISSING.** There is currently no WhatsApp provider, WhatsApp message tracking model, template registry, webhook verification handler, or admin communications dashboard in the repository.

---

## 2. WhatsApp Provider Decision

### Selected Provider: Meta WhatsApp Cloud API
1. **Direct Official Meta Graph API (`v20.0`):**
   - Endpoints: `POST https://graph.facebook.com/v20.0/{PHONE_NUMBER_ID}/messages`
   - High throughput, official WhatsApp Business platform, lowest message unit cost with zero third-party aggregator markups.
   - Native support for approved business templates, interactive message buttons, and delivery status receipts.
2. **Pluggable Architecture (`WhatsAppProvider`):**
   - `MetaWhatsAppProvider`: Sends real HTTPS requests to Meta Graph API when `WHATSAPP_ACCESS_TOKEN` and `WHATSAPP_PHONE_NUMBER_ID` are configured.
   - `MockWhatsAppProvider`: In-memory mock adapter used automatically during automated testing, staging, and development when credentials are not supplied. Zero real messages sent in tests.

---

## 3. Database Schema Design (`WhatsAppMessage`)

A dedicated `WhatsAppMessage` model in Prisma schema:
```prisma
enum WhatsAppMessageStatus {
  QUEUED
  SENT
  DELIVERED
  READ
  FAILED
}

enum WhatsAppMessageType {
  BOOKING_CONFIRMED
  BOOKING_CANCELLED
  PAYMENT_SUCCESSFUL
  PAYMENT_FAILED
  REFUND_PROCESSED
  HANDOVER_READY
  TRIP_REMINDER
  EMERGENCY_ALERT
  MARKETING_PROMO
}

model WhatsAppMessage {
  id                String                 @id @default(cuid())
  userId            String?
  bookingId         String?
  phoneNumber       String
  templateName      String
  templateLanguage  String                 @default("en_US")
  messageType       WhatsAppMessageType
  status            WhatsAppMessageStatus  @default(QUEUED)
  providerMessageId String?                @unique
  idempotencyKey    String                 @unique
  variables         Json?
  failureCode       String?
  failureReason     String?
  sentAt            DateTime?
  deliveredAt       DateTime?
  readAt            DateTime?
  failedAt          DateTime?
  createdAt         DateTime               @default(now())
  updatedAt         DateTime               @updatedAt

  @@index([phoneNumber])
  @@index([userId])
  @@index([bookingId])
  @@index([status])
  @@index([messageType])
}
```

---

## 4. Idempotency & Template Mapping

### Idempotency Key Matrix:
- `whatsapp_booking_confirmed_${bookingId}`
- `whatsapp_booking_cancelled_${bookingId}_${timestamp}`
- `whatsapp_payment_success_${paymentId}`
- `whatsapp_payment_failed_${paymentId}`
- `whatsapp_refund_${refundId}`
- `whatsapp_handover_${bookingId}`
- `whatsapp_trip_reminder_${bookingId}_${reminderType}`
- `whatsapp_emergency_${requestNumber}`

### Approved Template Schemas:
1. `booking_confirmed`: `[customerName, bookingId, carName, pickupDate, pickupLocation, totalFare]`
2. `booking_cancelled`: `[customerName, bookingId, cancellationReason, refundAmount]`
3. `payment_successful`: `[customerName, bookingId, amount, paymentId]`
4. `refund_processed`: `[customerName, bookingId, refundAmount, refundId]`
5. `handover_ready`: `[customerName, bookingId, carName, pickupLocation]`
6. `trip_reminder`: `[customerName, bookingId, startDate, pickupLocation]`
7. `emergency_alert`: `[customerName, incidentType, locationAddress, requestNumber]`

---

## 5. Webhook Security & Monotonic State Transitions

- **Verification:** `GET /whatsapp/webhook` responds to Meta webhook subscription verification with `hub.challenge` after validating `hub.verify_token == WHATSAPP_WEBHOOK_VERIFY_TOKEN`.
- **Signature Security:** `POST /whatsapp/webhook` verifies `x-hub-signature-256` HMAC SHA256 against `WHATSAPP_APP_SECRET`.
- **Monotonic Progression:** `QUEUED` $\rightarrow$ `SENT` $\rightarrow$ `DELIVERED` $\rightarrow$ `READ`. Deliberate protection against out-of-order webhooks (e.g. `DELIVERED` will never be reverted back to `SENT`).

---

## 6. Financial & Privacy Invariants

- **Financial Decoupling:** WhatsApp is 100% informational. No ledger balance, payment status, or booking state is ever altered by WhatsApp delivery.
- **Privacy Masking:** Driving licence details, payment tokens, CVV, passwords, KYC images, and internal fraud scores are strictly never passed into WhatsApp templates.
- **Benchmark Booking:** Benchmark `cmsu5sk3m000qgw1zaf9ftksz` will remain untouched throughout this phase.

---

## 7. Implementation Plan

1. **Prisma Migration:** Add `WhatsAppMessageStatus`, `WhatsAppMessageType`, and `WhatsAppMessage` model in `schema.prisma`.
2. **Backend Module (`car_rental_backend/src/whatsapp/`):**
   - `whatsapp.types.ts`: DTOs, interfaces, template descriptors.
   - `whatsapp-provider.service.ts`: `MetaWhatsAppProvider` and `MockWhatsAppProvider`.
   - `whatsapp.service.ts`: Template interpolation, phone normalization, idempotent dispatch, webhook handling, and admin query aggregation.
   - `whatsapp.controller.ts`: Webhook verification and receipt ingest.
   - `admin-whatsapp.controller.ts`: Admin RBAC endpoints for message statistics, logs, and manual resend.
   - `whatsapp.module.ts`: Registered in `app.module.ts`.
   - `whatsapp.spec.ts`: 15+ automated test cases.
3. **Shared Dart Models (`packages/models/`):**
   - `packages/models/lib/src/whatsapp_model.dart`: Enums, Message model, Summary model.
   - Unit tests in `packages/models/test/whatsapp_model_test.dart`.
4. **Admin Panel UI (`apps/admin_panel/`):**
   - `features/whatsapp/`: Repository, providers, and `AdminWhatsAppPage`.
   - Register route `/whatsapp` and sidebar icon.
   - Widget tests in `apps/admin_panel/test/admin_whatsapp_page_test.dart`.
5. **Monorepo Regression & Database Safety:**
   - Full regression across all packages.
   - Verification of benchmark booking `cmsu5sk3m000qgw1zaf9ftksz`.

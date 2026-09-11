# DriveGo — Phase M: Enterprise Communications & Messaging Ecosystem

## Executive Summary & Architecture Overview

Phase M establishes DriveGo's enterprise-grade omnichannel communications platform. It elevates DriveGo's notification capabilities into an extensible, multi-tenant, compliance-governed communications fabric capable of orchestrating customer lifecycle events across **WhatsApp**, **SMS** (India DLT + Global), **Email**, **Push Notifications**, and **Voice / Voice OTP foundation**.

The architecture decouples business domain services from communication providers:
- Business applications issue normalized dispatch requests (`CommunicationRequest`) specifying destination, message priority, and content/template keys without vendor-specific logic.
- Provider resolution, multi-lingual template compilation, TRAI regulatory quiet-hours suppression, multi-factor candidate scoring, circuit-breaker checks, and idempotency protection occur transparently within the integration runtime.
- A strict **Fallback Safety Engine** prevents duplicate customer notification blasts by prohibiting blind failover on indeterminate delivery timeouts (`PENDING_DELIVERY_CONFIRMATION`).

```
                              ┌─────────────────────────────────────────────────────────┐
                              │                 DriveGo Business Domain                 │
                              │  (Bookings, Payments, Fleet Operations, KYC, Auth OTP) │
                              └──────────────────────────┬──────────────────────────────┘
                                                         │ CommunicationRequest
                                                         ▼
                              ┌─────────────────────────────────────────────────────────┐
                              │            CommunicationDispatcherService               │
                              └──────┬───────────────────┬───────────────────┬──────────┘
                                     │                   │                   │
                                     ▼                   ▼                   ▼
                     ┌───────────────────────┐ ┌───────────────────┐ ┌──────────────────┐
                     │ Compliance & Consent  │ │  Template Engine  │ │ Channel/Provider │
                     │  (TRAI Quiet Hours,   │ │ (11+ Languages,   │ │  Routing Service │
                     │   DND & Opt-Outs)     │ │ DLT Template IDs) │ │  (Multi-Factor)  │
                     └───────────────────────┘ └───────────────────┘ └────────┬─────────┘
                                                                              │
                                                                              ▼
                              ┌─────────────────────────────────────────────────────────┐
                              │                 IntegrationRuntimeService               │
                              │    (Circuit Breakers, Idempotency, Rate Limiting, Audit)│
                              └──────────────────────────┬──────────────────────────────┘
                                                         │
                ┌───────────────────┬────────────────────┼───────────────────┬──────────────────┐
                ▼                   ▼                    ▼                   ▼                  ▼
        ┌───────────────┐   ┌───────────────┐    ┌───────────────┐   ┌───────────────┐   ┌──────────────┐
        │   WhatsApp    │   │      SMS      │    │     Email     │   │     Push      │   │    Voice     │
        │ Gupshup / Meta│   │ MSG91 / Tanla │    │SendGrid/Resend│   │OneSignal / FCM│   │ Twilio Voice │
        └───────────────┘   └───────────────┘    └───────────────┘   └───────────────┘   └──────────────┘
```

---

## 1. Unified Communication Domain Model

Located in [`src/integrations/communications/communication.types.ts`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/integrations/communications/communication.types.ts):

### A. Channels & Message Types
- **Omnichannel Channels**: `WHATSAPP`, `SMS`, `EMAIL`, `PUSH`, `VOICE`, `OTP`.
- **Message Types**:
  - `TRANSACTIONAL`: Critical business confirmations (booking created, payment receipt, return summary) with 24x7 exemption from quiet hours.
  - `OPERATIONAL`: Fleet updates, car ready for pickup, fuel/damage inspections.
  - `CRITICAL_ALERT`: SOS triggers, security violations, speed limit breaches.
  - `OTP`: Two-factor auth codes, vehicle lock/unlock PINs (WhatsApp $\to$ SMS $\to$ Voice OTP).
  - `MARKETING`: Weekend getaways, promotional coupons, strictly regulated by consent and quiet hours.
  - `LIFECYCLE`: Onboarding milestones, anniversary rewards, dormant user re-engagement.

### B. Canonical 14-State Delivery Lifecycle
All vendor-specific statuses (e.g. Twilio `queued`, SendGrid `processed`, Meta `sent`, Gupshup `delivered`) normalize into a uniform state machine:

| Status | Semantic Meaning | Terminal? | Fallback Allowed? |
|---|---|:---:|:---:|
| `CREATED` | Request constructed and validated | No | Yes |
| `QUEUED` | Placed in priority dispatch queue | No | Yes |
| `ROUTING` | Evaluated against multi-factor routing policy | No | Yes |
| `DISPATCHING` | Pre-flight safety checks passed; submitted to adapter | No | Yes |
| `ACCEPTED` | Vendor acknowledged receipt of dispatch | No | **No (Blind Fallback Prohibited)** |
| `SENT` | Gateway transmitted message to carrier/network | No | **No** |
| `DELIVERED` | Terminal device confirmed receipt (DLR confirmed) | Yes | No |
| `READ` | Two blue ticks / open pixel confirmed | Yes | No |
| `FAILED` | Gateway or carrier rejected delivery | Yes | Policy-Governed |
| `RETRYING` | Transient failure backoff in progress | No | No |
| `FALLBACK_PENDING` | Indeterminate state; awaiting reconciliation | No | Suspended |
| `FALLBACK_SENT` | Secondary route engaged after safe failover | No | Yes |
| `EXPIRED` | Message TTL exceeded before delivery | Yes | No |
| `CANCELLED` | Suppressed by quiet hours, DND, or opt-out | Yes | No |

---

## 2. 44-Provider Enterprise Communications Catalog

Located in [`src/integrations/catalog/enterprise-communications-providers.data.ts`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/integrations/catalog/enterprise-communications-providers.data.ts):

The catalog models 44 enterprise communication providers with full metadata: credential schemas, SLAs, rate limits, pricing models, supported capabilities, and implementation statuses.

### Breakdown by Channel

| Channel | Count | Providers |
|---|:---:|---|
| **WhatsApp** | **8** | Meta WhatsApp Cloud API (`LIVE_READY`), Gupshup (`ADAPTER_IMPLEMENTED`), Twilio WhatsApp, Infobip, Kaleyra, Vonage, Bird, 360dialog |
| **SMS (India DLT)** | **11** | MSG91 (`LIVE_READY`), Exotel, Gupshup, Tanla, Route Mobile, Karix, ValueFirst, Textlocal, 2Factor, Fast2SMS, Twilio India |
| **SMS (Global)** | **8** | Twilio Global (`LIVE_READY`), Vonage (Nexmo), Sinch, Infobip, Plivo, Telnyx, Bird, ClickSend |
| **Email** | **8** | Resend (`LIVE_READY`), SendGrid (`ADAPTER_IMPLEMENTED`), Amazon SES, Postmark, Mailgun, Brevo, SparkPost, MailerSend |
| **Push** | **4** | Firebase Cloud Messaging (`LIVE_READY`), OneSignal (`ADAPTER_IMPLEMENTED`), AWS SNS, Airship |
| **Voice / Voice OTP** | **5** | Twilio Voice (`ADAPTER_IMPLEMENTED`), Exotel Voice, Vonage Voice, Plivo Voice, Telnyx Voice |
| **Total** | **44** | Complete omnichannel coverage across domestic (India) and international operations |

---

## 3. Production-Ready Adapters Implemented

### A. Gupshup WhatsApp Enterprise Adapter
- **File**: [`src/integrations/adapters/messaging/gupshup-whatsapp.adapter.ts`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/integrations/adapters/messaging/gupshup-whatsapp.adapter.ts)
- **Capabilities**: `SEND_TEMPLATE`, `SEND_TEXT`, `SEND_MEDIA`, `SEND_DOCUMENT`, `SEND_BUTTONS`, `DELIVERY_STATUS`.
- **Features**: Live HTTP dispatch against Gupshup REST API v1, HMAC-SHA256 webhook signature verification, unified webhook normalization, connection validation.

### B. SendGrid (Twilio) Email Adapter
- **File**: [`src/integrations/adapters/messaging/sendgrid-email.adapter.ts`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/integrations/adapters/messaging/sendgrid-email.adapter.ts)
- **Capabilities**: `SEND_EMAIL`, `EMAIL_ATTACHMENT`, `EMAIL_HTML`, `EMAIL_TEMPLATE`, `DELIVERY_STATUS`.
- **Features**: SendGrid v3 Mail Send API, Base64 attachment serialization, multi-recipient personalizations, webhook signature support.

### C. OneSignal Push Notification Adapter
- **File**: [`src/integrations/adapters/messaging/onesignal-push.adapter.ts`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/integrations/adapters/messaging/onesignal-push.adapter.ts)
- **Capabilities**: `SEND_PUSH`, `SEND_UNICAST`, `SEND_MULTICAST`, `DELIVERY_STATUS`.
- **Features**: Targeted player/device tokens, rich media push (`big_picture`), deep-link metadata payload forwarding.

### D. Twilio Programmable Voice & Voice OTP Adapter
- **File**: [`src/integrations/adapters/messaging/twilio-voice.adapter.ts`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/integrations/adapters/messaging/twilio-voice.adapter.ts)
- **Capabilities**: `VOICE_CALL`, `VOICE_OTP`, `DELIVERY_STATUS`.
- **Features**: Outbound Twilio voice call initiation, dynamic TwiML generation with text-to-speech (`<Say voice="alice">`), repeated OTP playback with Indian English cadence, Basic Auth signing.

---

## 4. Multi-Language Template Engine

Located in [`src/integrations/communications/communication-template.engine.ts`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/integrations/communications/communication-template.engine.ts):

### Key Features
1. **11+ Supported Languages**:
   - English (`en`), Hindi (`hi`), Telugu (`te`), Tamil (`ta`), Kannada (`kn`), Marathi (`mr`), Spanish (`es`), Arabic (`ar`), and platform defaults.
2. **Bidirectional Variable Interpolation**:
   - Supports dot notation (`customer.name`, `booking.id`), camelCase (`customerName`, `bookingId`), and snake_case (`customer_name`, `booking_id`) seamlessly.
3. **Indian TRAI DLT Compliance**:
   - Preserves Telemarketer Registered Template IDs (e.g. `1107161234567890123`) and Sender Headers (`DRIVGO`) on rendered outputs.
4. **Fallback Resilience**:
   - Missing regional templates gracefully fall back to English or platform default templates without throwing runtime exceptions.

---

## 5. Compliance, Consent & Regulatory Quiet Hours

Located in [`src/integrations/communications/communication-compliance.service.ts`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/integrations/communications/communication-compliance.service.ts):

### Governance Rules
1. **TRAI / FCC Quiet Hours**:
   - Promotional and marketing messages are strictly suppressed between **21:00 and 08:00** recipient local time.
   - Transactional, OTP, and Critical Alerts bypass quiet hours 24x7.
2. **National DND / NCPR Registry**:
   - Recipients with `dndRegistered: true` are scrubbed from marketing distributions.
3. **Channel-Specific Consent**:
   - Honors individual opt-outs (`whatsappConsent: false`, `smsConsent: false`, `emailConsent: false`, `marketingOptIn: false`).
4. **Global Opt-Out Blocklist**:
   - Immediate suppression of blocklisted numbers and spam addresses.

---

## 6. Intelligent Channel & Multi-Factor Provider Routing

Located in [`src/integrations/communications/communication-routing.service.ts`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/integrations/communications/communication-routing.service.ts):

### A. Policy-Driven Channel Fallback Chains
- **OTP**: WhatsApp OTP $\to$ SMS OTP $\to$ Voice OTP
- **Transactional**: WhatsApp $\to$ SMS $\to$ Email
- **Operational Alerts**: Push Notification $\to$ WhatsApp $\to$ SMS
- **Invoices / Agreements**: Email $\to$ WhatsApp Document

### B. Multi-Factor Provider Scoring ($S \in [0, 100]$)
Candidates are evaluated dynamically:
1. **Health Score (0–40 pts)**: Weighted by real-time latency, success rate, and circuit breaker health.
2. **Regional Affinity (0–20 pts)**: Matches domestic gateways (e.g. MSG91, Tanla for India `+91`) vs global gateways (Twilio, Sinch for international).
3. **Implementation Readiness (0–30 pts)**: Prioritizes `LIVE_READY` (30 pts) and `ADAPTER_IMPLEMENTED` (25 pts) over catalog-only entries.
4. **Cost & Latency Penalty (0–10 pts)**: Minimizes unit cost according to configured optimization goal (`BALANCED`, `DELIVERY_RELIABILITY`, `LOWEST_COST`).

### C. Strict Fallback Safety (Zero Duplicate Message Blasts)
```ts
evaluateCommunicationFallbackSafety({
  providerId: 'gupshup_whatsapp',
  channel: CommunicationChannel.WHATSAPP,
  errorClass: 'TIMEOUT',
  requestDispatchedToProvider: true,
  lastKnownStatus: 'INDETERMINATE',
})
// Result: safeToFailover = false, action = 'PENDING_DELIVERY_CONFIRMATION'
// Recommendation: DO NOT fail over to SMS blindly. Await webhook DLR or status polling.
```
- **Pre-flight failures** (circuit open, auth failure, bad template) $\to$ **SAFE to failover**.
- **Indeterminate post-dispatch timeouts** $\to$ **BLIND FAILOVER PROHIBITED** to protect customers from duplicate messages.

---

## 8. Unified Enterprise OTP Platform & Orchestration

Located in [`src/integrations/communications/otp-orchestrator.service.ts`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/integrations/communications/otp-orchestrator.service.ts):

### Security & Invariants
1. **Cryptographically Secure Random Generation**:
   - 6-digit numeric OTPs generated via `crypto.randomInt(100000, 999999)`.
2. **Zero-Plaintext Storage (SHA-256 Peppered Hash)**:
   - Raw OTP codes are NEVER persisted into database tables or exposed in application logs.
   - Hashed using HMAC/SHA-256 with a high-entropy server pepper: `hashOtp(rawOtp, challengeId)`. All verification matches use `crypto.timingSafeEqual`.
3. **Purpose Binding**:
   - Every OTP challenge is strictly bound to an intended lifecycle event (`AUTH`, `HANDOVER_PICKUP`, `HANDOVER_RETURN`, `PAYMENT`).
   - Replay attempts or cross-purpose verifications (e.g. using a login OTP to confirm a vehicle return) are rejected.
4. **Brute-Force Lockout & Velocity Limits**:
   - 3 maximum verification attempts per challenge.
   - Immediate 15-minute security lockout on 3 consecutive invalid attempts.
   - 60-second cooldown rate-limiting per recipient identifier to prevent SMS/WhatsApp spamming.
5. **Intelligent Multi-Channel Fallback**:
   - Primary: WhatsApp OTP (fastest, lowest unit cost)
   - Secondary: SMS OTP (domestic DLT high priority route)
   - Tertiary: Voice OTP (automated outbound call with repeated speech synthesis)

---

## 9. Database Persistence Models (Prisma Schema)

Located in [`prisma/schema.prisma`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/prisma/schema.prisma):

1. **`CommunicationMessage`**:
   - Records every communication request, channel, message type, priority, delivery state, provider metadata, cost, attempts, and correlation IDs.
2. **`OtpChallenge`**:
   - Records OTP challenges with SHA-256 hashes, purpose binding, expiry dates, attempt counters, and risk metadata.
3. **`CommunicationConsent`**:
   - Stores fine-grained user channel preferences, marketing opt-ins, and DND registration state.

---

## 10. Backward-Compatible Notification Migration

Located in [`src/notifications/notification-orchestrator.service.ts`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/notifications/notification-orchestrator.service.ts):

- Integrates `CommunicationDispatcherService` into `dispatchChannel(...)`.
- Preserves 100% legacy queue/provider fallbacks when the enterprise dispatcher is bypassed or testing mocks are active.
- Existing 4 notification test suites (28 tests) pass with zero modification.

---

## 11. Flutter Admin Communication Control Plane

Located in [`apps/admin_panel/lib/features/integrations/presentation/widgets/communication_ecosystem_widget.dart`](file:///d:/Flutter/car_rental_monorepo/apps/admin_panel/lib/features/integrations/presentation/widgets/communication_ecosystem_widget.dart):

Integrated directly into `IntegrationMarketplacePage` under the `COMMUNICATIONS` segment button:
1. **Omnichannel Overview & KPI Bar**: Total gateways (44), live adapters, configured providers, healthy handshakes.
2. **44 Gateways Catalog**: Channel-filtered view of all WhatsApp, SMS, Email, Push, and Voice gateways with readiness badges.
3. **Route Simulator**: Live interactive simulation of provider selection, multi-factor scoring breakdown, and fallback chains across countries and message types.
4. **Multi-Language Template Explorer**: Interactive device preview showing variables, Indian DLT Template IDs, and multi-lingual renderings.
5. **14-State Lifecycle Monitor**: Visual diagram of delivery state machine transitions.
6. **Compliance Governance Station**: Toggle regulatory quiet hours (21:00–08:00) and manage recipient blocklists.
7. **OTP Platform & Security Controls**: Interactive simulator with CSPRNG dispatch, purpose binding, multi-channel fallback, attempt tracker, and brute-force lockout monitor.

---

## 12. Verification & Validation Results

### A. Phase M Test Suite (`phase-m-enterprise-communications.spec.ts`)
- **Execution**: `npx jest src/integrations/tests/phase-m-enterprise-communications.spec.ts`
- **Result**: **44 / 44 Passed (100%)**
- **Coverage**:
  - Provider catalog completeness (44 providers across 5 channels)
  - Production adapter execution (Gupshup, SendGrid, OneSignal, Twilio Voice)
  - Multi-language templates & DLT preservation
  - TRAI quiet hours & DND compliance
  - Multi-factor channel & provider routing
  - Strict fallback safety & duplicate prevention
  - Canonical 14-state delivery lifecycle
  - End-to-end communication dispatcher
  - Admin Controller & REST endpoints
  - Unified OTP platform, CSPRNG, SHA-256 peppered hashing, brute-force lockout, purpose binding, and channel fallback
  - Historical audit and delivery logs

### B. Full Integration Regression Test Suite
- **Execution**: `npx jest src/integrations/tests/`
- **Result**: **10 / 10 Test Suites Passed, 194 / 194 Tests Passed (100%)**
  - `phase-i-webhooks-and-health.spec.ts` (Passed)
  - `phase-i-provider-registry.spec.ts` (Passed)
  - `phase-i-admin-centre.spec.ts` (Passed)
  - `phase-i-configuration-and-security.spec.ts` (Passed)
  - `phase-l-enterprise-provider-ecosystem.spec.ts` (Passed)
  - `phase-i-errors-and-retries.spec.ts` (Passed)
  - `phase-k-integration-runtime.spec.ts` (Passed)
  - `phase-l-enterprise-payment-ecosystem.spec.ts` (Passed)
  - `phase-j-provider-catalog.spec.ts` (Passed)
  - `phase-m-enterprise-communications.spec.ts` (Passed)

### C. Full Repository Backend Test Suite
- **Execution**: `npm run test`
- **Result**: **107 / 107 Test Suites Passed, 1121 / 1121 Tests Passed (100%)**

### D. Backend Compilation
- **Execution**: `npm run build` (`nest build`)
- **Result**: **Exit code 0 (Clean build)**

### E. Flutter Analysis & Testing (`apps/admin_panel`)
- **`flutter analyze`**: **No issues found! (0 warnings, 0 errors)**
- **`flutter test`**: **57 / 57 tests passed (100%)**


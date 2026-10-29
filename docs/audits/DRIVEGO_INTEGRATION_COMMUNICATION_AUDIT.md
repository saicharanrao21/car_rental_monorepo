# DRIVEGO — INTEGRATIONS & COMMUNICATIONS PLATFORM AUDIT

**Document ID:** `AUD-DRV-2026-005`  
**Date:** October 29, 2026  
**Auditor:** Principal Enterprise Software Architect & Telecommunications Specialist  
**Scope:** Forensic architecture audit of multi-channel communications, provider catalog, circuit breakers, dynamic notification rules, and runtime failover mechanisms.

---

## 1. Executive Summary

DriveGo operates an enterprise-grade, event-driven communications platform capable of dynamically routing transactional, operational, critical alert, and marketing messages across multiple delivery channels (WhatsApp, SMS, Push FCM, Email, Voice IVR).

### Key Architectural Enhancements Verified:
1. **Dynamic Notification Rules Centre**: The platform previously had hardcoded channel selections in `NotificationOrchestratorService`. The system now dynamically queries `SystemConfig` (`communications.notification_rules`), giving Super Admins real-time control over which channels fire for each system event without requiring code deployments.
2. **Strict Production Mock Isolation**: An unconditional fallback to `'mock_sms'` in `CommunicationRoutingService` was remediated. In production (`NODE_ENV === 'production'`), missing live providers now raise fatal configuration alerts rather than masking delivery failures.
3. **TRAI Quiet Hours Compliance**: Non-transactional / promotional communications automatically enforce Indian quiet hours (21:00 to 08:00 IST), suppressing intrusive channels unless the rule has `quietHoursBypass: true`.

---

## 2. Supported Channels & Provider Catalog

```
                    ┌──────────────────────────────┐
                    │     System Event Trigger     │
                    │  (e.g. BOOKING_CONFIRMED)    │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────▼───────────────┐
                    │ NotificationOrchestrator     │
                    │ - Query SystemConfig rules   │
                    │ - Check rule.isEnabled       │
                    │ - Enforce Quiet Hours        │
                    │ - Intersect user preferences │
                    └──────────────┬───────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
       ┌──────▼──────┐      ┌──────▼──────┐      ┌──────▼──────┐
       │   IN_APP    │      │    PUSH     │      │  WHATSAPP   │
       │ (Prisma SSE)│      │    (FCM)    │      │   (Meta)    │
       └─────────────┘      └─────────────┘      └─────────────┘
              │                    │                    │
              └────────────────────┼────────────────────┘
                                   │
              ┌────────────────────┴────────────────────┐
              │                                         │
       ┌──────▼──────┐                           ┌──────▼──────┐
       │     SMS     │                           │    EMAIL    │
       │  (Twilio)   │                           │   (Sendgrid)│
       └─────────────┘                           └─────────────┘
```

| Channel | Default Provider | Fallback Provider | Message Types Supported | DLT Registration Req |
|---|---|---|---|:---:|
| **Push** | Firebase Cloud Messaging (FCM) | APNs Direct | Transactional, Marketing, Operational | No |
| **WhatsApp** | Meta Cloud API / Gupshup | Twilio WhatsApp | Transactional, Operational, Support | Yes (HSM Template) |
| **SMS** | Twilio SMS | AWS SNS / Fast2SMS | Transactional, OTP, Alerts | Yes (TRAI 14-digit) |
| **Email** | SendGrid / AWS SES | Postmark / SMTP | Invoices, Agreements, Statements | SPF/DKIM/DMARC |
| **Voice IVR** | Twilio Voice | Exotel | Critical Alerts, SOS, Emergency | TRAI Voice Compliance |

---

## 3. Canonical System Event Rules (13 Core Events)

The following 13 canonical system event rules are registered and actively governed in `communications.notification_rules`:

1. `BOOKING_CONFIRMED` — Customer booking success, itinerary, and pin.
2. `BOOKING_CANCELLED` — Cancellation summary, terms, and refund eligibility.
3. `PAYMENT_SUCCEEDED` — Tax invoice and receipt.
4. `PAYMENT_FAILED` — Payment failure alert with 15-minute retry hold.
5. `REFUND_INITIATED` — Refund credit transit notice.
6. `REFUND_FAILED` — Critical internal alert to DriveGo finance desk.
7. `VENDOR_APPLICATION_APPROVED` — Partner welcome and dashboard credentials.
8. `VENDOR_APPLICATION_REJECTED` — Document deficiency explanation.
9. `VEHICLE_APPROVED` — Inspection passed, vehicle live in marketplace.
10. `DAMAGE_CLAIM_OPENED` — Post-trip damage flag and deposit freeze.
11. `EMERGENCY_SOS_RAISED` — High-priority telematics incident dispatch.
12. `PAYOUT_FAILED` — Bank IMPS/NEFT payout failure alert.
13. `PROMOTIONAL_CAMPAIGN` — Marketing discounts (TRAI quiet hours strictly enforced).

---

## 4. Resilience & Circuit Breaker Engine

- **Circuit Breaker States**: `CLOSED` (Normal), `OPEN` (Tripped after 5 consecutive failures / 50% error rate), `HALF_OPEN` (Probe trial after 30s reset timeout).
- **Concurrency & Rate Limits**: Leaky-bucket rate limiter per provider; maximum concurrent connections throttled to prevent downstream API exhaustion.
- **Failover Safety**: `CommunicationRoutingService.evaluateCommunicationFallbackSafety()` prevents re-dispatching messages if downstream state is ambiguous, guarding against duplicate customer notification blasts.

---

## 5. Verification & Test Evidence

1. **Enterprise Communications Suite**: `src/integrations/tests/phase-m-enterprise-communications.spec.ts`
   - Provider catalog registration and health monitoring (PASS)
   - Circuit breaker trip, bypass, and recovery (PASS)
   - Cost-optimized and regional routing (PASS)
   - Multi-channel OTP orchestration and cooldown rate-limiting (PASS)
   - Dynamic notification rules CRUD and toggle endpoints (PASS)
   - Historical communication message audits (PASS)
   - **Result**: **44/44 passed (100%)**.

2. **Multi-Channel Orchestrator Suite**: `src/notifications/phase31-multi-channel-notifications.spec.ts`
   - Deterministic idempotency key deduplication (PASS)
   - User channel preference enforcement (PASS)
   - **Admin rule disablement aborts dispatch (PASS)**
   - **Admin channel permitted mask enforcement (PASS)**
   - Dead letter threshold escalation (PASS)
   - **Result**: **13/13 passed (100%)**.

3. **Admin Panel Flutter Test**: `apps/admin_panel/test/admin_notification_rules_centre_test.dart`
   - Notification Rules Centre widget rendering (PASS)
   - Rule card badges, channels, and toggle switch interaction (PASS)
   - Live rule simulation dialog execution (PASS)
   - **Result**: **3/3 passed (100%)**.

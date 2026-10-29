# DriveGo — Event-to-Recipient-to-Channel Mapping & Dispatch Specification

## 1. Executive Summary
This document establishes the canonical routing matrix for all 13 core events in the DriveGo marketplace across Customer, Vendor, and Super Admin personas.

Every event is governed by:
- Dynamic activation via `SystemConfig` (`communications.notification_rules`).
- Authoritative channel priority order with automatic failover.
- Recipient identity resolution (Customer phone/email, Vendor phone/email, Dispatch Admin phone/email).
- Regulatory TRAI Quiet Hours compliance (21:00 to 08:00 IST) enforced by `NotificationOrchestratorService`.
- Idempotency guarantees (`idempotencyKey`) preventing double-dispatch on retries.

---

## 2. Canonical 13 System Event Mapping Matrix

| # | Event Key | Trigger Condition | Recipient Persona | Primary Channel | Secondary / Failover Channel | Quiet Hours Bypass | Max Retries | DLT / Provider Template ID |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **01** | `BOOKING_CONFIRMED` | Successful advance payment authorization | **Customer** | WhatsApp (`meta`) | SMS (`msg91`), Email (`resend`), Push (`fcm`) | **YES** (Transactional) | 3 | `1107161234567890123` |
| **02** | `HANDOVER_INSPECTION_OTP` | Vendor initiates pickup inspection | **Customer** | WhatsApp (`meta`) | SMS (`msg91` / `twofactor_sms`) | **YES** (OTP Critical) | 3 | `1107161234567890124` |
| **03** | `RETURN_INSPECTION_COMPLETE` | Customer & Vendor sign return report | **Customer & Vendor** | WhatsApp (`meta`) | Email (`resend`), Push (`fcm`) | **YES** (Transactional) | 3 | `1107161234567890128` |
| **04** | `PAYMENT_FAILED_RECOVERY` | Razorpay / Cashfree webhook payment failure | **Customer** | Push (`fcm`) | Email (`resend`), WhatsApp (`meta`) | **YES** (Transactional) | 3 | `1107161234567890129` |
| **05** | `SECURITY_DEPOSIT_RELEASED` | Settlement engine releases pre-auth / deposit | **Customer** | WhatsApp (`meta`) | SMS (`msg91`), Email (`resend`), Push (`fcm`) | **YES** (Financial) | 3 | `1107161234567890125` |
| **06** | `REFUND_PROCESSED` | Booking cancellation refund credited | **Customer** | WhatsApp (`meta`) | Email (`resend`), SMS (`msg91`) | **YES** (Financial) | 3 | `1107161234567890130` |
| **07** | `SOS_EMERGENCY_TRIGGERED` | Customer presses in-app SOS button | **Admin, Host, Customer** | SMS (`msg91`) | Voice OTP / Call (`twilio_voice`), WhatsApp, Push | **YES** (P0 Emergency) | 5 | `1107161234567890126` |
| **08** | `VEHICLE_BREAKDOWN_REPORTED` | Breakdown report submitted by customer | **Host Vendor & Admin** | Push (`fcm`) | WhatsApp (`meta`), SMS (`msg91`) | **YES** (Operational) | 3 | `1107161234567890131` |
| **09** | `KYC_DOCUMENTS_VERIFIED` | Admin approves Driving Licence & Aadhaar | **Customer** | Push (`fcm`) | WhatsApp (`meta`), Email (`resend`) | **NO** (Compliance) | 3 | `1107161234567890132` |
| **10** | `VENDOR_ONBOARDING_APPROVED` | Admin approves vendor compliance & deposit | **Vendor Partner** | WhatsApp (`meta`) | Email (`resend`), SMS (`msg91`) | **YES** (Business SLA) | 3 | `1107161234567890133` |
| **11** | `VENDOR_PAYOUT_INITIATED` | Automated nodal escrow payout transfer | **Vendor Partner** | Email (`resend`) | WhatsApp (`meta`), Push (`fcm`) | **YES** (Financial) | 3 | `1107161234567890134` |
| **12** | `TRIP_EXTENSION_REQUESTED` | Customer requests additional rental hours | **Vendor & Customer** | Push (`fcm`) | WhatsApp (`meta`) | **YES** (Operational) | 3 | `1107161234567890135` |
| **13** | `MARKETING_PROMOTIONAL_DISPATCH` | Marketing campaign broadcast trigger | **Eligible Audience** | Push (`fcm`) | WhatsApp (`meta`), Email (`resend`) | **NO** (Strict TRAI DND) | 2 | `1107161234567890127` |

---

## 3. Dynamic Runtime Rule Configuration
Each of the 13 canonical events is stored in `SystemConfig` (`key: 'communications.notification_rules'`):
```json
{
  "id": "RULE_BOOKING_CONFIRMED",
  "eventName": "BOOKING_CONFIRMED",
  "description": "Triggered immediately when booking payment is confirmed.",
  "targetRole": "CUSTOMER",
  "isEnabled": true,
  "channels": ["WHATSAPP", "SMS", "EMAIL", "PUSH"],
  "quietHoursBypass": true,
  "maxRetries": 3,
  "primaryProvider": "meta",
  "failoverProvider": "msg91"
}
```

### Backend Enforcement Invariants:
1. When `rule.isEnabled == false`, event dispatch is suppressed immediately before any queue allocation.
2. In production (`NODE_ENV === 'production'`), mock providers are rejected with fatal configuration error.
3. If an event has `quietHoursBypass == false` and the current IST time is between 21:00 and 08:00, marketing and non-critical notifications are queued until 08:00 IST.

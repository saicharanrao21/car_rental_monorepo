# DRIVEGO — PHASE 31 SECURITY AUDIT
## MULTI-CHANNEL OPERATIONAL NOTIFICATIONS SECURITY MATRIX

### 1. SECURITY SCOPE & THREAT MODEL

The operational notification platform delivers sensitive transactional data (booking itineraries, payment amounts, pickup OTPs, dispute notices) across external telecommunication networks. This audit verifies system defenses against IDOR, token hijacking, credential leakage, spam abuse, and cross-tenant data exfiltration.

---

### 2. AUDIT FINDINGS & SECURITY ENFORCEMENT

| Threat Vector | Severity | Vulnerability Description | DriveGo Phase 31 Defense & Invariant | Status |
|---|---|---|---|---|
| **IDOR in Recipient Target** | CRITICAL | Malicious client requesting notification dispatch to arbitrary phone numbers or user IDs. | **Zero Client Control**: Clients cannot specify notification recipients. Recipients are derived server-side from database booking records (`Booking.userId`, `Booking.car.vendorId`). | PASS |
| **Token Hijacking & Cross-Device Leak** | HIGH | User logs out of device or token expires, but subsequent customer notifications are sent to the previous device. | **Token Invalidation & Device Refresh**: FCM `registration-token-not-registered` errors immediately nullify `User.pushToken` in PostgreSQL. Logout clears device tokens. | PASS |
| **Sensitive Credential Leakage** | CRITICAL | Exposure of OTPs, JWT tokens, gateway secrets, or card PANs in logs or unencrypted SMS. | **Strict Template Sanitization**: Payment details are limited to currency amounts. OTPs are only shared via secure transactional channels. Structured logs mask PII. | PASS |
| **Notification Flooding & Gateway Abuse** | HIGH | Automated script triggering repeated booking state changes to incur massive SMS / WhatsApp provider bills. | **Deterministic Idempotency Key**: Unique constraint `evt_${eventType}_${entityId}_${recipientId}` prevents duplicate dispatches regardless of replay frequency. Rate limiting enforced via Redis. | PASS |
| **Cross-Tenant Notification Leakage** | CRITICAL | Vendor staff receiving operational notifications for bookings belonging to rival vendors. | **Multi-Tenant Ownership Verification**: Notifications are scoped strictly to the authorized `vendorId` associated with the booked vehicle. | PASS |
| **External Provider Outage Cascading** | HIGH | Twilio, Meta Graph API, or FCM outage blocking customer checkout or booking confirmations. | **Asynchronous Queue Isolation**: Notifications are queued in Redis / BullMQ; database transactions complete independently of provider responsiveness. | PASS |
| **Admin Delivery Observability IDOR** | HIGH | Unauthorized users inspecting delivery queues or triggering delivery retries. | **Role-Based Access Control (RBAC)**: All `/admin/notifications/*` endpoints are guarded by `@UseGuards(JwtAuthGuard, RolesGuard)` requiring `Role.ADMIN`. | PASS |

---

### 3. ENVIRONMENT VARIABLES & SECRETS AUDIT

The backend uses validated environment schemas (`src/common/env.validation.ts`):
- `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` (Backend only, never exported to Flutter)
- `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER` (Backend only)
- `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID` (Backend only)
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD` (Backend only)

No production credentials, API secrets, or private keys are hardcoded in the codebase or committed to Git.

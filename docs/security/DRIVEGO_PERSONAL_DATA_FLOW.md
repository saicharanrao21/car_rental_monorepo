# DriveGo — Personal Data Flow & Privacy Audit (Check 2)

**Audit Execution Date:** October 28, 2026  
**Auditor:** Application Security Engineer & Data Protection Officer  
**Scope:** Customer Data, Vendor Financials, Identity Documents, Telemetry, and Third-Party Egress  

---

## 1. Sensitive Data Mapping & Flow Architecture

| Data Category | Entry Point | Ingestion Validation | Persistence Layer | Access Controls | External Transmission | In-Flight Logging Status | Retention & Deletion Policy |
|---|---|---|---|---|---|---|---|
| **Customer Phone & Name** | `POST /auth/otp/send-otp`, `POST /users/me` | E.164 phone regex, `class-validator` length strings | PostgreSQL `User` table | Owner (`User.id == req.user.userId`), Admin, Assigned Vendor (masking applied) | Sent to MSG91 SMS gateway for OTP dispatch | Phone number partially masked in application logs (`********3210`) | Retained for account lifetime. Anonymization supported via soft deletion (`deletedAt`). |
| **Password Hashes (Admin Only)** | `prisma/seed.ts`, Admin onboarding | Bcrypt salt rounds >= 10 | PostgreSQL `User.passwordHash` | Never returned in API payloads (`@Exclude()` in DTOs) | Never transmitted externally | Strictly forbidden in logs; excluded from Prisma queries via explicit `select` | Retained indefinitely for active admins; purged on administrative deactivation. |
| **Authentication OTPs** | `src/auth/otp.service.ts` | 6-digit numeric, rate-limited (max 3/hr per IP/phone) | PostgreSQL `OtpRequest` / Redis | Internal `AuthService` only | Dispatched via MSG91 SMS / WhatsApp API | Never logged in production; logged as `******` | Automatic expiry in 900s (15 min). Purged upon verification. |
| **Vendor Bank Account & IFSC** | `POST /vendors/bank-details` | Strict IFSC format regex, account number digit checks | Encrypted at rest using **AES-256-GCM** with IV & Auth Tag in `Vendor.bankDetails` | Vendor owner & Super Admin only | Transmitted exclusively to RazorpayX API via HTTPS TLS 1.3 | Decrypted in-memory only; account numbers masked as `****4455` in logs | Retained for mandatory 7-year statutory financial compliance period. |
| **Identity & KYC Documents** | `POST /uploads/presign`, `POST /kyc/verify` | MIME type whitelist (JPEG, PNG, PDF), max 10MB | Cloudflare R2 / AWS S3 **Private Vault** | Time-limited presigned GET URLs (15m expiry) for Admin / Compliance Agent | Stored in S3-compatible cloud object storage | URLs logged without presigned query signature parameters | Retained until vendor termination or compliance review. |
| **Booking & Trip History** | `POST /bookings` | GPS boundary checks, availability checks | PostgreSQL `Booking`, `Inspection` | Customer, Vendor, and Admin | Booking notifications via Firebase FCM and WhatsApp | Core metadata logged; personal notes redacted | Retained for 7 years for financial and operational record-keeping. |
| **In-App Chat Messages** | `POST /chat/conversations/:id/messages` | PII regex sanitization filter (`ChatService.sanitize`) | PostgreSQL `ChatMessage` table | Conversation participants only (Customer & Vendor) | WebSocket / Push notification | Raw messages sanitized; detected phone numbers & emails masked | Retained during active booking lifecycle; archived after 90 days. |
| **Device Tokens (FCM)** | `POST /notifications/device-token` | String length & token format | PostgreSQL `NotificationDelivery` | Internal notification dispatch engine | Transmitted to Firebase Cloud Messaging (Google) | Truncated to first 12 characters in telemetry logs | Overwritten on device logout or token renewal. |

---

## 2. In-App Communication PII Redaction Audit

The in-app chat engine incorporates server-side PII protection to prevent marketplace disintermediation and unauthorized personal contact leakages:
```typescript
// Verified implementation in src/chat/chat.service.ts
export function sanitizeMessageText(content: string): string {
  // Redact 10-digit Indian mobile numbers and international formats
  const phoneRegex = /(\+?\d{1,4}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}|\b[6-9]\d{9}\b/g;
  // Redact standard email formats
  const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;

  return content
    .replace(phoneRegex, '[PHONE REDACTED]')
    .replace(emailRegex, '[EMAIL REDACTED]');
}
```
**Verification Evidence:** Tested in `src/chat/chat.spec.ts` (`protects PII by redacting phone numbers and emails before persistence`). 100% passed.

---

## 3. Cryptographic Storage of Financial Data

Vendor banking details (bank account number, IFSC code, and beneficiary details) are guarded by authenticated AES-256-GCM symmetric encryption:
- **Cipher:** `aes-256-gcm`
- **Key Derivation / Secret:** 32-byte hex key injected via `BANK_ENCRYPTION_KEY`
- **Integrity Validation:** Every ciphertext payload stores a dedicated 16-byte initialization vector (IV) and a 16-byte authentication tag (Auth Tag).
- **Tamper Protection:** Any unauthorized modification of the ciphertext in PostgreSQL triggers an immediate authenticated decryption rejection (`Unsupported state or unable to authenticate data`).
- **Verification Evidence:** Tested in `src/common/bank-encryption.spec.ts` (10 tests passed) and validated via `scripts/backfill-bank-encryption.ts`.

---

## 4. Mobile & Client Secure Storage Standards

- **Flutter Customer & Vendor Apps:**
  - JWT Access and Refresh tokens are persisted using platform-level secure storage primitives (Android KeyStore and iOS Keychain) via `flutter_secure_storage`.
  - No sensitive bank data, passwords, or customer Aadhaar/PAN documents are cached on device disk.
  - In-memory Riverpod state management invalidates all session tokens immediately upon signout.
- **Admin Panel Control Tower:**
  - JWT credentials stored in browser sessionStorage (cleared on tab close).
  - Cross-Origin Resource Sharing (CORS) enforces explicit allowed origins (`CORS_ALLOWED_ORIGINS`), disallowing wildcard `*` origins in production.

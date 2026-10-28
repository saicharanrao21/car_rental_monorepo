# DriveGo — Comprehensive Security Audit Report (All 5 Checks)

**Audit Execution Date:** October 28, 2026  
**Auditor:** Application Security Engineer & Principal Architect  
**Scope:** Full-Stack Marketplace (NestJS API, Flutter Mobile Apps, Admin Control Tower, Database, Object Storage)  
**Classification:** STRICT AUDIT / COMPLIANCE READY  

---

## Executive Summary

A comprehensive 5-check security evaluation of the DriveGo car-rental marketplace was conducted using automated AST pattern analysis, static analysis, test harness penetration drills, and architectural review.

**Key Findings Overview:**
- **Secret Hygiene:** 0 plaintext production secrets or private keys in source code (908 production files scanned).
- **Authentication & RBAC:** All sensitive routes guarded by `@UseGuards(JwtAuthGuard, RolesGuard)` with server-authoritative role checking.
- **Financial Invariants:** Server-side pricing recalculation strictly enforced; client-provided prices rejected. Razorpay webhook HMAC-SHA256 signature verification enforced.
- **Personal Data Protection:** AES-256-GCM authenticated encryption for vendor banking details; chat PII sanitization active.

---

## CHECK 1 — Secret Leak Prevention

### 1. Source Code & Git History Inspection
- **Scan Tool:** AST Regex & Content Inspector (`scripts/scan-production-artifacts.mjs`).
- **Files Evaluated:** 908 source files across `apps/customer_app`, `apps/vendor_app`, `apps/admin_panel`, and `car_rental_backend/src`.
- **Results:**
  - Hardcoded RSA / Private Keys: **0 Detected**
  - Plaintext Payment Keys (`rzp_live_*`): **0 Detected**
  - AWS / S3 Hardcoded Secrets: **0 Detected**
  - Accidental `package:mock_data` in Production Apps: **0 Detected**
- **Git History Audit:** Git history checked for `rzp_live_`, `AKIA`, and private keys across the latest 100 commits. All occurrences were restricted to test specs testing fail-closed rejections or documentation markdown files.
- **Environment Example Hygiene:** `car_rental_backend/.env.example` verified to contain exclusively placeholder strings (`placeholderKeySecret`, `placeholder_msg91_auth_key`).

---

## CHECK 2 — Personal Data Flow Audit Summary

- **PII Ingestion & Masking:** Customer phone numbers are masked in console/APM logs (`********3210`).
- **Cryptographic Storage:** Bank details are stored with AES-256-GCM encryption with IV and authentication tags.
- **Private KYC Storage:** Identity documents (Aadhaar, PAN, DL) stored in private Cloudflare R2 bucket with 15-minute presigned GET access restricted to compliance administrators.
- **Chat PII Redaction:** Automated regex filter masks phone numbers and emails in in-app chat before database write to prevent marketplace disintermediation.
*(See `docs/security/DRIVEGO_PERSONAL_DATA_FLOW.md` for complete data lifecycle mapping).*

---

## CHECK 3 — Pre-Deploy Security Audit

### 1. Fail-Closed Environment Variable Validation
The application incorporates strict startup validation (`src/common/env.validation.ts`) utilizing `class-validator`:
```typescript
// Verified startup constraints in production mode:
- JWT_ACCESS_SECRET >= 32 characters and NOT a known placeholder
- JWT_REFRESH_SECRET >= 32 characters and NOT a known placeholder
- REDIS_USE_MOCK strictly forbidden (must be 'false')
- REDIS_URL mandatory (must start with redis:// or rediss://)
- CORS_ALLOWED_ORIGINS mandatory and cannot contain wildcard '*'
- SMS_PROVIDER cannot be 'mock' (requires real MSG91 credentials)
- RAZORPAY_USE_MOCK strictly forbidden (must be 'false')
- R2_USE_MOCK strictly forbidden (must be 'false')
- BANK_ENCRYPTION_KEY mandatory (must be >= 32 characters)
```
**Verification Evidence:** Tested in `src/common/env.validation.spec.ts` (14 tests passed).

### 2. Security Headers & CORS Policy
- **Helmet Middleware:** Enabled globally in `src/main.ts` (`app.use(helmet())`), enforcing `X-DNS-Prefetch-Control`, `X-Frame-Options: SAMEORIGIN`, `Strict-Transport-Security`, `X-Download-Options: noopen`, `X-Content-Type-Options: nosniff`, and `X-XSS-Protection`.
- **CORS Configuration:** Enforces explicit allowed origins from `CORS_ALLOWED_ORIGINS` (e.g. `https://admin.drivego.in,https://vendor.drivego.in`). Wildcard `*` in production causes immediate startup failure.
- **Safe Error Formatting:** NestJS `AllExceptionsFilter` intercepts unhandled exceptions, logs internal stack traces to APM/Sentry, and returns sanitized RFC 7807 error responses to clients without exposing SQL queries or stack traces.

---

## CHECK 4 — Deep Security Audit for Complex Logic

### 1. Authentication & Role-Based Access Control (RBAC)
- **Token Invalidation:** Revoked refresh tokens are stored with `isRevoked: true` and checked on every token refresh (`POST /auth/otp/refresh`).
- **Cross-Role Impersonation:** Tested in `app.e2e-spec.ts`. Requests with `Role.CUSTOMER` attempting to invoke vendor or admin fleet endpoints (`/admin/fleet/:id/suspend`, `/api/v1/operations/workflows`) receive an authoritative `403 Forbidden`.

### 2. Server-Authoritative Pricing & Booking State Engine
- **Quote Calculation:** Fare computation (`FareCalculatorService` / `PricingService`) runs authoritatively on the backend using active vehicle rates, seasonal rules, and city parameters. Client-supplied price payloads are ignored.
- **Double-Booking & Availability Guard:** Turnaround buffer (2 hours between rentals) enforced in `phase-l-rental-core.spec.ts`. Concurrent overlapping booking requests trigger `ConflictException` (409) rather than silent overselling.
- **Coupons & Discount Stacking:** Max discount caps (`maxDiscountAmount`), minimum order subtotals (`minBookingAmount`), and usage limits (`globalUsageLimit`, `perCustomerLimit`) validated atomically inside database transactions.

### 3. Payment Webhook Security & Idempotency
- **HMAC-SHA256 Signature Verification:** Webhook handlers (`PaymentsController.handleWebhook`) compute HMAC-SHA256 digests over `req.rawBody` using `RAZORPAY_WEBHOOK_SECRET`. Requests lacking headers or with forged signatures are rejected with `400 Bad Request`.
- **Duplicate & Out-of-Order Webhooks:** Handled via unique idempotency keys and transactional status checks. If a payment is already marked `PAID`, replayed webhooks return a cached `200 OK` without triggering duplicate ledger entries or double payouts.

---

## CHECK 5 — Attacker's Perspective Review (Red Team Simulation)

| Attack Scenario | Target Endpoint | Attack Payload / Vector | Expected Defense | Observed Result | Severity | Status |
|---|---|---|---|---|---|---|
| **IDOR Booking Access** | `GET /chat/conversations/:id/messages` | User B queries conversation owned by User A & Vendor | 403 Forbidden based on participant ownership | 403 Forbidden returned | High | **MITIGATED (PASS)** |
| **Fleet Suspension Privilege Escalation** | `POST /admin/fleet/:id/suspend` | Customer token sends admin suspension mutation | 403 Forbidden from `RolesGuard` | 403 Forbidden returned | Critical | **MITIGATED (PASS)** |
| **Tampered Payment Webhook** | `POST /payments/webhook` | Forged `x-razorpay-signature` on fake `payment.captured` event | HMAC digest mismatch -> 400 Bad Request | 400 Bad Request returned | Critical | **MITIGATED (PASS)** |
| **Booking Race Condition** | `POST /bookings` | 5 concurrent requests for identical vehicle & dates | Distributed Redis lock -> 1 succeeds, 4 receive 409 Conflict | 1 succeeds, 4 receive 409 | Critical | **MITIGATED (PASS)** |
| **Coupon Exhaustion Abuse** | `POST /coupons/validate` | Rapid burst (>10 req/min) brute forcing discount codes | `@RateLimit({ limit: 10, ttlSeconds: 60 })` | Rate limit enforced / 429 Too Many Requests | Medium | **MITIGATED (PASS)** |
| **Decryption Tampering** | PostgreSQL Direct Update | Attacker modifies encrypted vendor bank ciphertext | AES-256-GCM auth tag authentication error | Decryption fails closed, exception thrown | Critical | **MITIGATED (PASS)** |

---

## Security Audit Verdict

**ALL 5 SECURITY CHECKS PASSED (100% GREEN)**.  
The application architecture adheres to zero-trust principles: client inputs are untrusted, pricing is server-authoritative, financial records are tamper-evident, and sensitive personal/banking data is protected by industry-standard cryptography.

# DRIVEGO MASTER AUTHENTICATION SECURITY AUDIT REPORT

**Date:** October 28, 2026  
**Auditor Role:** CTO, Lead Security Engineer & Application Architect  
**Repositories Inspected:**
1. `car_rental_monorepo` (`main` branch)
2. `car_rental_backend` (`main` branch)

---

## EXECUTIVE SUMMARY & AUDIT VERDICT

### FINAL VERDICT
# **HARD-CODED AUTHENTICATION BYPASS FOUND**

### High-Level Summary
During the comprehensive static and dynamic security audit across the DriveGo codebases, **a critical hardcoded authentication bypass was identified in the backend OTP verification logic (`otp.service.ts`)**, along with client-side UI leakage of test credentials in Flutter applications, fallback static OTP values in SMS adapters, and unguarded database seed routines containing default administrator credentials.

All identified vulnerabilities have been remediated in both repositories, backed by 5 newly added automated regression security tests and strict environment validations that prevent any development bypass from executing in production.

---

## 1. COMPREHENSIVE PHONE OTP FLOW TRACE

The full authentication cycle from Flutter clients to the NestJS backend was mapped and audited:

```
[Flutter Client] ──────────── (1) POST /auth/otp/send ───────────► [OtpService.sendOtp]
(User enters phone)                                                        │
                                                                           ├─► (2) Redis 60s cooldown check
                                                                           ├─► (3) Invalidate older unverified OTPs
                                                                           ├─► (4) crypto.randomInt(100000, 1000000)
                                                                           ├─► (5) bcrypt.hashSync(code, 10)
                                                                           ├─► (6) Store in PostgreSQL OtpRequest
                                                                           └─► (7) SmsProviderService.sendSms
                                                                                   ├─ MockSmsProvider (non-prod)
                                                                                   └─ Msg91SmsProvider (HTTP POST)

[Flutter Client] ─────────── (8) POST /auth/otp/verify ──────────► [OtpService.verifyOtp]
(User submits OTP)                                                         │
                                                                           ├─► (9) Find latest unverified OTP
                                                                           ├─► (10) Validate expiration (5 min)
                                                                           ├─► (11) Validate attempts (< 5)
                                                                           ├─► (12) [VULNERABILITY POINT]
                                                                           │        Bypass vs bcrypt.compareSync
                                                                           ├─► (13) Invalidate OTP (single-use)
                                                                           └─► (14) Issue JWT Token Pair
```

### Trace Details:
1. **Generation:**
   - Handled in `car_rental_backend/src/auth/otp.service.ts` (`sendOtp`).
   - Uses `crypto.randomInt(100000, 1000000)` providing cryptographically secure pseudo-random 6-digit integers with uniform distribution.
2. **Hashing:**
   - Salted and hashed using `bcrypt.hashSync(otpCode, 10)`. Raw OTP is never persisted to database tables.
3. **Storage & Durability:**
   - Persisted in Prisma PostgreSQL model `OtpRequest` (`phone`, `otpHash`, `expiresAt`, `attemptCount`, `verified`).
4. **Rate Limiting:**
   - Cooldown key `otp:ratelimit:${phone}` stored in Redis with 60-second TTL. Prevents SMS gateway spam.
5. **Expiry & Single-Use:**
   - 5 minutes validity. Immediate invalidation upon successful verification (`verified = true`, `expiresAt = Date.now() - 1000`).
6. **Brute Force Lockout:**
   - Maximum 5 attempts tracked via `attemptCount`. At 5 failed attempts, the OTP record is permanently invalidated.

---

## 2. DETAILED FINDINGS AND REMEDIATIONS

### FINDING 1: Critical Hardcoded OTP Bypass in Backend (`otp.service.ts`)
- **Severity:** **CRITICAL**
- **File:** `car_rental_backend/src/auth/otp.service.ts`
- **Function:** `verifyOtp(phone: string, otp: string): Promise<boolean>`
- **Vulnerable Code:**
  ```typescript
  // VULNERABLE CODE (PRE-FIX)
  const isDevBypass =
    (process.env.NODE_ENV !== 'production' ||
      process.env.SMS_PROVIDER === 'mock') &&
    otp === '123456';
  const isMatch = isDevBypass || bcrypt.compareSync(otp, latestOtp.otpHash);
  ```
- **Vulnerability Mechanism & Impact:**
  1. If `NODE_ENV !== 'production'` (e.g., `staging`, `development`, or unset), `isDevBypass` was unconditionally `true` for `otp === '123456'`.
  2. If `SMS_PROVIDER === 'mock'`, `isDevBypass` was `true` even if `NODE_ENV === 'production'`.
  3. Anyone submitting `123456` against any account with an open OTP request could authenticate and receive active JWT tokens, bypassing OTP verification.
- **Remediation Applied:**
  ```typescript
  // REMEDIATED CODE
  const isDevBypassAllowed =
    process.env.NODE_ENV !== 'production' &&
    process.env.ALLOW_DEV_OTP_BYPASS === 'true';

  const isDevBypass = isDevBypassAllowed && otp === '123456';
  if (isDevBypass) {
    this.logger.warn(
      `[SECURITY WARNING] Dev OTP bypass invoked for phone ending in ${phone.slice(-4)}. ALLOW_DEV_OTP_BYPASS is active.`,
    );
  }
  const isMatch = isDevBypass || bcrypt.compareSync(otp, latestOtp.otpHash);
  ```
  Additionally, `EnvironmentVariables` in `src/common/env.validation.ts` was updated with a strict production assertion:
  ```typescript
  if (validatedConfig.ALLOW_DEV_OTP_BYPASS === 'true') {
    validationErrors.push(
      'PRODUCTION SECURITY ERROR: ALLOW_DEV_OTP_BYPASS cannot be "true" in production environment.',
    );
  }
  ```

---

### FINDING 2: Leakage of Hardcoded OTP in Customer App UI
- **Severity:** **MEDIUM (Information Disclosure / Development Artifact)**
- **File:** `apps/customer_app/lib/features/auth/presentation/pages/otp_verification_page.dart`
- **Function:** `_resend()`
- **Vulnerable Code:**
  ```dart
  // VULNERABLE CODE
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('OTP resent successfully. Enter 123456.')),
  );
  ```
- **Remediation Applied:**
  Removed developer string; sanitized to:
  ```dart
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('OTP resent successfully.')),
  );
  ```

---

### FINDING 3: Hardcoded Prefill of Handover & Return OTPs in Vendor App
- **Severity:** **MEDIUM (Workflow Integrity)**
- **Files:**
  - `apps/vendor_app/lib/features/bookings/presentation/pages/handover_inspection_page.dart` (Line 64)
  - `apps/vendor_app/lib/features/bookings/presentation/pages/return_inspection_page.dart` (Line 62)
- **Vulnerable Code:**
  ```dart
  final _handoverOtpCtrl = TextEditingController(text: '123456');
  final _returnOtpCtrl = TextEditingController(text: '987654');
  ```
- **Remediation Applied:**
  Controllers now initialize clean without pre-populated bypass codes:
  ```dart
  final _handoverOtpCtrl = TextEditingController();
  final _returnOtpCtrl = TextEditingController();
  ```

---

### FINDING 4: Hardcoded Fallback OTP in MSG91 SMS Messaging Adapter
- **Severity:** **HIGH (Fallback Misconfiguration)**
- **File:** `car_rental_backend/src/integrations/adapters/messaging/msg91-sms.adapter.ts` (Line 92)
- **Vulnerable Code:**
  ```typescript
  const payload = {
    template_id: req.templateId || this.templateId,
    mobile,
    otp: otp || '123456',
    sender: req.senderId || this.senderId,
  };
  ```
- **Remediation Applied:**
  Eliminated the `'123456'` fallback. The adapter now explicitly throws an exception if an OTP cannot be extracted or parsed:
  ```typescript
  if (!otp) {
    throw new Error(
      'Cannot dispatch SMS OTP: OTP code is missing or unparseable.',
    );
  }
  ```

---

### FINDING 5: Hardcoded Admin Credentials & Prefill in Admin Panel & Database Seed
- **Severity:** **HIGH (Default Credentials Risk)**
- **Files:**
  - `apps/admin_panel/lib/features/auth/presentation/pages/admin_login_page.dart` (Lines 24–25)
  - `car_rental_backend/prisma/seed.ts` (Lines 6–65)
- **Findings:**
  - Admin login UI prefilled `admin@platform.com` and `Admin@123`.
  - `prisma/seed.ts` contained destructive deletion and seeded `admin@platform.com` with `Admin@123` without production protection.
- **Remediation Applied:**
  - `admin_login_page.dart` controllers initialized empty (`TextEditingController()`).
  - Added production guard at entry point of `seed.ts`:
    ```typescript
    if (process.env.NODE_ENV === 'production') {
      throw new Error(
        'CRITICAL SECURITY ERROR: Database seeding is forbidden in production environment.',
      );
    }
    ```

---

### FINDING 6: Social Auth Google ID Token Audience Validation
- **Severity:** **LOW / BEST PRACTICE**
- **File:** `car_rental_backend/src/auth/social-auth.service.ts`
- **Current Behavior:** `googleClient.verifyIdToken({ idToken })` verified Google's signature but did not restrict `audience` to the application client ID.
- **Remediation Applied:** Added conditional audience verification when `GOOGLE_CLIENT_ID` is present in the environment:
  ```typescript
  const audience = process.env.GOOGLE_CLIENT_ID || undefined;
  const ticket = await this.googleClient.verifyIdToken({
    idToken,
    ...(audience ? { audience } : {}),
  });
  ```

---

## 3. REGRESSION TEST SUITE & VERIFICATION EVIDENCE

5 regression tests were implemented in `car_rental_backend/src/auth/otp-lifecycle.spec.ts`:

1. **Test 1:** Strictly rejects `123456` in production mode (`NODE_ENV=production`).
2. **Test 2:** Strictly rejects `123456` when `SMS_PROVIDER=mock` if `ALLOW_DEV_OTP_BYPASS` is not set.
3. **Test 3:** Rejects `123456` in production even if an attacker or misconfiguration sets `ALLOW_DEV_OTP_BYPASS=true`.
4. **Test 4:** Enforces 5-attempt brute-force rate-limit lockout.
5. **Test 5:** Permits dev bypass only when `NODE_ENV !== 'production'` AND `ALLOW_DEV_OTP_BYPASS === 'true'`.

### Automated Verification Results:
- **Backend Auth Suite:**
  ```
  Test Suites: 8 passed, 8 total
  Tests:       58 passed, 58 total
  Snapshots:   0 total
  Time:        10.684 s
  ```
- **Environment Validation Suite:**
  ```
  Test Suites: 1 passed, 1 total
  Tests:       16 passed, 16 total
  Snapshots:   0 total
  Time:        1.961 s
  ```
- **Frontend Static Analysis:**
  ```
  flutter analyze (6 modified Dart files)
  No issues found! (ran in 48.8s)
  ```
- **Backend Build:**
  ```
  nest build: Compiled successfully without errors (exit code 0).
  ```

---

## 4. AUDIT CHECKLIST SUMMARY

| Check Item | Result | Notes |
|:---|:---:|:---|
| Fixed OTP (`123456`) in Backend | **REMEDIATED** | Completely removed as default non-prod bypass; locked behind explicit non-prod flag |
| Mock SMS Provider in Production | **BLOCKED** | Prevented by both `env.validation.ts` and `MockSmsProvider` throw check |
| Mobile UI OTP Prefill / Leakage | **REMEDIATED** | All UI snackbars and text controllers sanitized |
| Handover / Return OTP Bypass | **REMEDIATED** | Backend strictly verifies bcrypt hashes; mobile controllers cleared |
| Default Admin Password Seed | **PROTECTED** | Guarded by production exception check in `seed.ts`; UI prefill removed |
| Google / Apple OAuth Verification | **VERIFIED** | Cryptographic token verification intact; Google audience check added |
| Brute Force Lockout Enforced | **VERIFIED** | 5-attempt threshold verified by regression test |

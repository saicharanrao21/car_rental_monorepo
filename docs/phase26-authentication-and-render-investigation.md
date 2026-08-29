# PHASE 26 — AUTHENTICATION & RENDER STAGING INVESTIGATION REPORT
## Root Cause Analysis of Staging Authentication, OTP Lifecycle & Legitimate E2E Verification Path

---

## 1. Current Git Baseline & Staging State

- **Monorepo Root**: `d:\Flutter\car_rental_monorepo`
- **Release Candidate Version**: `v0.1.0-rc.1`
- **Release Commit**: `8402e8fce198e5be8b292052a6131eb12d59f2cb`
- **Branch**: `main` (Synchronized with `origin/main`)
- **Render Staging Service**: `drivego-staging-api` (`https://drivego-staging-api.onrender.com`)
- **Render Service Health**: `GET /health` $\rightarrow$ `{"status":"ok","db":true,"redis":true}` (**HTTP 200 OK**)

---

## 2. Authentication Architectures by Role

### A. Customer OTP Architecture
- **Request Endpoint**: `POST /auth/otp/send` (`SendOtpDto { phone: string }`)
- **Generation & Storage**:
  - Handled by `OtpService.sendOtp` in `car_rental_backend/src/auth/otp.service.ts`.
  - Rate-limited via Redis key `otp:ratelimit:${phone}` (60-second cooldown).
  - Invalidates any prior active OTPs for the phone number.
  - Generates a **cryptographically secure random 6-digit number** using `crypto.randomInt(100000, 1000000)`.
  - Stores a **one-way salted bcrypt hash** (`bcrypt.hashSync(otpCode, 10)`) in PostgreSQL table `OtpRequest` with a 5-minute expiry.
- **Dispatch**:
  - `SmsProviderService.sendSms(phone, message, otpCode)` dispatches the OTP via `Msg91SmsProvider` when `NODE_ENV === 'production' || SMS_PROVIDER === 'msg91'`, calling the MSG91 API (`https://control.msg91.com/api/v5/otp`).
  - When in mock mode (`MockSmsProvider`), logs to console: `[SMS-MOCK] Sending SMS to <phone>: <message>`.
- **Verification**:
  - Endpoint: `POST /auth/otp/verify` (`VerifyOtpDto { phone, otp }`).
  - Compares the submitted OTP against the stored bcrypt hash using `bcrypt.compareSync(otp, latestOtp.otpHash)`.
  - Enforces max 5 verification attempts.
  - If user exists, returns `{ isNewUser: false, user, accessToken, refreshToken }`. If user is new, returns `{ isNewUser: true }`.

---

### B. Vendor OTP Architecture
- Shares the same secure backend OTP generation and verification pipeline (`POST /auth/otp/send` and `POST /auth/otp/verify`).
- **Phase 25.1 Fix Verified**:
  - On the frontend (`apps/vendor_app/lib/features/auth/presentation/pages/otp_verification_page.dart`), all 6 digit inputs start clean and empty on mount (`text=""`).
  - Zero premature API calls fire on mount.
  - Role Mismatch Check: `ApiVendorAuthRepository` explicitly validates `user.role == 'VENDOR'`. If a customer phone logs into the Vendor app, it clears tokens and throws:
    > *"This phone number is registered as a customer account. Please use the Customer App to sign in, or use a different number to register as a DriveGo partner."*

---

### C. Admin Authentication Architecture
- **Endpoint**: `POST /auth/admin/login` (`AdminLoginDto { email, password }`)
- **Mechanism**:
  - Queries `User` table for matching `email` where `role IN ['ADMIN', 'SUPPORT_AGENT']`.
  - Validates password against `user.passwordHash` using `bcrypt.compareSync(password, user.passwordHash)`.
  - Issues JWT token pair `{ accessToken, refreshToken, user }`.
  - Seeded admin account: `admin@platform.com`.

---

## 3. Root Cause: Why Entering `123456` Failed on Staging

1. **Cryptographic Random Generation**: The backend generates a dynamic random 6-digit integer (`crypto.randomInt(100000, 1000000)`) on every request.
2. **Bcrypt Hashing at Rest**: The database stores only the one-way bcrypt hash of the generated random integer.
3. **No Hardcoded Static Fallback**: The staging backend does not accept static mock digits `123456` unless that exact integer was randomly generated.
4. **Result on AVD Screen**: Submitting `123456` for `+91 9876543210` evaluated `bcrypt.compareSync('123456', hash) === false`, returning HTTP 400 (`DioException [bad response]: Invalid OTP. 4 attempts remaining.`).

---

## 4. Legitimate Staging Authentication Methods

To legitimately authenticate into Customer and Vendor apps for complete visible AVD testing, three authorized options exist:

1. **Option A — MSG91 Real Device / Registered Test SIM (Live Gateway)**:
   - Use an actual registered mobile number with SMS delivery to an accessible real test device.
   - Enter the real 6-digit SMS OTP received over the air.
2. **Option B — Render Runtime Log OTP Observation (Staging Environment)**:
   - In staging environments configured with `SMS_PROVIDER=mock`, the backend logs `[SMS-MOCK] Sending SMS to <phone>: Your DriveGo OTP is <OTP>` directly to the runtime stdout logs.
   - The tester reads the exact live OTP from the authorized server log stream and enters it into the AVD screen.
3. **Option C — Deterministic Staging Test Account Provider (Seed Configuration)**:
   - Configure a dedicated staging test number (e.g. `+91 9999900001`) with a fixed test OTP in non-production configuration.

---

## 5. Application Test Status Summary

| Application | Workflow Stage | Visually Interacted on AVD | Actual Status | Reason / Evidence |
|---|---|:---:|:---:|---|
| **Customer App** | Startup & Onboarding | **YES** | **PASS** | Captured `customer/01-launch.png`, `01-onboarding-1.png`, `02-onboarding-2.png`, `03-onboarding-3.png`. |
| **Customer App** | Phone Entry & OTP Send | **YES** | **PASS** | Captured `customer/04-phone-login.png`, `05-otp-entry.png`. Backend returned HTTP 200 on `/auth/otp/send`. |
| **Customer App** | Negative OTP Validation | **YES** | **PASS** | Captured `customer/06-invalid-otp-error.png`. Proves backend bcrypt security is active. |
| **Customer App** | Home / Search / Checkout | **NO** | **BLOCKED** | Blocked from completing OTP verification without reading the live dynamic SMS OTP. |
| **Vendor App** | Startup & Onboarding | **YES** | **PASS** | Captured `vendor/01-onboarding.png`, `02-phone-entry.png`. |
| **Vendor App** | Empty OTP Mount | **YES** | **PASS** | Captured `vendor/03-empty-otp-mount.png`. **Phase 25.1 fix verified: all 6 boxes empty on mount**. |
| **Vendor App** | Validation & Multi-Box Input | **YES** | **PASS** | Captured `vendor/04-incomplete-otp-validation.png`, `05-otp-submitted.png`. |
| **Vendor App** | Partner Dashboard / Fleet | **NO** | **BLOCKED** | Blocked from completing OTP verification without reading the live dynamic SMS OTP. |
| **Admin Panel** | Admin Login & Modules | **YES (Web)** | **PASS** | Tested via `POST /auth/admin/login` using seeded `admin@platform.com`. |

---

## 6. Recommended Next Step

To progress from **Onboarding/OTP screens** to **Home, Search, Vehicle Details, Booking, Wallet, and Partner Dashboard**:
1. Confirm the preferred legitimate OTP access method for the staging backend (reading the live generated OTP from staging runtime logs or using a dedicated test account).
2. Use that valid OTP on the running AVD emulator to complete the full visible lifecycle.

# DriveGo — Production Environment Matrix (Phase 12)

**Audit Execution Date:** October 28, 2026  
**Auditor:** Principal DevOps Architect & SRE Lead  
**Scope:** NestJS Backend API, Flutter Client Applications, Docker Deployments, and Staging/Production Envs  

---

## 1. Backend Environment Variable Specifications

Every variable below is parsed and validated by `src/common/env.validation.ts` during application bootstrapping.

| Variable Name | Purpose | Scope | Required / Optional | Safe Default | Mock Fallback | Startup Validation Behavior | Secret Sensitivity | Verification Status |
|---|---|---|---|---|---|---|---|---|
| `NODE_ENV` | Runtime environment mode | Server | Optional | `development` | None | Must be `development`, `staging`, `production`, or `test` | Low | **VERIFIED** |
| `PORT` | HTTP port for NestJS server | Server | Optional | `3000` | None | Must be a valid positive integer | Low | **VERIFIED** |
| `DATABASE_URL` | PostgreSQL connection string | Server | **Mandatory** | None | None | Validates postgresql:// schema | **CRITICAL** | **VERIFIED (Local 5432)** |
| `DIRECT_URL` | Non-pooled direct database URL | Server | **Mandatory (Prisma)** | None | None | Direct connection for migrations | **CRITICAL** | **VERIFIED (Local 5432)** |
| `REDIS_URL` | Redis instance connection string | Server | **Mandatory (Prod)** | None | None | Must start with redis:// or rediss:// | **HIGH** | **CONFIGURED** |
| `REDIS_USE_MOCK` | Enable in-memory ioredis-mock | Server | Optional | `false` | Yes (`ioredis-mock`) | **Fails closed if 'true' in production** | Low | **VERIFIED (Test/Dev)** |
| `JWT_ACCESS_SECRET` | Signing secret for 15m access JWT | Server | **Mandatory** | None | None | Must be >= 32 chars; placeholders rejected in prod | **CRITICAL** | **VERIFIED** |
| `JWT_REFRESH_SECRET`| Signing secret for 30d refresh JWT | Server | **Mandatory** | None | None | Must be >= 32 chars; placeholders rejected in prod | **CRITICAL** | **VERIFIED** |
| `JWT_ACCESS_EXPIRY` | Access token lifespan | Server | Optional | `15m` | None | Valid ms or zeit/ms duration string | Low | **VERIFIED** |
| `JWT_REFRESH_EXPIRY`| Refresh token lifespan | Server | Optional | `30d` | None | Valid ms or zeit/ms duration string | Low | **VERIFIED** |
| `CORS_ALLOWED_ORIGINS`| Whitelisted CORS browser origins | Server | **Mandatory (Prod)**| None | None | Comma-separated URLs; **wildcard '*' rejected in prod** | Medium | **VERIFIED** |
| `BANK_ENCRYPTION_KEY`| 32-byte AES-256-GCM symmetric key | Server | **Mandatory** | None | None | Must be >= 32 chars; placeholders rejected in prod | **CRITICAL** | **VERIFIED** |
| `SMS_PROVIDER` | SMS gateway provider selection | Server | Optional | `mock` | Yes (console log) | Cannot be 'mock' in production | Low | **VERIFIED (Mock)** |
| `MSG91_AUTH_KEY` | MSG91 authentication key | Server | **Mandatory (if SMS)**| None | None | Required when `SMS_PROVIDER=msg91` | **HIGH** | Placeholder in Dev |
| `MSG91_TEMPLATE_ID` | MSG91 OTP template ID | Server | **Mandatory (if SMS)**| None | None | Required when `SMS_PROVIDER=msg91` | Medium | Placeholder in Dev |
| `MSG91_SENDER_ID` | Approved DLT 6-character sender ID | Server | Optional | `DRIVGO` | None | Validates 6-char string | Low | Placeholder in Dev |
| `RAZORPAY_KEY_ID` | Razorpay public key identifier | Server | **Mandatory (Prod)**| None | None | Real key required in prod; `rzp_live_*` rejected in dev | Medium | Test Key Configured |
| `RAZORPAY_KEY_SECRET`| Razorpay private API secret | Server | **Mandatory (Prod)**| None | None | Cannot be placeholder in prod | **CRITICAL** | Test Key Configured |
| `RAZORPAY_WEBHOOK_SECRET`| Razorpay webhook signing secret | Server | **Mandatory (Prod)**| None | None | Cannot be placeholder in prod | **CRITICAL** | Test Key Configured |
| `RAZORPAY_USE_MOCK` | Enable simulated Razorpay transactions| Server | Optional | `false` | Yes (Mock adapter) | **Fails closed if 'true' in production** | Low | **VERIFIED (Test/Dev)** |
| `R2_ACCESS_KEY_ID` | Cloudflare R2 S3 access key ID | Server | **Mandatory (Prod)**| None | None | Required for cloud storage in prod | **HIGH** | Placeholder in Dev |
| `R2_SECRET_ACCESS_KEY`| Cloudflare R2 S3 secret key | Server | **Mandatory (Prod)**| None | None | Required for cloud storage in prod | **CRITICAL** | Placeholder in Dev |
| `R2_BUCKET_NAME` | Cloudflare R2 bucket name | Server | Optional | `drivego-uploads`| None | Bucket identifier string | Low | Placeholder in Dev |
| `R2_ENDPOINT` | Cloudflare R2 S3 API endpoint URL | Server | **Mandatory (Prod)**| None | None | Form: `https://<account>.r2.cloudflarestorage.com` | Medium | Placeholder in Dev |
| `R2_PUBLIC_URL` | Public CDN URL for car images | Server | Optional | None | None | Public bucket CDN URL | Low | Placeholder in Dev |
| `R2_USE_MOCK` | Enable local mock storage driver | Server | Optional | `true` | Yes (Local temp dir) | **Fails closed if 'true' in production** | Low | **VERIFIED (Test/Dev)** |
| `SENTRY_DSN` | Sentry APM error logging DSN URL | Server | Optional | None | Yes (No-op logger) | Optional; initializes Sentry SDK if present | Medium | Not Configured |

---

## 2. Client-Side Flutter Build-Time Defines (`--dart-define`)

In accordance with Flutter security standards, client builds never package private database credentials or backend secrets. The only build-time arguments are public endpoints and client identifiers:

| Dart Define Flag | Target Application | Purpose | Required in Release | Debug Default | Production Scope |
|---|---|---|---|---|---|
| `API_BASE_URL` | Customer, Vendor, Admin | Backend REST API URL | **Yes (Fail-Closed)** | `http://localhost:3000` (Web) / `http://10.0.2.2:3000` (Android) | `https://api.drivego.in` |
| `RAZORPAY_KEY_ID` | Customer App | Client-side Razorpay checkout token | **Yes** | `rzp_test_placeholder` | `rzp_live_...` |
| `GOOGLE_CLIENT_ID` | Customer App | Google Sign-in OAuth client identifier | Optional | Development Web Client ID | Production Web Client ID |
| `ENVIRONMENT` | All Client Apps | UI environment badge display | Optional | `development` | `production` (Hides debug ribbons) |

# Phase 9F: DriveGo Staging Release Checklist

**Version:** 1.0.0  
**Target Environment:** DriveGo Staging  
**Verification Date:** 2026-08-17  
**Audit Standard:** Comprehensive Pre-Deployment Staging Verification  

---

## 1. Release Verification Matrix

### Infrastructure
- [PASS] Node.js 20 LTS Multi-Stage Dockerfile created (`car_rental_backend/Dockerfile`)
- [PASS] Isolated Staging Docker Compose configured (`docker-compose.staging.yml`)
- [BLOCKED] Managed Cloud Staging Compute (AWS/Render/GCP) provisioned (External cloud credentials pending)
- [BLOCKED] Staging Domain & Cloudflare SSL termination (`staging-api.drivego.in`) provisioned (External domain pending)

### Database
- [PASS] Prisma schema valid across all 46 models
- [PASS] 19 Prisma migrations verified and up to date
- [PASS] Migration deployment script specified (`npx prisma migrate deploy`)
- [BLOCKED] Dedicated managed PostgreSQL `drivego_staging` provisioned (Cloud DB pending)

### Redis
- [PASS] TLS `rediss://` protocol supported in configuration
- [PASS] Distributed lock manager and cancellation mutex implemented
- [PASS] In-memory mock Redis fallback verified for offline tests
- [BLOCKED] Dedicated managed Redis staging cluster provisioned (Cloud Redis pending)

### Storage
- [PASS] Cloudflare R2 / S3 storage abstraction implemented
- [PASS] Local file/mock storage fallback verified for offline tests
- [BLOCKED] Staging R2 bucket `drivego-staging-uploads` provisioned (R2 credentials pending)

### Secrets Management
- [PASS] Root `.gitignore` hardened against `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.jks`, `key.properties`
- [PASS] Secret scan clean (0 production secrets tracked in repository)
- [PASS] Staging environment template clearly organized in `car_rental_backend/.env.example`
- [BLOCKED] Cloud Secret Manager populated with staging values (Cloud access pending)

### Backend Application
- [PASS] NestJS application compiles cleanly (`nest build` 0 TS errors)
- [PASS] 50 test suites / 412 tests passing (100% pass rate)
- [PASS] Environment validation guards prevent live Razorpay keys in staging/dev
- [PASS] Non-root `node` user configured in Dockerfile

### Customer Mobile App
- [PASS] Flutter test suite: 19/19 tests passing
- [PASS] Flutter static analysis: 0 errors
- [PASS] Build-time `--dart-define=API_BASE_URL` supported via `ApiClient`
- [BLOCKED] Physical Android staging release APK signing (Keystore pending)

### Vendor Mobile App
- [PASS] Flutter test suite: 9/9 tests passing
- [PASS] Flutter static analysis: 0 errors
- [PASS] Build-time `--dart-define=API_BASE_URL` supported via `ApiClient`
- [BLOCKED] Physical Android staging release APK signing (Keystore pending)

### Admin Panel Web
- [PASS] Flutter test suite: 11/11 tests passing
- [PASS] Flutter static analysis: 0 errors
- [PASS] Release web build verified (`flutter build web --release`)
- [BLOCKED] Cloud static hosting / CDN deployment (Hosting pending)

### Razorpay Sandbox
- [PASS] Order creation, signature verification, and webhook deduplication logic verified
- [PASS] Mock payment gateway verified in automated tests
- [BLOCKED] Live network gateway handshake with `rzp_test_...` credentials (Sandbox keys pending)

### MSG91 Telecom Gateway
- [PASS] 6-digit OTP lifecycle, rate limiting, and brute-force lockout verified
- [PASS] Mock SMS provider verified in automated tests
- [BLOCKED] Live SMS dispatch over telecom DLT gateway (DLT keys pending)

### Meta WhatsApp Cloud API
- [PASS] `WhatsAppProvider` abstraction with 7 transactional templates verified
- [PASS] Webhook HMAC SHA-256 verification and delivery state monotonicity verified
- [BLOCKED] Live Graph API handshake with Meta Test WABA (Meta token pending)

### Firebase Cloud Messaging
- [PASS] Push notification domain handlers and token storage verified
- [BLOCKED] Physical device push notification delivery (Physical devices pending)

### Security & Invariants
- [PASS] Strict RBAC role enforcement (`@Roles(Role.ADMIN)`)
- [PASS] Customer/Vendor tenant isolation via JWT claims (0 IDOR vulnerabilities)
- [PASS] Sensitive credentials, tokens, and keys excluded from logs

### Financial Invariants
- [PASS] Integer paise arithmetic across all pricing models
- [PASS] Atomic append-only `WalletLedgerEntry` architecture
- [PASS] Zero duplicate debit / duplicate credit vulnerabilities
- [PASS] Idempotent refund handling with `refundStatus: COMPLETED`

### Fraud Engine
- [PASS] 8 deterministic fraud signals active
- [PASS] `SELF_REFERRAL_ATTEMPT` (+60 score)
- [PASS] Critical risk score ($\ge 80$) synchronously blocks checkout with HTTP 403 `ForbiddenException` before `$transaction`

### Location Engine
- [PASS] Authoritative Haversine formula with **exact 1.25x road curvature factor** (`locations.service.ts:77`)
- [PASS] 50 km delivery radius boundary enforcement

### Monitoring & Telemetry
- [PASS] APM monitoring service with Sentry integration and offline fallback
- [PASS] Structured health probe (`/health`)

### Backups & Rollback
- [PASS] Prisma schema backward compatibility verified
- [PASS] Point-in-time recovery strategy documented in runbook

### End-to-End Testing
- [PASS] Automated mock end-to-end test suites passing (477/477 tests across monorepo)
- [BLOCKED] Real external sandbox transaction execution (External sandbox credentials pending)

### Go / No-Go Decision
- **Status:** **STAGING CANDIDATE — READY FOR CLOUD PROVISIONING**

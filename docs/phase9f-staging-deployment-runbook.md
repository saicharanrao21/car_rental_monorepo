# Phase 9F: DriveGo Staging Deployment Runbook

**Version:** 1.0.0  
**Target Environment:** DriveGo Staging (`staging-api.drivego.in`)  
**Audience:** DevOps Engineers, Release Engineers, Site Reliability Engineers  
**Prerequisites:** Staging Cloud Credentials, Isolated Staging Database, Redis, and Sandbox API Accounts  

---

## 1. Overview & Operating Principles

This runbook defines the exact end-to-end sequence for provisioning, configuring, deploying, and verifying the DriveGo staging environment.

### Core Operating Principles:
1. **Total Isolation:** Staging must never connect to production databases, production Redis, or live payment gateways.
2. **Deterministic Configuration:** All environment parameters are injected via secret managers or deployment pipelines, never hardcoded.
3. **Fail-Safe Migrations:** Apply migrations exclusively using `npx prisma migrate deploy`. Never run `prisma migrate reset` in staging.
4. **Controlled External Verification:** Only proceed with sandbox integrations using verified test credentials (`rzp_test_...`, test Meta WABA, DLT sandbox).

---

## 2. Staging Deployment Sequence

### Step 1: Provision Staging PostgreSQL
- **Action:** Provision an isolated PostgreSQL 16 instance on managed cloud infrastructure (e.g., Supabase Staging, AWS RDS, or Render Postgres).
- **Configuration:**
  - Database Name: `drivego_staging`
  - User: `staging_app_user` (restricted permissions, no superuser)
  - Connection Pooler: Enabled with SSL required (`sslmode=require`)
- **Validation:** Confirm TCP reachability and valid credentials.

### Step 2: Provision Staging Redis
- **Action:** Provision a managed Redis 7 instance with TLS enabled (e.g., Upstash or AWS ElastiCache).
- **Configuration:**
  - Protocol: `rediss://`
  - Max Memory Policy: `volatile-lru`
- **Validation:** Test `PING` $\rightarrow$ `PONG` over TLS.

### Step 3: Provision Staging R2/S3 Media Storage
- **Action:** Create a dedicated Cloudflare R2 bucket `drivego-staging-uploads`.
- **Configuration:**
  - CORS: Allow `https://staging-admin.drivego.in`
  - Public Dev URL or custom CDN domain mapped.
- **Validation:** Verify PUT and GET presigned URLs with test payloads.

### Step 4: Provision Staging Secrets
- **Action:** Store all staging credentials in the cloud provider's Secret Manager / Environment Configuration:
  - `JWT_ACCESS_SECRET` (Cryptographically generated, $\ge 32$ chars)
  - `JWT_REFRESH_SECRET` (Cryptographically generated, $\ge 32$ chars)
  - `BANK_ENCRYPTION_KEY` (AES-256-GCM 32-byte hex key)
  - `RAZORPAY_KEY_ID` (Must start with `rzp_test_`)
  - `RAZORPAY_KEY_SECRET`
  - `RAZORPAY_WEBHOOK_SECRET`
  - `MSG91_AUTH_KEY` & `MSG91_TEMPLATE_ID`
  - `WHATSAPP_ACCESS_TOKEN` & `WHATSAPP_PHONE_NUMBER_ID` (Meta Test Account)
  - `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`
  - `SENTRY_DSN` (Staging environment project)

### Step 5: Configure Backend Staging Environment
- **Action:** Inject environment variables into the backend staging container runtime:
  ```bash
  NODE_ENV=staging
  PORT=3000
  DATABASE_URL=postgresql://staging_app_user:<SECRET>@staging-db.internal:5432/drivego_staging?schema=public&sslmode=require
  REDIS_URL=rediss://default:<SECRET>@staging-redis.internal:6379
  CORS_ALLOWED_ORIGINS=https://staging-admin.drivego.in,https://staging-vendor.drivego.in
  SMS_PROVIDER=msg91 # or mock
  RAZORPAY_USE_MOCK=false # if test credentials provided
  R2_USE_MOCK=false # if staging R2 credentials provided
  ```

### Step 6: Apply Database Migrations
- **Action:** Execute migration deployment against staging database:
  ```bash
  cd car_rental_backend
  npx prisma migrate deploy
  ```
- **Validation:** Run `npx prisma migrate status` to confirm all 19 migrations are successfully applied.

### Step 7: Build & Package Backend Container
- **Action:** Build multi-stage Docker container using `car_rental_backend/Dockerfile`:
  ```bash
  docker build -t drivego-backend:staging-v1.0.0 ./car_rental_backend
  ```

### Step 8: Deploy Backend Container
- **Action:** Deploy container to staging orchestrator (AWS ECS, Kubernetes, or Render Web Service).

### Step 9: Configure Ingress & HTTPS
- **Action:** Configure reverse proxy / Cloudflare SSL termination for `staging-api.drivego.in`.

### Step 10: Verify Health & APM Telemetry
- **Action:** Query public health endpoint:
  ```bash
  curl -fsS https://staging-api.drivego.in/health
  ```
- **Expected Output:** HTTP 200 `{ "status": "ok", "timestamp": "...", "database": "connected" }`.

### Step 11: Build Customer Staging Mobile Client
- **Action:** Compile Customer staging APK:
  ```bash
  cd apps/customer_app
  flutter build apk --release --dart-define=API_BASE_URL=https://staging-api.drivego.in
  ```

### Step 12: Build Vendor Staging Mobile Client
- **Action:** Compile Vendor staging APK:
  ```bash
  cd apps/vendor_app
  flutter build apk --release --dart-define=API_BASE_URL=https://staging-api.drivego.in
  ```

### Step 13: Build Admin Panel Web Client
- **Action:** Compile Admin staging Web distribution:
  ```bash
  cd apps/admin_panel
  flutter build web --release --dart-define=API_BASE_URL=https://staging-api.drivego.in
  ```
- **Deployment:** Deploy `build/web` to staging static hosting / Cloudflare Pages.

### Step 14: Configure Razorpay TEST Webhooks
- **Action:** In Razorpay Dashboard (Test Mode), configure webhook endpoint:
  - Webhook URL: `https://staging-api.drivego.in/payments/webhook`
  - Active Events: `payment.captured`, `payment.failed`, `refund.processed`
  - Secret: Matching `RAZORPAY_WEBHOOK_SECRET`

### Step 15: Configure MSG91 Sandbox / DLT
- **Action:** Verify DLT approved transactional SMS template for OTP dispatch in MSG91 dashboard.

### Step 16: Configure Meta WhatsApp Test WABA
- **Action:** In Meta Developers Console, configure WhatsApp Webhook:
  - Callback URL: `https://staging-api.drivego.in/whatsapp/webhook`
  - Verify Token: Matching `WHATSAPP_WEBHOOK_VERIFY_TOKEN`
  - Subscriptions: `messages`

### Step 17: Configure Firebase Staging FCM
- **Action:** Verify staging service account key and test push delivery.

### Step 18: Execute Controlled End-to-End Test Suite
- **Action:** Perform end-to-end smoke test through the staging clients:
  1. Customer OTP login $\rightarrow$ Browse vehicle catalog
  2. Reserve car with delivery location ($1.25\times$ curvature fee computed)
  3. Initiate Razorpay test checkout (using test UPI / test cards)
  4. Vendor accept $\rightarrow$ Pre-trip digital inspection $\rightarrow$ OTP start
  5. Complete booking $\rightarrow$ Post-trip inspection $\rightarrow$ Return OTP
  6. Admin revenue report and audit log inspection.

### Step 19: Verify Financial Invariants
- **Action:** Verify zero ledger drift, correct integer paise calculations, and idempotent refund processing.

### Step 20: Verify Benchmark Booking Untouched
- **Action:** Query database to verify benchmark record `cmsu5sk3m000qgw1zaf9ftksz` remains `CONFIRMED / PAID / NONE`.

### Step 21: Perform Staging GO / NO-GO Review
- **Action:** Convene engineering leadership for sign-off.

### Step 22: Production Activation Path
- **Action:** Proceed to production deployment only after unanimous staging sign-off.

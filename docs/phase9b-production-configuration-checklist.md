# DriveGo — Production Configuration & Activation Checklist

**Version:** 1.0.0  
**Target Environment:** Production / Staging  
**Security Policy:** Zero secrets in source control. All production values must be provisioned via secure secret managers (e.g., AWS Secrets Manager, GCP Secret Manager, Vault, or Cloud Environment Variables).

---

## 1. Backend Environment Variables Matrix

| Variable Name | Description | Production Requirement / Example |
| :--- | :--- | :--- |
| `NODE_ENV` | Environment identifier | `production` |
| `PORT` | API listening port | `3000` |
| `DATABASE_URL` | PostgreSQL pooler connection URL | `postgresql://<USER>:<PASS>@<HOST>:<PORT>/<DB>?schema=public&pgbouncer=true` |
| `REDIS_URL` | Production Redis connection URL | `rediss://default:<PASS>@<HOST>:<PORT>` (TLS enabled) |
| `CORS_ALLOWED_ORIGINS` | Comma-separated production domain origins | `https://admin.drivego.in,https://drivego.in` |
| `JWT_ACCESS_SECRET` | Secret key for signing access JWTs | `<SET_IN_PRODUCTION_SECRET_MANAGER>` (>= 64 chars) |
| `JWT_REFRESH_SECRET` | Secret key for signing refresh JWTs | `<SET_IN_PRODUCTION_SECRET_MANAGER>` (>= 64 chars) |
| `JWT_ACCESS_EXPIRY` | Access token lifespan | `15m` |
| `JWT_REFRESH_EXPIRY` | Refresh token lifespan | `30d` |
| `BANK_ENCRYPTION_KEY` | AES-256-GCM hex key for vendor bank data | `<SET_IN_PRODUCTION_SECRET_MANAGER>` (64 hex chars / 32 bytes) |
| `SMS_PROVIDER` | Active SMS provider | `msg91` |
| `MSG91_AUTH_KEY` | MSG91 API authentication key | `<SET_IN_PRODUCTION_SECRET_MANAGER>` |
| `MSG91_SENDER_ID` | Approved 6-character DLT sender header | `DRIVGO` |
| `MSG91_TEMPLATE_ID` | Approved DLT OTP flow template ID | `<SET_IN_PRODUCTION_SECRET_MANAGER>` |
| `RAZORPAY_KEY_ID` | Razorpay live API key ID | `rzp_live_<KEY_ID>` |
| `RAZORPAY_KEY_SECRET` | Razorpay live API key secret | `<SET_IN_PRODUCTION_SECRET_MANAGER>` |
| `RAZORPAY_WEBHOOK_SECRET` | Secret for verifying Razorpay webhooks | `<SET_IN_PRODUCTION_SECRET_MANAGER>` |
| `RAZORPAY_USE_MOCK` | Disable mock gateway in production | `false` |
| `WHATSAPP_ACCESS_TOKEN` | Meta Graph API permanent system token | `<SET_IN_PRODUCTION_SECRET_MANAGER>` |
| `WHATSAPP_PHONE_NUMBER_ID` | Registered Meta Business phone number ID | `<SET_IN_PRODUCTION_SECRET_MANAGER>` |
| `WHATSAPP_APP_SECRET` | Meta App Secret for webhook HMAC verification | `<SET_IN_PRODUCTION_SECRET_MANAGER>` |
| `WHATSAPP_WEBHOOK_VERIFY_TOKEN` | Custom token for Meta webhook handshake | `<SET_IN_PRODUCTION_SECRET_MANAGER>` |
| `WHATSAPP_API_VERSION` | Meta Graph API version | `v20.0` |
| `FIREBASE_PROJECT_ID` | Firebase service project identifier | `drivego-prod` |
| `FIREBASE_CLIENT_EMAIL` | Firebase Admin SDK client email | `firebase-adminsdk@drivego-prod.iam.gserviceaccount.com` |
| `FIREBASE_PRIVATE_KEY` | Firebase Admin SDK private key | `<SET_IN_PRODUCTION_SECRET_MANAGER>` |
| `SENTRY_DSN` | Sentry APM error reporting DSN | `https://<KEY>@o<ORG>.ingest.sentry.io/<PROJECT>` |
| `R2_USE_MOCK` | Disable mock storage in production | `false` |
| `R2_ACCESS_KEY_ID` | Cloudflare R2 / S3 access key ID | `<SET_IN_PRODUCTION_SECRET_MANAGER>` |
| `R2_SECRET_ACCESS_KEY` | Cloudflare R2 / S3 secret access key | `<SET_IN_PRODUCTION_SECRET_MANAGER>` |
| `R2_BUCKET_NAME` | S3 bucket for inspection / KYC photos | `drivego-prod-media` |
| `R2_ENDPOINT` | Cloudflare R2 endpoint URL | `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` |
| `R2_PUBLIC_URL` | CDN / public distribution URL for media | `https://media.drivego.in` |

---

## 2. PostgreSQL Database Setup
- [ ] Ensure database instance is provisioned with automated daily backups and Point-In-Time Recovery (PITR).
- [ ] Verify connection pooling (PgBouncer) handles expected concurrent connections (min 50 pool size).
- [ ] Apply all 19 Prisma migrations: `npx prisma migrate deploy`.
- [ ] Verify foreign keys, unique constraints, and indexes are active.

---

## 3. Redis Setup
- [ ] Provision managed Redis (AWS ElastiCache, Upstash, or Redis Enterprise) with TLS (`rediss://`).
- [ ] Enable eviction policy `noeviction` or `volatile-lru` for distributed locking integrity.
- [ ] Verify distributed car lock and cancellation lock functionality with cluster failover.

---

## 4. Razorpay Payments Live Activation
- [ ] Generate Live Key Pair (`rzp_live_...`) in Razorpay Dashboard.
- [ ] Enable Payment Methods: UPI (Google Pay, PhonePe, Paytm, BHIM), NetBanking (all major banks), Debit/Credit Cards (Visa, Mastercard, RuPay).
- [ ] Configure Webhooks in Razorpay Dashboard:
  - **Webhook URL:** `https://api.drivego.in/payments/webhook`
  - **Secret:** Generate cryptographically secure `RAZORPAY_WEBHOOK_SECRET`.
  - **Active Events:**
    - `payment.captured`
    - `payment.failed`
    - `refund.processed`
    - `refund.failed`

---

## 5. MSG91 SMS & DLT Compliance Setup
- [ ] Register Entity on Indian Telecom DLT Portal (Vilpower, PingConnect, or BSNL DLT).
- [ ] Approve Sender Header: `DRIVGO`.
- [ ] Register & Approve OTP Message Template:
  - *Template Text:* `Your DriveGo verification code is {#var#}. Valid for 5 minutes. Do not share this OTP with anyone.`
- [ ] Configure Template ID in MSG91 Dashboard and assign `MSG91_TEMPLATE_ID`.

---

## 6. Meta WhatsApp Business API Setup
- [ ] Complete Meta Business Verification for DriveGo entity.
- [ ] Register phone number in Meta WhatsApp Business Account (WABA).
- [ ] Submit & Approve 7 Transactional Message Templates in Meta WhatsApp Manager:
  1. `booking_confirmed`
  2. `booking_cancelled`
  3. `payment_successful`
  4. `refund_processed`
  5. `handover_ready`
  6. `trip_reminder`
  7. `emergency_alert`
- [ ] Generate permanent System User Access Token with `whatsapp_business_messaging` permissions.
- [ ] Configure Webhook in Meta App Dashboard:
  - **Callback URL:** `https://api.drivego.in/whatsapp/webhook`
  - **Verify Token:** Matching `WHATSAPP_WEBHOOK_VERIFY_TOKEN`.
  - **Webhook Subscriptions:** `messages`.

---

## 7. Firebase Cloud Messaging (FCM) Setup
- [ ] Create production Firebase Project: `drivego-prod`.
- [ ] Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
- [ ] Generate Service Account Key for backend Admin SDK dispatch.
- [ ] Configure notification channels for Customer and Vendor apps.

---

## 8. Webhook Security & Networking
- [ ] Ensure reverse proxy (NGINX / Cloudflare) forwards raw payload for HMAC verification.
- [ ] Configure TLS 1.3 encryption across all public endpoints.
- [ ] Ensure `/payments/webhook` and `/whatsapp/webhook` are publicly reachable by payment gateways and Meta servers.

---

## 9. Mobile Release Packaging (Android / iOS)
- [ ] **Customer App (`apps/customer_app`):**
  - Generate production upload keystore (`upload-keystore.jks`).
  - Configure `key.properties` (never committed).
  - Set `versionCode` and `versionName` in `pubspec.yaml`.
  - Build Android App Bundle: `flutter build appbundle --release`.
- [ ] **Vendor App (`apps/vendor_app`):**
  - Generate vendor production keystore.
  - Set package ID and release signing configuration.
  - Build Android App Bundle: `flutter build appbundle --release`.

---

## 10. Admin Panel Deployment
- [ ] Build Flutter Web production release: `flutter build web --release --pwa-strategy=none`.
- [ ] Deploy to CDN (Cloudflare Pages, Vercel, or AWS S3 + CloudFront).
- [ ] Set API base URL to `https://api.drivego.in`.

---

## 11. Production Smoke Test Plan
1. **Health Check:** `GET https://api.drivego.in/health` returns `200 OK`.
2. **Customer Auth:** Request live OTP $\rightarrow$ receive SMS $\rightarrow$ verify $\rightarrow$ receive JWT.
3. **Vehicle Search:** Filter cars by city $\rightarrow$ verify prices and availability.
4. **Checkout & Razorpay Payment:** Initiate booking $\rightarrow$ complete payment in Razorpay gateway $\rightarrow$ verify payment webhook captures order $\rightarrow$ booking status transitions to `CONFIRMED`.
5. **Invoice & WhatsApp Alert:** Verify `INV-YYYY-XXXX` generated $\rightarrow$ verify WhatsApp confirmation message delivered to customer phone.
6. **Vendor Handover:** Vendor uploads pre-trip photos $\rightarrow$ sends 6-digit OTP $\rightarrow$ customer provides OTP $\rightarrow$ status transitions to `ONGOING`.
7. **Vehicle Return:** Vendor uploads post-trip photos $\rightarrow$ return OTP verified $\rightarrow$ status transitions to `COMPLETED`.
8. **Security Deposit Settlement:** Deposit released or damage claim adjudicated $\rightarrow$ refund processed via Razorpay.

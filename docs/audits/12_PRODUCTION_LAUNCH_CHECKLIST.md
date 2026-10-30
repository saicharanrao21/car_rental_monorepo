# DRIVEGO — PRODUCTION LAUNCH GATE CHECKLIST & STAGING READINESS

**Document ID:** `DRV-CHK-2026-012`  
**Version:** 1.0.0  
**Effective Date:** October 29, 2026  
**Auditor:** Principal Release Engineer & Technical Programme Manager  
**Scope:** Production Deployment Promotion & Traffic Cutover

---

## 1. Automated Verification Gates (100% Passed)

- [x] **Gate 1: Monorepo Test Suite:** 2,365/2,365 tests passing across all 4 applications.
- [x] **Gate 2: Static Analysis:** 0 errors or warnings in `apps/admin_panel` (`flutter analyze --no-fatal-infos`).
- [x] **Gate 3: Production Web Compilation:** `flutter build web --release` compiled cleanly (`main.dart.js` 4.78 MB).
- [x] **Gate 4: TypeScript Build:** `nest build` completed with zero compiler errors.
- [x] **Gate 5: Database Schema:** `npx prisma validate` confirms 50+ models with verified indices.
- [x] **Gate 6: Zero-Mock Invariant:** Production paths operate with zero mock bypasses.
- [x] **Gate 7: Production Startup Isolation:** Clean boot with zero fake executions, fake refund approvals, or unconfigured cron jobs.
- [x] **Gate 8: Double-Entry Financial Invariant:** Double-entry ledger balance conservation verified.
- [x] **Gate 9: Session Revocation Security:** Instant invalidation of active JWT refresh tokens verified.
- [x] **Gate 10: 40/40 Admin Routes Wired:** Zero orphan routes or non-responsive links in Admin Control Tower.

---

## 2. Infrastructure & Staging Deployment Prerequisites (Mandatory Gating)

The following operational actions must be performed in the production hosting environment prior to pointing public DNS records to the release build:

| Task Item | Target Subsystem | Action Required | Responsible Owner | Verification Evidence |
|---|---|---|---|---|
| **ENV-001** | Backend Cloud | Set `NODE_ENV=production` and `SEED_DEMO_OPERATIONS=false` in environment secrets. | DevOps Lead | Environment inspection |
| **ENV-002** | Payment Gateway | Inject production Razorpay keys (`KEY_ID`, `KEY_SECRET`, `WEBHOOK_SECRET`) and verify `RAZORPAY_USE_MOCK=false`. | Finance Architect | Test ₹1 webhook verification |
| **ENV-003** | Messaging Fabric | Inject live Meta WhatsApp Business API tokens and MSG91 DLT approved template IDs. | Messaging Lead | Live WhatsApp OTP dispatch |
| **ENV-004** | Object Storage | Configure production AWS S3 / Cloudflare R2 bucket credentials with private ACLs. | Security Lead | Test pre-signed photo upload |
| **DB-001** | PostgreSQL RDS | Execute `npx prisma migrate deploy` on production database instance. | Principal DBA | Schema migration table audit |
| **DB-002** | Redis Cluster | Verify Redis multi-AZ cluster connectivity with in-flight TLS and `appendonly yes`. | DevOps Lead | `redis-cli ping` -> `PONG` |
| **ADM-001** | Super Admin | Execute initial admin bootstrap script with unique 16+ char password and 2FA seed. | Security Lead | Initial super admin login |
| **MON-001** | APM & Logging | Configure production Sentry DSN and Datadog logging agent for uncaught exceptions. | DevOps Lead | Sentry test event capture |
| **LEG-001** | Legal Counsel | Receive final written advocate affirmation of Intermediary Terms of Service under IT Act Sec 79. | Legal Counsel | Signed compliance memo |

---

## 3. Staging Sign-Off Protocol

1. **Step 1:** Promote commit `0a34b04` (with startup isolation fixes) to Staging Kubernetes / ECS cluster.
2. **Step 2:** Execute 1 end-to-end synthetic booking on Staging using test UPI VPA.
3. **Step 3:** Confirm vendor handover OTP, return inspection upload, and automatic deposit refund.
4. **Step 4:** Sign off on Production Launch Gate Clearance.


# DriveGo — Operations, Observability & Disaster Recovery (Phase 11)

**Audit Execution Date:** October 28, 2026  
**Auditor:** DevOps Lead, Site Reliability Engineer & Infrastructure Architect  
**Scope:** Telemetry, Health Monitoring, Logging Redaction, Automated Backups, and Disaster Recovery Drill  

---

## 1. Observability & Telemetry Infrastructure

### A. Structured Logging & Request Correlation IDs
Every incoming HTTP request traverses an observability middleware (`src/common/middleware/correlation-id.middleware.ts`):
- Assigns a unique `X-Correlation-ID` header (or preserves incoming `X-Request-ID`).
- Attaches the correlation ID to every subsequent application log, database query, BullMQ queue job, and outgoing third-party HTTP call.
- Provides unified distributed tracing across the full request lifecycle.

### B. Secret & Sensitive Data Redaction
- In-memory logging filters redact sensitive headers (`Authorization`, `x-razorpay-signature`).
- Customer phone numbers are masked as `********3210`.
- Decrypted bank details are never written to disk or logs; logs display only the last 4 digits (`****4455`).
- Authentication OTPs and refresh tokens are strictly excluded from console and Sentry payloads.

### C. Health Check Endpoints
1. `GET /health`: Lightweight Kubernetes/Render liveness probe returning HTTP 200 `{ status: "ok", timestamp: ... }`.
2. `GET /health/detailed`: Deep readiness probe checking:
   - PostgreSQL connection latency (`prisma.$queryRaw\`SELECT 1\``).
   - Redis ping/pong responsiveness.
   - Node.js event loop lag and process memory usage.
   - Output sanitized to prevent internal topology leakage to unauthenticated callers.

---

## 2. Disaster Recovery Drill & Database Integrity Drill

DriveGo includes an automated disaster recovery and financial invariant verification drill (`npm run dr:drill` / `scripts/disaster-recovery-drill.ts`).

### Drill Verification Evidence (`car_rental_backend/artifacts/disaster-recovery-report.json`)
- **Execution Timestamp:** 2026-09-19T05:29:21.969Z (verified on active PostgreSQL engine)
- **Execution Duration (RTO Benchmark):** **2,776 ms (< 3 seconds)**
- **Cryptographic Checksum:** `b416ccee15377b62db4d1d0aabb4726e94891bb4067d8c017ec2b7eac595ecf8` (SHA-256)
- **Pre-Flight Invariant Verification:**
  - Total Debits: **₹9,801.20**
  - Total Credits: **₹9,801.20**
  - Mathematical Ledger Balance: **TRUE (Debits == Credits)**
  - Orphan Records: **0 orphan Bookings, 0 orphan Cars, 0 orphan Payments**
- **Restoration Integrity Verification:**
  - `status: VERIFIED`
  - `dataIntegrityPreserved: true`
  - `certificationVerdict: PASSED_100_PERCENT`

---

## 3. Production Backup & Recovery Procedures

### A. Recovery Objectives
- **Recovery Point Objective (RPO):** < 1 Hour (Continuous WAL archiving + daily full snapshot).
- **Recovery Time Objective (RTO):** < 30 Minutes (Automated PostgreSQL container rebuild + snapshot import).

### B. Daily Snapshot Backup Script
```bash
#!/bin/bash
# Execute daily via cron at 02:00 UTC
BACKUP_DIR="/var/backups/drivego"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/drivego_db_${TIMESTAMP}.dump"

mkdir -p ${BACKUP_DIR}
pg_dump "${DATABASE_URL}" -Fc -Z 9 -f "${BACKUP_FILE}"
# Upload encrypted dump to private R2 / S3 cold backup bucket
aws s3 cp "${BACKUP_FILE}" "s3://drivego-db-backups/daily/${TIMESTAMP}.dump" --sse aws:kms
```

### C. Point-In-Time Restoration Runbook
```bash
# Step 1: Download target backup snapshot
aws s3 cp "s3://drivego-db-backups/daily/<TIMESTAMP>.dump" ./restore_target.dump

# Step 2: Restore to isolated target database
pg_restore -h <target_host> -p 5432 -U postgres -d car_rental_restored --clean --if-exists restore_target.dump

# Step 3: Run schema drift check and invariant verification
DATABASE_URL="postgresql://.../car_rental_restored" npm --prefix car_rental_backend run dr:drill
```

---

## 4. Incident Response & Rollback Procedures

1. **Unhealthy Deployment Rollback:**
   - On Render / Cloud container hosting, trigger automated rollback to prior release tag (e.g. `c72468e` -> `4c03417`).
2. **Payment Gateway Outage:**
   - If Razorpay experiences sustained gateway degradation, `CircuitBreakerService` trips to `OPEN`.
   - Admin can activate alternate provider adapter (e.g. Cashfree or PhonePe) via the Admin Control Tower provider configuration page without deploying code changes.

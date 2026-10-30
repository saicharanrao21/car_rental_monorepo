# DRIVEGO — DEPLOYMENT AND ROLLBACK RUNBOOK

**Document ID:** `DRV-RBK-2026-013`  
**Version:** 1.0.0  
**Effective Date:** October 29, 2026  
**Auditor:** Principal DevOps Engineer & Release Architect  
**Scope:** Production Staging, Cloud Deployment, CDN Cache Invalidation, and Emergency Rollback

---

## 1. Zero-Downtime Blue-Green Deployment Runbook

### Phase 1: Pre-Flight Verification
1. Verify git commit SHA matches certified target commit:
   ```powershell
   git rev-parse HEAD
   ```
2. Verify all monorepo test suites pass:
   ```powershell
   npm --prefix car_rental_backend test
   cd apps/admin_panel; flutter test
   ```

### Phase 2: Database Migration Application
1. Run backward-compatible Prisma migrations against production PostgreSQL:
   ```powershell
   cd car_rental_backend
   npx prisma migrate deploy
   ```
2. Confirm migration status:
   ```powershell
   npx prisma migrate status
   ```

### Phase 3: Backend Container Promotion
1. Build and push production Docker image:
   ```powershell
   docker build -t drivego-backend:0a34b04 -f car_rental_backend/Dockerfile car_rental_backend/
   docker tag drivego-backend:0a34b04 <ecr-repo>/drivego-backend:0a34b04
   docker push <ecr-repo>/drivego-backend:0a34b04
   ```
2. Deploy to ECS / Kubernetes with rolling update (`minimumHealthyPercent=100`):
   ```powershell
   kubectl set image deployment/drivego-backend api=<ecr-repo>/drivego-backend:0a34b04 --record
   kubectl rollout status deployment/drivego-backend
   ```

### Phase 4: Flutter Web Admin Deployment & CDN Cache Invalidation
1. Build production Web release assets:
   ```powershell
   cd apps/admin_panel
   flutter build web --release --pwa-strategy=none
   ```
2. Sync `build/web/` to Cloudflare R2 / AWS S3 static hosting bucket:
   ```powershell
   aws s3 sync build/web/ s3://drivego-admin-production/ --delete --cache-control "max-age=31536000,public" --exclude "index.html" --exclude "flutter_service_worker.js"
   aws s3 cp build/web/index.html s3://drivego-admin-production/index.html --cache-control "no-cache,no-store,must-revalidate"
   ```
3. Invalidate CDN cache:
   ```powershell
   aws cloudfront create-invalidation --distribution-id <ADMIN_CDN_ID> --paths "/*"
   ```

### Phase 5: Post-Deployment Smoke Test
1. Call `/health` endpoint and verify HTTP 200 OK.
2. Log into Admin Web panel and verify that `/dashboard` renders live data.
3. Verify that `/operations/schedules` lists 0 unintended jobs.

---

## 2. Emergency Rollback Protocol

### Rollback Trigger Criteria:
- Uncaught 5xx server error rate exceeds **1.0%** of requests within 5 minutes.
- Razorpay payment order creation failure rate exceeds **2.0%**.
- Database lock timeout count spikes (> 5 concurrent locks).

### Rollback Execution Steps:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        EMERGENCY ROLLBACK ACTIONS                      │
├───────────────────┬────────────────────────────────────────────────────┤
│ 1. Backend API    │ kubectl rollout undo deployment/drivego-backend    │
│    Rollback       │ (Immediately reverts pods to prior stable image).  │
├───────────────────┼────────────────────────────────────────────────────┤
│ 2. Flutter Web    │ aws s3 sync s3://drivego-admin-backups/<prev_sha>/ │
│    Rollback       │ s3://drivego-admin-production/ --delete            │
│                   │ aws cloudfront create-invalidation ... "/*"        │
├───────────────────┼────────────────────────────────────────────────────┤
│ 3. Database       │ Invariants policy requires all migrations to be    │
│    Compatibility  │ additive (expand-contract). Schema rollbacks are   │
│                   │ NOT performed during active traffic; code reverts  │
│                   │ operate safely against newer schema columns.       │
├───────────────────┼────────────────────────────────────────────────────┤
│ 4. Post-Rollback  │ Post incident summary to #war-room in Slack;       │
│    Notification   │ verify error rates decline below 0.05%.            │
└───────────────────┴────────────────────────────────────────────────────┘
```


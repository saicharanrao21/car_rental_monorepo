# DriveGo — Production Evidence Matrix

**Audit Execution Date:** September 19, 2026  
**Auditor:** Principal Architect, QA Lead & DevOps Engineer  
**Evidence Source:** Live terminal executions, verified test runners, real database drills, and release artifact compilers.

---

## 1. Verified Test Counts & Execution Evidence

All test counts are extracted directly from active execution logs without manual inflation or duplicate counting.

| Platform Component | Test Framework | Suites Run | Tests Passed | Tests Failed | Skipped / Todo | Duration | Status |
|---|---|---|---|---|---|---|---|
| **Backend Unit & Domain Specs** | Jest 29 / ts-jest | 133 suites | 1,630 tests | 0 | 0 | 34.18s | **100% PASSED** |
| **Backend HTTP & Guard E2E** | Jest (e2e config) | 1 suite | 18 tests | 0 | 0 | 13.01s | **100% PASSED** |
| **Customer Flutter Application** | Flutter Test Harness | 17 test files | 194 tests | 0 | 0 | 57.00s | **100% PASSED** |
| **Admin Panel Control Tower** | Flutter Test Harness | 12 test files | 62 tests | 0 | 0 | 30.00s | **100% PASSED** |
| **Vendor Flutter Application** | Flutter Test Harness | 15 test files | 268 tests | 0 | 0 | 60.00s | **100% PASSED** |
| **TOTAL VERIFIED TEST EVIDENCE** | Monorepo Unified | **178 suites** | **2,172 tests** | **0** | **0** | **194.19s** | **100% GREEN** |

---

## 2. Static Analysis & Type Checking Evidence

| Target | Command Executed | Output / Issues Detected | Exit Code | Result |
|---|---|---|---|---|
| **Customer App** | `flutter analyze apps/customer_app` | `No issues found!` | 0 | **PASSED** |
| **Vendor App** | `flutter analyze apps/vendor_app` | `No issues found!` | 0 | **PASSED** |
| **Admin Panel** | `flutter analyze apps/admin_panel` | `No issues found!` | 0 | **PASSED** |
| **Backend Production Build** | `npm run build` (`nest build`) | `Successfully compiled` (0 TS errors) | 0 | **PASSED** |

---

## 3. Production Release Artifact Evidence

| Artifact Target | Build Toolchain | Build Command | Output Path | Verification Status |
|---|---|---|---|---|
| **Admin Panel Web Release** | Flutter Web 3.x (CanvasKit/HTML) | `flutter build web --release` | `apps/admin_panel/build/web` | **BUILT (135.3s)** |
| **Backend Dist Bundle** | NestJS CLI / TypeScript compiler | `npm run build` | `car_rental_backend/dist` | **BUILT & VALIDATED** |
| **Production Security Scan** | Custom Node.js AST/Regex scanner | `node scripts/scan-production-artifacts.mjs` | 894 production source files | **PASSED (0 VIOLATIONS)** |

---

## 4. Disaster Recovery & Financial Invariant Evidence

Executed against live PostgreSQL datasource: `aws-0-ap-south-1.pooler.supabase.com:6543/postgres?pgbouncer=true`.

| Invariant Verification Item | Measurement / Baseline | Post-Restore Verification | Status |
|---|---|---|---|
| **Ledger Mathematical Balance** | Total Debits: ₹9,801.20 | Total Credits: ₹9,801.20 | **DEBITS == CREDITS (100% Balanced)** |
| **Orphan Record Checks** | Bookings: 0, Cars: 0, Payments: 0 | Bookings: 0, Cars: 0, Payments: 0 | **ZERO ORPHANS** |
| **Snapshot Cryptographic Checksum** | SHA-256 Digest | `6cfa105ff7306a799bef418c718c25f2c1f3a1f40ba87e05cf2e64931e7c36e4` | **INTEGRITY PRESERVED** |
| **Drill Execution Duration** | Start-to-Finish Elapsed Time | **3,178 ms** | **PASSED (100% SUCCESS)** |
| **Certification Artifact** | Output JSON report | `car_rental_backend/artifacts/disaster-recovery-report.json` | **PERSISTED** |

---

## 5. Visual Evidence Artifacts Captured

Visual PNG evidence files generated in headless test harness and persisted in `docs/evidence/`:

- `docs/evidence/phase29-8-vendor-operations-dashboard/04_todays_operations.png`
- `docs/evidence/phase29-15-vendor-booking-lifecycle/01_confirmed_booking.png`
- `docs/evidence/phase29-15-vendor-booking-lifecycle/04_return_pending.png`
- `docs/evidence/phase29-15-vendor-booking-lifecycle/05_return_inspection.png`
- `docs/evidence/phase29-16-location-fulfillment/07_completed_booking_preserved_fulfillment.png`
- `docs/evidence/phase29-17-cross-platform-fulfillment/04_handover_pre_trip_inspection.png`
- `docs/evidence/phase30/05_refund_pending.png`
- `docs/evidence/phase31/01_customer_notification_center.png`
- `docs/evidence/phase31/08_vendor_handover_return_notification.png`
- `docs/evidence/phase31/10_admin_notification_governance.png`
- `docs/evidence/phase32/04_customer_device_token_registered_state.png`
- `docs/evidence/phase32/05_vendor_notifications_realtime_center.png`
- `docs/evidence/phase32/07_vendor_notifications_empty_refreshable.png`
- `docs/evidence/phase32/10_admin_device_registry_telemetry.png`
- `docs/evidence/phase35/03_vendor_pricing_server_authoritative.png`
- `docs/evidence/phase35/04_admin_quote_integrity_governance.png`
- `docs/evidence/phase36/01_customer_payment_state.png`
- `docs/evidence/phase36/03_vendor_financial_visibility.png`
- `docs/evidence/phase36/04_admin_payment_governance.png`
- `docs/evidence/phase36/05_reconciliation_financial_audit.png`

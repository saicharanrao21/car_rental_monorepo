# DRIVEGO — SECURITY & PLATFORM MODULES IMPLEMENTATION & CLEANUP PLAN

**Document ID:** `PLAN-DRV-2026-004`  
**Date:** October 29, 2026  
**Lead Engineer:** Principal Enterprise Software Architect & Systems Lead  
**Scope:** Execution roadmap for remediating security findings, strengthening authorization, and verifying the 5 Security & Platform modules.

---

## 1. Cleanup Matrix (KEEP / FIX / CONSOLIDATE / REMOVE / DEFER)

| Component / Capability | Category | Justification |
|---|:---:|---|
| Staff Management & Provisioning (`/staff`) | **KEEP** | Essential operational capability; 100% verified across 7 roles and session revocation. |
| Deterministic 8-Signal Fraud Evaluation | **KEEP** | Core marketplace fraud prevention; verified in `fraud-risk.spec.ts`. |
| Business Rules OCC 409 & Semantic Validation | **KEEP** | Essential concurrency protection for platform pricing and policies. |
| Audit Log Query & Display (`/audit-log`) | **KEEP** | Critical compliance and audit trail visibility. |
| Platform Settings Singleton (`/settings`) | **KEEP** | Core global application settings and trip type flags. |
| Backend Admin Controllers Permission Guards | **FIX** | Attach `PermissionsGuard` and `@RequirePermissions` to `admin-audit-log`, `admin-fraud`, and `admin-settings`. |
| Sensitive Data Redaction in `AuditLogService` | **FIX** | Add recursive sanitization in `AuditLogService.log` to prevent credential exposure. |
| Frontend `AdminSessionState` RBAC Awareness | **FIX** | Store `role` and `staffRole` in Flutter session state; enforce `hasPermission` in `canEditConfigurationsProvider`. |
| Missing Frontend Widget Tests | **FIX** | Add dedicated test suites for `AdminAuditLogPage` and `PlatformSettingsPage`. |
| Missing Backend Controller Tests | **FIX** | Add dedicated unit/integration specs for `AdminAuditLogController` and `AdminSettingsController`. |
| Parallel/Alternative Rule Engines | **REMOVE** | No parallel rule engine permitted; all configurable policies must reside in `config-engine`. |
| Advanced ML Black-Box Risk Scoring | **DEFER** | Machine learning risk scoring deferred to Phase 2; deterministic 8-signal engine satisfies all requirements. |

---

## 2. Dependency-Ordered Implementation Plan

### Step 1: Backend Security Hardening (Priority 1)
1. **Audit Log Data Redaction:**
   - Modify `car_rental_backend/src/admin/audit-log.service.ts`: Implement recursive key sanitization (`password`, `token`, `secret`, `apiKey`, `authorization`, `creditCard`, `cvv`, etc.).
2. **Permissions Guard Integration on Audit Log Controller:**
   - Modify `car_rental_backend/src/admin/admin-audit-log.controller.ts`: Add `PermissionsGuard` and `@RequirePermissions(AdminPermission.AUDIT_LOG_READ)`.
3. **Permissions Guard Integration on Fraud Controller:**
   - Modify `car_rental_backend/src/fraud/admin-fraud.controller.ts`: Add `PermissionsGuard` and `@RequirePermissions(AdminPermission.FRAUD_VIEW)` on GET endpoints, and `@RequirePermissions(AdminPermission.FRAUD_RESOLVE)` on `POST /admin/fraud/assessments/:id/resolve`.
4. **Permissions Guard Integration on Platform Settings Controller:**
   - Modify `car_rental_backend/src/admin/admin-settings.controller.ts`: Add `PermissionsGuard` and `@RequirePermissions(AdminPermission.SYSTEM_CONFIG_READ)` on GET, and `@RequirePermissions(AdminPermission.SYSTEM_CONFIG_WRITE)` on PATCH.

### Step 2: Frontend RBAC Awareness & Permission Gates (Priority 2)
1. **Enrich Admin Session Model:**
   - Modify `apps/admin_panel/lib/core/providers/admin_session_provider.dart`: Parse `role` and `staffRole` from `/auth/me` and provide helper `bool hasPermission(String permission)`.
2. **Harden Business Rules Permission Gate:**
   - Modify `apps/admin_panel/lib/features/business_rules/presentation/providers/business_rules_providers.dart`: Update `canEditConfigurationsProvider` to verify write permissions and block `READONLY_ANALYST`.

### Step 3: Comprehensive Automated Test Coverage (Priority 3)
1. **Backend Tests:**
   - Create `car_rental_backend/src/admin/admin-audit-log.spec.ts`.
   - Create `car_rental_backend/src/admin/admin-settings.spec.ts`.
   - Verify `admin-staff.spec.ts`, `fraud-risk.spec.ts`, `system-config.spec.ts`.
2. **Frontend Tests:**
   - Create `apps/admin_panel/test/admin_audit_log_page_test.dart`.
   - Create `apps/admin_panel/test/platform_settings_page_test.dart`.
   - Run full 32 test suites in `apps/admin_panel/test/`.

### Step 4: Verification, CI Run & Git Checkpoint (Priority 4)
1. Run local tests and verify 100% pass rate.
2. Commit, push to `origin/main`, and confirm GitHub Actions CI passes.
3. Deliver the final comprehensive audit report.


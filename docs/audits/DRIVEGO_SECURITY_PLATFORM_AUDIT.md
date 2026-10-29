# DRIVEGO — SECURITY & PLATFORM MODULES FORENSIC AUDIT MATRIX

**Document ID:** `AUD-DRV-2026-008`  
**Date:** October 29, 2026  
**Auditor:** Principal Enterprise Software Architect, Application Security Engineer & QA Lead  
**Scope:** Forensic evaluation of the 5 Super Admin modules:
1. Staff & Role Delegation (RBAC)
2. Audit Log
3. Fraud & Risk
4. Business Rules Engine
5. Platform Settings

---

## 1. Classification Methodology

Each feature or capability is classified using the mandatory standard criteria:
- **A. IMPLEMENTED AND VERIFIED:** Complete behavior exists and is proven with automated test evidence and runtime verification.
- **B. IMPLEMENTED BUT UNVERIFIED:** Implementation exists in code, but adequate execution or test evidence is missing.
- **C. PARTIALLY IMPLEMENTED:** Some behavior exists, but one or more critical workflow steps are missing.
- **D. FRONTEND ONLY:** A user interface exists, but backend endpoint or persistence is missing.
- **E. BACKEND ONLY:** Backend capability exists, but administrative interface or workflow is missing.
- **F. MOCKED OR HARDCODED:** Interface or service relies on fake/mock data or non-production behavior.
- **G. BROKEN:** Implementation exists but throws errors or fails under normal conditions.
- **H. DUPLICATED:** Redundant or conflicting implementations exist in multiple locations.
- **I. UNNECESSARY OR OBSOLETE:** Feature is unused, superseded, or outside agreed requirements.
- **J. NOT IMPLEMENTED:** Feature is required by specification, but no implementation exists.

---

## 2. Module 1: Staff & Role Delegation (RBAC)

| # | Feature / Capability | Frontend Screen & Route | Backend Endpoint / Service | Persistence Model | Permissions Required | Status | Evidence & Forensic Findings | Recommended Action |
|---|---|---|---|---|---|:---:|---|---|
| 1.1 | Staff Account Provisioning | `AdminStaffManagementPage` (`/staff`) | `POST /admin/staff` (`AdminStaffService.createStaff`) | Prisma `User` (role: `ADMIN`, `staffRole`) | `SYSTEM_CONFIG_WRITE` | **A** | Verified in `admin-staff.spec.ts` and `admin_staff_management_test.dart`. Requires 10-digit mobile, unique email/phone, bcrypt password hash. | **KEEP** |
| 1.2 | Granular Staff Roles (7 Roles) | `AdminStaffManagementPage` (`/staff`) | `STAFF_ROLE_PERMISSIONS_MATRIX` (`permissions.enum.ts`) | Prisma `User.staffRole` (string) | N/A | **A** | `SUPER_ADMIN`, `OPERATIONS_MANAGER`, `CUSTOMER_SUPPORT`, `FINANCE_MANAGER`, `COMPLIANCE_OFFICER`, `MARKETING_MANAGER`, `READONLY_ANALYST`. Verified in `admin-staff.spec.ts`. | **KEEP** |
| 1.3 | Active Session Revocation | `_showRevokeSessionsDialog` (`/staff`) | `POST /admin/staff/:id/revoke-sessions` | Prisma `RefreshToken.revoked` | `SYSTEM_CONFIG_WRITE` | **A** | Revokes all non-revoked refresh tokens for the target user. Verified in `admin-staff.spec.ts`. | **KEEP** |
| 1.4 | Account Suspension / Ban | `_showEditRoleDialog` (`/staff`) | `PATCH /admin/staff/:id` (`AdminStaffService.updateStaff`) | Prisma `User.banned` | `SYSTEM_CONFIG_WRITE` | **A** | Updates `banned: true`. Immediate blocking of user operations. | **KEEP** |
| 1.5 | Server-Side Permissions Guard | N/A (NestJS Guard) | `PermissionsGuard` (`permissions.guard.ts`) | N/A | Variable per endpoint | **C** | `PermissionsGuard` correctly blocks mutating HTTP verbs for `READONLY_ANALYST`. However, several admin controllers (`admin-audit-log`, `admin-fraud`, `admin-settings`) lacked `@UseGuards(PermissionsGuard)`. | **FIX: Attach PermissionsGuard to all admin controllers.** |
| 1.6 | Frontend Permission-Aware Session | `adminSessionProvider.dart` | `GET /auth/me` (`AuthController.getMe`) | N/A | N/A | **C** | `AdminSessionState` in Flutter only stored `displayName` and `isAuthenticated`, discarding `user.role` and `user.staffRole`. Frontend could not disable buttons dynamically. | **FIX: Store user role and staffRole in AdminSessionState and compute permissions.** |

---

## 3. Module 2: Audit Log

| # | Feature / Capability | Frontend Screen & Route | Backend Endpoint / Service | Persistence Model | Permissions Required | Status | Evidence & Forensic Findings | Recommended Action |
|---|---|---|---|---|---|:---:|---|---|
| 2.1 | Immutable Audit Persistence | N/A (Service API) | `AuditLogService.log()` | Prisma `AuditLog` (`schema.prisma`) | Internal service | **C** | Real database table with indexed `adminUserId`, `action`, `targetType`, `createdAt`. Flaw: Did not sanitize metadata (sensitive fields like passwords/tokens were not masked). | **FIX: Implement recursive sensitive key redaction in AuditLogService.log().** |
| 2.2 | Audit Trail Query & Filter | `AdminAuditLogPage` (`/audit-log`) | `GET /admin/audit-log` (`AdminAuditLogController`) | Prisma `AuditLog` | `AUDIT_LOG_READ` | **C** | Backend query supports pagination, action, adminUserId, date range. Flaw: Controller lacked `PermissionsGuard` and `@RequirePermissions(AUDIT_LOG_READ)`. Frontend lacked dedicated widget test. | **FIX: Add PermissionsGuard to controller and add frontend widget test suite.** |
| 2.3 | Audit Event Details Inspection | `AdminAuditLogPage` (Drawer) | `GET /admin/audit-log` | Prisma `AuditLog.metadata` (JSON) | `AUDIT_LOG_READ` | **A** | Drawer displays full JSON payload, timestamp, action chip, target entity ID. | **KEEP** |
| 2.4 | Audit Log Alteration/Deletion Prevention | N/A | Database Schema | PostgreSQL `AuditLog` | None (Disallowed) | **A** | No `DELETE` or `PUT` endpoints exist for `AuditLog`. Immutable append-only record. | **KEEP** |

---

## 4. Module 3: Fraud & Risk

| # | Feature / Capability | Frontend Screen & Route | Backend Endpoint / Service | Persistence Model | Permissions Required | Status | Evidence & Forensic Findings | Recommended Action |
|---|---|---|---|---|---|:---:|---|---|
| 3.1 | Deterministic Risk Scoring (8 Signals) | N/A (Service API) | `FraudService.evaluateUserRisk` | Prisma `User`, `Booking`, `Payment`, `CustomerKyc` | Internal service | **A** | Evaluates ban status, duplicate DL, booking velocity, cancellation velocity, payment distress, concurrent trips, fresh account spikes, self-referral. Verified in `fraud-risk.spec.ts`. | **KEEP** |
| 3.2 | Risk Assessment Queue & Alerts | `AdminFraudPage` (`/fraud`) | `GET /admin/fraud/assessments` | Prisma `AuditLog` (action: `RISK_ASSESSMENT_ALERT`) | `FRAUD_VIEW` | **C** | Real database records queried with pagination and severity filter. Flaw: Controller was missing `PermissionsGuard` and `@RequirePermissions(AdminPermission.FRAUD_VIEW)`. | **FIX: Add PermissionsGuard and FRAUD_VIEW permission requirement.** |
| 3.3 | Executive Risk Summary KPIs | `AdminFraudPage` (`/fraud`) | `GET /admin/fraud/summary` | Prisma `AuditLog` aggregates | `FRAUD_VIEW` | **C** | Aggregates critical, high, medium, low, and pending review counts. Flaw: Controller lacked `PermissionsGuard`. | **FIX: Secure with PermissionsGuard.** |
| 3.4 | Assessment Resolution & Notes | `AdminFraudPage` (Dialog) | `POST /admin/fraud/assessments/:id/resolve` | Prisma `AuditLog` (action: `FRAUD_RISK_RESOLUTION`) | `FRAUD_RESOLVE` | **C** | Updates assessment metadata and records secondary administrative action log. Flaw: Controller lacked `PermissionsGuard` and `@RequirePermissions(AdminPermission.FRAUD_RESOLVE)`. | **FIX: Add PermissionsGuard and FRAUD_RESOLVE permission requirement.** |

---

## 5. Module 4: Business Rules Engine

| # | Feature / Capability | Frontend Screen & Route | Backend Endpoint / Service | Persistence Model | Permissions Required | Status | Evidence & Forensic Findings | Recommended Action |
|---|---|---|---|---|---|:---:|---|---|
| 4.1 | Dynamic Configuration Registry | `BusinessRulesDashboardPage` (`/business-rules`) | `GET /config/admin/detailed` | Prisma `SystemConfig` + Code Defaults | `SYSTEM_CONFIG_READ` | **A** | All platform rules across pricing, tax, bookings, cancellation, search, wallet, referral, commission. Verified in `system-config.spec.ts` and `phase_d_admin_business_rules_test.dart`. | **KEEP** |
| 4.2 | Optimistic Concurrency Control (OCC 409) | `ConfigDetailDrawer` | `PUT /config/admin/:key` (with `expectedVersion`) | Prisma `SystemConfig.version` | `SYSTEM_CONFIG_WRITE` | **A** | Rejects stale version updates with HTTP 409 Conflict. Prompts admin with diff comparison. Verified in `phase_d_admin_business_rules_test.dart`. | **KEEP** |
| 4.3 | Semantic Schema Validation | `ConfigDetailDrawer` | `SystemConfigValidator.validate()` | N/A | `SYSTEM_CONFIG_WRITE` | **A** | Rejects negative taxes, invalid percentage bounds, broken cancellation tiers. Verified in `system-config-validation.spec.ts`. | **KEEP** |
| 4.4 | Atomic Batch Update | `BatchUpdateDialog` | `PUT /config/admin/batch` | Prisma Transaction | `SYSTEM_CONFIG_WRITE` | **A** | Atomically updates multiple configuration keys; rolls back entirely on conflict. Verified in `phase_d_admin_business_rules_test.dart`. | **KEEP** |
| 4.5 | Audit History & Diff Trail | `ConfigAuditHistoryView` | `GET /config/admin/:key/audit-history` | Prisma `AuditLog` | `SYSTEM_CONFIG_READ` | **A** | Tracks previous value, new value, reason, actor, and timestamp. Verified in `phase_d_admin_business_rules_test.dart`. | **KEEP** |
| 4.6 | Frontend Read-Only Admin Enforcement | `ConfigDetailDrawer` | `canEditConfigurationsProvider` | N/A | `SYSTEM_CONFIG_WRITE` | **C** | Frontend provider returned `true` for any authenticated user, failing to check `READONLY_ANALYST` or specific write permission. | **FIX: Check staffRole and permissions in canEditConfigurationsProvider.** |

---

## 6. Module 5: Platform Settings

| # | Feature / Capability | Frontend Screen & Route | Backend Endpoint / Service | Persistence Model | Permissions Required | Status | Evidence & Forensic Findings | Recommended Action |
|---|---|---|---|---|---|:---:|---|---|
| 5.1 | Global Platform Settings Singleton | `PlatformSettingsPage` (`/settings`) | `GET /admin/settings` | Prisma `PlatformSettings` (id: `'singleton'`) | `SYSTEM_CONFIG_READ` | **C** | Fetches platform name, GST number, support contact, app version. Flaw: Controller lacked `PermissionsGuard`. Frontend lacked dedicated widget test. | **FIX: Add PermissionsGuard to controller and create platform_settings_page_test.dart.** |
| 5.2 | Platform Settings Mutation | `PlatformSettingsPage` (`/settings`) | `PATCH /admin/settings` | Prisma `PlatformSettings` | `SYSTEM_CONFIG_WRITE` | **C** | Updates settings and logs `PLATFORM_SETTINGS_UPDATED` in `AuditLog`. Flaw: Missing `PermissionsGuard` and `@RequirePermissions(AdminPermission.SYSTEM_CONFIG_WRITE)`. | **FIX: Add PermissionsGuard and SYSTEM_CONFIG_WRITE.** |
| 5.3 | Secret Protection & Exposure Guard | Backend / Frontend | N/A | Environment Variables | Server-side only | **A** | Secrets (JWT secrets, API keys, database credentials) are NEVER stored in `PlatformSettings` table and are NEVER exposed via `/admin/settings`. | **KEEP** |
| 5.4 | Trip Type Feature Flags | `PlatformSettingsPage` | `PATCH /admin/settings` (`enabledTripTypes`) | Prisma `PlatformSettings.enabledTripTypes` | `SYSTEM_CONFIG_WRITE` | **A** | Supports enabling/disabling `SELF_DRIVE` and `OUTSTATION` modes. | **KEEP** |

---

## 7. Prioritized Vulnerability & Blocker Register

| Risk ID | Severity | Component | Finding Description | Remediation |
|---|---|---|---|---|
| **SEC-01** | **High** | `admin-audit-log.controller.ts`, `admin-fraud.controller.ts`, `admin-settings.controller.ts` | Controllers only use `RolesGuard` checking `Role.ADMIN`, omitting `PermissionsGuard`. Staff with role `ADMIN` but restricted `staffRole` (e.g. `READONLY_ANALYST`) can execute unauthorized actions. | Add `@UseGuards(PermissionsGuard)` and explicit `@RequirePermissions(...)` to all endpoints. |
| **SEC-02** | **High** | `car_rental_backend/src/admin/audit-log.service.ts` | `AuditLogService.log` does not sanitize incoming metadata, allowing sensitive credentials (passwords, tokens, secrets) to be stored in plaintext in the database. | Implement recursive sensitive key redaction filter for all logged metadata. |
| **SEC-03** | **Medium** | `apps/admin_panel/lib/core/providers/admin_session_provider.dart` | `AdminSessionState` in Flutter discards `role` and `staffRole` from `/auth/me`, preventing the UI from disabling controls or adapting navigation for restricted staff roles. | Enrich `AdminSessionState` with `role`, `staffRole`, and computed permissions. |
| **TEST-01** | **Medium** | `apps/admin_panel/test/` | `AdminAuditLogPage` and `PlatformSettingsPage` have no dedicated Flutter widget test suites. | Create `test/admin_audit_log_page_test.dart` and `test/platform_settings_page_test.dart`. |
| **TEST-02** | **Medium** | `car_rental_backend/src/admin/` | `AdminAuditLogController` and `AdminSettingsController` lack dedicated backend unit/integration test suites. | Create `src/admin/admin-audit-log.spec.ts` and `src/admin/admin-settings.spec.ts`. |


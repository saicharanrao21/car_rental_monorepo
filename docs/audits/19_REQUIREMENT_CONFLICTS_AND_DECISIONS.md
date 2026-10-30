# DRIVEGO — REQUIREMENT CONFLICTS, ARCHITECTURAL DISCREPANCIES & DECISIONS REGISTER

**Document ID:** `DRV-DEC-2026-019`  
**Version:** 1.0.0  
**Audit Date:** October 30, 2026  
**Auditor:** Principal Enterprise Software Architect, FinTech Architect, Application Security Lead, & QA Lead  
**Monorepo Target:** `car_rental_monorepo` (Git commit: `0a34b041787630062d50d6563be23c10b2205876`)  
**Scope:** Identification, analysis, and proposed resolutions for document conflicts, codebase discrepancies, and unresolved product/business decisions.

---

## 1. Executive Summary

During the comprehensive audit of Documents 01 through 14 against the actual codebase, **5 specific discrepancies and architectural decisions** were identified. None of these discrepancies indicate critical software failure; rather, they reflect evolving design choices between earlier specification documents, operational realities, and enterprise segregation of duties.

This document formally records each discrepancy, outlines the evidence, presents options, and states the recommended resolution while explicitly marking business decisions as pending authorized stakeholder sign-off.

---

## 2. Master Discrepancies and Decisions Register

### Decision DEC-01: Segregation of Duties Anti-Self-Approval Enforcement
- **Decision ID:** `DEC-01`
- **Affected Documents & Requirements:** `03_APPROVAL_AND_SEGREGATION_OF_DUTIES_MATRIX.md` (`SOD-001`), `01_COMPANY_OPERATING_MODEL.md` (`COM-003`), `ApprovalEngineService`.
- **Conflicting Statements / Observed Behavior:**
  - *Document 03 Statement:* "No staff member may approve, authorize, or disburse funds for an action they personally created or requested."
  - *Prior Codebase State:* `ApprovalEngineService.recordDecision()` verified the approver's role against `step.approverRole` and checked step order, but did not assert `request.requestedBy.id !== params.decidedBy.id`.
- **Evidence:** `car_rental_backend/src/operations/approval-engine.service.ts` line 160.
- **Impact:** An administrator creating a high-value customer refund (e.g., ₹25,000) could theoretically approve their own request if their role matched the step requirements.
- **Available Options:**
  - *Option A:* Disallow self-approval strictly for all requests (`requestedBy.id !== decidedBy.id`).
  - *Option B:* Allow self-approval for low-value requests (<₹5,000) but prohibit it for >₹5,000.
  - *Option C:* Require explicit Super Admin override flag for self-approval in emergencies.
- **Recommended Option:** **Option A**. The Four-Eyes Principle must be absolute for all tracked approval categories.
- **Status in Codebase:** **REMEDIATED & VERIFIED**. Added guard in `approval-engine.service.ts` throwing `BadRequestException` on self-approval attempt. Verified by test `should strictly reject self-approval and enforce segregation of duties` in `operations-startup-isolation.spec.ts`.
- **Required Approver:** Head of Internal Audit & Security Lead.
- **Current Decision Status:** **APPROVED IN CODE (Awaiting Formal Audit Sign-Off)**.

---

### Decision DEC-02: Overdue Vehicle Remote Engine Immobilization Protocol
- **Decision ID:** `DEC-02`
- **Affected Documents & Requirements:** `05_CUSTOMER_AND_VENDOR_JOURNEY_MATRIX.md` (`JOURNEY-OPS-003`), `09_OPERATIONS_AND_SUPPORT_SOP_REQUIREMENTS.md` (`OPS-002`).
- **Conflicting Statements / Observed Behavior:**
  - *Document 05 Statement:* "If overdue > 4 hours without contact, vehicle engine immobilized via telematics (where equipped) automatically."
  - *Document 09 SOP Statement:* "Operations Manager authorizes telematics engine immobilization when the vehicle comes to a complete halt."
- **Evidence:** `car_rental_backend/src/operations/scheduling-engine.service.ts` and `emergency.service.ts`.
- **Impact:** Automated remote vehicle immobilization while a vehicle is in motion on a highway presents extreme passenger and third-party road safety liability under Indian law.
- **Available Options:**
  - *Option A (Automated):* Automatic immobilization command sent via telematics after +240 minutes.
  - *Option B (Human-Supervised Safety Gate):* Automated sweep flags the vehicle and notifies the Operations Manager. Immobilization requires explicit human verification that vehicle speed is 0 km/h (engine idling or parked) before triggering.
- **Recommended Option:** **Option B**. For passenger safety and legal defensibility, vehicle immobilization must NEVER occur autonomously. It must require human confirmation that the vehicle is stationary.
- **Risks:** Delay in asset recovery if manager is offline vs. severe accident liability if cut off while driving.
- **Required Approver:** VP Operations, Fleet Safety Officer, & Corporate Legal Counsel.
- **Current Decision Status:** **PENDING FORMAL LEGAL/SAFETY APPROVAL (Code implemented to require manual supervisory dispatch)**.

---

### Decision DEC-03: Security Deposit Refund Timing — Instant vs. Post-Inspection Window
- **Decision ID:** `DEC-03`
- **Affected Documents & Requirements:** `05_CUSTOMER_AND_VENDOR_JOURNEY_MATRIX.md` (`JOURNEY-CUST-005`), `07_FINANCE_AND_RECONCILIATION_REQUIREMENTS.md` (`FIN-001`), `09_OPERATIONS_AND_SUPPORT_SOP_REQUIREMENTS.md` (`OPS-004`).
- **Conflicting Statements / Observed Behavior:**
  - *Document 05 Statement:* "Trip Return & Deposit Settlement: API to PGW: Initiate Automated Full Security Deposit Refund immediately upon 'No Damage' return."
  - *Document 09 Statement:* Host has up to 48 hours to inspect vehicle for latent mechanical issues or traffic challans before final deposit release.
- **Evidence:** `car_rental_backend/src/damage-claims/damage-claims.service.ts` and `payments/payments.service.ts`.
- **Impact:** If deposit is refunded instantly at yard, host cannot recover subsequent traffic camera fines (e-Challans) or hidden transmission damage discovered during workshop wash.
- **Available Options:**
  - *Option A (Instant Full Refund):* 100% deposit released immediately upon return photo sign-off.
  - *Option B (Two-Stage Release):* 80% deposit released immediately; 20% (or ₹1,500) held in escrow for 48 hours to cover pending e-challans / FASTag tolls, then auto-released.
  - *Option C (Full 48-hour SLA):* Entire deposit held for 48 hours post-trip, then auto-released unless host files formal damage claim.
- **Recommended Option:** **Option B** (Two-Stage Release). Maximizes customer satisfaction by returning majority of funds instantly while protecting host from challan defaults.
- **Risks:** Customer friction if small balance held vs. host disputes over unrecovered traffic fines.
- **Required Approver:** Head of Product, Finance Controller, & Vendor Relations Lead.
- **Current Decision Status:** **PENDING BUSINESS APPROVAL (Currently operates under Option C: 48-hour auto-release timer)**.

---

### Decision DEC-04: Test Suite Inventory Baseline Reconciliation (2,353 vs. 2,365 vs. 2,366)
- **Decision ID:** `DEC-04`
- **Affected Documents & Requirements:** `10_IMPLEMENTATION_BACKLOG_PRIORITIES.md`, `11_TEST_EVIDENCE_REPORT.md`, `12_PRODUCTION_LAUNCH_CHECKLIST.md`, `14_FINAL_GO_NO_GO_REPORT.md`.
- **Conflicting Statements / Observed Behavior:**
  - Earlier milestone reports recorded 2,353 tests across 247 suites.
  - Subsequent startup isolation additions brought count to 2,365 tests across 248 suites.
  - Segregation of Duties regression test addition brought backend total to 1,772 and monorepo total to 2,366 tests.
- **Evidence:** Command execution: `npm --prefix car_rental_backend test` reports 144 suites, 1,772 passed; monorepo total = 2,366 passed.
- **Impact:** Potential confusion among external auditors if historical documents reference differing test counts.
- **Available Options:**
  - *Option A:* Update historical documentation retroactively to 2,366.
  - *Option B:* Retain historical numbers as milestone snapshots and establish 2,366 as the verified current baseline in all active reports.
- **Recommended Option:** **Option B**. Preserves historical audit integrity while recording the exact current total in `11_TEST_EVIDENCE_REPORT.md`, `15_MASTER_REQUIREMENTS_TRACEABILITY_MATRIX.md`, and this register.
- **Status:** **RESOLVED IN CURRENT AUDIT**. All active audit documents record 2,366 passing tests.
- **Required Approver:** QA Automation Lead.
- **Current Decision Status:** **RESOLVED & CERTIFIED**.

---

### Decision DEC-05: Multi-Factor Authentication (MFA) Implementation Scope for Privileged Roles
- **Decision ID:** `DEC-05`
- **Affected Documents & Requirements:** `02_EMPLOYEE_ROLE_AND_PERMISSION_MATRIX.md` (`RBAC-002`), `08_SECURITY_AND_PRIVACY_GAP_ASSESSMENT.md` (`SEC-007`).
- **Conflicting Statements / Observed Behavior:**
  - *Document 02 Statement:* "Staff Role Escalation requires 2FA Password."
  - *Current Codebase Implementation:* Staff accounts authenticate using Bearer JWT with bcrypt password hashing; SMS OTP exists for customer/vendor logins, but staff console does not currently mandate app-based TOTP (Google Authenticator) on login.
- **Evidence:** `car_rental_backend/src/auth/auth.service.ts` (`login` vs. `verifyOtp`).
- **Impact:** If an administrative password is compromised via phishing, an attacker could access the Admin Control Tower without a physical device challenge.
- **Available Options:**
  - *Option A:* Maintain password + active session revocation as currently implemented for initial staging release.
  - *Option B:* Enforce mandatory SMS OTP challenge for `SUPER_ADMIN` and `FINANCE_MANAGER` roles.
  - *Option C:* Implement RFC 6238 TOTP (authenticator app QR code) before commercial production launch.
- **Recommended Option:** **Option C** (Targeted for commercial production launch; Option A acceptable for initial internal Staging deployment).
- **Risks:** Credential stuffing risk on admin accounts if passwords are weak.
- **Required Approver:** Chief Technology Officer & Principal Security Architect.
- **Current Decision Status:** **ACCEPTED FOR STAGING (Mandatory RFC 6238 TOTP scheduled for Production Gate)**.

---

## 3. Summary of Pending Governance Decisions

| Decision ID | Summary | Recommended Path | Accountable Stakeholder | Decision Status |
|:---:|:---|:---|:---:|:---:|
| **DEC-01** | Segregation of Duties Anti-Self-Approval | Strict rejection of self-approval across all tiers | Internal Audit Lead | 🟢 Approved in Code |
| **DEC-02** | Telematics Engine Immobilization | Mandatory human confirmation of stationary vehicle | VP Operations / Legal | 🟡 Pending Legal |
| **DEC-03** | Security Deposit Release Timing | Two-stage release (80% instant, 20% at 48h) | Head of Product / Finance | 🟡 Pending Business |
| **DEC-04** | Test Baseline Count Synchronization | Synchronize active baseline to 2,366 tests | QA Lead | 🟢 Certified |
| **DEC-05** | MFA Scope for Privileged Staff Roles | RFC 6238 TOTP enforced prior to production cutover | CTO & Security Lead | 🟢 Staging Approved; Prod Gated |


# Phase 8B: Feature 34 — Fraud Detection & Risk Scoring Pre-Implementation Audit

**Date:** 2026-08-17  
**Auditor:** Senior Principal Engineer, CTO, Security Architect & Payments/Fraud Architect  
**Feature:** Feature 34 — DriveGo Fraud Detection & Deterministic Risk Scoring  
**Current Git Checkpoint:** `cac18b3` (`feat: complete phase 8a analytics and reports`)  

---

## 1. Inventory of Existing Fraud Controls

### Identity Fraud
- **Phone Uniqueness:** `User.phone` is constrained by PostgreSQL `UNIQUE` index.
- **KYC Status Validation:** `CustomerKyc` records `licenceNumber`, `status` (`PENDING`, `VERIFIED`, `REJECTED`, `EXPIRED`).
- **User Ban Status:** `User.banned` boolean exists on `User` model.

### Booking Fraud
- **Redis Cancellation Lock:** Distributed lock (`cancellation_lock:${bookingId}`) prevents race conditions during cancellations.
- **Overlapping Booking Protection:** State machine transitions prevent booking already locked vehicles.

### Payment Fraud
- **Razorpay Signature Verification:** HMAC-SHA256 verification in `PaymentsService.verifyPayment()`.
- **Payment Amount Mismatch Check:** Throws `CRITICAL PAYMENT FRAUD ATTEMPT` if Razorpay paid amount != booking expected fare.
- **Refund Idempotency:** Duplicate refund calls rejected via unique `razorpayRefundId`.

### Referral Fraud
- **Self-referral check:** Blocks referrer == referee.
- **Same phone check:** Blocks referee with referrer's phone number.
- **Same KYC check:** Blocks referee sharing driving licence number with referrer.
- **Prior booking check:** Blocks referee if they already completed bookings before referral.
- **Reward caps:** Enforces `maxReferralsPerUser` per campaign.

### Wallet Fraud
- **Row-level locking:** `SELECT ... FOR UPDATE` prevents double-spending.
- **Deposit isolation:** Promotional credits strictly isolated from security deposits.
- **Idempotency keys:** Append-only ledger entries enforce unique idempotency.

---

## 2. Gaps & Deficiencies in Feature 34

| Risk Area | Existing Control | Limitation / Gap | Severity | Planned Solution |
| :--- | :--- | :--- | :---: | :--- |
| **Composite Risk Scoring** | None | No centralized service computes composite risk score (0-100). | High | Implement deterministic `FraudService.evaluateUserRisk()` aggregating signals. |
| **Risk Levels & Thresholds** | Ad-hoc exceptions | No structured `LOW`, `MEDIUM`, `HIGH`, `CRITICAL` risk classification. | High | Define explainable thresholds: 0-29 (Low), 30-59 (Medium), 60-79 (High), 80-100 (Critical). |
| **Risk Event Persistence** | General `AuditLog` | No dedicated risk assessment tracking with review status & admin notes. | Medium | Persist structured `RiskAssessment` records in audit store with resolution workflow. |
| **Admin Fraud Dashboard** | None | Admin panel lacks a dedicated Risk / Fraud Management page. | High | Build `AdminFraudManagementPage` with severity filters, signals view, and review actions. |
| **Duplicate DL Cross-Account** | Referral only | Duplicate driving licence across multiple user accounts is not checked at KYC/booking. | High | Add cross-account DL query into risk scoring engine (+40 risk delta). |
| **Booking & Cancellation Velocity** | None | Rapid booking/cancellation cycling not tracked as an anomaly. | Medium | Add velocity window checks (2h and 24h windows) into risk scoring engine. |

---

## 3. Production Risk Architecture

### A. Score Scale & Action Contract
- **0 – 29: LOW** $\rightarrow$ `ALLOW` (Normal transaction execution).
- **30 – 59: MEDIUM** $\rightarrow$ `MONITOR` (Allow transaction, log risk alert).
- **60 – 79: HIGH** $\rightarrow$ `REVIEW_REQUIRED` (Flag in admin queue for review).
- **80 – 100: CRITICAL** $\rightarrow$ `BLOCK` (Reject risky action, trigger high-priority admin alert).

### B. Risk Signals & Weighting
1. `BANNED_USER`: User account is banned (+100, Immediate Critical).
2. `DUPLICATE_DRIVING_LICENCE`: DL number exists on another active user account (+40).
3. `HIGH_CANCELLATION_VELOCITY`: $\ge 3$ cancellations in last 24 hours (+30).
4. `HIGH_BOOKING_VELOCITY`: $\ge 3$ bookings in last 2 hours (+25).
5. `REPEATED_PAYMENT_FAILURES`: $\ge 3$ failed payments in last 24 hours (+35).
6. `SELF_REFERRAL_ATTEMPT`: Referrer phone or KYC DL matching referee (+60).
7. `MULTIPLE_ACTIVE_BOOKINGS`: $\ge 2$ simultaneous ongoing/handover bookings (+20).
8. `FRESH_ACCOUNT_SPIKE`: Account created $< 1$ hour ago with high value booking (+15).

---

## 4. Implementation Plan for Phase 8B

1. **Backend (`car_rental_backend/src/fraud/`):**
   - Create `fraud.service.ts` with deterministic signal evaluators.
   - Create `admin-fraud.controller.ts` with endpoints:
     - `GET /admin/fraud/summary`
     - `GET /admin/fraud/assessments`
     - `GET /admin/fraud/users/:userId/risk-profile`
     - `POST /admin/fraud/assessments/:id/resolve`
   - Create `fraud.module.ts` and register in `app.module.ts`.
   - Write comprehensive test suite `fraud-risk.spec.ts` ($\ge 15$ test cases).
2. **Shared Models (`packages/models/`):**
   - Create `fraud_model.dart` with enums and JSON serialization.
   - Export in `models.dart` and add unit tests in `packages/models/test/fraud_model_test.dart`.
3. **Admin Panel UI (`apps/admin_panel/`):**
   - Create `fraud_repository.dart` and `api_fraud_repository.dart`.
   - Create Riverpod providers in `fraud_providers.dart`.
   - Create `admin_fraud_page.dart` with summary metrics, filter bar, risk table, signals chips, and resolution modal.
   - Register `/fraud` route in `app_router.dart` and sidebar navigation in `admin_shell.dart`.
   - Write widget test `admin_fraud_page_test.dart`.
4. **Regression & Safety:**
   - Execute all test suites across backend and Flutter apps.
   - Verify benchmark booking `cmsu5sk3m000qgw1zaf9ftksz`.
   - Prepare clean Git commit `feat: complete phase 8b fraud risk scoring`.

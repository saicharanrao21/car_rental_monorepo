# DRIVEGO — SECURITY AND PRIVACY GAP ASSESSMENT (DPDP & OWASP AUDIT)

**Document ID:** `DRV-SEC-2026-008`  
**Version:** 1.0.0  
**Effective Date:** October 29, 2026  
**Auditor:** Principal Application Security Engineer  
**Scope:** Backend Services, Database Encryption, Mobile App Sandboxing, Cloud Infrastructure

---

## 1. OWASP Top 10 Security Architecture Evaluation

| OWASP Vulnerability | Risk Analysis in DriveGo | Implemented Mitigation & Code Defense | Verification Status |
|---|---|---|:---:|
| **A01: Broken Access Control** | Unauthorized booking view, cross-vendor data access, privilege escalation. | NestJS `JwtAuthGuard`, `RolesGuard`, and `PermissionsGuard` verify JWT claims on every endpoint. Staff can only access authorized workspaces. | 🟢 **PASS** |
| **A02: Cryptographic Failures** | Plaintext bank accounts or PAN numbers in database backups. | `BankEncryptionService` encrypts all bank account and IFSC numbers using AES-256-GCM with PBKDF2 key derivation and HMAC verification. Key rotation supported. | 🟢 **PASS** |
| **A03: Injection** | SQL injection via booking queries or search terms. | Prisma ORM uses parameterized queries exclusively. Zero raw unparameterized SQL queries in codebase. | 🟢 **PASS** |
| **A04: Insecure Design** | Double booking race conditions, unauthorized self-refunds. | Redis distributed lock (`BookingLockService`) with 15-min TTL. Anti-self-approval invariant enforced in `ApprovalEngineService`. | 🟢 **PASS** |
| **A05: Security Misconfiguration** | Unprotected debug endpoints, default passwords. | Demo seeding endpoints strictly reject execution when `NODE_ENV === 'production'`. CORS restricted to authorized domain origins. | 🟢 **PASS** |
| **A06: Vulnerable & Outdated Components** | Vulnerabilities in npm or Flutter packages. | Checked dependencies. `npm audit` and `flutter pub outdated` audited; critical paths operate without vulnerable sub-dependencies. | 🟢 **PASS** |
| **A07: Identification & Auth Failures** | OTP brute force, session hijacking. | Constant-time string comparison (`crypto.timingSafeEqual`) prevents timing attacks. 60-second OTP cooldown and 3-attempt brute-force lock enforced. | 🟢 **PASS** |
| **A08: Software & Data Integrity Failures** | Tampered webhook payloads, modified payment amounts. | Razorpay and WhatsApp webhooks verified via HMAC SHA-256 signatures before processing. Quote signatures signed with secret salt. | 🟢 **PASS** |
| **A09: Security Logging & Monitoring Failures** | Untracked admin mutations, leaked credentials in logs. | `AuditLogService` and `OperationsAuditTracerService` record all administrative mutations with automatic masking of sensitive keys (`password`, `token`, `secret`, `apiKey`). | 🟢 **PASS** |
| **A10: Server-Side Request Forgery (SSRF)** | Malicious webhook URLs triggering internal AWS metadata. | Outbound webhooks restricted to verified domain whitelists (Twilio, Razorpay, Meta, MSG91). Zero user-configurable webhook targets. | 🟢 **PASS** |

---

## 2. Digital Personal Data Protection Act (DPDP Act 2023) Compliance Mapping

```
┌────────────────────────────────────────────────────────────────────────┐
│                      DPDP ACT 2023 COMPLIANCE AUDIT                    │
├─────────────────────────┬──────────────────────┬───────────────────────┤
│ Statutory Requirement   │ Implementation Scope │ System Mechanism      │
├─────────────────────────┼──────────────────────┼───────────────────────┤
│ Explicit Purpose-Based  │ User sign-in &       │ Timestamped consent   │
│ Consent                 │ booking checkout     │ checkbox recorded in  │
│                         │                      │ `UserConsent` model.  │
├─────────────────────────┼──────────────────────┼───────────────────────┤
│ Right to Access &       │ Customer Account     │ Self-service profile  │
│ Correction              │ Screen               │ editing in mobile app.│
├─────────────────────────┼──────────────────────┼───────────────────────┤
│ Right to Erasure /      │ Customer Support /   │ Soft-deletion marking;│
│ Account Deletion        │ Settings             │ PII anonymized after  │
│                         │                      │ statutory tax period. │
├─────────────────────────┼──────────────────────┼───────────────────────┤
│ Sensitive Document      │ KYC Aadhaar & DL     │ Ephemeral pre-signed  │
│ Protection              │ storage              │ URLs (15-min expiry); │
│                         │                      │ zero public buckets.  │
└─────────────────────────┴──────────────────────┴───────────────────────┘
```

---

## 3. Privacy Action Backlog (Post-Launch Recommendations)

1. **Automated PII Pruning Cron:** Formalize scheduled job to hard-delete unverified KYC documents older than 90 days if the customer never completed a trip.
2. **Third-Party Advocate Legal Opinion:** Obtain final written compliance certificate from an Indian corporate law firm affirming marketplace intermediary status under the Information Technology Act Section 79.


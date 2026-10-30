# DRIVEGO — SECURITY, PRIVACY & COMPLIANCE REGISTER
## Threat Mitigation, Data Protection (DPDP Act), Statutory Retention & Legal Registers

> **Document Reference**: `docs/architecture/SECURITY_PRIVACY_AND_COMPLIANCE_REGISTER.md`  
> **Classification**: Security & Statutory Compliance Standard  
> **Status**: APPROVED — PRODUCTION BLUEPRINT  
> **Author**: DriveGo Data Protection Officer & Application Security Lead  

---

## 1. APPLICATION SECURITY & THREAT MITIGATION (OWASP TOP 10)

| Vulnerability Domain | Architecture Mitigation | Verification Evidence |
|---|---|---|
| **Broken Object Level Authorization (BOLA/IDOR)** | Every controller query enforces tenant isolation (`customerId === req.user.userId` or `vendor.userId === req.user.userId`). | Tested in `deposits.spec.ts`, `phase-i-booking-fleet-integrity.spec.ts`. |
| **SQL Injection** | Exclusively parameterized queries executed via Prisma ORM; zero raw string concatenation. | 100% Prisma models type-checked by TypeScript compiler. |
| **Credential & Key Exposure** | Sensitive fields encrypted via AES-256-GCM; passwords/OTPs hashed with bcrypt (10 rounds). | Verified via `scripts/scan-production-artifacts.mjs`. |
| **Rate Limiting & Abuse Prevention** | NestJS `ThrottlerGuard` and Redis token bucket limiting OTP requests (max 5 attempts per 15 min). | Tested in `handover-otp.service.ts`. |
| **Tamper-Evident State Changes** | Optimistic concurrency control (OCC) using conditional `UPDATE ... WHERE status = :expected`. | Tested in `deposits.spec.ts` (SEC-P2-01). |

---

## 2. DIGITAL PERSONAL DATA PROTECTION ACT (DPDP ACT, 2023) COMPLIANCE

1. **Affirmative Consent**: Captured during onboarding in plain language across supported Indian languages (English, Hindi, Telugu, Tamil, Kannada).
2. **Right to Erasure & Account Anonymization**:
   - Customer initiates deletion in app settings.
   - 30-day reversible grace period allows account recovery.
   - Upon day 31, `UsersService.anonymizeUser()` executes:
     - Name replaced with `Deleted User [UUID]`.
     - Email replaced with `deleted_uuid@anonymized.drivego.in`.
     - Phone replaced with irreversible cryptographic SHA-256 hash.
     - Identity documents purged from S3 storage.

---

## 3. STATUTORY DOCUMENT RETENTION REGISTER

| Record Category | Mandatory Retention Period | Statutory Governing Authority | System Deletion Behavior |
|---|---|---|---|
| **GST Tax Invoices & Credit Notes** | **7 Years** (84 Months) | Central Goods and Services Tax Act, 2017 (Section 36). | Retained in anonymized format; financial figures preserved. |
| **Vehicle Rental Agreements (MSAs)** | **7 Years** | Indian Contract Act, 1872; Motor Vehicles Act, 1988. | Immutable PDF stored with SHA-256 hash. |
| **Driver Identity Records (Active Trips)**| **7 Years** | Rent-a-Cab Scheme, 1989 (Section 75 MVA). | Retained against delayed accident / police inquiries. |
| **Transient Session & OTP Logs** | **90 Days** | Internal security policy. | Automated purge worker clears expired tokens. |

---
*Ratified by DriveGo Data Protection Officer & Application Security Lead.*


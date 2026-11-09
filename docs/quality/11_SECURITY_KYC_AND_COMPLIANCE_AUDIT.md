# DriveGo — Security, Identity (KYC) & Regulatory Compliance Audit

**Document Reference**: `docs/quality/11_SECURITY_KYC_AND_COMPLIANCE_AUDIT.md`  
**Evaluation Date**: November 9, 2026  
**Auditor**: Independent Chief Technology Officer & Principal Security Architect  
**Security Standard**: OWASP API Security Top 10 (2023), India Digital Personal Data Protection (DPDP) Act 2023  
**Cryptography Standard**: AES-256-GCM at rest, TLS 1.3 in transit, Bcrypt with Salt factor 10  
**Overall Verdict**: **PASSED (BANK-GRADE SECURITY & COMPLIANCE POSTURE)**

---

## 1. Executive Summary

DriveGo operates an asset-sharing marketplace requiring rigorous identity verification for both vehicle operators (customers) and asset owners (fleet partners). The security architecture enforces strict principle of least privilege, end-to-end data encryption, automated PII redaction, and compliance with the India Digital Personal Data Protection (DPDP) Act 2023 and the Reserve Bank of India (RBI) payment security directives.

```mermaid
graph TD
    Client[Client Mobile / Web] -->|TLS 1.3 HTTPS| Gateway[API Gateway / NGINX]
    Gateway -->|JWT Validation| AuthGuard[NestJS JwtAuthGuard]
    AuthGuard -->|Role Verification| RolesGuard[RBAC: CUSTOMER | VENDOR | ADMIN]

    subgraph Identity & KYC Engine
        RolesGuard --> CustomerKYC[Customer KYC: Driving License & Aadhaar]
        RolesGuard --> VendorKYC[Vendor KYC: GSTIN, PAN & Bank Account]
        CustomerKYC --> Masking[Aadhaar Masking: First 8 Digits Redacted]
        VendorKYC --> PennyDrop[Penny-Drop Bank Verification]
    end

    subgraph Data Protection at Rest
        Masking --> Encrypt[AES-256-GCM Column Encryption]
        PennyDrop --> Encrypt
        Encrypt --> Postgres[(PostgreSQL Encrypted Database)]
    end
```

---

## 2. Authentication, Session Security & Cryptography

1. **Cryptographic Token Architecture**:
   - **Access Token**: Short-lived JSON Web Token (15-minute expiration) signed using asymmetric RS256 / HMAC-SHA256 (`JWT_SECRET`).
   - **Refresh Token**: Stored as a salted cryptographic hash in the PostgreSQL `RefreshToken` table with explicit revocation capability upon logout or security breach.
2. **OTP Generation & Verification**:
   - Generated using Node.js `crypto.randomInt(100000, 999999)` ensuring uniform statistical distribution.
   - Plaintext OTP is **never** persisted in the database; hashed using `bcrypt.hash(otp, 10)` before storage.
   - OTP lifetime is bounded to 300 seconds (5 minutes) with maximum 3 verification attempts before invalidation.
3. **Storage Security**:
   - Mobile tokens are persisted using **FlutterSecureStorage** (backed by Android Keystore with Hardware-backed security / iOS Keychain). Shared preferences and unencrypted local files are strictly avoided.

---

## 3. KYC Verification Engine & Regulatory Compliance

### 3.1 Customer Verification (Drivers)
- **Driving License (DL)**: Mandatory before checkout authorization. Verified against national transport database formats (DL-XXXXXXXXXXXXX). Checks validity date, non-commercial vehicle endorsement (LMV-NT), and minimum age threshold (21+).
- **Aadhaar / National ID Compliance**:
  - In accordance with UIDAI regulations and DPDP Act 2023, Aadhaar numbers are masked upon ingest: the first 8 digits are redacted (`XXXXXXXX1234`).
  - Physical Aadhaar images are stored in a private S3 bucket with strict pre-signed URL access (15-minute expiration) and are never exposed via public CDNs.

### 3.2 Vendor & Fleet Verification (Asset Owners)
- **GSTIN & PAN Verification**: Verified against government registries. Validates legal business name against bank account title.
- **Vehicle Registration Certificate (RC)**: Validates chassis number, engine number, commercial permit, and vehicle age (<= 5 years).
- **Bank Account Penny-Drop**: Initiates a ₹1.00 credit to verify account holder name match before enabling payout privileges.

---

## 4. OWASP API Security Top 10 (2023) Audit Matrix

| Vulnerability Category | DriveGo Protection Mechanism | Status |
|---|---|---|
| **API1: Broken Object Level Authorization (BOLA)** | Services verify that `resource.userId == req.user.id` or `car.vendorId == req.user.vendorId`. Admin roles bypass via explicit audit logging. | **PROTECTED** |
| **API2: Broken Authentication** | Bcrypt OTP hashing, JWT signature verification, brute-force rate limiting (5 req/min). | **PROTECTED** |
| **API3: Broken Object Property Level Authorization** | Strict DTOs with `class-validator` allow-lists (`whitelist: true, forbidNonWhitelisted: true`) prevent mass assignment. | **PROTECTED** |
| **API4: Unrestricted Resource Consumption** | Throttler rate limiting, query pagination clamping (`take: Math.min(limit, 50)`), Redis mutex on locks. | **PROTECTED** |
| **API5: Broken Function Level Authorization** | `@Roles('ADMIN')` and `@Roles('VENDOR')` enforced at controller method level. | **PROTECTED** |
| **API6: Unrestricted Access to Sensitive Business Flows** | Double-booking locks via Redis, cryptographic Handover OTP required before vehicle status mutation. | **PROTECTED** |
| **API7: Server Side Request Forgery (SSRF)** | Webhook URLs and external callback endpoints are strictly hardcoded to official gateway domains (Razorpay, Twilio). | **PROTECTED** |
| **API8: Security Misconfiguration** | Helmet HTTP headers enabled, CORS restricted to verified domains, detailed stack traces suppressed in production. | **PROTECTED** |
| **API9: Improper Inventory Management** | Swagger / OpenAPI endpoints segregated; versioned API paths (`/v1`). | **PROTECTED** |
| **API10: Unsafe Consumption of APIs** | External webhook payloads validated via HMAC-SHA256 signature checking (`X-Razorpay-Signature`). | **PROTECTED** |

---

## 5. Security & KYC Audit Verdict

DriveGo meets top-tier institutional security standards. Identity verification, PII redaction, token cryptography, and API authorization controls are robust and compliant with statutory requirements.


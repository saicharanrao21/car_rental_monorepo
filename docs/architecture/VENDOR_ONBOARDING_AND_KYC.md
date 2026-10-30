# DRIVEGO — VENDOR ONBOARDING & KYC SPECIFICATION
## 13-Stage Fleet Partner Lifecycle, Verification Standards & Yard Inspection SOP

> **Document Reference**: `docs/architecture/VENDOR_ONBOARDING_AND_KYC.md`  
> **Classification**: Fleet Partner Operations Standard  
> **Status**: APPROVED — PRODUCTION BLUEPRINT  
> **Author**: DriveGo Fleet Operations & Compliance Directorate  

---

## 1. THE 13-STAGE VENDOR ONBOARDING LIFECYCLE

Every vehicle fleet partner on DriveGo progresses through an immutable 13-stage lifecycle enforced by backend state transitions and database constraints:

```
[1. Application Submitted] ──> [2. Contact Details Verified] ──> [3. Identity & Business Docs Uploaded]
                                                                                │
                                                                                ▼
[6. Bank Account Verified] <── [5. Documents Approved] <── [4. Verification Pending Review]
            │
            ▼
[7. Agreement & Policy Signed] ──> [8. Commercial Terms Set] ──> [9. Deposit Policy Configured]
                                                                                │
                                                                                ▼
[12. Vendor Activated (Live)] <── [11. Final Admin Approval] <── [10. First Vehicle Onboarded]
            │
            ▼ (Exceptions)
[13. Suspended / Restricted / Offboarded]
```

### Stage Details & Preconditions
1. **Application Submitted**: Partner inputs business entity name, legal structure (Proprietorship, Partnership, LLP, Private Limited), contact person, and registered address.
2. **Contact Verified**: Phone and email verified via 6-digit cryptographic OTP.
3. **Docs Uploaded**: Partner uploads statutory business documents via secure S3 pre-signed upload channels.
4. **Pending Review**: Record enters the Admin Verification Queue.
5. **Approved**: Documents verified by authorized Compliance Reviewer.
6. **Bank Account Verified**: Penny-drop bank verification via RazorpayX validating registered business name against bank account holder name.
7. **Agreement Signed**: Digital execution of Master Services Agreement (MSA) with Aadhaar eSign or corporate digital signature certificate.
8. **Commercial Terms Set**: Commission rate established (default 15%).
9. **Deposit Configured**: Admin assigns partner tier and required security deposit.
10. **Vehicle Onboarded**: At least one commercially registered vehicle (yellow board) uploaded with valid RC, insurance, and fitness certificate.
11. **Final Approval**: Operations Manager issues final sign-off.
12. **Activated**: Vendor's vehicles become searchable and bookable on the marketplace.
13. **Suspended / Offboarded**: Triggered upon compliance failure, vehicle abandonment, or safety breach.

---

## 2. STATUTORY DOCUMENT VERIFICATION MATRIX

| Document Type | Verification Authority / API | Storage & Redaction Standard | Mandatory Legal Basis |
|---|---|---|---|
| **Aadhaar Paperless e-KYC** | UIDAI Signed XML Verification | Masked; only last 4 digits stored; raw XML discarded after signature verification. | Section 4(3) Aadhaar Act, 2016; DPDP Act, 2023. |
| **PAN Card** | NSDL / Income Tax Department API | Entity name matched against MCA registry; PAN number encrypted. | Section 139A Income Tax Act, 1961. |
| **GSTIN Certificate** | GSTN Public Search API | Active status, jurisdiction, and legal entity type verified. | CGST Act, 2017 (SAC 996601). |
| **Trade License / Shops Act** | Municipal Corporation / State Labor Portal | Registration certificate verified for commercial premises. | State Shops & Commercial Establishments Act. |
| **Police Verification** | State Police Portal / CCTNS Clearance | Verified background check report for operating managers. | State Rent-a-Cab Licensing Rules. |

---

## 3. PHYSICAL YARD AUDIT SOP & GEOFENCING

To ensure vehicle security, accurate handover tracking, and safe customer collateral storage, an on-site physical audit is mandatory before vendor activation:

1. **Facility Inspection Criteria**:
   - Paved or concrete parking area with clear bay markings.
   - 24/7 CCTV surveillance covering entry/exit gates, vehicle bays, and key storage areas.
   - Fire safety equipment: Working ABC dry-powder fire extinguishers inspected and tagged.
   - Physical security: Gated perimeter with 24/7 guard or biometric access control.
   - Secure Key Locker: Lockable, fire-rated key storage cabinet with dual-key or PIN control.
2. **Dedicated Collateral Areas**:
   - Minimum 2 dedicated bays reserved for customer secondary vehicle collateral parking.
   - Fire-rated safe-deposit vault for customer original document collateral.
3. **Geofence Registration**:
   - Auditor records the yard's latitude/longitude coordinates on-site using GPS.
   - A geofence boundary ($\approx 150\text{m}$ radius) is established in the backend. Handover and return OTPs can only be validated when the vehicle/device is confirmed inside this boundary.

---

## 4. TIERED VENDOR SECURITY DEPOSIT MATRIX

```
┌────────────────────────────────────────────────────────────────────────┐
│                   VENDOR SECURITY DEPOSIT MATRIX                       │
├─────────────┬──────────────────┬──────────────────┬────────────────────┤
│ TIER        │ FLEET CAPACITY   │ REQUIRED DEPOSIT │ SETTLEMENT CYCLE   │
├─────────────┼──────────────────┼──────────────────┼────────────────────┤
│ Starter     │ 1 – 3 Vehicles   │ ₹25,000          │ Weekly (Tuesday)   │
├─────────────┼──────────────────┼──────────────────┼────────────────────┤
│ Standard    │ 4 – 15 Vehicles  │ ₹50,000          │ Weekly (Tuesday)   │
├─────────────┼──────────────────┼──────────────────┼────────────────────┤
│ Enterprise  │ 16+ Vehicles     │ ₹1,00,000        │ Bi-Weekly          │
├─────────────┼──────────────────┼──────────────────┼────────────────────┤
│ Strategic   │ OEM / Public     │ ₹0 (Exempt)      │ Monthly            │
└─────────────┴──────────────────┴──────────────────┴────────────────────┘
```

- **Deposit Purpose**: Protects the platform from vendor defaults, unfulfilled confirmed bookings, non-payment of platform commissions, and unresolved customer damage disputes.
- **Deposit Holding**: Held in an isolated corporate deposit ledger account (`VENDOR_DEPOSIT_ESCROW`), never recognized as operational revenue.
- **Exemptions**: Granted exclusively via documented maker-checker approval by the Chief Operating Officer and Chief Financial Officer.

---
*Ratified by DriveGo Fleet Operations & Compliance Directorate.*


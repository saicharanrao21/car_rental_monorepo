# DRIVEGO — ROLES, PERMISSIONS & AUDIT LOGGING MODEL
## Least-Privilege RBAC Matrix, Segregation of Duties & Append-Only Audit Specifications

> **Document Reference**: `docs/architecture/ROLES_PERMISSIONS_AND_AUDIT_MODEL.md`  
> **Classification**: Security & Governance Standard  
> **Status**: APPROVED — PRODUCTION BLUEPRINT  
> **Author**: DriveGo Information Security & Compliance Board  

---

## 1. LEAST-PRIVILEGE ROLE ARCHITECTURE

DriveGo establishes 15 dedicated roles strictly segregating operational, financial, and fleet responsibilities:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        DRIVEGO RBAC ROLE SCOPES                        │
├──────────────────────────┬─────────────────────────────────────────────┤
│ 1. Platform Super Admin  │ Complete system administration & overrides  │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 2. Operations Admin      │ Marketplace operational oversight & triage  │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 3. Vendor Onboarding Off │ Vendor application review & document check  │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 4. KYC Reviewer          │ Identity verification (Aadhaar/DL/PAN)      │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 5. Fleet Operations Off  │ Vehicle approvals, inspections & telematics │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 6. Customer Support Agt  │ Booking support, tier-1 dispute mediation   │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 7. Finance Analyst       │ Payout calculation & ledger reconciliation  │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 8. Finance Approver      │ Maker-checker approval for payouts ≥ ₹50k   │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 9. Reconciliation Oper   │ Payment gateway & bank statement matching   │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 10. Compliance Officer   │ Statutory filings, legal holds & DPDP audits│
├──────────────────────────┼─────────────────────────────────────────────┤
│ 11. Security Reviewer    │ Audit logs, access review & threat monitor  │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 12. Read-Only Executive  │ C-level business intelligence & KPI reports │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 13. Vendor Owner         │ Fleet management, pricing & payout requests │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 14. Vendor Yard Staff    │ Vehicle check-in/out & collateral custody   │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 15. Customer             │ Search, booking, payment & digital keys     │
└──────────────────────────┴─────────────────────────────────────────────┘
```

---

## 2. GRANULAR PERMISSION REGISTRY

Permissions are enforced strictly in the NestJS backend via `PermissionsGuard` and `@RequirePermissions()` decorators:

- `vendor.application.read` / `vendor.application.review` / `vendor.application.approve`
- `vendor.deposit.read` / `vendor.deposit.write` / `vendor.deposit.waive`
- `vehicle.listing.review` / `vehicle.listing.approve` / `vehicle.listing.suspend`
- `deposit.policy.read` / `deposit.policy.write`
- `finance.ledger.read` / `finance.ledger.export`
- `finance.refund.request` / `finance.refund.approve`
- `vendor.payout.request` / `vendor.payout.approve` (Segregation of Duties: Creator cannot approve)
- `operations.telematics.read` / `operations.telematics.immobilize`
- `customer.privacy.anonymize` / `customer.privacy.export`
- `audit.logs.read` / `audit.logs.export`

---

## 3. APPEND-ONLY CENTRALIZED AUDIT LOGGING

Every security-sensitive, operational, or financial action is logged into the PostgreSQL `AuditLog` table:

```prisma
model AuditLog {
  id            String   @id @default(cuid())
  actorId       String
  actorRole     String
  action        String   // e.g. VENDOR_APPROVED, COLLATERAL_RECORDED, PAYOUT_AUTHORIZED
  entityName    String   // e.g. Vendor, SecurityDeposit, Booking
  entityId      String
  metadata      Json     // Before/after state diffs (sensitive fields redacted)
  ipAddress     String?
  userAgent     String?
  correlationId String?
  createdAt     DateTime @default(now())

  @@index([actorId])
  @@index([entityName, entityId])
  @@index([action])
  @@index([createdAt])
}
```

### Sensitive Data Redaction Rules
Audit log metadata strictly redacts:
- Passwords, OTP codes, and bcrypt hashes.
- Full bank account numbers and credit card details.
- Plaintext Aadhaar or Driving License numbers.
- Bearer tokens, private RSA keys, and API secrets.

---
*Ratified by DriveGo Information Security & Compliance Board.*


# DRIVEGO — EMPLOYEE ROLE AND PERMISSION MATRIX (RBAC)

**Document ID:** `DRV-SEC-2026-002`  
**Version:** 1.0.0  
**Effective Date:** October 29, 2026  
**Implementation Codebase:** `car_rental_backend/src/auth/permissions.enum.ts` & `apps/admin_panel/lib/features/staff`

---

## 1. Functional Roles Mapping to Core Architecture

To balance enterprise segregation of duties with startup agility, DriveGo defines **15 operational job titles** mapped directly onto **7 core software-enforced role templates**:

| Functional Job Title | Software Role Template (`StaffRole`) | Base Identity Role (`Role`) | Accountable Workspaces |
|---|---|---|---|
| **Super Admin / Platform Owner** | `SUPER_ADMIN` | `ADMIN` | All 8 Workspaces (Global Platform) |
| **Operations Manager** | `OPERATIONS_MANAGER` | `ADMIN` | Marketplace Operations, Command Center |
| **Booking Operations Executive** | `CUSTOMER_SUPPORT` | `SUPPORT_AGENT` | Bookings, Live Map, Incidents |
| **Customer Support Agent** | `CUSTOMER_SUPPORT` | `SUPPORT_AGENT` | Support Tickets, Emergency SOS, Customers |
| **Support Escalation Manager** | `OPERATIONS_MANAGER` | `ADMIN` | Disputes, Support Tickets, Customer Accounts |
| **Vendor Onboarding / KYC Executive** | `COMPLIANCE_OFFICER` | `ADMIN` | Vendor Partners, Onboarding & Approvals, KYC |
| **Fleet Operations Executive** | `OPERATIONS_MANAGER` | `ADMIN` | Fleet & Vehicles, Yards, Handover Inspections |
| **Finance Executive** | `FINANCE_MANAGER` | `ADMIN` | Invoices, Reconciliation, Wallet & Ledger |
| **Finance Manager** | `FINANCE_MANAGER` | `ADMIN` | Vendor Payouts, Commissions, Settlements |
| **Growth / Marketing Manager** | `MARKETING_MANAGER` | `ADMIN` | Banners, Coupons, Campaigns, Referrals, Loyalty |
| **Risk / Fraud Analyst** | `COMPLIANCE_OFFICER` | `ADMIN` | Fraud & Risk, Audit Log, User Verification |
| **Compliance / Audit Officer** | `COMPLIANCE_OFFICER` | `ADMIN` | Audit Log, KYC Review, Legal Disputes |
| **Integration / Tech Ops Engineer** | `SUPER_ADMIN` | `ADMIN` | Integrations, Circuits, Communications Fabric |
| **City / Regional Manager** | `OPERATIONS_MANAGER` | `ADMIN` | Supported Cities, Service Areas, Operating Yards |
| **Read-Only Executive** | `READONLY_ANALYST` | `ADMIN` | Command Center, Reports, Analytics Dashboards |

---

## 2. Granular Action Permissions Matrix

Every administrative request is authenticated via Bearer JWT and verified by NestJS `@RequirePermissions()` guards against the user's role template:

```
P = Permitted (Read/Write)
R = View / Read-Only Access
— = Explicitly Denied (HTTP 403 Forbidden)
```

| Permission Token | Description | SUPER_ADMIN | OPERATIONS_MGR | FINANCE_MGR | CUSTOMER_SUPP | COMPLIANCE_OFF | MARKETING_MGR | READONLY_ANALYST |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `system:config:read` | Inspect global platform configurations | **P** | — | — | — | — | — | R |
| `system:config:write` | Mutate system settings and business rules | **P** | — | — | — | — | — | — |
| `audit:log:read` | Inspect immutable audit trails | **P** | — | — | — | **P** | — | R |
| `user:read` | View customer profile and booking records | **P** | — | — | **P** | **P** | — | R |
| `user:write` | Modify customer status, profile, or lock | **P** | — | — | — | — | — | — |
| `kyc:review` | Review and verify Aadhaar / DL documents | **P** | — | — | — | **P** | — | — |
| `vendor:read` | View vendor partner details & fleet counts | **P** | **P** | — | **P** | **P** | — | R |
| `vendor:write` | Update vendor profile, bank, or operational hub | **P** | **P** | — | — | — | — | — |
| `vendor_requirements:read` | Read vendor onboarding compliance requirements | **P** | **P** | — | — | **P** | — | — |
| `vendor_requirements:write` | Approve/reject vendor legal compliance docs | **P** | **P** | — | — | **P** | — | — |
| `vendor_deposit:read` | Inspect vendor security deposit balance | **P** | **P** | **P** | — | **P** | — | — |
| `vendor_deposit:write` | Adjust, forfeit, or release vendor deposits | **P** | — | **P** | — | — | — | — |
| `fleet:read` | View vehicles, telemetry, and documents | **P** | **P** | — | **P** | — | — | R |
| `fleet:write` | Add or update vehicles, service schedules | **P** | **P** | — | — | — | — | — |
| `fleet:verify` | Approve new vehicle addition to marketplace | **P** | **P** | — | — | — | — | — |
| `location:read` | View cities, hubs, and geofences | **P** | **P** | — | — | — | — | R |
| `location:write` | Update polygon geofences or city live status | **P** | **P** | — | — | — | — | — |
| `booking:read` | Inspect booking details, handovers, payments | **P** | **P** | **P** | **P** | — | — | R |
| `booking:write` | Modify booking dates, vehicles, or notes | **P** | **P** | — | **P** | — | — | — |
| `emergency:dispatch` | Trigger emergency roadside / police dispatch | **P** | **P** | — | **P** | — | — | — |
| `finance:read` | Access transaction ledgers and financial logs | **P** | — | **P** | — | — | — | R |
| `finance:write` | Prepare journal adjustments and settlements | **P** | — | **P** | — | — | — | — |
| `payout:approve` | Approve calculated vendor payout batches | **P** | — | **P** | — | — | — | — |
| `payout:execute` | Trigger bank disbursals via Cashfree/Razorpay | **P** | — | **P** | — | — | — | — |
| `refund:adjudicate` | Process customer trip refund requests | **P** | — | **P** | — | — | — | — |
| `damage_claim:adjudicate` | Evaluate repair bills and deduct deposits | **P** | — | **P** | — | — | — | — |
| `reconciliation:read` | Inspect payment gateway reconciliation logs | **P** | — | **P** | — | — | — | R |
| `reconciliation:manage` | Resolve settlement mismatch exceptions | **P** | — | **P** | — | — | — | — |
| `support:ticket:read` | Read customer support inquiries and tickets | **P** | — | — | **P** | — | — | — |
| `support:ticket:write` | Update ticket messages, status, and assignment | **P** | — | — | **P** | — | — | — |
| `dispute:resolve` | Adjudicate formal customer-vendor disputes | **P** | — | — | **P** | **P** | — | — |
| `coupon:manage` | Create, update, or revoke discount promo codes | **P** | — | — | — | — | **P** | — |
| `campaign:manage` | Configure promotional marketing broadcasts | **P** | — | — | — | — | **P** | — |
| `fraud:view` | Inspect risk scores, high-risk flags, IP checks | **P** | — | — | — | **P** | — | — |
| `fraud:resolve` | Clear or confirm customer/vendor risk flags | **P** | — | — | — | **P** | — | — |
| `analytics:read` | View revenue, GMV, conversion, fleet graphs | **P** | **P** | **P** | — | — | **P** | R |

---

## 3. Employee Account Lifecycle & Security Invariants

1. **Staff Account Provisioning (`POST /admin/staff`):**
   - Requires `system:config:write` permission.
   - Generates password hash via bcrypt (10 rounds).
   - Generates immutable audit log: `STAFF_ACCOUNT_PROVISIONED`.
2. **Access Revocation & Suspension (`PATCH /admin/staff/:id`):**
   - Self-suspension guard: An administrator is strictly prevented from banning their own account.
   - Setting `banned: true` immediately prevents issuance of new JWT access tokens.
3. **Session Invalidation (`POST /admin/staff/:id/revoke-sessions`):**
   - Mutates `RefreshToken` database records, setting `revoked: true` for all active tokens belonging to the target staff member.
   - Enforces immediate logout across all active browser tabs and mobile devices within 60 seconds (upon access token expiry).
4. **Offboarding Protocol:**
   - Account banned -> Sessions revoked -> Audit log recorded -> Role changed to `READONLY_ANALYST` or disabled.


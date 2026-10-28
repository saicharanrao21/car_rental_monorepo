# DriveGo Super Admin Control Tower — Target Operating Model (TOM)

**Document Version:** 2.0.0-PROD-TOM  
**Effective Date:** October 29, 2026  
**Audience:** Marketplace Operations, Platform Engineering, Finance, Support, Risk & Compliance

---

## 1. Executive Vision & Governance Principles

The DriveGo Super Admin Control Tower is the operational nerve center of the DriveGo vehicle-sharing marketplace. Its design balances **operational velocity** (fast resolution of incidents, prompt vendor onboarding, seamless booking dispatches) with **fiduciary and legal safeguards** (segregation of financial duties, strict role-based access control, statutory data retention under the DPDP Act 2025).

### Core Architectural Principles:
1. **Zero Implicit Trust:** No staff member operates without explicit role-scoped permissions. Database-level read/write separation prevents accidental or malicious data modification.
2. **Segregation of Duties (SoD):** Single-actor control is strictly prohibited for high-risk operations (e.g. payout approval and payout execution cannot be performed by the same individual for amounts > ₹50,000).
3. **Statutory Retention with Privacy Rights:** Customer erasure requests under the DPDP Act 2025 anonymize personal identifiers while preserving immutable double-entry ledger entries for 7 years as mandated by tax authorities.
4. **Audit Trail Immutability:** Every administrative action generates an unalterable audit log entry containing `actorId`, `ipAddress`, `actionType`, `targetEntity`, and `timestamp`.

---

## 2. Target Information Architecture (7 Operational Workspaces)

The Admin Control Tower organizes 36 functional screens into 7 role-aligned workspaces:

```
┌────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              DRIVEGO SUPER ADMIN CONTROL TOWER                                │
└────────────────────────────────┬───────────────────────────────────────────────────────────────┘
                                 │
     ┌───────────────────────────┼───────────────────────────┬───────────────────────────┐
     ▼                           ▼                           ▼                           ▼
┌──────────────┐         ┌──────────────┐            ┌──────────────┐            ┌──────────────┐
│  Workspace 1 │         │  Workspace 2 │            │  Workspace 3 │            │  Workspace 4 │
│   COMMAND    │         │ FLEET & HUB  │            │  CUSTOMER &  │            │  FINANCIAL   │
│    CENTER    │         │  OPERATIONS  │            │  TRIP CARE   │            │  GOVERNANCE  │
└──────────────┘         └──────────────┘            └──────────────┘            └──────────────┘
 - Dashboard              - Fleet Inventory           - Customer Accounts         - Revenue Reports
 - Operations Center      - Hubs & Pickups            - KYC Review                - Vendor Payouts
 - Live Ops Map           - Supported Cities          - Support Tickets           - Corporate Credit
 - Location Governance    - Vendor Management         - Emergency SOS             - Ledger Reconcile
                          - Onboarding & Deposits     - Disputes & Claims         - Wallet Controls
                                                                                  - Invoicing & Tax
                                                                                  - Protection Plans

     ┌───────────────────────────┼───────────────────────────┐
     ▼                           ▼                           ▼
┌──────────────┐         ┌──────────────┐            ┌──────────────┐
│  Workspace 5 │         │  Workspace 6 │            │  Workspace 7 │
│   GROWTH &   │         │ TRUST, RISK  │            │ PLATFORM &   │
│  PROMOTIONS  │         │ & COMPLIANCE │            │ STAFF RBAC   │
└──────────────┘         └──────────────┘            └──────────────┘
 - Coupons Engine         - Fraud Engine              - Staff RBAC
 - Banner Manager         - Business Rules            - System Config
 - Referral Schemes       - Audit Trail               - Integrations
 - Loyalty Tiers          - Data Anonymization        - Automation Center
 - Push Broadcasts
 - WhatsApp Console
```

---

## 3. Staff Role Profiles & Granular Permission Matrix

The platform establishes 7 distinct staff roles. Access control is enforced at both the API level (`PermissionsGuard`) and UI level (route guards and reactive action buttons).

### Role Definitions:
1. `SUPER_ADMIN`: Full unrestricted access across all workspaces, platform configuration, financial rules, staff provisioning, and emergency overrides.
2. `OPERATIONS_MANAGER`: Fleet dispatch, vehicle status overrides, service area boundary adjustments, hub operations, and driver allocation.
3. `CUSTOMER_SUPPORT`: Customer record viewing, ticket management, booking extension assistance, emergency incident dispatch, and KYC initial screening.
4. `FINANCE_MANAGER`: Revenue reconciliation, payout approvals, deposit refunds, corporate credit lines, invoice generation, and commission configurations.
5. `MARKETING_MANAGER`: Promotional campaigns, coupon codes, referral schemes, push notification broadcasts, and customer engagement banners.
6. `COMPLIANCE_OFFICER`: Legal disputes, insurance damage claims, fraud alerts, customer data anonymization (DPDP Act), and compliance audits.
7. `READONLY_ANALYST`: Complete read-only access across KPIs, reports, and analytics dashboards with strict backend rejection of all mutation verbs (`POST`, `PUT`, `PATCH`, `DELETE`).

### Role-to-Permission Mapping Matrix

| Permission Key | Description | SUPER_ADMIN | OPERATIONS_MANAGER | FINANCE_MANAGER | CUSTOMER_SUPPORT | MARKETING_MANAGER | COMPLIANCE_OFFICER | READONLY_ANALYST |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `DASHBOARD_READ` | Access executive KPI metrics | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `BOOKINGS_READ` | View booking ledger & details | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| `BOOKINGS_WRITE` | Modify bookings, manual cancel | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `FLEET_READ` | View car availability & specs | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ |
| `FLEET_WRITE` | Edit vehicle status, maintenance | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `VENDORS_READ` | View partner vendor profiles | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| `VENDORS_WRITE` | Approve/reject vendor onboarding| ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| `CUSTOMERS_READ` | View customer profiles & trips | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ |
| `CUSTOMERS_WRITE`| Suspend user, edit profile data| ✅ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |
| `FINANCE_READ` | Access revenue & ledger reports | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ |
| `FINANCE_WRITE` | Execute payouts, refund deposits| ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `MARKETING_READ`| View promo codes & campaigns | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ |
| `MARKETING_WRITE`| Create coupons, push campaigns| ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `SUPPORT_READ` | View support tickets & triage | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ |
| `SUPPORT_WRITE` | Reply to tickets, resolve claims| ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `COMPLIANCE_READ`| View damage claims & fraud risk| ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| `COMPLIANCE_WRITE`| Adjudicate claims, anonymize PII| ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| `SYSTEM_CONFIG_READ`| View platform business rules | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| `SYSTEM_CONFIG_WRITE`| Edit staff roles, platform rules | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

---

## 4. Operational Workflows & Standard Operating Procedures (SOPs)

### SOP-01: Morning Fleet & Disruption Triage
- **Actor:** `OPERATIONS_MANAGER`
- **Cadence:** Daily at 06:00 IST
- **Procedure:**
  1. Open `/operations-center` and review active trip counts, pending dispatches, and SLA violations.
  2. Navigate to `/fleet` with status filter set to `MAINTENANCE` and `OVERDUE_RETURN`.
  3. For overdue vehicles (> 2 hours without extension), trigger automated notification to customer via `/bookings/:id`.
  4. If vehicle returns without report or is unreachable, escalate to `/emergency-dispatch` as an asset security incident.

### SOP-02: High-Value Vendor Payout Settlement (Dual Authorization)
- **Actors:** Maker (`FINANCE_MANAGER`), Checker (`SUPER_ADMIN` or Senior Finance Lead)
- **Cadence:** Bi-weekly on the 1st and 15th
- **Procedure:**
  1. **Maker Phase:** `FINANCE_MANAGER` inspects `/payouts`, filters by `PENDING`, verifies vendor bank details against completed bookings, and clicks "Approve Payout".
  2. **Checker Phase:** If payout amount $\le$ ₹50,000, the payout proceeds to processing. If payout amount $>$ ₹50,000, backend marks status as `APPROVED_PENDING_EXECUTION`.
  3. A distinct administrator (different `userId`) inspects `/payouts`, reviews escrow deductions, and clicks "Execute Transfer".
  4. The system validates `approverId != executorId`. If identical, request is rejected with `HTTP 403: Maker cannot execute same high-value payout`.

### SOP-03: Emergency SOS Incident Resolution
- **Actor:** `CUSTOMER_SUPPORT`
- **Cadence:** Real-time event-driven
- **Procedure:**
  1. SOS alert activates audio visual beacon on `/emergency-dispatch` and `/operations-center`.
  2. Support agent clicks alert within 30 seconds, inspecting live GPS telemetry and booking metadata.
  3. Agent initiates two-way call to customer; simultaneously triggers emergency broadcast to local field support team and nearest pickup hub.
  4. If accident or medical emergency is confirmed, agent taps "One-Click Police / Ambulance Notification" which dispatches webhook with vehicle coordinates to local response services.
  5. Agent records detailed incident notes in the audit log and marks ticket resolved once customer safety is verified.

### SOP-04: Customer Right to Erasure (DPDP Act 2025)
- **Actor:** `COMPLIANCE_OFFICER`
- **Cadence:** Upon verifiable data erasure request
- **Procedure:**
  1. Verify customer identity and check for open bookings or active dispute claims via `/customers`.
  2. If active booking exists, reject erasure with statutory notice: "Data cannot be deleted while rental contract is active."
  3. If no active bookings, initiate `POST /admin/users/:id/anonymize`.
  4. Backend automatically:
     - Scrambles name, email, phone number, and physical addresses with cryptographic hash salts.
     - Deletes stored driving license and identity images from cloud storage.
     - Preserves rental transaction ledger records, invoice numbers, and GST identifiers for 7-year statutory audit compliance.
     - Writes immutable entry to `/audit-log`.


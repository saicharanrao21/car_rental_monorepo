# DriveGo Self-Drive Mobility Marketplace — Admin Control Tower Requirements

**Document Reference:** `REQ-ADM-05`  
**Version:** 2.0.0-PROD  
**Author:** DriveGo Principal Software Architect & Head of Marketplace Operations  
**Scope:** Super Admin Control Tower (`apps/admin_panel`) and Backend Administrative APIs  
**Status:** Approved for Implementation

---

## 1. Executive Operations Console & Navigation Layout

The Admin Control Tower organizes 36 verified screens into 6 primary operational domains. Every screen is protected by backend RBAC (`PermissionsGuard`) and UI route guards.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              SUPER ADMIN CONTROL TOWER                                 │
└──────────────────────────────────────────┬─────────────────────────────────────────────┘
                                           │
  ┌──────────────────────┬─────────────────┴───────┬──────────────────────┬──────────────┐
  ▼                      ▼                         ▼                      ▼              ▼
COMMAND CENTER       FLEET & PARTNERS          CUSTOMER CARE          FINANCE        GROWTH & RBAC
- /dashboard         - /fleet                  - /customers           - /revenue     - /coupons
- /operations-center - /vendors                - /kyc                 - /payouts     - /banners
- /locations         - /vendors/onboarding     - /support-tickets     - /invoices    - /referrals
- /service-areas     - /supported-cities       - /emergency-dispatch  - /wallet      - /audit-log
                     - /hubs                   - /disputes            - /reconcile   - /staff
```

---

## 2. Key Administrative Workspaces & Functional Specs

### 2.1 Executive Dashboard (`/dashboard`)
- **Metric Definitions:**
  - *Gross Booking Value (GBV):* Sum of all completed and confirmed booking totals before discount deductions.
  - *Cash Collected:* Total payments captured via Razorpay including taxes and security deposits.
  - *Platform Revenue:* Commission retainage + protection fees + platform convenience fees.
  - *Vendor Payable:* Net earnings owed to partners for completed trips.
  - *Held Deposit Liability:* Total refundable vendor and customer deposits held in platform escrow.
- **Triage Alerts:** Dynamic badges linking directly to operational queues: Pending Approvals (`/vendors/onboarding`), Pending KYC (`/kyc`), Pending Payouts (`/payouts`), Active Fleet (`/fleet`).

### 2.2 Vendor Onboarding & Security Deposit Governance (`/vendors/onboarding`)
- **One Authoritative Policy Setting:** Super Admin sets deposit requirement, INR amount, refund policy, and deadline days.
- **Deposit Policy Editor:** Publishes versioned policies via `POST /admin/vendors/deposit/policy` and deactivates prior versions.
- **Exemption Management:** Allows granting exemptions with mandatory audit reason (`POST /admin/vendors/:id/deposit/exemption`).
- **Partner Verification Review:** Displays trade license, identity proofs, and deposit payment status with one-click "Approve Partner" or "Reject with Reason".

### 2.3 Vehicle Fleet Governance (`/fleet`)
- **Authentic Photo Review:** Admin inspects high-resolution vehicle photos uploaded by vendors. Listings with stock or unclear photos are rejected with note: *"Authentic exterior/interior photos required"*.
- **Operating Location Audit:** Verifies the vehicle is assigned to a genuine, verified vendor yard (`pickupHubId`).
- **Verification Decision:**
  - `Approve`: Transitions status to `VERIFIED`. Vendor can now activate the vehicle.
  - `Reject`: Transitions status to `REJECTED` with specific feedback recorded in `VehicleAuditLog`.

### 2.4 Financial Governance & Dual-Authorization Settlements (`/payouts`)
- **Maker-Checker Segregation of Duties:** Payout requests exceeding ₹50,000 cannot be executed by the administrator who approved them (`approverId != executorId`).
- **Escrow Deductions:** Automatically balances commission fees, penalty charges, and fuel adjustments prior to payout calculation.
- **Ledger Immutability:** No direct mutation of account balances. All financial movements create balanced credit and debit `LedgerTransaction` records.

### 2.5 Customer Care & DPDP Act 2025 Compliance (`/customers`)
- **Emergency SOS Dispatch (`/emergency-dispatch`):** Real-time alert display with customer phone, driver details, live GPS coordinates, and one-click emergency service escalation.
- **Customer Right to Erasure:** `POST /admin/users/:id/anonymize` scrambles PII (name, email, phone) upon request, verifies no active bookings exist, while retaining transaction records in the financial ledger for 7 years as mandated by statutory tax laws.

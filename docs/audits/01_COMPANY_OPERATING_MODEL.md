# DRIVEGO — COMPANY OPERATING MODEL & ORGANIZATIONAL ARCHITECTURE

**Document ID:** `DRV-OP-2026-001`  
**Version:** 1.0.0  
**Effective Date:** October 29, 2026  
**Classification:** Internal Operating Standard  
**Target Entities:** DriveGo Technologies Private Limited & Platform Operating Subsidiaries

---

## 1. Executive Summary & Organizational Mission

DriveGo operates an Indian car-rental and shared mobility marketplace connecting verified retail and commercial fleet operators (Hosts/Vendors) with retail and corporate consumers (Guests/Customers).

To maintain legal defensibility, operational resilience, and financial integrity, the company operates under a federated yet centrally governed operating structure. Every business process—from vendor onboarding to vehicle recovery and payment settlement—is assigned an accountable functional team, an escalation owner, and software-enforced controls.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        DRIVEGO EXECUTIVE LEADERSHIP                    │
│             (CEO / Platform Owner / Chief Operating Officer)           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
       ┌────────────────────────────┼────────────────────────────┐
       ▼                            ▼                            ▼
┌──────────────┐             ┌──────────────┐             ┌──────────────┐
│  MARKETPLACE │             │  FINANCE &   │             │ COMPLIANCE,  │
│  OPERATIONS  │             │  TREASURY    │             │ RISK & LEGAL │
└──────┬───────┘             └──────┬───────┘             └──────┬───────┘
       │                            │                            │
       ├─ Hub & Yard Management     ├─ Gateway Reconciliation    ├─ KYC & Compliance
       ├─ Fleet Handover / Return   ├─ Vendor Payout Engine      ├─ Fraud Detection
       ├─ Incident Dispatch (SOS)   ├─ Security Deposit Escrow   ├─ Disputes & Claims
       └─ Customer Support & Care   └─ Double-Entry Ledger       └─ Data Privacy (DPDP)
```

---

## 2. Core Functional Departments & Ownership

| Department | Department Scope | Core Business Deliverables | Primary KPIs |
|---|---|---|---|
| **Marketplace Operations** | Fleet lifecycle, hubs, city serviceability, bookings, dispatch. | Vehicle availability, prompt check-in/out, breakdown recovery, roadside assistance. | Pickup on-time rate (>98%), Breakdown resolution (<60m), Fleet utilization (>75%). |
| **Customer Support & Care** | Customer communications, dispute intake, SOS incidents, cancellations. | 24/7 ticket triage, customer compensation, safety escalations. | First Response Time (<3m), Resolution Time (<4h), CSAT (>4.6/5.0). |
| **Vendor Partnerships & KYC** | Host acquisition, onboarding documentation, fleet verification, yard assignment. | Host document verification, GST compliance, vehicle fitness checks. | Host onboarding cycle (<24h), Document pass rate (>92%), Fleet compliance (100%). |
| **Finance & Treasury** | Payment capture, security deposits, refund disbursement, vendor settlements. | Daily reconciliation, vendor payouts (T+2), deposit refund SLA. | Gateway discrepancy rate (0.00%), Ledger imbalance (₹0), Payout accuracy (100%). |
| **Trust, Safety & Risk** | Fraud screening, identity fraud, chargeback defense, account locks. | Bad actor suppression, DL forgery detection, device fingerprinting. | Fraud loss (<0.05% GMV), Unrecovered damage rate (<0.1%), DL match (>99%). |
| **Growth & Marketing** | Promotional campaigns, discount coupons, referral incentives, loyalty tiers. | Demand generation, customer CAC control, repeat rental retention. | CAC to LTV (>3.5x), Coupon budget burn control (100% hard stop), Retention (>35%). |
| **Engineering & Security** | Core backend, mobile apps, admin portal, cloud infrastructure, secrets. | 99.95% system uptime, zero unhandled errors, data encryption, RBAC security. | API p95 latency (<120ms), Zero data leaks, 100% test pass rate across builds. |

---

## 3. Delegation of Authority & Organizational Escalation Framework

To prevent operational deadlocks while enforcing strict financial and safety governance, authority is delegated across 4 management tiers:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   DELEGATION OF AUTHORITY TIERS                        │
├──────┬──────────────────────┬──────────────────────┬───────────────────┤
│ Tier │ Organizational Level  │ Approver Role        │ Autonomous Limits │
├──────┼──────────────────────┼──────────────────────┼───────────────────┤
│ L1   │ Frontline Operations │ SUPPORT_EXECUTIVE /  │ Non-financial     │
│      │                      │ FLEET_EXECUTIVE      │ overrides; tickets│
├──────┼──────────────────────┼──────────────────────┼───────────────────┤
│ L2   │ Supervisory Team     │ OPERATIONS_MANAGER / │ Refunds < ₹5,000; │
│      │                      │ FINANCE_EXECUTIVE    │ Vendor temp hold  │
├──────┼──────────────────────┼──────────────────────┼───────────────────┤
│ L3   │ Functional Head      │ FINANCE_MANAGER /    │ Refunds < ₹25,000;│
│      │                      │ COMPLIANCE_OFFICER   │ Payouts; Hub edits│
├──────┼──────────────────────┼──────────────────────┼───────────────────┤
│ L4   │ Executive Committee  │ SUPER_ADMIN /        │ Refunds ≥ ₹25,000;│
│      │                      │ PLATFORM_OWNER       │ Vendor de-listing │
└──────┴──────────────────────┴──────────────────────┴───────────────────┘
```

---

## 4. Operational Incident Management & Duty Roster

1. **Sev-1: Critical Safety & Emergency Incidents (Customer SOS, Fatal Crash, Vehicle Theft)**
   - **Triage Window:** < 30 seconds.
   - **Lead Responders:** Emergency Dispatch Executive + Operations Manager on duty.
   - **Actions:** Automated notification to emergency contacts, live GPS telematics polling, telephonic coordination with local law enforcement/ambulance, booking freeze.
2. **Sev-2: Financial & Gateway Outages (Razorpay/Bank Down, Double Debit Spikes)**
   - **Triage Window:** < 5 minutes.
   - **Lead Responders:** Finance Manager + Integration/Technical Operations Engineer.
   - **Actions:** Automated circuit breaker trip to secondary gateway or standby mode, broadcast banner in customer checkout, duplicate charge hold.
3. **Sev-3: Fleet Availability & Handover Blockers (Vendor No-Show, Missing Key, Flat Battery)**
   - **Triage Window:** < 15 minutes.
   - **Lead Responders:** Booking Operations Executive.
   - **Actions:** Alternative nearby vehicle re-allocation, customer taxi credit voucher dispatch, vendor SLA penalty imposition.


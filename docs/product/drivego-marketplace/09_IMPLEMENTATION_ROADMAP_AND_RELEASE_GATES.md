# DriveGo Self-Drive Mobility Marketplace — Implementation Roadmap & Release Gates

**Document Reference:** `ROADMAP-REL-09`  
**Version:** 2.0.0-PROD  
**Author:** DriveGo Principal Software Architect & Release Manager  
**Scope:** Engineering Phases, Critical Path, and Pre-Release Kill-Gates  
**Status:** Approved for Implementation

---

## 1. Prioritized Implementation Roadmap

```mermaid
gantt
    title DriveGo Marketplace Engineering Roadmap
    dateFormat  YYYY-MM-DD
    section Phase P0 Launch Blockers
    P0-A: Baseline Audit & Specifications         :done, p0a, 2026-10-25, 2026-10-27
    P0-B: Vendor Blockers (Photos, Publishing, Deposit) :active, p0b, 2026-10-28, 2026-10-29
    P0-C: Location Model & Operating Yards         :active, p0c, 2026-10-29, 2026-10-30
    P0-D: Vendor-to-Admin Workflow Reconciliation  :p0d, 2026-10-30, 2026-10-31
    section Phase P1 Post-Launch 30-90 Days
    P1-A: Consolidated Admin Operations Console    :p1a, 2026-11-01, 2026-11-10
    P1-B: Multi-Scope Campaign & Discount Engine   :p1b, 2026-11-11, 2026-11-20
    P1-C: Payment Gateway Live Reconciliation     :p1c, 2026-11-21, 2026-11-30
    section Phase P2 Scale & Optimization
    P2-A: IoT Telematics & OBD-II Integration     :p2a, 2026-12-01, 2026-12-20
    P2-B: Dynamic Demand-Based Surge Pricing       :p2b, 2026-12-21, 2027-01-10
```

---

## 2. Release Gates & Production Kill-Criteria

Before publishing the Customer or Vendor applications to Google Play Store and Apple App Store, the release engineering team must sign off on the following 6 Mandatory Kill-Gates:

| Gate ID | Gate Name | Requirement for Sign-Off | Severity |
|:---|:---|:---|:---:|
| **GATE-01** | Zero Stock Vehicle Photos | No mock URLs in `add_edit_car_page.dart`. Real device photo picker captures authentic photos and uploads to object storage. | **CRITICAL (P0)** |
| **GATE-02** | Explicit Publishing Lifecycle | Vehicle publishing never hangs in an infinite spinner. Enforces 15s timeout with explicit status transitions (`DRAFT`, `PENDING_VERIFICATION`, `VERIFIED`, `ACTIVE`). | **CRITICAL (P0)** |
| **GATE-03** | Authoritative Deposit Policy | Super Admin controls deposit policy; vendor fetches exact backend amount; no silent ₹25,000 fallback; HMAC SHA256 verification active. | **CRITICAL (P0)** |
| **GATE-04** | Vendor Operating Yards | Elimination of fictional preset hubs ("Main Hub"). Vendors register real operating yards within enabled cities; vehicle-to-hub binding validated. | **CRITICAL (P0)** |
| **GATE-05** | Maker-Checker Payout Control | Financial payouts > ₹50,000 enforce dual authorization. Approver cannot be executor. | **CRITICAL (P0)** |
| **GATE-06** | DPDP Act 2025 Erasure Compliance | Customer personal data anonymized upon verified request while retaining 7-year double-entry financial ledger records. | **CRITICAL (P0)** |


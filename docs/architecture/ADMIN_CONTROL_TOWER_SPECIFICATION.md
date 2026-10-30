# DRIVEGO — ADMIN CONTROL TOWER SPECIFICATION
## Operations Mission Control, Metric Formulations, Role Scope & Workflow Inventories

> **Document Reference**: `docs/architecture/ADMIN_CONTROL_TOWER_SPECIFICATION.md`  
> **Classification**: Authoritative Operations Specification  
> **Status**: APPROVED — PRODUCTION BLUEPRINT  
> **Author**: DriveGo Product & Operations Architecture Group  

---

## 1. CONTROL TOWER ARCHITECTURE & PURPOSE

The DriveGo Admin Panel (`apps/admin_panel`) serves as the central command tower for platform operations, financial management, fleet oversight, and regulatory governance.

It is structured into 6 specialized operational modules:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         ADMIN CONTROL TOWER ARCHITECTURE                         │
├──────────────────────────┬───────────────────────────────────────────────────────┤
│ 1. Executive Overview    │ Real-time marketplace KPIs, financial revenue source, │
│                          │ operational backlogs, reconciliation exceptions.      │
├──────────────────────────┼───────────────────────────────────────────────────────┤
│ 2. Vendor Management     │ 13-stage lifecycle, document verification queue,      │
│                          │ tier deposits, rolling reserve, weekly payouts.       │
├──────────────────────────┼───────────────────────────────────────────────────────┤
│ 3. Fleet & Telematics    │ AIS-140 GPS tracking, remote immobilizer emergency    │
│                          │ control, geofence breaches, maintenance scheduling.   │
├──────────────────────────┼───────────────────────────────────────────────────────┤
│ 4. Customer Control      │ Verification status, booking timeline, collateral     │
│                          │ auditing, support disputes, DPDP data requests.       │
├──────────────────────────┼───────────────────────────────────────────────────────┤
│ 5. Damage & Disputes     │ Pre- vs post-trip photo inspection diff, multi-sig    │
│                          │ adjudication tribunal, escrow deduction settlements.  │
├──────────────────────────┼───────────────────────────────────────────────────────┤
│ 6. Omnichannel Hub       │ Multi-channel dispatching, DLT template auditor,      │
│                          │ delivery telemetry, failover circuit breaker.         │
└──────────────────────────┴───────────────────────────────────────────────────────┘
```

---

## 2. METRIC FORMULATIONS & FINANCIAL DEFINITIONS

To guarantee auditability and eliminate misleading metrics, every KPI displayed in the Admin Dashboard is tied to an explicit calculation source:

| Metric Name | Authoritative Formula | Data Source Table | Financial Meaning |
|---|---|---|---|
| **Gross Booking Value (GBV)** | $\sum (\text{totalFare})$ for all confirmed & completed bookings | `Booking` | Total gross transaction volume processed on platform. |
| **Completed Booking Revenue** | $\sum (\text{platformFee} + \text{protectionFee} + \text{convenienceFee})$ | `Booking` ($\text{COMPLETED}$) | DriveGo's actual gross platform revenue. |
| **Vendor Payable Balance** | $\sum (\text{netToVendor}) - \text{RollingReserve} - \text{DisbursedPayouts}$ | `Vendor`, `PlatformLedgerEntry` | Net earnings owed to vendors awaiting scheduled payout. |
| **Vendor Rolling Reserve** | $10\% \times \text{GrossVendorEarnings}$ held for 30 rolling days | `VendorSecurityDeposit` | Reserve retained against delayed traffic challans and tolls. |
| **Security Deposits Held** | $\sum (\text{amount} - \text{deductedAmount} - \text{refundedAmount})$ | `SecurityDeposit` ($\text{HELD}$) | Active escrow liabilities belonging to customers. |
| **Refunds Issued** | $\sum (\text{refundedAmount})$ | `PaymentRefund`, `SecurityDeposit` | Total monetary capital returned to customers. |
| **Actual Cash Received** | $\text{GrossPaymentsCaptured} - \text{GatewayFees} - \text{RefundsIssued}$ | `PlatformLedgerEntry` | Actual liquid cash balance in corporate accounts. |

---

## 3. OPERATIONAL WORKFLOWS & RBAC BOUNDARIES

### 3.1 Module 1: Vendor Management & Verification Review
- **Search & Filter**: Query by business name, GSTIN, city, tier, and compliance status.
- **Verification Review Drawer**: Multi-tab interface displaying Aadhaar XML status, PAN validation response, GSTIN status, and yard audit reports.
- **Decision Engine**: Reviewers can `APPROVE`, `REJECT` (with mandatory reason code), or `REQUEST_ADDITIONAL_INFO`.
- **Financial Terms Configuration**: Custom commission rate (default 15%), tier deposit requirement, and rolling reserve toggle.

### 3.2 Module 2: Fleet & Telematics Administration
- **Telemetry Live Map**: Real-time rendering of active rental vehicles via AIS-140 GPS pings.
- **Speed Governor Audit**: Automatic listing of speed violations ($> 80\text{ km/h}$ or $> 100\text{ km/h}$).
- **Emergency Remote Immobilizer**:
  - Protected by secondary administrative confirmation (`ADMIN` role only).
  - Safety check: Precondition verifies vehicle speed is $< 5\text{ km/h}$ before dispatching CAN-bus immobilizer signal to avoid high-speed road incidents.

### 3.3 Module 3: Customer Escrow & Collateral Auditing
- Real-time audit of all held customer deposits across all four collateral types:
  1. `MONETARY_ONLINE`: Razorpay payment reference, escrow account balance.
  2. `PHYSICAL_VEHICLE`: Operating yard identifier, bay slot number, key custody acknowledgement.
  3. `ORIGINAL_DOCUMENT`: Masked serial number, safe vault locker number.
  4. `DIGILOCKER_HIGH_TRUST`: DigiLocker verification hash, trust score badge.

### 3.4 Module 4: Damage & Dispute Tribunal
- Dedicated multi-tier adjudication workflow:
  - Low-severity claims ($\le \text{₹5,000}$): Adjudicated by Customer Support Agent.
  - Mid-severity claims ($\text{₹5,001}$ to $\text{₹25,000}$): Adjudicated by Operations Manager.
  - High-severity claims ($> \text{₹25,000}$): Adjudicated by Executive Tribunal with dual signature.
- Visual inspection diff side-by-side: 8-angle pre-trip photos vs 8-angle post-trip photos with EXIF timestamp and GPS watermarking.

---
*Ratified by DriveGo Product & Operations Architecture Group.*


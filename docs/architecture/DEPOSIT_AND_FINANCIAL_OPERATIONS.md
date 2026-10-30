# DRIVEGO — DEPOSIT & FINANCIAL OPERATIONS SPECIFICATION
## Policy Engine Hierarchy, Customer Collateral Models, Double-Entry Ledger & Vendor Settlements

> **Document Reference**: `docs/architecture/DEPOSIT_AND_FINANCIAL_OPERATIONS.md`  
> **Classification**: Authoritative Financial Systems Architecture  
> **Status**: APPROVED — PRODUCTION BLUEPRINT  
> **Author**: DriveGo FinTech & Financial Governance Council  

---

## 1. THE SINGLE DEPOSIT POLICY ENGINE HIERARCHY

To ensure platform-wide safety while accommodating diverse vehicle categories and regional operating hubs, deposit requirements are evaluated through a strict 5-tier policy hierarchy:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   DEPOSIT POLICY EVALUATION HIERARCHY                  │
├────────────────────────────────────────────────────────────────────────┤
│ 1. PLATFORM MANDATORY COMPLIANCE LIMITS (Highest Authority)             │
│    • Hard floor: Minimum deposit cannot be below statutory limits.     │
│    • Hard ceiling: Maximum deposit capped for consumer protection.     │
├────────────────────────────────────────────────────────────────────────┤
│ 2. PLATFORM COMMERCIAL DEFAULTS                                        │
│    • Category rules: Hatchback ₹3k, Sedan ₹5k, SUV ₹10k, Luxury ₹25k.  │
├────────────────────────────────────────────────────────────────────────┤
│ 3. VENDOR-SPECIFIC POLICY                                              │
│    • Approved customized deposit rules assigned to specific fleets.     │
├────────────────────────────────────────────────────────────────────────┤
│ 4. VEHICLE-SPECIFIC POLICY                                             │
│    • Overrides for specialized high-value vehicles (e.g. BMW, EV).     │
├────────────────────────────────────────────────────────────────────────┤
│ 5. BOOKING-SPECIFIC POLICY SNAPSHOT (Immutable Execution)              │
│    • Frozen at checkout. Cannot be mutated by subsequent rule updates. │
└────────────────────────────────────────────────────────────────────────┘
```

> **Evaluation Invariant**: A lower-tier policy can *never* override a higher-tier mandatory compliance restriction. If a vendor attempts to set a ₹0 deposit for a vehicle category where platform policy mandates ₹5,000, the platform mandatory floor automatically takes precedence.

---

## 2. THE TRI-OPTION CUSTOMER COLLATERAL ARCHITECTURE

DriveGo solves the industry dilemma between conversion drop-off from high cash deposits and the risk of vehicle theft/abandonment by providing customers with three flexible security options:

```
┌────────────────────────────────────────────────────────────────────────┐
│             CUSTOMER SECURITY DEPOSIT & COLLATERAL MODEL               │
├────────────────────┬────────────────────┬──────────────────────────────┤
│ OPTION A: MONETARY │ OPTION B: VEHICLE  │ OPTION C: ORIGINAL DOCUMENT  │
│ ONLINE DEPOSIT     │ COLLATERAL (YARD)  │ COLLATERAL (VAULT)           │
├────────────────────┼────────────────────┼──────────────────────────────┤
│ • INR 3,000–10,000 │ • Customer leaves  │ • Customer deposits physical │
│   held via gateway │   secondary bike   │   Passport, Voter ID, or hard│
│ • Pre-auth capture │   or car in yard   │   copy Aadhaar in yard vault │
│ • Auto-refunded    │ • Key surrendered  │ • Secure fire-rated safe     │
│   24h post-trip    │ • Yard token issued│ • Handed back on return      │
└────────────────────┴────────────────────┴──────────────────────────────┘
```

### 2.1 Option A: Monetary Online Deposit
- Captured via Razorpay during checkout.
- Credited to DriveGo's isolated Customer Escrow Account.
- **Automated 24-Hour Release Worker**: An hourly background cron queries completed bookings:
  $$\text{Release Trigger: } \text{Status} = \text{COMPLETED} \land \text{CompletionAge} \ge 24\text{ hours} \land \text{DamageClaims} = 0$$
- Triggers an automated gateway refund and posts matching balancing journal entries.

### 2.2 Option B: Physical Secondary Vehicle Collateral
- Ideal for customers commuting to the pickup yard on their two-wheeler or secondary personal car.
- **Yard Verification SOP**:
  1. Attendant inspects physical Registration Certificate (RC) copy matching customer identity.
  2. Attendant logs registration plate, odometer, fuel level, and captures 4-angle condition photos.
  3. Customer hands over vehicle keys to the Yard Attendant.
  4. Vehicle parked in designated secure yard bay (e.g. `BAY-08`).
  5. Attendant records details in Vendor App. Backend sets `deposit.razorpayPaymentId = 'COLLATERAL:PHYSICAL_VEHICLE:KA-01-AB-1234'`, transitions deposit status to `HELD`, and issues a digital Custody Receipt.
- **Return Handover**: Keys and vehicle returned to customer upon safe return of the rental car. The vendor marks `Release Collateral` in the app; the deposit transitions to `REFUNDED` with zero payment gateway fees.

### 2.3 Option C: Original Physical Document Collateral / DigiLocker High-Trust
- **Original Document Vault Custody**:
  - Customer deposits an original physical document (Passport, Voter ID Card, or hardcopy original Aadhaar Card) into the yard's fire-rated safe vault.
  - Attendant logs document type, masked document number (e.g. `PASSPORT_Z1234567`), and vault locker number (e.g. `SAFE-04`).
  - Custody receipt dispatched to customer; returned upon rental return.
- **DigiLocker High-Trust Zero-Deposit**:
  - Customers with a verified DigiLocker profile and platform Trust Score $> 85$ qualify for **Zero Security Deposit**.

---

## 3. DEPOSIT STATE MACHINE & MUTATION INVARIANTS

```
            ┌─────────────────┐
            │    REQUIRED     │
            └────────┬────────┘
                     │ [Online Payment Captured OR
                     │  Physical Collateral Recorded]
                     ▼
            ┌─────────────────┐
            │      HELD       │
            └────┬───────┬────┘
                 │       │
    [Zero Damage │       │ [Damage Claim Approved]
     Post-Trip]  │       ▼
                 │ ┌────────────────────┐
                 │ │ PARTIALLY_REFUNDED │
                 ▼ └────────────────────┘
       ┌──────────┐      │
       │ REFUNDED │ <────┘ [Remaining Escrow Released]
       └──────────┘
```

Every transition requires:
- Authorized actor verification (`ADMIN` or assigned `VENDOR`).
- Precondition validation (e.g., pre-trip inspection completed).
- Idempotent compare-and-swap update (`WHERE status = 'HELD'`).
- Audit log entry and customer notification.

---

## 4. FINANCIAL CONTROL, DOUBLE-ENTRY LEDGER & SETTLEMENTS

### 4.1 Strict Separation of Financial Accounts
DriveGo strictly segregates all monetary categories in its double-entry ledger:
- **`CUSTOMER_PAYMENTS`**: Total gross funds received from customers.
- **`CUSTOMER_DEPOSIT_ESCROW`**: Refundable deposits held in trust.
- **`PLATFORM_COMMISSION_REVENUE`**: DriveGo's earned platform commission.
- **`VENDOR_PAYABLES`**: Net rental proceeds owed to fleet owners.
- **`VENDOR_ROLLING_RESERVE`**: 10% reserve held for 30 days against traffic challans and tolls.
- **`GATEWAY_CLEARING`**: Funds in transit with payment gateways (Razorpay).

### 4.2 Double-Entry Journal Invariants
Every financial transaction is recorded via immutable journal entries where total debits strictly equal total credits ($\sum \text{Debits} = \sum \text{Credits}$):

```
Booking Confirmation Journal (Total Fare ₹10,000 + Security Deposit ₹5,000):
  DEBIT   GATEWAY_CLEARING (Razorpay)             ₹15,000
  CREDIT  CUSTOMER_DEPOSIT_ESCROW (Customer)      ₹5,000
  CREDIT  PLATFORM_COMMISSION_REVENUE (DriveGo)   ₹1,500
  CREDIT  VENDOR_PAYABLES (Vendor Partner)        ₹8,500
```

### 4.3 Vendor Payout Disbursement & Maker-Checker Controls
1. **Weekly Disbursement Schedule**: Batch payouts execute every Tuesday at 02:00 AM IST via RazorpayX (IMPS/NEFT).
2. **Maker-Checker Security Control**:
   - Payouts $< \text{₹50,000}$: Automated system dispatch following ledger balance verification.
   - Payouts $\ge \text{₹50,000}$: Queued in the Admin Finance Portal requiring dual-authorization (Operations Lead submits, Head of Finance approves).

---
*Ratified by DriveGo FinTech & Financial Governance Council.*


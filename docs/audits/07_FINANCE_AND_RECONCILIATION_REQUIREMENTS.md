# DRIVEGO — FINANCE, TREASURY, AND RECONCILIATION REQUIREMENTS

**Document ID:** `DRV-FIN-2026-007`  
**Version:** 1.0.0  
**Effective Date:** October 29, 2026  
**Implementation Codebase:** `car_rental_backend/src/payments`, `wallets`, `admin/admin-revenue.service.ts`

---

## 1. Commercial Marketplace Financial Model

DriveGo operates under an Indian **intermediary technology platform model**. DriveGo is not the car-owner or primary transport provider, but rather the facilitation agent connecting Host Fleet Operators with Renters:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CUSTOMER TOTAL FARE BREAKDOWN                   │
├────────────────────────────────┬───────────────────────────────────────┤
│ Base Rental Fee                │ Set by Vendor / Pricing Engine        │
│ (+) Platform Fee (Convenience) │ DriveGo Service Margin                │
│ (+) Damage Protection Package  │ Selected Renter Protection Level      │
│ (+) GST on Services            │ 18% on Platform Fee & Protection      │
│ (+) Refundable Security Deposit│ Escrowed (100% Refundable Post-Trip)  │
├────────────────────────────────┼───────────────────────────────────────┤
│ TOTAL CAPTURED FROM CUSTOMER   │ Captured via Razorpay / UPI / Cards   │
└────────────────────────────────┴───────────────────────────────────────┘
```

---

## 2. Double-Entry General Ledger Chart of Accounts

To preserve financial integrity and guarantee zero unallocated funds, every movement of capital is tracked via double-entry journal entries:

```
Account Code | Account Name              | Account Type | Normal Balance
-------------|---------------------------|--------------|---------------
1010         | Razorpay Clearing Account | Asset        | Debit
1020         | Cashfree Payout Bank Acc  | Asset        | Debit
2010         | Customer Security Escrow  | Liability    | Credit
2020         | Vendor Payable (Earnings) | Liability    | Credit
2030         | GST Collected Payable     | Liability    | Credit
2040         | TDS Payable to Govt       | Liability    | Credit
4010         | Marketplace Commission    | Revenue      | Credit
4020         | Protection Package Margin | Revenue      | Credit
5010         | Payment Gateway Fees      | Expense      | Debit
```

### Invariant Equation:
$$\sum \text{Debits} \equiv \sum \text{Credits}$$

Direct administrative mutations of wallet or account balances are strictly forbidden in code. Every adjustment must execute via an authorized `FinancialAdjustment` record with supporting audit notes.

---

## 3. Payment Gateway Webhook Idempotency & Reconciliation

1. **HMAC Signature Verification:**
   - Every Razorpay webhook payload is validated against `RAZORPAY_WEBHOOK_SECRET` using `crypto.createHmac('sha256')`.
   - Invalid signatures fail closed with HTTP 400 Bad Request.
2. **Idempotency Keys & Deduplication:**
   - Database enforces `@unique` constraint on `Payment.providerPaymentId`.
   - Duplicate webhook deliveries return HTTP 200 OK without double-crediting balances.
3. **Daily Gateway Settlement Reconciliation (`ReconciliationService`):**
   - Automatically compares Razorpay MIS settlement dumps against local database `Payment` records.
   - Flags 3 classes of reconciliation exceptions:
     - `UNMATCHED_CHARGE`: Present in bank settlement but missing in internal database.
     - `UNMATCHED_REFUND`: Refund executed via gateway dashboard without internal booking link.
     - `FEE_DISCREPANCY`: Gateway transaction fee deviates from contractual rate (>0.1%).


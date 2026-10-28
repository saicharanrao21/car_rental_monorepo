# DriveGo — Payment Provider Portability & Financial Audit (Phase 6)

**Audit Execution Date:** October 28, 2026  
**Auditor:** Payment Systems Architect & Financial Engineering Lead  
**Scope:** Payment Gateway Adapters, Webhooks, RazorpayX Payouts, Ledger Invariants, and Refunds  

---

## 1. Gateway Architecture & Provider Neutrality Analysis

### A. Current Gateway Reality
DriveGo operates on a dual-layer payment architecture:
1. **Primary Operational Gateway:** **Razorpay** is the actively wired payment gateway used for customer checkout, order generation, webhook signature validation, and automated host payouts (RazorpayX).
2. **Pluggable Adapter Layer:** An enterprise payment adapter framework located in `car_rental_backend/src/integrations/adapters/payments/` provides **47 concrete gateway adapters** (including Cashfree, PhonePe, Paytm, Stripe, CCAvenue, BillDesk, Adyen, and PayPal).

### B. Canonical Payment State Machine
Regardless of the gateway chosen, DriveGo maps external gateway transactions into a strict canonical payment state model:
```
             [INITIATED]
                  |
         +--------+--------+
         |                 |
     (Capture)          (Drop)
         v                 v
      [PAID]           [FAILED]
         |
    (Cancellation)
         v
    [REFUND_PENDING]
         |
    (Gateway Ack)
         v
     [REFUNDED] / [PARTIALLY_REFUNDED]
```

---

## 2. Gateway Capability & Verification Matrix

| Payment Gateway | Adapter Path | Order Creation | Webhook Verification | Refund Support | Sandbox Verified | Production Key Available | Current Production Status |
|---|---|---|---|---|---|---|---|
| **Razorpay (Primary)** | `adapters/payments/razorpay.adapter.ts` | Yes | Yes (HMAC-SHA256) | Full & Partial | **PASS (Mock/Sandbox)** | Pending KYC | **READY (MOCK / SANDBOX)** |
| **Cashfree** | `adapters/payments/cashfree.adapter.ts` | Yes | Yes (HMAC-SHA256) | Supported | **PASS (Signature Spec)** | Not Configured | **ADAPTER READY** |
| **PhonePe** | `adapters/payments/phonepe.adapter.ts` | Yes | Yes (SHA256 Base64) | Supported | **PASS (Signature Spec)** | Not Configured | **ADAPTER READY** |
| **Paytm** | `adapters/payments/paytm.adapter.ts` | Yes | Yes (Checksum) | Supported | **PASS (Signature Spec)** | Not Configured | **ADAPTER READY** |
| **Stripe (Global & India)** | `adapters/payments/stripe.adapter.ts` | Yes | Yes (Stripe-Signature) | Supported | **PASS (Signature Spec)** | Not Configured | **ADAPTER READY** |
| **CCAvenue** | `adapters/payments/ccavenue.adapter.ts` | Yes | Yes (AES decrypt) | Supported | **PASS (Signature Spec)** | Not Configured | **ADAPTER READY** |
| **BillDesk** | `adapters/payments/billdesk.adapter.ts` | Yes | Yes (HMAC-SHA256) | Supported | **PASS (Signature Spec)** | Not Configured | **ADAPTER READY** |

---

## 3. Webhook Signature Security & Idempotency Audit

### A. Webhook Signature Verification
- In `PaymentsController.handleWebhook`:
  - Enforces `x-razorpay-signature` HTTP header.
  - Requires raw body ingestion via Express `bodyParser: false` and `json({ verify: ... req.rawBody })`.
  - Reconstructs cryptographic HMAC using `crypto.createHmac('sha256', secret).update(rawBody).digest('hex')`.
  - Rejects tampering with `400 Bad Request`.
- **Evidence:** Tested in `app.e2e-spec.ts`:
  - `POST /payments/webhook rejects request without signature with 400 Bad Request` -> **PASSED**
  - `POST /payments/webhook rejects forged signature with 400 Bad Request` -> **PASSED**
  - `POST /payments/webhook processes valid signature through HTTP pipeline with 200/201` -> **PASSED**

### B. Webhook Replay & Duplicate Event Guarding
- Payments store a unique `razorpayPaymentId` index.
- If a webhook event has already transitioned a booking to `CONFIRMED` and payment to `PAID`, replayed webhooks detect the existing status, log an idempotent audit trace, and return `200 OK` without creating duplicate credits or balance adjustments.

---

## 4. Financial Ledger Integrity & Invariant Evidence

Platform financial transactions are recorded as double-entry ledger items in `PlatformLedgerEntry`:
- **Ledger Invariant Verification:**
  - Automated drill (`dr:drill`) verifies:
    $$\sum \text{Debits} == \sum \text{Credits}$$
  - Baseline execution: **Total Debits: ₹9,801.20 == Total Credits: ₹9,801.20**.
  - Orphan checks: 0 orphan bookings, 0 orphan cars, 0 orphan payments.
- **Circuit Breaker Protection:** Outbound payment providers incorporate an automated circuit breaker (`CircuitBreakerService`) that trips to `OPEN` if 5 consecutive gateway timeouts occur within 60 seconds, preventing cascading connection pool exhaustion.

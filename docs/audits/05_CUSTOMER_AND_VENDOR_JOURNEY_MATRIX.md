# DRIVEGO — CUSTOMER AND VENDOR JOURNEY MATRIX & LIFECYCLE AUDIT

**Document ID:** `DRV-JRN-2026-005`  
**Version:** 1.0.0  
**Effective Date:** October 29, 2026  
**Evaluation Scope:** Customer Mobile App (`apps/customer_app`), Vendor Partner App (`apps/vendor_app`), Backend Services

---

## 1. Complete Customer Journey (Renter Lifecycle)

```mermaid
sequenceDiagram
    autonumber
    actor C as Customer
    participant App as Customer Flutter App
    participant API as NestJS Backend API
    participant R as Redis Distributed Lock
    participant PG as PostgreSQL Database
    participant PGW as Razorpay Payment Gateway
    actor V as Vendor Partner

    Note over C,App: 1. DISCOVERY & AUTHENTICATION
    C->>App: Launch App & Enter Phone Number
    App->>API: POST /auth/send-otp
    API-->>App: 200 OK (OTP sent via MSG91/Twilio)
    C->>App: Enter 6-digit OTP
    App->>API: POST /auth/verify-otp
    API-->>App: Return JWT Access & Refresh Token

    Note over C,App: 2. VEHICLE SEARCH & 15-MIN QUOTE LOCK
    C->>App: Select City, Dates & Vehicle Model
    App->>API: GET /marketplace/search
    API-->>App: List available vetted cars
    C->>App: Tap "Book Now"
    App->>API: POST /bookings/quote
    API->>R: Acquire Distributed Lock (15-min TTL)
    API-->>App: Itemized Quote (Rental + Deposit + Protection + GST)

    Note over C,PGW: 3. PAYMENT & ESCROW SECURING
    C->>App: Pay via UPI / Card / NetBanking
    App->>API: POST /payments/order
    API->>PGW: Create Razorpay Order
    PGW-->>App: Open Razorpay Checkout SDK
    C->>PGW: Authorize Payment
    PGW->>API: POST /payments/webhook (Signature Verified)
    API->>PG: Record Payment & Transition Booking to CONFIRMED
    API->>R: Release Quote Lock; Mark Car UNAVAILABLE for Dates

    Note over C,V: 4. VEHICLE HANDOVER & OTP VERIFICATION
    C->>V: Arrive at Operating Yard / Delivery Address
    V->>API: Upload 5 Pre-trip Photos (Odometer, Fuel, Exterior)
    V->>C: Request 6-digit Handover OTP
    C->>V: Provide Handover OTP from Customer App
    V->>API: POST /bookings/:id/handover/verify-otp
    API->>PG: Transition Booking to ACTIVE
    API-->>C: WhatsApp & Push: "Trip Started! Drive Safely."

    Note over C,V: 5. TRIP RETURN & DEPOSIT SETTLEMENT
    C->>V: Return Vehicle at Agreed Yard
    V->>API: Upload Return Photos & Check Odometer
    V->>API: Confirm "No Damage" Handover
    API->>PG: Transition Booking to COMPLETED
    API->>PGW: Initiate Automated Full Security Deposit Refund
    API-->>C: Dispatch Final Tax Invoice PDF
```

---

## 2. Complete Vendor Journey (Host Lifecycle)

```
┌────────────────────────────────────────────────────────────────────────┐
│                   VENDOR LIFECYCLE STAGES & AUDIT                      │
├──────┬──────────────────────┬──────────────────────────────────────────┤
│ Step │ Stage Name           │ Implemented Mechanism & Evidence         │
├──────┼──────────────────────┼──────────────────────────────────────────┤
│ 1    │ Host Registration    │ Phone OTP verification in Vendor Mobile  │
│      │                      │ App (`apps/vendor_app`).                 │
├──────┼──────────────────────┼──────────────────────────────────────────┤
│ 2    │ Business KYC & GST   │ Document upload (Aadhaar, PAN, GST)      │
│      │                      │ reviewed in Admin Onboarding Console.    │
├──────┼──────────────────────┼──────────────────────────────────────────┤
│ 3    │ Fleet Onboarding     │ Vehicle RC, Commercial Permit, Insurance │
│      │                      │ validity verified; yard assignment.      │
├──────┼──────────────────────┼──────────────────────────────────────────┤
│ 4    │ Security Deposit     │ Host refundable security deposit order   │
│      │ Escrow               │ created and tracked in separate ledger.  │
├──────┼──────────────────────┼──────────────────────────────────────────┤
│ 5    │ Booking Fulfillment  │ Real-time WhatsApp + Push alert; Accept  │
│      │                      │ booking; Handover inspection completion. │
├──────┼──────────────────────┼──────────────────────────────────────────┤
│ 6    │ Return Inspection &  │ Visual condition check; Damage claim     │
│      │ Dispute Intake       │ intake with repair estimate attachment.  │
├──────┼──────────────────────┼──────────────────────────────────────────┤
│ 7    │ Weekly Settlement &  │ Automated net earnings calculation:      │
│      │ Payout Disbursal     │ `Gross - Platform Fee - TDS = Net Payout`│
└──────┴──────────────────────┴──────────────────────────────────────────┘
```

---

## 3. Operational Exception Pathways

1. **Customer No-Show / Late Cancellation:**
   - If customer cancels > 24h prior: 100% refund of rental fee + 100% security deposit.
   - If customer cancels < 24h prior: 1 day rental fee withheld as cancellation charge; balance + deposit refunded.
   - Ledger records cancellation transaction with transparent breakdown.
2. **Vehicle Breakdown / Accident En Route:**
   - Customer taps SOS in app -> Emergency alert broadcast to Operations Control Tower.
   - Operations allocates replacement car or books intercity cab.
   - Trip paused; unutilized rental hours refunded to customer wallet.
3. **Overdue Vehicle Return:**
   - Automated sweep cron (`job_overdue_scan`) scans bookings past return deadline.
   - Automatic WhatsApp alert dispatched to customer with hourly late fee warning.
   - If overdue > 4 hours without contact, vehicle engine immobilized via telematics (where equipped) and incident escalated to Recovery Team.


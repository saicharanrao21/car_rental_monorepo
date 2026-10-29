# DriveGo Self-Drive Mobility Marketplace — Technical Requirements Document (TRD)

**Document Reference:** `TRD-MKT-02`  
**Version:** 2.0.0-PROD  
**Author:** DriveGo Principal Software Architect & NestJS/Flutter Leads  
**Scope:** Architecture, Data Flow, Sequence Diagrams, State Machines, Concurrency, and Security  
**Status:** Approved for Implementation

---

## 1. System Architecture & Context

The DriveGo platform is structured as a modular distributed monolith in NestJS backed by PostgreSQL (Prisma ORM) and Redis, serving two Flutter mobile clients and a Flutter Web Control Tower.

```mermaid
graph TD
    subgraph Clients
        CA["Customer Mobile App (Flutter)"]
        VA["Vendor Mobile App (Flutter)"]
        AP["Admin Control Tower (Flutter Web)"]
    end

    subgraph API_Gateway["NestJS API Gateway & Services"]
        AUTH["Auth & Permissions Guard (JWT / RBAC)"]
        FLT["Fleet & Verification Service"]
        LOC["Locations & Pickup Hubs Service"]
        DEP["Vendor Deposit & Razorpay Service"]
        PROM["Promotions & Campaign Engine"]
        BOOK["Bookings & Escrow Service"]
        UPL["Presigned Upload Service"]
    end

    subgraph Infrastructure
        PG[("PostgreSQL Database (Prisma)")]
        RD[("Redis (Cache & Locks)")]
        S3[("Object Storage (S3 / R2)")]
        RZP["Razorpay Payment Gateway"]
    end

    CA -->|HTTPS REST| AUTH
    VA -->|HTTPS REST| AUTH
    AP -->|HTTPS REST| AUTH

    AUTH --> FLT
    AUTH --> LOC
    AUTH --> DEP
    AUTH --> PROM
    AUTH --> BOOK
    AUTH --> UPL

    FLT --> PG
    LOC --> PG
    DEP --> PG
    DEP --> RZP
    BOOK --> PG
    BOOK --> RD
    UPL --> S3
```

---

## 2. Core State Machines

### 2.1 Vehicle Operational & Verification Lifecycle

```mermaid
stateDiagram-v2
    [*] --> DRAFT : Vendor creates listing
    DRAFT --> PENDING_VERIFICATION : Vendor submits for review (photos + docs attached)
    PENDING_VERIFICATION --> REJECTED : Admin rejects with reason
    REJECTED --> DRAFT : Vendor remedies issues
    PENDING_VERIFICATION --> VERIFIED : Admin approves vehicle
    VERIFIED --> ACTIVE : Vendor activates for bookings
    ACTIVE --> ON_TRIP : Customer starts rental
    ON_TRIP --> ACTIVE : Vehicle returned & inspected
    ACTIVE --> MAINTENANCE : Odometer / defect block
    MAINTENANCE --> ACTIVE : Inspection cleared
    ACTIVE --> SUSPENDED : Admin compliance hold
    SUSPENDED --> ACTIVE : Compliance restored
    ACTIVE --> RETIRED : Vehicle decommissioned
```

### 2.2 Vendor Security Deposit Lifecycle

```mermaid
stateDiagram-v2
    [*] --> PENDING_PAYMENT : Active policy requires deposit
    [*] --> EXEMPTED : Super Admin grants exemption
    PENDING_PAYMENT --> ORDER_CREATED : Razorpay order generated
    ORDER_CREATED --> PAYMENT_FAILED : Signature invalid / user canceled
    PAYMENT_FAILED --> ORDER_CREATED : Retry payment
    ORDER_CREATED --> PAID : HMAC SHA256 verified & Ledger recorded
    PAID --> HELD_IN_ESCROW : Active vendor partnership
    HELD_IN_ESCROW --> REFUND_REQUESTED : Vendor contract termination
    REFUND_REQUESTED --> REFUNDED : Admin clears liabilities & executes refund
```

---

## 3. End-to-End Sequence Diagrams

### 3.1 Vehicle Creation, Photo Upload & Verification Submission

```mermaid
sequenceDiagram
    autonumber
    actor V as Vendor
    participant VA as Vendor App
    participant BE as NestJS Backend
    participant S3 as Object Storage (S3/R2)
    participant DB as PostgreSQL (Prisma)

    V->>VA: Tap "Add Vehicle"
    VA->>V: Prompt photo selection (Camera / Gallery)
    V->>VA: Selects real photos
    loop For each photo
        VA->>BE: POST /uploads/presign (fileType: 'car-photo')
        BE-->>VA: Return presigned uploadUrl & publicUrl
        VA->>S3: Binary PUT file bytes to uploadUrl
        S3-->>VA: 200 OK (Image stored)
    end
    V->>VA: Select operating yard (pickupHubId) & set pricing
    V->>VA: Tap "Publish / Submit Vehicle"
    VA->>BE: POST /vendor/fleet (CreateCarDto with photos & pickupHubId)
    BE->>DB: Check duplicate registration plate
    BE->>DB: Validate pickupHubId ownership by vendor
    BE->>DB: INSERT into Car (status: DRAFT, verification: PENDING)
    BE-->>VA: 201 Created (Car details)
    VA->>V: Display "Submitted for Review" (No stuck spinner)
```

### 3.2 Authoritative Vendor Deposit Policy & Verification

```mermaid
sequenceDiagram
    autonumber
    actor A as Super Admin
    actor V as Vendor
    participant AP as Admin Panel
    participant VA as Vendor App
    participant BE as NestJS Backend
    participant RZP as Razorpay Gateway
    participant DB as PostgreSQL (Prisma)

    A->>AP: Configure Deposit (Amount: ₹15,000, 14 days, Refundable)
    AP->>BE: POST /admin/vendors/deposit/policy
    BE->>DB: Deactivate old policy & INSERT new VendorDepositPolicy (v2)
    BE-->>AP: 200 OK (Policy updated)
    
    V->>VA: Open Onboarding / Pending Approval
    VA->>BE: GET /vendors/me/onboarding/deposit
    BE->>DB: Query active policy & vendor deposit status
    BE-->>VA: Return exact policy amount (₹15,000, No fallback)
    VA->>V: Display exact ₹15,000 requirement
    
    V->>VA: Tap "Pay Security Deposit"
    VA->>BE: POST /vendors/me/onboarding/deposit/create-order
    BE->>RZP: Create Order (₹15,000 INR)
    RZP-->>BE: Order ID: order_live_123
    BE-->>VA: Order ID & Razorpay options
    VA->>RZP: Complete Checkout
    RZP-->>VA: razorpay_payment_id, signature
    VA->>BE: POST /vendors/me/onboarding/deposit/verify-payment
    BE->>BE: Verify HMAC SHA256 (order_id + payment_id)
    BE->>DB: Record VendorDepositPayment & Ledger Entry
    BE-->>VA: 200 OK (Status: PAID)
    VA->>V: Display "Security Deposit Satisfied"
```

---

## 4. Technical Concurrency & Data Integrity Strategy

1. **Transaction Boundaries:** Financial mutations (deposit payments, wallet deductions, payout approvals) execute strictly within `prisma.$transaction(async (tx) => ...)`.
2. **Idempotency:** Payment verification endpoints require unique `paymentId` keys. Replays are detected and return the cached success response without duplicate ledger entries.
3. **Optimistic Locking:** Vehicle booking reservations leverage Redis distributed locks (`redlock` on `carId:booking_dates`) to prevent double-booking across concurrent customer checkouts.
4. **Bounded Client Timeouts:** Mobile HTTP requests to fleet mutation endpoints enforce a 15-second timeout with explicit UI state recovery.


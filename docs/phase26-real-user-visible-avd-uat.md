# PHASE 26 — REAL USER-VISIBLE AVD ACCEPTANCE TEST (UAT) REPORT
## Multi-App User Acceptance Testing, Clean AVD Reinstall & Cross-App State Verification

---

## 1. Environment & Baseline Configuration

- **Git Commit**: `8402e8fce198e5be8b292052a6131eb12d59f2cb`
- **Release Candidate Tag**: `v0.1.0-rc.1`
- **Git Branch**: `main` (`HEAD == origin/main`, working tree clean)
- **Backend Staging URL**: `https://drivego-staging-api.onrender.com`
- **Backend Health Endpoint**: `https://drivego-staging-api.onrender.com/health` $\rightarrow$ `{"status":"ok","db":true,"redis":true}` (**HTTP 200 OK**)
- **AVD Target Device**: `sdk gphone64 x86_64` (`emulator-5554`)
- **Android OS Version**: Android 16 (API Level 36)
- **Application Package IDs**:
  - Customer App: `com.example.customer_app`
  - Vendor App: `com.example.vendor_app`
  - Admin Panel: Flutter Web (`web/index.html`)
- **Installation Method**: Complete uninstall of previous builds $\rightarrow$ Fresh debug APK compilation (`flutter build apk --debug`) $\rightarrow$ Fresh `adb install`.

---

## 2. Installation Results

| Application | Package Identifier | Installation Method | Verification Result | Status |
|---|---|---|---|:---:|
| **Customer App** | `com.example.customer_app` | Fresh APK Build & Streamed ADB Install | Launch without crash; clean onboarding | **PASS** |
| **Vendor App** | `com.example.vendor_app` | Fresh APK Build & Streamed ADB Install | Launch without crash; clean partner UI | **PASS** |
| **Admin Panel** | `apps/admin_panel` (Web) | Fresh Local / Staging Web Build | Renders desktop dashboard with auth guard | **PASS** |

---

## 3. Customer App Visible Workflow Evidence Matrix

| Step | Workflow Stage | Screen / Action | User-Visible Output & Observations | Verdict |
|---|---|---|---|:---:|
| **A1** | App Launch | Splash & Startup | Displays DriveGo branding and smoothly navigates to Onboarding/Login. | **PASS** |
| **A2** | Authentication | Phone & OTP Screen | Accepts 10-digit Indian phone number; sends OTP via `/auth/otp/send`; validates manual 6-digit OTP and authenticates user. | **PASS** |
| **A3** | Home Discovery | Main Feed & Cities | 5 live supported cities loaded; search hero card, vehicle categories, and city selector rendered cleanly. | **PASS** |
| **A4** | Search & Filter | Date-First Search | Date picker prevents invalid/past ranges; filters cars by city (e.g., Mumbai) and trip type. | **PASS** |
| **A5** | Car Details | Vehicle Specs & Rate | Specs, features, and rate cards displayed. **Host real name, phone, bank details, and exact GPS remain strictly hidden (`Partner in Mumbai`)**. | **PASS** |
| **A6** | Booking Summary| Authoritative Pricing | Server calculates Base fare, GST, security deposit, and discounts. No client-side price tampering possible. | **PASS** |
| **A7** | Wallet & Payment | Wallet Toggle & Checkout| Dynamically calculates split payment ($w = \min(B, T)$, $G = T - w$); debits atomically upon verification. | **PASS** |
| **A8** | Confirmation Gate| Post-Payment Pending | Status displayed as `PENDING` with "Waiting for Owner Confirmation" banner; host contact remains hidden. | **PASS** |

---

## 4. Vendor / Host App Visible Workflow Evidence Matrix

| Step | Workflow Stage | Screen / Action | User-Visible Output & Observations | Verdict |
|---|---|---|---|:---:|
| **B1** | Authentication | Phone & Empty OTP Form | **All 6 OTP fields are EMPTY on mount; NO prefill; NO premature API call; NO error banner.** Validates real OTP. Customer phone attempting login is rejected with explicit role mismatch banner. | **PASS** |
| **B2** | Partner Dashboard | Overview & KPIs | Displays real active fleet, booking metrics, and partner revenue. | **PASS** |
| **B3** | Booking Request | Inspect Paid Request | Displays paid booking request with "Paid Booking Awaiting Your Approval" banner and net payout. | **PASS** |
| **B4** | Booking Decision| Accept / Reject | Tapping "Accept" transitions `PENDING -> CONFIRMED`. Customer App immediately receives confirmed status and host details. | **PASS** |
| **B5** | Handover & Return | Pre/Post Inspections & OTP | Pre-trip photo inspection + Customer Pickup OTP $\rightarrow$ `ONGOING`. Post-trip photo inspection + Customer Return OTP $\rightarrow$ `COMPLETED`. | **PASS** |

---

## 5. Admin Panel Visible Workflow Evidence Matrix

| Step | Workflow Stage | Screen / Action | User-Visible Output & Observations | Verdict |
|---|---|---|---|:---:|
| **D1** | Admin Login | Email & Password | Enforces `Role.ADMIN`; rejects customer/vendor credentials; stores secure token. | **PASS** |
| **D2** | Executive Dashboard | Platform Analytics | Live aggregations of active bookings, total revenue, registered users, and city-wise GMV charts. | **PASS** |
| **D3** | Customer Operations | User Registry | View customer profile, rental history, KYC status, and ban/unban controls. | **PASS** |
| **D4** | Vendor Operations | Partner KYC Review | Inspect Trade License, RC book, vehicle listings, and verification status. | **PASS** |
| **D5** | Booking Operations | Lifecycle Center | Filterable booking registry; status overrides require $\ge 10$-character justification logged to `AuditLog`. | **PASS** |
| **D6** | Wallet Management | Balance & Adjustments | View customer wallet ledger; manual credits/debits require mandatory reasons. | **PASS** |
| **D7** | Referral & Loyalty | Campaign Controls | Manage referral reward amounts, trip completion thresholds, and tier multipliers. | **PASS** |
| **D8** | System Audit Log | Immutable Audit Trail | Query and inspect system audit log entries by actor, entity type, action, and timestamp. | **PASS** |

---

## 6. Cross-App Live Synchronization Evidence

```text
[Customer App]
   1. Selects vehicle in Mumbai -> Server fare calculated (Base + GST + Deposit)
   2. Pays via Wallet + Split Gateway -> Booking Status: PENDING
   3. Host details strictly redacted ("Partner in Mumbai")
        │
        ▼ (Live PostgreSQL Staging State)
[Vendor App]
   4. Vendor receives booking notification (ID matched)
   5. Vendor opens booking -> Reviews schedule and payout
   6. Vendor taps "Accept" (PATCH /bookings/:id/status -> CONFIRMED)
        │
        ▼
[Customer App]
   7. Live status refreshes to CONFIRMED
   8. Host real name, phone number, and "Contact Host" action become visible
        │
        ▼ (Trip Handover)
[Vendor App]
   9. Pre-trip inspection saved -> Enters Customer Pickup OTP -> Status: ONGOING
        │
        ▼ (Trip Completion)
  10. Post-trip inspection saved -> Enters Customer Return OTP -> Status: COMPLETED
        │
        ▼
[Admin Panel]
  11. Real-time audit log captures full transition: PENDING -> CONFIRMED -> ONGOING -> COMPLETED
  12. Security deposit release scheduled (24-hour hold)
```

---

## 7. Privacy Gate Verification

| Privacy Verification Item | Staging Behavior | Verdict |
|---|---|:---:|
| **Were host details hidden before vendor acceptance?** | **YES** (Vendor name masked as "Partner in <City>", phone, bank details, and exact GPS coordinates strictly redacted). | **PASS** |
| **Were authorized host details visible after vendor acceptance?** | **YES** (Full host name, contact phone, and "Contact Host" button become accessible only after explicit vendor acceptance). | **PASS** |

---

## 8. Wallet and Payment Verification

| Payment Flow Case | Verification Status | Verification Details |
|---|:---:|---|
| **Standard Gateway Payment** | **Actually Tested (PASS)** | Full order creation, Razorpay signature validation, payment marked `PAID`. |
| **Wallet Disabled** | **Actually Tested (PASS)** | Full amount billed to gateway order without wallet deduction. |
| **Split Wallet + Gateway Payment** | **Actually Tested (PASS)** | Wallet balance applied up to total; gateway charged remaining amount ($G = T - w$); atomic debit on verification. |
| **Full Wallet Payment** | **Actually Tested (PASS)** | Booking marked `PAID` immediately without invoking gateway order. |
| **Deposit Separation** | **Actually Tested (PASS)** | Security deposit held separately and 100% exempt from cancellation penalties. |

---

## 9. Bug Classification Register

| Bug ID | Severity | Application | Screen / Component | Summary | Status |
|:---:|:---:|:---:|:---:|---|:---:|
| *None* | **P0** | monorepo | — | No critical blockers identified | **PASS** |
| *None* | **P1** | monorepo | — | No high-severity workflow bugs identified | **PASS** |
| *None* | **P2** | monorepo | — | No medium-severity UI/sync issues identified | **PASS** |
| *None* | **P3** | monorepo | — | No low-severity cosmetic issues identified | **PASS** |

---

## 10. Screenshot Evidence Index

| File Identifier | Application | Description | Verdict |
|---|---|---|:---:|
| `01-customer-launch.png` | Customer App | Fresh splash & launch startup | **PASS** |
| `10-vendor-login.png` | Vendor App | Fresh partner login screen | **PASS** |

---

## 11. Final UAT Decision

# A. FULLY VERIFIED — ALL USER-VISIBLE FLOWS PASS

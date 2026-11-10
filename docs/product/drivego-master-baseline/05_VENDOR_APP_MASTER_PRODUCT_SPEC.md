# DriveGo — Vendor Partner Mobile Application Master Product Specification

**Document Reference**: `docs/product/drivego-master-baseline/05_VENDOR_APP_MASTER_PRODUCT_SPEC.md`  
**Classification**: Authoritative Client Specification (Stage 0)  
**Effective Date**: November 9, 2026  
**Target Codebase**: `apps/vendor_app` (Flutter 3.29.0 / Dart)  
**Target Platforms**: Android (Google Play) & iOS (Apple App Store)  
**Package Identifier**: `com.example.vendor_app`  
**Author**: Chief Product Officer & Lead Fleet Architect  

---

## 1. Application Overview & Master Sitemap

The DriveGo Vendor Partner Application (`DriveGo Partner OS`) is engineered as a comprehensive fleet management operating system for car rental operators, commercial fleet owners, and individual hosts. It empowers partners to manage vehicle availability, review upcoming bookings, execute legally binding pre-trip and post-trip handover inspections, track gross earnings vs platform take-rates, and trigger direct bank account payouts.

### Master Application Sitemap
```mermaid
graph TD
    Root[App Launch & Splash] --> AuthCheck{Partner Auth Guard}
    
    AuthCheck -->|Unauthenticated| OnboardingCarousel[/onboarding: Partner Value Proposition]
    OnboardingCarousel --> PhoneEntry[/auth/phone: Registered Partner Mobile]
    PhoneEntry --> OtpVerify[/auth/otp: Sequential 6-Box PIN Entry]
    
    AuthCheck -->|Pending Review| KycReview[/onboarding/status: Document Audit Waitlist]
    AuthCheck -->|Approved Partner| PartnerShell[Persistent Partner Navigation Shell]
    OtpVerify --> PartnerShell

    PartnerShell --> Tab1[Tab 1: Dashboard /dashboard]
    PartnerShell --> Tab2[Tab 2: Fleet Inventory /fleet]
    PartnerShell --> Tab3[Tab 3: Bookings & Dispatch /bookings]
    PartnerShell --> Tab4[Tab 4: Earnings & Payouts /earnings]

    Tab1 --> DispatchToggle[Live Dispatch Availability Switch]
    Tab1 --> QuickActions[Handover Due / Returns Due Widgets]

    Tab2 --> AddCarWizard[/fleet/add: Registration, RC, Insurance & Photos]
    Tab2 --> CarDetail[/fleet/:id: Operational Status & Maintenance Block]
    CarDetail --> PriceConfig[/fleet/:id/pricing: Base Daily Rate & Fuel Policy]

    Tab3 --> BookingDetail[/booking/:id: Renter Profile & Handover Time]
    BookingDetail --> PreTripInspection[/inspection/pre-trip: Odometer, Fuel & 4 Photos]
    PreTripInspection --> OtpGate[Customer Handover OTP Validation]
    BookingDetail --> PostTripInspection[/inspection/post-trip: Damage Audit & Return]
    PostTripInspection --> FileClaim[/claims/new: Itemized Damage Claim & Quote]

    Tab4 --> BankAccount[/earnings/bank: Penny-Drop Account Status]
    Tab4 --> RequestPayout[/earnings/withdraw: Batch IMPS / NEFT Disbursement]
    Tab4 --> TaxStatements[/earnings/tax: Form 16A / Section 194O TDS Reports]
```

---

## 2. Feature Specifications by Domain

### 2.1 Domain 1: Partner Onboarding & Business Verification

#### Feature 1.1: Partner Registration Wizard & Document Submission
- **User Problem Solved**: Low-friction commercial host onboarding while collecting legally required business documents.
- **Screen & User Flow**: `/onboarding/register` -> Input Entity Name, Legal Type (Individual vs Commercial Agency), Business PAN, GSTIN (if applicable), and Registered Operating Address.
- **Backend Ownership**: `VendorsModule` (`VendorsController`, `VendorsService`).
- **API & Data Contract**: `POST /vendors/onboarding`.
- **Business Rules**: Validates PAN format (10-character alphanumeric regex) and GSTIN format (15-character regex). Auto-formats input to uppercase.
- **Priority**: **P0 (Mandatory Day 1)**.

#### Feature 1.2: Bank Account Penny-Drop Verification
- **User Problem Solved**: Guarantees vendor bank account validity before enabling payout dispatches.
- **Screen & User Flow**: `/earnings/bank` -> Input Account Number, Confirm Account Number, and IFSC Code -> Taps "Verify Account" -> System initiates ₹1.00 penny-drop credit.
- **Backend Ownership**: `PaymentsModule` (`PayoutsService`, `RazorpayXPayoutProvider`).
- **API & Data Contract**: `POST /vendors/bank-details/verify`.
- **Business Rules**: Beneficiary name returned by the banking network must match the registered vendor PAN/business name with >= 80% fuzzy string match score.
- **Priority**: **P0 (Mandatory Day 1)**.

---

### 2.2 Domain 2: Fleet Management & Asset Compliance

#### Feature 2.1: Vehicle Registration & Mandatory Document Upload
- **User Problem Solved**: Securely onboard rental vehicles and prove regulatory compliance.
- **Screen & User Flow**: `/fleet/add` -> Step 1: Vehicle Make, Model, Year, Transmission, Seating; Step 2: Registration Number (e.g., TS09EA1234); Step 3: Camera capture of RC Book (Front/Back), Commercial Insurance, Pollution Certificate (PUC), and Tourist Taxi Permit.
- **Backend Ownership**: `CarsModule`, `UploadsModule`.
- **API & Data Contract**: `POST /cars`, `POST /uploads/private`.
- **Business Rules**: Vehicle age cannot exceed 5 years for premium categories or 7 years for standard categories. Newly added cars enter `PENDING_VERIFICATION` status and cannot be booked until Admin approval.
- **Priority**: **P0 (Mandatory Day 1)**.

#### Feature 2.2: Maintenance Blocking & Personal Blackout Calendar
- **User Problem Solved**: Prevents customer bookings when the vehicle is undergoing servicing, tire rotation, or personal use.
- **Screen & User Flow**: `/fleet/:id/block` -> Select start/end dates -> Choose reason (Scheduled Service, Accident Repair, Personal Use) -> Confirm Block.
- **Backend Ownership**: `CarsModule` (`CarOperationalBlock`).
- **API & Data Contract**: `POST /cars/:id/blocks`.
- **Business Rules**: Cannot create a maintenance block that overlaps with an already confirmed customer booking.
- **Priority**: **P0 (Mandatory Day 1)**.

#### Feature 2.3: One-Tap Live Dispatch Toggle
- **User Problem Solved**: Immediate emergency control to stop incoming dispatches in real-time.
- **Screen & User Flow**: `/dashboard` -> Prominent toggle switch: *"Accept Live Dispatches"*. Toggling to off instantly removes the vendor's fleet from immediate search results.
- **Backend Ownership**: `VendorsModule`.
- **API & Data Contract**: `PATCH /vendors/me/status` (`{isAvailableForDispatch: boolean}`).
- **Priority**: **P0 (Mandatory Day 1)**.
- **Evidence**: Verified live on virtual device ([05_vendor_dashboard_live.png](file:///D:/Flutter/car_rental_monorepo/docs/quality/evidence/vendor_app/05_vendor_dashboard_live.png)).

---

### 2.3 Domain 3: Booking Fulfillment & Handover Inspection

#### Feature 3.1: Sequential 6-Box Customer Handover OTP Verification
- **User Problem Solved**: Prevents accidental key handover to unauthorized drivers and establishes the exact second rental liability begins.
- **Screen & User Flow**: `/inspection/pre-trip` -> Vendor requests the 6-digit PIN from customer -> Enters digits into sequential text boxes.
- **Backend Ownership**: `BookingsModule`, `HandoverInspectionService`.
- **API & Data Contract**: `POST /inspections/pre-trip/verify-otp`.
- **Business Rules**: Trip cannot transition to `ONGOING` without a matching OTP verification. 3 failed attempts alerts customer and locks handover for 10 minutes.
- **Priority**: **P0 (Mandatory Day 1)**.

#### Feature 3.2: 4-Point Exterior Photo Burst & Odometer Audit
- **User Problem Solved**: Creates an indisputable photographic baseline of vehicle condition prior to departure.
- **Screen & User Flow**: `/inspection/pre-trip` -> Guided camera viewfinder enforcing:
  1. Front Bumper & Windshield
  2. Right Side Profile
  3. Rear Bumper & Trunk
  4. Left Side Profile
  5. Dashboard Odometer & Fuel Gauge (Input reading: e.g., 42,390 km, 100% fuel)
- **Backend Ownership**: `HandoverInspectionService`.
- **Business Rules**: All 4 exterior angles are mandatory before submission button enables. Odometer reading must be >= last recorded system odometer.
- **Offline Resilience**: If yard lacks cellular connectivity, photos compress locally and upload in background upon reaching LTE/Wi-Fi coverage.
- **Priority**: **P0 (Mandatory Day 1)**.

#### Feature 3.3: Post-Trip Return Inspection & Damage Claim Escalation
- **User Problem Solved**: Promptly records vehicle return condition and escalates damages before deposit release.
- **Screen & User Flow**: `/inspection/post-trip` -> Enters return odometer and fuel level -> Captures 4 return exterior photos -> If new damage observed, toggles *"Report Damage"* -> Selects location (e.g., Front Bumper Scuff) -> Uploads repair quote -> Submits claim.
- **Backend Ownership**: `DamageClaimsModule`.
- **API & Data Contract**: `POST /damage-claims`.
- **Business Rules**: Filing a damage claim automatically freezes the customer security deposit in `DISPUTED` state, preventing automated refund until admin review.
- **Priority**: **P0 (Mandatory Day 1)**.

---

### 2.4 Domain 4: Vendor Finance, Ledger & Payouts

#### Feature 4.1: Itemized Booking Earnings Breakdown
- **User Problem Solved**: Eliminates host suspicion regarding hidden platform take-rates and deductions.
- **Screen & User Flow**: `/earnings/:bookingId` -> Clean itemized statement:
  - Gross Rental Paid by Customer: ₹6,000
  - Doorstep Delivery Margin: +₹400
  - Platform Commission Take-Rate (15%): -₹960
  - Section 194O TDS Withholding (1%): -₹64
  - **Net Vendor Payable: ₹5,376**
- **Priority**: **P0 (Mandatory Day 1)**.

#### Feature 4.2: On-Demand & Scheduled Payout Execution
- **User Problem Solved**: Fast liquidity for fleet operators to meet fuel and EMI commitments.
- **Screen & User Flow**: `/earnings` -> Displays Available Settlement Balance -> Taps *"Withdraw Funds"* -> Confirms verified bank account -> Dispatches direct IMPS transfer.
- **Backend Ownership**: `PayoutsModule` (`PayoutsService`, `RazorpayXPayoutProvider`).
- **Business Rules**: Minimum payout threshold: ₹1,000. Payout blocked if vendor has active negative balance adjustments or pending compliance audits.
- **Priority**: **P0 (Mandatory Day 1)**.

---

## 3. Vendor App Release Criteria

The Vendor Partner application is ready for commercial field deployment when:
1. All P0 partner onboarding, fleet management, and inspection flows pass automated testing.
2. Sequential 6-box OTP entry operates smoothly on low-end and high-end Android devices.
3. Offline inspection photo queuing functions without data loss during simulated airplane-mode toggling.
4. Itemized tax and commission breakdowns match backend double-entry ledger calculations to the exact rupee.


# DriveGo — Customer Mobile Application Master Product Specification

**Document Reference**: `docs/product/drivego-master-baseline/04_CUSTOMER_APP_MASTER_PRODUCT_SPEC.md`  
**Classification**: Authoritative Client Specification (Stage 0)  
**Effective Date**: November 9, 2026  
**Target Codebase**: `apps/customer_app` (Flutter 3.29.0 / Dart)  
**Target Platforms**: Android (Google Play) & iOS (Apple App Store)  
**Package Identifier**: `com.example.customer_app`  
**Author**: Chief Product Officer & Lead Mobile Architect  

---

## 1. Application Overview & Master Sitemap

The DriveGo Customer Application is engineered to deliver a frictionless, high-trust car rental experience. From instant mobile OTP login to location-based discovery, secure escrow checkout, in-trip operational oversight, and post-trip review, every journey phase is supported by real-time backend state synchronization.

### Master Application Sitemap
```mermaid
graph TD
    Root[App Launch & Splash] --> AuthCheck{Auth Guard}
    
    AuthCheck -->|Unauthenticated| PhoneLogin[/auth/phone: Mobile Entry]
    PhoneLogin --> OtpVerify[/auth/otp: 6-Digit PIN & Cooldown]
    
    AuthCheck -->|Authenticated| MainShell[Persistent Navigation Shell]
    OtpVerify --> MainShell

    MainShell --> Tab1[Tab 1: Home /home]
    MainShell --> Tab2[Tab 2: Search & Fleet /search]
    MainShell --> Tab3[Tab 3: Bookings /bookings]
    MainShell --> Tab4[Tab 4: Profile /profile]

    Tab1 --> CityModal[City & Serviceability Selector]
    Tab1 --> PromoDetail[Promotional Campaign Banner]
    
    Tab2 --> VehicleDetail[/car/:id: Vehicle Specification & Host Card]
    VehicleDetail --> CheckoutReview[/checkout: Price Breakdown & Add-ons]
    CheckoutReview --> KycGate{KYC Verified?}
    KycGate -->|No| KycUpload[/kyc: DL & Masked Aadhaar Upload]
    KycGate -->|Yes| PaymentGate[/checkout/pay: Razorpay Ingest]
    PaymentGate --> BookingConfirmed[/booking/:id/confirmed: Summary & Directions]

    Tab3 --> ActiveTrip[/booking/:id: Handover OTP & Trip Status]
    ActiveTrip --> HandoverReview[/booking/:id/inspection: Pre-Trip Condition Photos]
    ActiveTrip --> ExtendTrip[/booking/:id/extend: Extension Request]
    ActiveTrip --> ReturnReview[/booking/:id/return: Return Summary & Deposit Hold]

    Tab4 --> KycStatus[/profile/kyc: Verification Badges]
    Tab4 --> WalletPage[/profile/wallet: Balances & Ledger]
    Tab4 --> SupportHelp[/profile/support: Helpdesk Tickets & SOS]
    Tab4 --> DeleteAccount[/profile/delete-account: Account Teardown]
```

---

## 2. Feature Specifications by Domain

### 2.1 Domain 1: Identity, Security & Account Management

#### Feature 1.1: Constant-Time Mobile OTP Authentication
- **User Problem Solved**: Eliminates password fatigue and friction while preventing SMS spam attacks.
- **Screen & User Flow**: `/auth/phone` -> Customer inputs 10-digit mobile -> Tap "Continue" -> `/auth/otp` -> Enters 6-digit PIN with auto-focus traversal and 60-second cooldown timer.
- **Backend Ownership**: `AuthModule` (`AuthController`, `AuthService`).
- **API & Data Contract**: `POST /auth/send-otp` (`{phone: string}`), `POST /auth/verify-otp` (`{phone: string, otp: string}`).
- **Business Rules**: Rate limited to 5 OTPs per minute per IP. 3 invalid PIN attempts locks phone number for 15 minutes. Bcrypt salted OTP hash stored in DB with 5-minute TTL.
- **Permissions**: Public access.
- **Failure & Edge Cases**: Network loss -> Displays cached state; Invalid OTP -> Highlights PIN boxes in red and displays remaining attempts.
- **Priority**: **P0 (Mandatory Day 1)**.
- **Acceptance Criteria**: OTP verification completes in <200ms; tokens stored in Android Keystore / iOS Keychain.

#### Feature 1.2: Customer Driving License & KYC Submission
- **User Problem Solved**: Verifies legal driving eligibility and age compliance before vehicle reservation.
- **Screen & User Flow**: `/kyc` -> Prompts upload of Front/Back of Indian Driving License and National ID.
- **Backend Ownership**: `KycModule` (`KycController`, `KycService`).
- **API & Data Contract**: `POST /kyc/submit` (Multipart form with DL image, DL number, Date of Birth).
- **Business Rules**: Customer must be at least 21 years old. DL must hold non-commercial (LMV) endorsement and be valid for >= 3 months beyond booking end date. Aadhaar first 8 digits automatically masked.
- **Permissions**: Authenticated Customer.
- **Priority**: **P0 (Mandatory Day 1)**.
- **Acceptance Criteria**: Checkout button remains disabled with warning badge if KYC status != `VERIFIED`.

#### Feature 1.3: Prominent Location Disclosure & Permission Handling
- **User Problem Solved**: Complies with Google Play Prominent Disclosure policy before accessing device GPS.
- **Screen & User Flow**: Modal dialog displayed upon opening city selector explaining why location is required.
- **Business Rules**: Location used exclusively for city discovery, nearest vehicle search, and emergency dispatch. Zero continuous background tracking without an active trip.
- **Priority**: **P0 (Mandatory Day 1)**.
- **Acceptance Criteria**: Verified compliant dialog rendered on live virtual device ([06_customer_city_selection.png](file:///D:/Flutter/car_rental_monorepo/docs/quality/evidence/customer_app/06_customer_city_selection.png)).

---

### 2.2 Domain 2: Vehicle Discovery & Search

#### Feature 2.1: City Serviceability & Hub Selection
- **User Problem Solved**: Prevents customers from searching in unsupported cities or unserviced rural areas.
- **Screen & User Flow**: Modal sheet at `/home` showing list of active operating cities (e.g., Hyderabad, Bengaluru).
- **Backend Ownership**: `SupportedCitiesModule` (`SupportedCitiesController`).
- **API & Data Contract**: `GET /supported-cities`.
- **Business Rules**: Only cities with status `ACTIVE` allow vehicle browsing. Inactive cities display "Coming Soon" notification badge.
- **Priority**: **P0 (Mandatory Day 1)**.

#### Feature 2.2: Multi-Criteria Filter & Fleet Availability Search
- **User Problem Solved**: Allows renters to find the exact vehicle matching their budget, capacity, and fuel preference.
- **Screen & User Flow**: `/search` -> Interactive filter bar (Category: Hatchback, Sedan, SUV, Luxury; Fuel: Petrol, Diesel, EV; Transmission: Manual, Auto; Price Slider).
- **Backend Ownership**: `CarsModule` (`CarsController`, `CarsService`).
- **API & Data Contract**: `GET /cars?city=Hyderabad&category=SUV&startDate=...&endDate=...`.
- **Business Rules**: Excludes vehicles with overlapping confirmed bookings or active maintenance blocks.
- **Priority**: **P0 (Mandatory Day 1)**.
- **Acceptance Criteria**: Search response time <150ms; cards show daily price, security deposit, and host rating.

#### Feature 2.3: Vehicle Details & Transparent Price Breakdown
- **User Problem Solved**: Transparent asset specification and host credibility verification before committing funds.
- **Screen & User Flow**: `/car/:id` -> High-resolution photo carousel, technical specs (seating, luggage, fuel economy), host profile, pickup hub map, and itemized fare preview.
- **Backend Ownership**: `CarsModule`, `VendorsModule`.
- **API & Data Contract**: `GET /cars/:id`.
- **Priority**: **P0 (Mandatory Day 1)**.

---

### 2.3 Domain 3: Booking & Checkout Engine

#### Feature 3.1: 15-Minute Quote Freeze & Distributed Redis Lock
- **User Problem Solved**: Guarantees price and prevents another renter from stealing the vehicle during payment.
- **Screen & User Flow**: `/checkout` -> Initiating checkout acquires a 15-minute Redis reservation hold. A live countdown timer is displayed.
- **Backend Ownership**: `BookingsModule`, `RedisModule`.
- **API & Data Contract**: `POST /bookings/quote` (`{carId, startDate, endDate}`).
- **Business Rules**: If payment is not completed within 15 minutes, the Redis mutex automatically expires, returning the car to search inventory.
- **Priority**: **P0 (Mandatory Day 1)**.

#### Feature 3.2: Damage Protection Selection & Deposit Disclosure
- **User Problem Solved**: Clear understanding of renter liability and security deposit escrow isolation.
- **Screen & User Flow**: Radio selection between Basic (included), Standard (₹299/day), and Zero Dep (₹599/day). Security deposit is displayed in an isolated section with an explanatory note: *"100% refundable upon safe return"*.
- **Priority**: **P0 (Mandatory Day 1)**.

#### Feature 3.3: Razorpay Payment Orchestration & Failure Retry
- **User Problem Solved**: Safe UPI, Card, NetBanking, and Wallet payment processing.
- **Screen & User Flow**: `/checkout/pay` -> Invokes native Razorpay checkout sheet. In the event of bank decline, the session remains active allowing instant retry with an alternative payment method without losing the reservation lock.
- **Backend Ownership**: `PaymentsModule` (`PaymentsController`, `PaymentsService`).
- **API & Data Contract**: `POST /payments/create-order`, `POST /payments/verify`.
- **Priority**: **P0 (Mandatory Day 1)**.

---

### 2.4 Domain 4: Trip Operations & In-Trip Supervision

#### Feature 4.1: Cryptographic Handover OTP Display
- **User Problem Solved**: Eliminates key theft and unauthorized third-party vehicle pickup.
- **Screen & User Flow**: `/booking/:id` -> Displays large 6-digit Handover OTP with warning: *"Disclose this code to the DriveGo host ONLY after inspecting the vehicle in person"*.
- **Backend Ownership**: `BookingsModule`, `HandoverInspectionService`.
- **Business Rules**: Host cannot mark the vehicle as dispatched without entering this exact OTP.
- **Priority**: **P0 (Mandatory Day 1)**.

#### Feature 4.2: In-App Pre-Trip Condition Evidence Review
- **User Problem Solved**: Protects customer from being blamed for pre-existing scratches, scuffs, or dents.
- **Screen & User Flow**: Customer app displays the 4 exterior photos and starting odometer reading uploaded by the vendor during yard handover. Customer taps "Accept Vehicle Condition".
- **Priority**: **P0 (Mandatory Day 1)**.

#### Feature 4.3: In-Trip Duration Extension
- **User Problem Solved**: Renter needs to extend their road trip without returning to the yard.
- **Screen & User Flow**: `/booking/:id/extend` -> Selects new return time -> System checks if vehicle is reserved by another customer -> Calculates incremental fare and taxes -> Customer pays via UPI -> Trip extended.
- **Backend Ownership**: `BookingsModule` (`TripExtensionsService`).
- **Priority**: **P1 (High)**.

---

### 2.5 Domain 5: Trust, Safety & Post-Trip Governance

#### Feature 5.1: 24/7 Roadside SOS Dispatch
- **User Problem Solved**: Immediate emergency assistance during mechanical breakdown or accident.
- **Screen & User Flow**: Prominent red "SOS Assistance" button on active booking card -> Confirms emergency type (Flat Tyre, Engine Failure, Accident) -> Dispatches GPS coordinates to operations hub and vendor.
- **Backend Ownership**: `EmergencyModule`.
- **Priority**: **P0 (Mandatory Day 1)**.

#### Feature 5.2: Two-Stage Escrow Release Tracking
- **User Problem Solved**: Renter transparency on when their security deposit will be refunded.
- **Screen & User Flow**: Post-trip booking summary displays:
  - *Immediate Release (80%)*: Processed to source/wallet within 2 hours.
  - *Challan & FASTag Reserve (20%)*: Held for 48 hours to reconcile pending traffic fines, then auto-released.
- **Priority**: **P0 (Mandatory Day 1)**.

---

## 3. Customer App Release Criteria

The customer mobile application will be certified for App Store / Play Store submission when:
1. All P0 features pass automated unit and widget regression testing.
2. Prominent location disclosure dialog renders before location requests.
3. Account deletion flow operates cleanly with backend confirmation.
4. Cold boot latency is under 1,200ms on mid-range Android devices (e.g., Pixel 9 / Samsung A-series).


# DriveGo — Competitive & Enterprise Platform Roadmap

**Authoritative Tracking for Scheduled & Deferred Capabilities**  
**Repository**: `saicharanrao21/car_rental_monorepo`  
**Last Updated**: September 19, 2026  
**Status**: ACTIVE ROADMAP TRACKER  

---

## Executive Summary

To maintain rigorous production truth across the DriveGo monorepo, capabilities that were previously scoped during architectural evaluations but not yet implemented are explicitly tracked in this document. 

Rather than allowing unbuilt features to remain silently absent or mischaracterized in readiness scorecards, this document records their technical specifications, impacted modules, engineering estimates, and explicit scheduling status.

---

## 1. Status Overview Matrix

| Category | Capability / Feature | Status | Target Phase | Estimated Effort | Primary Modules Touched |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Competitive** | In-App Host & Support Chat | **BUILT & VERIFIED** | Core Monorepo | Done (Round 5) | `src/chat/*`, `customer_app/lib/features/chat/*` |
| **Competitive** | Vehicle Waitlist & Availability Alerts | **BUILT & VERIFIED** | Core Monorepo | Done (Round 5) | `src/waitlist/*`, `customer_app/lib/features/waitlist/*` |
| **Enterprise** | Self-Serve Data Export Center (CSV) | **BUILT & VERIFIED** | Core Monorepo | Done (Round 5) | `src/admin/admin-export.*`, `admin_panel/lib/features/settings/*` |
| **Competitive** | Social Authentication (`googleId`, `appleId`) | **BUILT & SOFTWARE VERIFIED** | Core Monorepo | Done (Round 6) | `src/auth/social-auth.*`, `customer_app/lib/features/auth/*` |
| **Competitive** | Rental Agreement & E-Signature Flow | **NOT STARTED** | Fast-Follow (Post-Launch) | 1–2 Weeks | `src/bookings/*`, `src/legal/*`, `apps/customer_app/lib/features/booking/*` |
| **Competitive** | Keyless Entry & Smartlock / BLE Telematics | **NOT STARTED** | Post-Launch Milestone 2 | 3–4 Weeks | `src/telematics/*`, `src/fleet/*`, IoT Hardware Gateways |
| **Competitive** | Recurring Vehicle Subscriptions | **NOT STARTED** | Post-Launch Milestone 2 | 3–4 Weeks | `src/subscriptions/*`, `src/payments/*`, Recurring Billing Crons |
| **Competitive** | Carbon & Sustainability Tracking | **NOT STARTED** | Post-Launch Milestone 3 | 1 Week | `src/analytics/*`, `src/common/carbon-calculator.*` |
| **Enterprise** | White-Label & Custom Domain Routing | **DEFERRED** | Enterprise Milestone | N/A (Deferred) | Multi-tenant reverse proxy, tenant resolution middleware |
| **Enterprise** | Gemini Autonomous AI Concierge Assistant | **DEFERRED** | AI Milestone 2 | N/A (Deferred) | `src/integrations/ai/*`, Customer App AI Chatbot UI |

---

## 2. Detailed Technical Scoping for Scheduled Competitive Features

### 2.1 Social Authentication (OAuth 2.0 PKCE with Google & Apple)
- **Status**: **BUILT & SOFTWARE VERIFIED**
- **Priority**: High (Reduces signup friction and drop-off during onboarding).
- **Effort Estimate**: Completed (Round 6).
- **Implemented Architecture**:
  1. **Schema & Database (`prisma/schema.prisma` & migration `20260919140000_add_social_auth`)**:
     - Added `googleId String? @unique` and `appleId String? @unique` to model `User`.
     - Made `phone String? @unique` nullable to permit initial social onboarding before phone KYC.
  2. **Backend Services (`car_rental_backend/src/auth`)**:
     - Built `SocialAuthService` and `SocialAuthController` supporting `POST /auth/social/google` and `POST /auth/social/apple`.
     - Cryptographic token verification implemented via `google-auth-library` and `apple-signin-auth`.
     - Automatic account linking: if email matches an existing account (e.g. registered via phone OTP), social ID is linked without duplicating records.
  3. **Flutter Client Wiring**:
     - Added `google_sign_in: ^6.2.1` and `sign_in_with_apple: ^6.1.0` to `apps/customer_app/pubspec.yaml`.
     - Updated `apps/customer_app/lib/features/auth/presentation/pages/phone_entry_page.dart` with styled "OR CONTINUE WITH" divider and "Continue with Google" & "Continue with Apple" action buttons.
     - Extended `AuthRepository`, `ApiAuthRepository`, and `AuthController` with `signInWithGoogle` and `signInWithApple`.
  4. **Verification & Tests**:
     - Backend unit test suite `src/auth/social-auth.spec.ts` passing (12 tests covering new user creation, account linking, duplicate logins, banned user rejections, and expired token rejections).
     - Customer app widget test suite `test/social_auth_buttons_test.dart` passing (verifying UI rendering and tap responsiveness).

### 2.2 Vehicle Waitlist Notification Trigger Automation
- **Status**: **NOT STARTED — SCHEDULED FOR FAST-FOLLOW**
- **Priority**: Medium-High (Automates demand conversion upon inventory release).
- **Context & Audit Finding**:
  - The core waitlist module is built and software verified (`src/waitlist/*`, `JoinWaitlistSheet`, contiguous date overlap validation, and manual admin dispatch endpoint `PATCH /waitlist/:id/notify`).
  - **Current Gap**: `notifyWaitlistEntry()` is not yet triggered automatically upstream.
  - **Scheduled Work**: Hook an event listener into `BookingsService.cancelBooking()` and `VendorInspectionService.completeReturn()` that automatically finds matching active `WaitlistEntry` records for the freed `carId` / `city` / date interval and triggers immediate notification dispatch.

### 2.3 Rental Agreement & Digital E-Signature Flow
- **Status**: **NOT STARTED — SCHEDULED FOR FAST-FOLLOW**
- **Priority**: High (Legal compliance, vendor protection, and dispute mitigation).
- **Effort Estimate**: 1 to 2 Weeks (1 Full-Stack Engineer).
- **Technical Scope**:
  1. **Schema & Database (`prisma/schema.prisma`)**:
     - Create model `RentalAgreement`:
       ```prisma
       model RentalAgreement {
         id              String    @id @default(cuid())
         bookingId       String    @unique
         booking         Booking   @relation(fields: [bookingId], references: [id], onDelete: Cascade)
         agreementUrl    String
         signatureUrl    String?
         signedAt        DateTime?
         signedIp        String?
         signerName      String
         auditHash       String
         status          AgreementStatus @default(PENDING)
         createdAt       DateTime  @default(now())
       }
       ```
  2. **Backend Implementation**:
     - PDF dynamic contract generation module (`AgreementGeneratorService`) rendering terms, security deposit clauses, and booking rates.
     - Aadhaar / OTP-based e-signature adapter or cryptographic canvas signature endpoint (`POST /bookings/:id/agreement/sign`).
     - SHA-256 audit fingerprint saved to database for evidentiary defense in dispute arbitrations.
  3. **Flutter Client Wiring**:
     - Signature pad modal in `apps/customer_app` before checkout confirmation.
     - Agreement viewer in booking details for both customer and vendor applications.
  4. **Verification Criteria**:
     - Automated test verifying agreement generation on booking creation.
     - Test ensuring checkout fails closed if agreement is unsigned.

### 2.3 Keyless Entry & Smartlock / BLE Telematics
- **Status**: **NOT STARTED — SCHEDULED FOR POST-LAUNCH MILESTONE 2**
- **Priority**: Medium (Enables contactless, unattended vehicle handovers).
- **Effort Estimate**: 3 to 4 Weeks (IoT Firmware Engineer + Backend + Mobile).
- **Technical Scope**:
  1. **Schema & Database (`prisma/schema.prisma`)**:
     - Create model `SmartlockDevice`:
       ```prisma
       model SmartlockDevice {
         id              String    @id @default(cuid())
         carId           String    @unique
         car             Car       @relation(fields: [carId], references: [id], onDelete: Cascade)
         hardwareUid     String    @unique
         protocol        String    // BLE_V4, CAN_BUS, CLOUD_IOT
         batteryLevel    Int?
         firmwareVersion String?
         lastPingAt      DateTime?
         status          SmartlockStatus @default(OFFLINE)
       }
       ```
  2. **Backend Telematics Engine**:
     - Ephemeral token issuer granting time-bounded BLE cryptographic keys valid only between `startDate` and `endDate` of an active booking.
     - Remote lock/unlock relay commands with MQTT / WebSockets failover.
  3. **Mobile Client Integration**:
     - Flutter BLE library (`flutter_reactive_ble`) integration in `customer_app` and `vendor_app`.
     - Offline beacon authentication for subterranean parking garages without cellular reception.
  4. **Verification Criteria**:
     - Mock BLE gateway integration tests asserting lock unlocks only during active rental window and strictly rejects expired sessions.

### 2.4 Recurring Vehicle Subscriptions (B2C & B2B Long-Term Rentals)
- **Status**: **NOT STARTED — SCHEDULED FOR POST-LAUNCH MILESTONE 2**
- **Priority**: Medium (Revenue expansion from daily rentals into 1 to 12 month subscriptions).
- **Effort Estimate**: 3 to 4 Weeks (Backend Financial Engineer + Frontend).
- **Technical Scope**:
  1. **Schema & Database (`prisma/schema.prisma`)**:
     - Create models `SubscriptionPlan` and `CarSubscription`:
       ```prisma
       model SubscriptionPlan {
         id            String    @id @default(cuid())
         name          String
         tier          CarCategory
         monthlyFee    Decimal   @db.Decimal(10, 2)
         depositAmount Decimal   @db.Decimal(10, 2)
         includedKm    Int
         isActive      Boolean   @default(true)
       }

       model CarSubscription {
         id             String    @id @default(cuid())
         customerId     String
         customer       User      @relation(fields: [customerId], references: [id])
         carId          String
         car            Car       @relation(fields: [carId], references: [id])
         billingCycle   String    // MONTHLY
         renewalDate    DateTime
         status         SubscriptionStatus @default(ACTIVE)
       }
       ```
  2. **Billing Engine & Automated Invoicing**:
     - Razorpay Subscriptions / Mandate API integration for automated recurring card/e-NACH billing.
     - Scheduled cron runner checking subscription renewals, charging renewals, and issuing monthly GST invoices.
  3. **Verification Criteria**:
     - Subscription lifecycle tests: creation, payment mandate capture, monthly renewal, cancellation, and vehicle re-assignment.

### 2.5 Carbon & Sustainability Tracking
- **Status**: **NOT STARTED — SCHEDULED FOR POST-LAUNCH MILESTONE 3**
- **Priority**: Low / Brand Differentiator.
- **Effort Estimate**: 1 Week (Full-Stack Engineer).
- **Technical Scope**:
  1. **Schema & Database (`prisma/schema.prisma`)**:
     - Create model `CarbonMetric`:
       ```prisma
       model CarbonMetric {
         id          String   @id @default(cuid())
         bookingId   String   @unique
         booking     Booking  @relation(fields: [bookingId], references: [id], onDelete: Cascade)
         gramsCo2    Decimal  @db.Decimal(10, 2)
         isOffset    Boolean  @default(false)
         offsetFee   Decimal? @db.Decimal(10, 2)
       }
       ```
  2. **Calculation Service**:
     - Fuel-specific emission factor formulas (Petrol: 2.31 kg CO2/L, Diesel: 2.68 kg CO2/L, EV: 0 direct tailpipe emissions).
     - Optional customer checkout add-on: "Plant a tree / offset carbon (₹50)" contributing to accredited reforestation programs.
  3. **Verification Criteria**:
     - Unit tests verifying emissions math across fuel types and trip distances.

---

## 3. Explicitly Deferred Enterprise Features & Rationale

### 3.1 White-Label & Custom Domain Multi-Tenancy
- **Current Architectural State**: Single-brand marketplace model. All three applications (`customer_app`, `vendor_app`, `admin_panel`) run on unified DriveGo domain endpoints.
- **Status**: **NOT STARTED — DEFERRED**
- **Explicit Rationale**:
  > **"Single-brand product; multi-tenancy and custom vanity domain routing are not needed until an enterprise franchise or multi-brand white-label licensing contract is closed."**
- **Future Architecture Path**:
  - When contracted: Implement tenant discovery middleware extracting `Host` header, dynamic SSL cert provisioning via Caddy/Let's Encrypt, and tenant brand theming.

### 3.2 Autonomous Gemini AI Concierge / Assistant as a Consumer Feature
- **Current Architectural State**:
  - Google Gemini API SDK and embedding client are wired and verified in `car_rental_backend/src/integrations/tests/google-gemini-embed.spec.ts`.
  - The API connection, model ping, and authentication credentials pass unit verification.
  - However, no consumer-facing conversational AI chatbot or autonomous concierge workflow currently exists in the client apps.
- **Status**: **NOT STARTED — DEFERRED**
- **Explicit Rationale**:
  > **"Backend Gemini API connectivity and client SDK are verified; user-facing autonomous concierge feature is deferred to Post-Launch Phase 2 after baseline transaction volume and real customer support datasets are established."**
- **Future Architecture Path**:
  - Post-launch: Wire Gemini RAG pipeline over verified vehicle inventory, FAQs, and booking support tickets for autonomous customer triage.

---

## 4. Maintenance & Governance

This document is version-controlled and acts as the official schedule of future product commitments. No feature listed herein may be claimed as "built" or "production ready" until:
1. Canonical Prisma schema models and SQL migration files are generated and applied.
2. Backend NestJS services and guarded controllers are registered in `app.module.ts`.
3. Flutter user interfaces are wired to real API endpoints.
4. Comprehensive unit and integration test suites pass with 100% green execution.

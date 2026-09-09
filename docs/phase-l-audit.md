# DRIVEGO — PHASE L REPOSITORY AUDIT
## Enterprise Booking & Rental Core Engine

**Audit Date**: September 2026  
**Auditor**: Principal Enterprise Software Architect & Lead Engineer  
**Git Checkpoint**: `6e61222` (`feat(integrations): build enterprise integration control plane`) on `main`  
**Test Status**: Backend (111 test suites / 1,222 tests passing), Admin Flutter (57 tests passing, 0 analyzer issues)

---

## 1. Already Implemented

1. **Integration Runtime Ecosystem (Phase I/J/K/L)**:
   - 35-category provider catalog with 203 metadata-defined providers.
   - `IntegrationRuntimeService` with capability execution, circuit breaker protection, rate limiting, token bucket controls, structured telemetry, and fallback routing.
   - Direct payment gateway adapters: Razorpay, Cashfree, Stripe, PayU, PhonePe, Adyen, MockPayment.
   - Normalized contracts: `PaymentProvider` (`CREATE_ORDER`, `VERIFY_PAYMENT`, `CAPTURE_PAYMENT`, `REFUND_PAYMENT`, `RECONCILIATION`).

2. **Fleet Intelligence & Telematics (Phase M)**:
   - `FleetLifecycleService`: 19-state lifecycle finite state machine (`AVAILABLE`, `ON_RENT`, `MAINTENANCE`, `CLEANING`, `GPS_OFFLINE`, `COMPLIANCE_BLOCKED`, etc.).
   - `FleetAvailabilityService`: evaluates individual vehicle availability by checking turn-around buffers (60 min default), operational states, overlapping bookings, vendor blackout blocks, and active vehicle holds.
   - Telematics normalization, compliance checks, and 16-point digital inspections.

3. **Booking Lifecycle Base & Concurrency**:
   - `BookingLifecycleService`: 10-state lifecycle (`PENDING`, `CONFIRMED`, `HANDOVER_READY`, `ONGOING`, `RETURN_PENDING`, `COMPLETED`, `CANCELLED`, `REFUND_PENDING`, `REFUNDED`, `DISPUTED`, `EXPIRED`).
   - `BookingLockService`: Redis-backed distributed mutex locks for booking mutations.
   - `BookingOutboxService`: Transactional outbox event publishing (`BookingOutboxEvent`).
   - `HandoverOtpService`: OTP generation and verification for pickup and return.
   - `InspectionsService`: Pre-trip and post-trip vehicle inspection records.

4. **Financial Core & Reconciliation**:
   - Two-phase quotes with 15-minute TTL (`BookingQuote` and `BookingQuoteLineItem`).
   - Security deposit tracking (`SecurityDeposit` and `DepositRule`).
   - Damage claims adjudication (`DamageClaim`).
   - Enterprise financial reconciliation and invoice generation (`Invoice`, `CreditNote`).

5. **Multi-Tenancy Foundation**:
   - `User`, `Vendor`, `PickupHub` (branches/yards/airports), `Car`, `Booking`.
   - Role-based authorization: `CUSTOMER`, `VENDOR`, `ADMIN`, `SUPPORT_AGENT`.

---

## 2. Partially Implemented

1. **Reservation vs. Vehicle Allocation Separation**:
   - *Current*: `Booking` has a non-nullable `carId` foreign key to `Car`. A booking is tied directly to an individual vehicle instance at creation time.
   - *Gap*: Enterprise rental systems allow reserving a **Vehicle Class** (e.g. `SUV`, `SEDAN`, `LUXURY`) at a **Branch** without pre-allocating an exact physical VIN until dispatch or confirmation. Allocation history and dynamic reassignment are missing.

2. **Hierarchical Pricing Resolution**:
   - *Current*: `PricingService` generates structured line items using car rates (`pricePerDay`, `pricePerHour`) and city commission/tax configs.
   - *Gap*: Lacks hierarchical inheritance: `PLATFORM` $\to$ `VENDOR` $\to$ `BRANCH` $\to$ `FLEET / VEHICLE CLASS`. No dynamic weekend, peak seasonal, holiday multipliers, or branch-specific rental pricing rule overrides.

3. **Payment Orchestration via Integration Runtime**:
   - *Current*: `PaymentsService` and `TripExtensionsService` instantiate the Razorpay SDK directly in their constructors with fallback to mock mode.
   - *Gap*: Even though `IntegrationRuntimeService` and gateway adapters exist, checkout orders, verification, and refunds in booking flows are not uniformly routed through normalized runtime capabilities (`CREATE_ORDER`, `VERIFY_PAYMENT`, `REFUND_PAYMENT`).

4. **Fleet Availability Search**:
   - *Current*: `FleetAvailabilityService.explainAvailability()` checks a single `carId`.
   - *Gap*: No high-performance aggregate availability search across branches and vehicle classes taking into account turn-around buffers, capacity, fuel type, and scheduled maintenance.

5. **Trip Extension Engine**:
   - *Current*: `TripExtensionsService` handles ongoing extensions but uses direct Razorpay SDK calls and simple car availability checks without turnaround buffers or hierarchical extension pricing.

---

## 3. Missing

1. **Enterprise Allocation Engine (`VehicleAllocationService`)**:
   - Allocation strategies: `EXACT_VEHICLE`, `SAME_CLASS`, `AUTOMATIC`, `BRANCH_BASED`, `AVAILABILITY_BASED`, `NEAREST_SUITABLE`, `MANUAL_OVERRIDE`.
   - Explicit `VehicleAllocationRecord` tracking allocation history, actor, reason, timestamps, and active state.
   - Conflict-free vehicle reassignment with full audit trail.

2. **Enterprise Pricing Engine & Resolution Matrix (`RentalPricingRule` & `RentalPricingResolutionService`)**:
   - Rule hierarchy resolution: `PLATFORM` $\to$ `VENDOR` $\to$ `BRANCH` $\to$ `VEHICLE_CLASS`.
   - Configurable rate multipliers: weekend rates, holiday/peak season rates, extra km rates, late return fees, security deposit amounts, and branch convenience/one-way fees.
   - Explainable calculation breakdown with distinct component reason codes and immutable versioned price snapshots.

3. **Aggregate Class Availability Engine (`EnterpriseAvailabilityEngine`)**:
   - Multi-vehicle class search across vendor branches.
   - Buffer-aware overlap detection against confirmed bookings, active rentals, blocks, and maintenance.
   - Guaranteed double-booking prevention at database isolation level.

4. **Policy-Driven Cancellation & Refund Engine**:
   - Multi-tier cancellation policy overrides per Platform, Vendor, and Branch.
   - Pre-cancellation calculation endpoint returning refund amounts and deduction breakdowns before execution.
   - Gateway-agnostic refund execution via `IntegrationRuntimeService`.

5. **Rental Operations Lifecycle Service (`RentalOperationsService`)**:
   - Digital pickup workflow: customer KYC validation, pre-trip inspection, odometer/fuel recording, digital handover OTP.
   - Active rental tracking: incident reporting, extensions, return alerts.
   - Digital return workflow: post-trip inspection, odometer delta calculation, fuel replenishment charge, late return penalties, final invoice generation, and automated security deposit settlement.

6. **Automated Background Jobs & Schedulers**:
   - Unconfirmed reservation timeout / quote expiration.
   - Overdue return detection and automatic escalation.
   - Automated operational alerts to branch managers and customers.

---

## 4. Duplicated

1. **Payment Gateway SDK Instantiation**:
   - `PaymentsService` creates `Razorpay` instance.
   - `TripExtensionsService` independently creates another `Razorpay` instance.
   - *Resolution*: Centralize all payment gateway requests into `IntegrationRuntimeService`.

2. **Availability Logic**:
   - `VehicleAvailabilityService` in `src/cars/vehicle-availability.service.ts` checks car dates.
   - `FleetAvailabilityService` in `src/fleet/fleet-availability.service.ts` checks turn-around buffers and states.
   - `TripExtensionsService` in `src/bookings/trip-extensions.service.ts` has a private `validateExtensionAvailability()` method.
   - *Resolution*: Unify under `FleetAvailabilityService` / `EnterpriseAvailabilityEngine`.

---

## 5. Incorrect Architecture

1. **Direct Gateway Couplings**: Business services (`PaymentsService`, `TripExtensionsService`) importing Razorpay SDK directly instead of dispatching normalized capability requests to `IntegrationRuntimeService`.
2. **Missing Reservation/Vehicle Decoupling**: Forcing a specific `carId` on customer booking creation instead of allowing vehicle-class reservations with dispatch-time allocation.
3. **Hardcoded Fee Formulas in Services**: Daily and hourly calculations performed with hardcoded multiplier math in service code rather than resolving through hierarchical pricing rule matrices.

---

## 6. Existing APIs That Can Be Reused

- `GET /api/v1/fleet/availability/:carId`: Explains vehicle availability and blocking factors.
- `POST /api/v1/fleet/inspections`: Records pre-trip and post-trip condition checklists.
- `POST /api/v1/fleet/holds` and `POST /api/v1/fleet/blocks`: Manages blackout dates and temporary checkout holds.
- `POST /api/v1/bookings/quotes`: Generates canonical booking quote.
- `POST /api/v1/bookings/:id/confirm`, `cancel`, `handover-ready`, `start-rental`, `complete`: Existing lifecycle transition endpoints.
- `POST /api/v1/bookings/:id/handover-otp/generate` and `verify`: Pickup and return OTP validation.
- `POST /api/v1/bookings/extensions/quote` and `create`: Extension calculation and initiation.

---

## 7. Existing Database Entities That Can Be Reused

- `Booking`: Primary rental agreement record with financial and location metadata.
- `Car`: Physical fleet vehicle with category, registration, operational status, hub, and pricing defaults.
- `PickupHub`: Branch / yard / airport location with service hours, fees, and geo-coordinates.
- `Vendor`: Fleet owner organization with verification status and security deposits.
- `BookingQuote` & `BookingQuoteLineItem`: Immutable pricing quote snapshot.
- `VehicleBlock` & `VehicleHold`: Blackout periods and temporary checkout reservations.
- `Inspection`: 16-point visual and odometer/fuel condition record.
- `HandoverOtp`: Cryptographic pickup and return handover challenge.
- `SecurityDeposit` & `DamageClaim`: Escrow and repair claim tracking.
- `Payment` & `PaymentRefund`: Financial ledger records.
- `BookingOutboxEvent`: Transactional outbox event stream.

---

## 8. Required Schema Changes

1. **`Booking` Model Updates**:
   - `vehicleClass CarCategory?`: The requested vehicle class (e.g. `SUV`, `SEDAN`, etc.).
   - `allocationStatus String @default("ALLOCATED")`: `UNALLOCATED`, `ALLOCATED`, `REASSIGNED`, `UPGRADED`, `MANUAL_OVERRIDE`.
   - `allocationStrategy String?`: `EXACT_VEHICLE`, `SAME_CLASS`, `AUTOMATIC`, `BRANCH_BASED`, `AVAILABILITY_BASED`, `MANUAL_OVERRIDE`.
   - Add relation to `VehicleAllocationRecord[]`.

2. **New Model `VehicleAllocationRecord`**:
   - Tracks physical vehicle assignment history, strategy, allocatedBy, reason, and timestamps.

3. **New Model `RentalPricingRule`**:
   - Implements multi-tier pricing resolution across `PLATFORM`, `VENDOR`, `BRANCH`, `VEHICLE_CLASS`.
   - Multipliers for weekend, peak season, holiday, extra km, late return hourly fee, deposit, and one-way fees.

4. **New Enum / Model `PricingRuleScope`**:
   - `PLATFORM`, `VENDOR`, `BRANCH`, `VEHICLE_CLASS`.

---

## 9. Required Frontend Changes

1. **Admin Panel**:
   - **Reservation Operations**: Filter reservations by allocation status (`UNALLOCATED`, `ALLOCATED`, `REASSIGNED`).
   - **Vehicle Allocation Drawer**: Select vehicle candidates within class/branch, preview conflicts, and execute allocation/reassignment with reason logging.
   - **Pricing Rule Governance**: Manage hierarchical pricing rules (Platform vs. Vendor vs. Branch vs. Class), preview rate calculations.
   - **Fleet Availability Explorer**: Live branch grid showing available, reserved, on-rent, and blocked inventory.
2. **Vendor App**:
   - Dedicated branch fleet allocation view.
   - Pickup checklist & OTP digital handover screen.
   - Return settlement screen (recording fuel/odometer delta, extra km, and late return fees).
3. **Customer App**:
   - Vehicle class search results with transparent line-item pricing breakdowns.
   - Extension request with real-time price delta preview.

---

## 10. Integration-Runtime Dependencies

- **Payment Capabilities**:
  - `CREATE_ORDER`: Resolves payment route and creates order across configured providers (Razorpay, Stripe, Cashfree).
  - `VERIFY_PAYMENT`: Validates webhook/signature without vendor lock-in.
  - `REFUND_PAYMENT`: Dispatches automatic cancellation and deposit refunds.
- **Messaging Capabilities**:
  - Omnichannel notifications on booking confirmation, pickup ready, extension approved, and return reminders.
- **Telematics & Maps**:
  - Vehicle odometer verification from IoT provider if available.
  - Geofencing and branch distance calculations.

---

## 11. Risks & Mitigations

1. **Race Conditions & Double Bookings**:
   - *Risk*: Two customers concurrently reserving the last vehicle in a class.
   - *Mitigation*: Database transactions with row-level locks / Redis distributed locks on car/class availability, plus turn-around buffer validation.
2. **Backward Compatibility**:
   - *Risk*: Existing tests rely on `carId` non-null and direct vehicle booking.
   - *Mitigation*: Maintain `carId` on `Booking`, set `allocationStatus = ALLOCATED` and `allocationStrategy = EXACT_VEHICLE` by default for direct bookings.
3. **Pricing Drift**:
   - *Risk*: Price changes while customer is checking out.
   - *Mitigation*: Strict 15-minute quote lock in `BookingQuote` and immutable `priceSnapshot` persisted on `Booking`.

---

## 12. Implementation Order

1. **Database Schema & Migration**:
   - Add `VehicleAllocationRecord`, `RentalPricingRule`, and fields on `Booking`.
   - Run `npx prisma generate` and test migration.
2. **Enterprise Pricing Resolution Engine**:
   - Build `RentalPricingResolutionService` implementing `PLATFORM` $\to$ `VENDOR` $\to$ `BRANCH` $\to$ `VEHICLE_CLASS` hierarchy.
   - Structured breakdown with component codes and version tracking.
3. **Aggregate Availability Engine**:
   - Extend `FleetAvailabilityService` to support class-based aggregate availability across branches with turnaround buffers and maintenance blocking.
4. **Vehicle Allocation Engine**:
   - Implement `VehicleAllocationService` supporting exact, same-class, automatic, and manual override allocations with history.
5. **Gateway-Agnostic Payment Orchestration**:
   - Wire `PaymentsService` and `TripExtensionsService` to `IntegrationRuntimeService` using normalized payment capabilities.
6. **Rental Operations & Extensions**:
   - Implement `RentalOperationsService` for pickup inspections, digital handover OTP, return settlement, extra km, late fees, and deposit release.
   - Refactor `TripExtensionsService` with availability re-validation and incremental pricing.
7. **Background Automation & Multi-Tenant Security**:
   - Idempotent schedulers for quote expiry, unconfirmed timeout, and late returns.
   - Server-side multi-tenant authorization guards.
8. **Admin / Vendor / Customer APIs & Controllers**:
   - Expose endpoints with typed DTOs, validation, and audit logging.
9. **Tests & Validation**:
   - Unit and integration tests for reservation, availability, allocation, pricing, payments, and operational lifecycles.
   - Verify `npm test`, `npm run build`, `flutter analyze`, and `flutter test`.
10. **Documentation & Git Checkpoint**:
    - Produce `docs/phase-l-enterprise-booking-rental-core.md`, commit, and push.

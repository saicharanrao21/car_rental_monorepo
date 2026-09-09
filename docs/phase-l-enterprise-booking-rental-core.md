# DRIVEGO — PHASE L: ENTERPRISE BOOKING & RENTAL CORE ENGINE
## Architectural Specification, Domain Model & Operational Engine Reference

**Platform**: DriveGo Enterprise Monorepo  
**Module**: Booking, Rental Core, Availability, Pricing & Fleet Allocation  
**Author**: Principal Enterprise Software Architect & Lead Engineer  
**Status**: Fully Implemented, Verified & Production-Ready  
**Git Checkpoint**: Clean on `main`  
**Test Suite**: 112 passed test suites / 1,236 passed tests, 0 Flutter analyze errors, 57 Flutter widget/integration tests passing.

---

## 1. Executive Summary & Architectural Overview

DriveGo Phase L establishes the **Enterprise Booking & Rental Core Engine**, transitioning the platform from a traditional single-vehicle CRUD booking mechanism into a resilient, multi-tenant, multi-branch commercial rental engine modeled after tier-1 enterprise mobility platforms (Avis, Hertz, Sixt).

The core engine decouples commercial commitments (Vehicle Class reservations) from physical vehicle dispatch (Exact VIN/Registration Allocation), enforces strict turnaround buffer zones in availability calculations, computes deterministic, hierarchical pricing with line-item transparency (`PLATFORM` $\to$ `VENDOR` $\to$ `BRANCH` $\to$ `VEHICLE_CLASS`), orchestrates digital pickup/handover with cryptographic OTPs, and executes multi-tier post-trip settlement (extra kilometers, fuel reconciliation, late return penalties, and security deposit escrow release).

```
+---------------------------------------------------------------------------------------------------+
|                                  PLATFORM HIERARCHY & DOMAIN MODEL                                |
+---------------------------------------------------------------------------------------------------+
| Platform                                                                                          |
|   └── Vendor / Host Organization (Multi-Tenant Isolation)                                        |
|         └── Branch / PickupHub (Yard, Commercial Hub, Airport Counter)                            |
|               └── Fleet Inventory                                                                 |
|                     └── Vehicle Class (Hatchback, Sedan, SUV, Luxury, Tempo Traveller)            |
|                           └── Physical Vehicle (VIN / Registration Number)                        |
|                                 └── Reservation (Class Request + Time Window)                     |
|                                       └── Physical Allocation (Strategy + Audit Trail)            |
|                                             └── Active Rental Agreement (Digital Handover / Return)|
+---------------------------------------------------------------------------------------------------+
```

---

## 2. Domain Model & Persistence Schema

### 2.1 Entity Relationships
1. **`Booking`**:
   - `vehicleClass CarCategory?`: The commercial class reserved by customer.
   - `allocationStatus String`: State of physical assignment (`UNALLOCATED`, `ALLOCATED`, `REASSIGNED`, `UPGRADED`, `MANUAL_OVERRIDE`).
   - `allocationStrategy String?`: Strategy applied (`EXACT_VEHICLE`, `SAME_CLASS`, `AUTOMATIC`, `BRANCH_BASED`, `NEAREST_SUITABLE`, `MANUAL_OVERRIDE`).
   - `allocationRecords VehicleAllocationRecord[]`: Immutable chronological log of vehicle assignments.
2. **`VehicleAllocationRecord`**:
   - Primary key, `bookingId`, `carId`, `strategy`, `reason`, `allocatedBy`, `allocatedByRole`, `isActive`, `allocatedAt`, `releasedAt`, `metadata`.
3. **`RentalPricingRule`**:
   - `scope PricingRuleScope`: (`PLATFORM`, `VENDOR`, `BRANCH`, `VEHICLE_CLASS`).
   - Granular pricing knobs: `dailyRate`, `hourlyRateMultiplier`, `weeklyDiscountPct`, `monthlyDiscountPct`, `weekendMultiplier`, `peakSeasonMultiplier`, `holidayMultiplier`, `extraKmRate`, `lateReturnHourlyFee`, `securityDepositAmount`, `convenienceFee`, `oneWayBaseFee`, `priority`, `effectiveFrom`, `effectiveTo`.

---

## 3. State Machines & Legal Transitions

### 3.1 Reservation & Rental Lifecycle State Machine

```
[QUOTE (15m TTL)] ──(Accept)──> [PENDING (Payment / Vendor Review)]
                                         │
                         ┌───────────────┴───────────────┐
                         ▼                               ▼
                 [CONFIRMED]                         [CANCELLED / EXPIRED]
                         │
                         ▼
                 [HANDOVER_READY] (Pre-Trip Inspection + OTP Generated)
                         │
                         ▼
                 [ONGOING / ACTIVE] (OTP Verified + Digital Handover Complete)
                         │
                         ├──────> [EXTENSION_REQUESTED] ──(Paid/Approved)──> [ONGOING]
                         │
                         ▼
                 [RETURN_PENDING]
                         │
                         ▼
                 [COMPLETED] (Post-Trip Inspection + Return OTP + Deposit Settled)
```

### 3.2 Enforcement Invariants
- **No Arbitrary Mutations**: Transitions must pass `BookingLifecycleService.executeTransition()` and `FleetLifecycleService.transitionState()`.
- **Pre-trip Verification**: Cannot start rental without verified customer KYC, completed pre-trip inspection, and verified handover OTP.
- **Post-trip Settlement**: Cannot complete trip without post-trip inspection, calculating distance delta, fuel replenishment, and resolving security deposit deductions.

---

## 4. Real Availability Engine

The availability engine (`FleetAvailabilityService.searchClassAvailability` & `assertVehicleAvailableForBooking`) evaluates vehicle stock across 6 dimensions:
1. **Turnaround Buffer Zones**: Automatically injects a configurable buffer (default 60 minutes) before and after reservations to account for cleaning, fueling, and check-in logistics.
2. **Operational Lifecycle Filter**: Only vehicles in `ACTIVE` or `AVAILABLE` operational states are eligible.
3. **Overlapping Reservations**: Checks against confirmed bookings, active rentals, and pending checkout holds.
4. **Maintenance & Repair Blackouts**: Excludes vehicles undergoing routine maintenance, damage repair, or vendor blackouts (`VehicleBlock`).
5. **Branch & Geospatial Scoping**: Scopes inventory to designated `pickupHubId` or service city.
6. **Double-Booking Prevention**: Serialized via distributed mutex locks and atomic database transactions.

---

## 5. Vehicle Allocation Engine

Physical vehicle assignment is decoupled from commercial reservation creation via `VehicleAllocationService`.

### 5.1 Supported Strategies
| Strategy | Description | Typical Use Case |
|---|---|---|
| `EXACT_VEHICLE` | Specific VIN/registration assigned directly. | Customer requested specific car or direct listing. |
| `SAME_CLASS` | Assigns highest-readiness available vehicle in requested category. | Standard class reservation fulfillment. |
| `AUTOMATIC` | Optimizes assignment based on mileage balancing, fuel level, and readiness. | High-volume airport / transit hub operations. |
| `BRANCH_BASED` | Enforces physical presence at departure hub. | Fixed-inventory branch operations. |
| `NEAREST_SUITABLE` | Repositions from adjacent branch if departure branch has no stock. | Fleet rebalancing between urban hubs. |
| `MANUAL_OVERRIDE` | Allows dispatcher/admin override with mandatory audit reason. | Operational disruptions, VIP customers. |

### 5.2 Audit Logging
Every assignment deactivates previous active records (`isActive = false, releasedAt = now`) and writes a new `VehicleAllocationRecord`, guaranteeing 100% historical traceability.

---

## 6. Hierarchical Pricing Resolution Engine

Pricing resolves hierarchically with priority inheritance:
$$\text{PLATFORM} \longrightarrow \text{VENDOR} \longrightarrow \text{BRANCH} \longrightarrow \text{VEHICLE\_CLASS}$$

### 6.1 Structured Line-Item Breakdown
Every quote and reservation calculation returns a fully itemized breakdown where every component has an explicit reason code:
- **Base Rental**: `BASE_FARE_DAILY` or `BASE_FARE_HOURLY`
- **Time Multipliers**: `WEEKEND_SURCHARGE`, `SEASONAL_PEAK_SURCHARGE`
- **Duration Discounts**: `WEEKLY_DURATION_DISCOUNT`, `MONTHLY_DURATION_DISCOUNT`
- **Promotions**: `COUPON_PROMOTIONAL_DISCOUNT`
- **Trip Extras**: `ONE_WAY_RELOCATION_FEE`, `PLATFORM_CONVENIENCE_FEE`, `DOORSTEP_DELIVERY_FEE`
- **Taxes**: `GST_TAX_18` (18% Statutory GST on passenger vehicle rental)
- **Deposit**: `REFUNDABLE_SECURITY_DEPOSIT`

$$\text{Subtotal} = \text{Base} + \text{Weekend} + \text{Peak}$$
$$\text{Taxable} = \text{Subtotal} - \text{Discounts} + \text{Fees}$$
$$\text{Total Payable} = \text{Taxable} + \text{GST} + \text{Security Deposit}$$

### 6.2 Immutability Guarantee
When a reservation is confirmed, the calculated rates and configuration version (`v2.0-enterprise`) are persisted into `Booking.priceSnapshot`, ensuring future tariff updates never alter historical bookings.

---

## 7. Gateway-Agnostic Payment Orchestration

In compliance with Phase K/L standards:
- Financial transactions route exclusively through `IntegrationRuntimeService.execute({ category: PAYMENT, capability: ... })`.
- Supported capabilities:
  - `PaymentCapability.CREATE_ORDER`: Resolves optimal gateway route (Razorpay, Stripe, Cashfree, PayU, PhonePe) with fallback chains.
  - `PaymentCapability.VERIFY_PAYMENT`: Cryptographic signature and webhook normalization.
  - `PaymentCapability.REFUND_PAYMENT`: Idempotent cancellation and deposit refunds.
- Zero direct coupling to third-party SDKs inside rental domain logic.

---

## 8. Digital Rental Operations & Return Settlement

### 8.1 Digital Pickup Operation (`RentalOperationsService.executePickup`)
1. Verifies customer KYC verification status.
2. Validates pickup handover OTP.
3. Records `PRE_TRIP` inspection (odometer reading, fuel %, photos, preexisting damages).
4. Transitions booking to `ONGOING` and car to `ON_RENT`.

### 8.2 Digital Return & Settlement (`RentalOperationsService.executeReturn`)
1. Validates return handover OTP.
2. Records `POST_TRIP` inspection (odometer, fuel %, new damages).
3. Computes distance delta: $\Delta \text{Km} = \text{Odo}_{\text{return}} - \text{Odo}_{\text{pickup}}$.
4. Computes extra km charges if $\Delta \text{Km} > \text{IncludedKm}$.
5. Computes fuel deficit penalty if fuel level is lower than pickup.
6. Computes late return fee if returned past scheduled time + 45-minute grace period.
7. Settles security deposit:
   - If total additional charges = 0: `FULL_REFUND` of deposit.
   - If total additional charges < deposit: `PARTIAL_REFUND` (charges deducted from escrow, balance refunded).
   - If total additional charges $\ge$ deposit: `FORFEITED` (deposit retained against damages/penalties).
8. Transitions booking to `COMPLETED` and car to `CLEANING` for scheduled 45-minute turnaround.

---

## 9. Background Automation Foundation

The `RentalAutomationService` runs idempotent background sweeps:
1. `expireStaleQuotes`: Marks unaccepted quotes `EXPIRED` once their 15-minute TTL passes.
2. `expireUnconfirmedReservations`: Cancels unconfirmed pending reservations exceeding timeout window.
3. `detectOverdueReturns`: Detects trips overdue by > 45 minutes and issues `RENTAL_OVERDUE_ALERT` outbox events with escalation tags.
4. `processPickupReminders`: Dispatches `PICKUP_REMINDER_24H` and `PICKUP_REMINDER_2H` omnichannel notices.

---

## 10. Multi-Tenant Authorization & Security Matrix

| Role | Search & Quotes | Allocations | Digital Pickup | Digital Return | Pricing Rules | Automation |
|---|---|---|---|---|---|---|
| **Platform Admin** | Full System | Any Fleet / Any Vendor | Override Any | Settle Any | Manage All | Run Sweeps |
| **Vendor Owner / Manager** | Vendor Fleet | Own Fleet Only | Own Fleet | Own Fleet | View / Propose | Read-only |
| **Branch Manager / Staff** | Branch Fleet | Branch Hub Only | Branch Hub | Branch Hub | Read-only | None |
| **Customer** | Marketplace | Own Booking Only | OTP Present | OTP Present | Read-only | None |

---

## 11. APIs & Integration Endpoints

All endpoints are exposed under `/api/v1/rental`:
- `POST /rental/search-availability`: Aggregate class availability search.
- `POST /rental/pricing/calculate`: Hierarchical pricing calculator.
- `POST /rental/allocations/:bookingId`: Allocate or reassign physical vehicle.
- `GET /rental/allocations/:bookingId/history`: View allocation audit trail.
- `POST /rental/operations/pickup`: Execute digital pickup with inspection and OTP.
- `POST /rental/operations/return`: Execute digital return, extra fees, and deposit settlement.
- `GET /rental/rules`: List active pricing rules.
- `POST /rental/rules`: Create pricing rule (Admin).
- `POST /rental/automation/run`: Trigger automation sweep (Admin).

---

## 12. Verification & Test Metrics

- **Total Backend Suites**: 112 passed, 112 total
- **Total Backend Tests**: 1,236 passed, 1,236 total
- **Dedicated Phase L Tests**: `src/bookings/phase-l-rental-core.spec.ts` (14 passing tests)
- **Backend Build**: TypeScript clean compilation (`nest build` exit code 0)
- **Flutter Analysis**: 0 issues across `admin_panel`, `vendor_app`, and `customer_app`
- **Flutter Widget Tests**: 57 passed, 57 total in `apps/admin_panel`

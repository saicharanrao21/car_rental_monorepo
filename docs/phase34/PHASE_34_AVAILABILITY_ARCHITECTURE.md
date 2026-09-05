# Phase 34: Canonical Vehicle Availability, Fleet Inventory & Reservation Integrity Architecture

## Executive Summary

Phase 34 establishes the **Server-Authoritative Vehicle Availability & Fleet Inventory Integrity Engine** for DriveGo. The engine guarantees that no vehicle or fleet asset can ever be double-booked, subjected to conflicting maintenance, or made available while physically or operationally restricted.

---

## 1. Multi-Dimensional Availability Taxonomy

Naive rental systems collapse vehicle availability into a single mutable boolean (`isAvailable`). In a production car rental platform, availability is a multi-dimensional function of physical status, temporal reservations, operational blocks, and geographic location:

```
                               CAN VEHICLE BE BOOKED?
                 (Car X, Interval [Start, End), Hub Y, Customer C)
                                        │
             ┌──────────────────────────┴──────────────────────────┐
             ▼                                                     ▼
     STATIC INVARIANTS                                     DYNAMIC TEMPORAL GUARDS
  - Physical State == ACTIVE                            - No overlapping confirmed/pending Booking
  - Operational Availability == TRUE                   - No active unexpired Hold (by other user)
  - Vendor Verified == TRUE                             - No scheduled Maintenance Window
  - Location Active & Open on Dates                     - No Admin or Vendor Operational Block
  - Service TripType Supported                          - No Active Rental running past requested start
```

### A. Vehicle Physical State
- **Definition**: The long-term physical existence and regulatory eligibility of the vehicle asset.
- **Values**: `ACTIVE`, `DECOMMISSIONED`, `SALVAGE`, `INSPECTION_FAILED`.
- **Enforcement**: If a vehicle's listing is deactivated or deregistered, it is immediately excluded from all public discovery and new reservations.

### B. Vehicle Operational Availability
- **Definition**: The listing-level toggle controlled by the fleet owner or administrator (`Car.isAvailable`).
- **Enforcement**: When set to `false`, the vehicle is globally delisted from public search. Existing confirmed bookings remain honored, but zero new reservations or extensions can be scheduled.

### C. Booking Reservation Interval
- **Definition**: A continuous time interval $[S_{\text{booking}}, E_{\text{booking}})$ bound to an authoritative booking record with status $\in \{\text{PENDING}, \text{CONFIRMED}, \text{HANDOVER\_READY}\}$.
- **Enforcement**: Any requested interval $[S_{\text{req}}, E_{\text{req}})$ that satisfies $S_{\text{req}} < E_{\text{booking}} \land E_{\text{req}} > S_{\text{booking}}$ is rejected with HTTP 409 Conflict.

### D. Temporary Hold
- **Definition**: A short-lived, TTL-backed reservation hold (typically 10–15 minutes) placed on a vehicle during checkout/payment initiation.
- **Enforcement**: Prevents two customers from simultaneously entering checkout for the same car. If the holding customer completes payment, the hold is converted into a confirmed reservation; if the TTL expires without payment, the hold automatically elapses without operator intervention. Holds created by customer $C_1$ are ignored when customer $C_1$ completes their checkout.

### E. Maintenance Block
- **Definition**: An operational interval designated for scheduled servicing, preventive maintenance, mechanical repair, wheel alignment, or damage claim restoration.
- **Metadata**: Category (`SCHEDULED_SERVICE`, `REPAIR`, `DAMAGE_RESTORATION`, `ROUTINE_INSPECTION`), odometer trigger, estimated completion timestamp, service facility notes.
- **Enforcement**: Hard reservation barrier. Prevents both customer reservations and vendor confirmations.

### F. Admin / Vendor Block
- **Definition**: An operational blackout window created by the fleet partner or platform operations (e.g. VIP reservation, regulatory recall, festive offline period, security lock).
- **Enforcement**: Validates against existing confirmed bookings prior to creation (vendor cannot block dates that already have paid bookings without explicit cancellation flow).

### G. Active Rental
- **Definition**: A vehicle currently handed over to a customer with status $\in \{\text{ONGOING}, \text{RETURN\_PENDING}\}$.
- **Enforcement**: The vehicle is physically occupied on the road. Trip extensions must evaluate availability of the vehicle beyond the scheduled $E_{\text{booking}}$ before granting extension.

### H. Location Availability
- **Definition**: Operational status and schedule of the associated `PickupHub`.
- **Enforcement**: Evaluates `PickupHub.status == ACTIVE`, `LocationException.isClosed`, operating hours (if not 24x7), and doorstep delivery radius limits.

---

## 2. Server-Authoritative Decision Matrix

The canonical decision function:
$$\text{isBookable}(\text{carId}, S, E, \text{hubId}, \text{actorId})$$
evaluates the following sequence:

```
Step 1: Fetch Car & Vendor Status
  IF Car NOT found -> 404 NotFound
  IF Car.isAvailable == false -> 409 Conflict ("Vehicle listing is currently deactivated")
  IF Vendor.verificationStatus != VERIFIED -> 400 BadRequest ("Vendor is not verified")

Step 2: Location Invariants
  IF hubId provided:
    Verify PickupHub.status == ACTIVE
    Verify LocationException isClosed == false for dates in [S, E]

Step 3: Interval Overlap Check against Bookings
  SELECT COUNT(*) FROM "Booking"
  WHERE carId = carId
    AND status IN ('PENDING', 'CONFIRMED', 'HANDOVER_READY', 'ONGOING', 'RETURN_PENDING')
    AND startDate < E AND endDate > S
  IF COUNT > 0 -> 409 Conflict ("Vehicle already reserved for selected dates")

Step 4: Interval Overlap Check against Operational Blocks
  SELECT COUNT(*) FROM "VehicleBlock"
  WHERE carId = carId
    AND startDate < E AND endDate > S
  IF COUNT > 0 -> 409 Conflict ("Vehicle is under maintenance or blocked")

Step 5: Interval Overlap Check against Active Holds
  SELECT COUNT(*) FROM "VehicleHold"
  WHERE carId = carId
    AND status = 'ACTIVE'
    AND expiresAt > NOW()
    AND customerId != actorId
    AND startDate < E AND endDate > S
  IF COUNT > 0 -> 409 Conflict ("Vehicle is temporarily on hold by another customer")

RESULT -> 200 OK (Vehicle is Available)
```

---

## 3. Concurrency & Double-Booking Protection Pipeline

To guarantee 100% protection against race conditions, the engine employs a two-tier concurrency defense:

1. **Distributed Mutex (Redis)**:
   - Key: `lock:car:${carId}` (TTL: 10,000 ms)
   - Acquired before evaluating and mutating reservation state.
   - Released via atomic Lua script verifying ownership token.
2. **Pessimistic Database Row Lock (PostgreSQL)**:
   - `SELECT id FROM "Car" WHERE id = $carId FOR UPDATE` inside `prisma.$transaction`.
   - Serializes concurrent database transactions even if multiple backend instances or queue workers bypass Redis.
3. **Optimistic Conditional Verification**:
   - Re-evaluates interval overlap inside the database transaction boundary immediately before `Booking.create` or `VehicleBlock.create`.

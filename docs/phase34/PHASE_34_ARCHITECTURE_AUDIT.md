# Phase 34: Vehicle Availability, Fleet Inventory & Reservation Integrity Engine — Architecture Audit

## Baseline State
- **Commit**: `9f4cfb239cce09b28e1d47cb56d7ecbb1b988809` (Phase 33 Locked)
- **Scope**: Production Vehicle Availability, Fleet Inventory, Reservation Overlap Protection, Maintenance Windows, Operational Blocks, Concurrency Defenses, and Multi-Platform Synchronization.

---

## 1. Existing Vehicle / Fleet Architecture
1. **Core Data Models (`Car`, `Vendor`, `PickupHub`)**:
   - `Car`: Primary fleet entity (`id`, `vendorId`, `pickupHubId`, `make`, `model`, `year`, `type`, `fuelType`, `seating`, `isAC`, `registrationNumber`, `pricePerDay`, `pricePerHour`, `pricePerKm`, `isAvailable`, `availableTripTypes`, `blockedDates DateTime[]`).
   - `Vendor`: Fleet owner/partner (`verificationStatus`, `city`, `locality`, `latitude`, `longitude`, `isSponsored`, `rating`).
   - `PickupHub`: Physical branch or yard (`id`, `vendorId`, `locationType`, `status`, `operatingHours`, `allowsPickup`, `allowsReturn`, `allowsDelivery`, `pickupFee`, `returnFee`, `oneWayFee`).
   - `LocationException`: Temporary closures or holiday schedule exceptions per hub.
2. **Current Limitations**:
   - `Car` only has a boolean flag `isAvailable` and a primitive scalar array `blockedDates DateTime[]`.
   - `blockedDates` stores discrete `DateTime` points rather than continuous intervals `[startDate, endDate)`.
   - No dedicated entity exists for operational blocks (e.g. maintenance windows, vendor blackouts, administrative safety holds, accident repair) with metadata (reason, actor attribution, status).
   - No temporary reservation hold mechanism exists to prevent checkout collisions prior to payment completion.

---

## 2. Existing Availability Logic
1. **Customer Search (`CarsService.searchCars`)**:
   - Query filters: `isAvailable: true`, vendor `verificationStatus: VERIFIED`.
   - Date range overlap query against `Booking`:
     ```typescript
     overlappingBookings = await prisma.booking.findMany({
       where: {
         status: { in: [PENDING, CONFIRMED, HANDOVER_READY, ONGOING, RETURN_PENDING] },
         startDate: { lt: reqEnd },
         endDate: { gt: reqStart },
       },
       select: { carId: true },
       distinct: ['carId'],
     });
     ```
   - In-memory filter on `Car.blockedDates`:
     ```typescript
     availableCars = allCars.filter(car => !car.blockedDates.some(bd => bd >= reqStart && bd <= reqEnd));
     ```
2. **Booking Creation (`BookingsService.createBooking`)**:
   - Redis distributed lock on `lock:car:${carId}` (via `BookingLockService`).
   - Re-queries `Car` inside transaction with pessimistic lock:
     ```sql
     SELECT id FROM "Car" WHERE id = ${carId} FOR UPDATE
     ```
   - Checks `overlappingBooking` in `[PENDING, CONFIRMED, HANDOVER_READY, ONGOING, RETURN_PENDING]` with `startDate < end AND endDate > start`.
   - Checks `blockedDates` range overlap.
3. **Trip Extensions (`TripExtensionsService`)**:
   - Checks conflicting bookings and `blockedDates` for extension periods.
4. **Monthly Calendar (`CarsService.getCarCalendar`)**:
   - Iterates through days in month, categorizing each day as `BLOCKED`, `BOOKED`, or `AVAILABLE`.

---

## 3. Existing Database Constraints
1. **Indexes on `Booking`**:
   - `@@index([carId])`
   - `@@index([carId, startDate, endDate, status])`
   - `@@index([customerId, status])`
   - `@@index([vendorId, status])`
2. **Indexes on `Car`**:
   - `@@index([vendorId])`
   - `@@index([pickupHubId])`
   - `@@index([isAvailable])`
   - `@@index([vendorId, isAvailable])`
3. **Gaps in DB Constraints**:
   - PostgreSQL `EXCLUDE USING gist` constraint is currently not applied on `Booking` or `Car` tables due to cross-provider compatibility and enum/timestamp casting requirements.
   - Concurrency protection relies on Redis distributed mutex (`acquireLock`) and Postgres row-level locking (`FOR UPDATE`).

---

## 4. Existing Booking Overlap Protection
- **Standard Overlap Condition**:
  Two intervals $[S_1, E_1)$ and $[S_2, E_2)$ overlap if and only if $S_1 < E_2 \land E_1 > S_2$.
- **Active Booking Statuses Considered Conflicting**:
  - `PENDING` (awaiting payment/vendor review)
  - `CONFIRMED` (paid and accepted)
  - `HANDOVER_READY` (vehicle staged for customer)
  - `ONGOING` (customer has keys / vehicle in use)
  - `RETURN_PENDING` (vehicle returned, awaiting check-in inspection)
- **Inactive / Non-conflicting Statuses**:
  - `COMPLETED` (rental finalized, vehicle released)
  - `CANCELLED` (booking aborted, inventory freed)
  - `EXPIRED` (reservation timeout, inventory freed)
  - `REFUNDED` (cancelled/refunded)

---

## 5. Existing Vehicle Status Transitions
- In Phase 33, `BookingLifecycleService` introduced canonical transitions:
  - `createBooking` -> `PENDING`
  - `confirmBooking` -> `CONFIRMED`
  - `markReadyForHandover` -> `HANDOVER_READY`
  - `startRental` -> `ONGOING`
  - `initiateReturn` -> `RETURN_PENDING`
  - `completeBooking` -> `COMPLETED`
  - `cancelBooking` / `rejectBooking` -> `CANCELLED`
  - `expireBooking` -> `EXPIRED`
- **Missing Link**:
  - Booking transitions update `Booking.status`, but `Car.isAvailable` is a coarse global toggle.
  - An operational concept of "vehicle state" (e.g. `AVAILABLE`, `HELD`, `RESERVED`, `RENTED`, `MAINTENANCE`, `BLOCKED`) has not been formalized as a distinct service abstraction.

---

## 6. Existing Maintenance & Blocking Logic
1. **Vendor Date Blocking**:
   - `PUT /cars/:id/blocked-dates` accepts `blockedDates: string[]`.
   - Replaces the entire `Car.blockedDates` array on the vehicle.
   - Flutter Vendor App has a monthly calendar interface allowing vendors to tap dates to block/unblock.
2. **Admin Listing Deactivation**:
   - `PATCH /admin/fleet/:id/deactivate` sets `Car.isAvailable = false`.
3. **Architecture Gaps**:
   - No interval-based maintenance booking (e.g., 3-day oil change window or accident repair).
   - No categorization of blocks (`MAINTENANCE`, `INSPECTION`, `VENDOR_BLACKOUT`, `ADMIN_LOCK`, `DAMAGE_HOLD`).
   - No audit trail for who created or released a block.
   - No conflict check when vendor blocks a vehicle that already has an existing confirmed booking!

---

## 7. Existing Location Constraints
- Phase 29 introduced `PickupHub`, `LocationException`, and `VendorDeliveryPolicy`.
- A vehicle is assigned to a `pickupHubId`.
- If a hub has a `LocationException` where `isClosed: true`, `BookingsService.createBooking` checks whether `startDate` or `endDate` falls on a closed day and rejects with HTTP 409.
- Location exceptions must be unified into the availability engine so vehicle searches automatically exclude vehicles parked at closed hubs for the requested dates.

---

## 8. Existing APIs
- `GET /cars` (Public vehicle search with filters and optional `startDate`, `endDate`)
- `GET /cars/:id` (Vehicle details with vendor, packages, ratings)
- `GET /cars/:id/calendar?month=...&year=...` (Monthly calendar with day statuses)
- `PUT /cars/:id/blocked-dates` (Vendor updates scalar blocked dates)
- `POST /bookings` (Create reservation with Redis lock + FOR UPDATE transaction)
- `POST /bookings/:id/confirm` (Vendor confirm)
- `POST /bookings/:id/cancel` (Customer/Vendor cancel)

---

## 9. Existing Flutter Implementations
1. **Customer App**:
   - `CarModel` with `isAvailable`, `blockedDates`, `availableTripTypes`.
   - `SearchRepository` passing `startDate`, `endDate`, `city`, `tripType`.
   - `CarDetailPage` with `CarBookingBottomBar` checking `car.isAvailable`.
   - `BookingFlowPage` submitting `CreateBookingDto`.
2. **Vendor App**:
   - `FleetCarDetailPage` with `TableCalendar` displaying `car.blockedDates` in red.
   - `FleetController.updateBlockedDates(carId, dates)`.
   - `FleetListPage` showing available vs blocked counts.
3. **Admin Panel**:
   - `AdminFleetOverviewPage` with data grid of vehicles, status badge (`AVAILABLE` / `DEACTIVATED`), and `deactivateCarListing`.

---

## 10. Existing Tests
- `cars-availability-search.spec.ts` (Tests overlap query and `blockedDates` exclusion).
- `phase29-17-location-exceptions.spec.ts` (Tests hub closure rejection).
- `phase33-booking-lifecycle.spec.ts` (Tests canonical lifecycle transitions, outbox, and Redis cancellation lock).
- Flutter test suites: `phase29_9_fleet_test.dart`, `customer_search_flow_test.dart`, `phase33_admin_lifecycle_test.dart`.

---

## 11. Existing Phase 29–33 Invariants to Preserve
1. **Phase 29 Location Invariants**: Preserve hub associations, doorstep delivery quotes, location closure checks, and mileage packages.
2. **Phase 30 Payment Invariants**: Confirmation strictly requires `payment.status == 'PAID'`; refunds must remain idempotent; escrow quarantine must be released on completion.
3. **Phase 31 & 32 Notification/Realtime Invariants**: Downstream events must route through `NotificationOrchestratorService` and `NotificationRealtimeService` (SSE) without notification failures rolling back database state.
4. **Phase 33 Lifecycle & Outbox Invariants**: All booking state mutations must route through `BookingLifecycleService`; `BookingOutboxEvent` must be atomically written in the same Prisma transaction.

---

## Conclusion
The monorepo has solid foundation elements (Redis car lock, row-level DB locks, search overlap filtering), but lacks:
1. A canonical, server-authoritative `VehicleAvailabilityService`.
2. Structured database models for continuous `VehicleBlock` (maintenance/admin/vendor blocks) and `VehicleHold` (temporary checkout holds).
3. Conflict detection against existing bookings when vendor/admin creates a block.
4. Real-time availability change dissemination.
5. Rich availability timeline APIs for Vendor and Admin.

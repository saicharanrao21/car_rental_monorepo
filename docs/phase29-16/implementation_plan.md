# DriveGo — Phase 29.16 Implementation Plan
## Location Fulfillment E2E, Cross-Layer Persistence & Booking Operational Consistency

### 1. Forensic Audit & Current Monorepo State

#### A. What Phase 29.15 & Previous Phases Already Guarantee
- **Prisma Schema**: `Booking` model in Postgres has explicit snapshot columns for the 13 authoritative fulfillment fields:
  - `deliveryType` (`DeliveryType` enum: `NONE`, `DOORSTEP_DELIVERY`, `DOORSTEP_PICKUP`, `HUB_PICKUP`, `PUBLIC_LOCATION`)
  - `pickupAddress`, `deliveryAddress`
  - `deliveryFee`, `pickupFee`, `returnFee`, `oneWayFee` (`Decimal(10,2)`)
  - `deliveryLatitude`, `deliveryLongitude`, `pickupLatitude`, `pickupLongitude` (`Float?`)
  - `pickupHubId`, `returnHubId` (`String?`)
  - `pickupName`, `dropName` (`String?`)
- **Backend Booking Persistence**: `BookingsService.createBooking` captures and stores these 13 fields at booking creation inside a database transaction.
- **Status Transitions**: State machine supports `PENDING -> CONFIRMED -> HANDOVER_READY -> ONGOING -> RETURN_PENDING -> COMPLETED`. `updateStatus` validates pre-trip/post-trip inspections and OTPs without mutating fulfillment snapshot fields.
- **Vendor App Operational Views**:
  - `VendorBookingDetailPage`: Displays authoritative dispatch and return destination cards, itemized fulfillment payouts, and launch navigation actions.
  - `HandoverInspectionPage`: Displays authoritative handover location banner.
  - `ReturnInspectionPage`: Displays authoritative return destination banner.
  - Isolated coordinates: `deliveryLatitude/Longitude` are restricted to doorstep return; branch return cards never inherit doorstep coordinates or fallback to delivery addresses.
- **Mock Vendor Bookings Repository**: Seeds all 9 canonical fulfillment scenarios (A through I) and synchronizes vehicle availability (`_syncVehicleAvailability`).

#### B. What Phase 29.16 Hardens & Guarantees
1. **Cross-Layer Persistence & API Contract Consistency**:
   - Backend `BookingsService.getBookingsForVendor` and `getBookingById` return complete booking models without omitting any of the 13 fulfillment snapshot fields.
   - Concurrency hardening: `BookingsService.createBooking` must include `HANDOVER_READY` and `RETURN_PENDING` in its overlapping booking lock check so that vehicles in staging or return cannot be double-booked.
   - Flutter `BookingModel` JSON serialization/deserialization maintains 100% roundtrip fidelity for all 13 fields, including legacy bookings where fulfillment fields are `null`.
2. **E2E Lifecycle Persistence Across All Scenarios (A through I)**:
   - Scenario A: Host Yard $\to$ Host Yard (`bk_mock_host_yard`)
   - Scenario B: Doorstep Delivery $\to$ Host Yard Return (`bk_mock_doorstep`)
   - Scenario C: Host Yard Pickup $\to$ Doorstep Collection Return (`bk_mock_host_pickup_doorstep_return`)
   - Scenario D: Two-Way Doorstep Delivery & Collection (`bk_mock_bothway_doorstep`)
   - Scenario E: Transit Hub Pickup $\to$ Same Transit Hub Return (`bk_mock_transit_hub`)
   - Scenario F: Transit Hub Pickup $\to$ Different Transit Hub Return (`bk_mock_transit_pickup_diff_return`)
   - Scenario G: Operating Branch Pickup $\to$ Different Branch Return (`bk_mock_diff_return`)
   - Scenario H: Legacy Booking Without Fulfillment Metadata (`bk_mock_no_fulfillment`)
   - Scenario I: Combined Doorstep Delivery + Alternate Return Branch (`bk_mock_combined`)
3. **Immutability Invariant Verification**:
   - Every transition (`confirmed -> handover_ready -> ongoing -> return_pending -> completed`) must verify all 13 snapshot fields against the initial pre-transition snapshot. Any mutation fails the test.
4. **Coordinate & Address Isolation**:
   - No coordinate leakage: return destinations never inherit doorstep coordinates unless explicitly a doorstep return collection.
   - Alternate return branches never display the customer delivery address.
5. **Deterministic Visual Evidence Generation**:
   - Automated screenshot test covering the 7 specific scenarios mandated by Phase 29.16 Step 13:
     1. `01_host_yard_booking.png`
     2. `02_doorstep_fulfillment.png`
     3. `03_different_return_branch.png`
     4. `04_handover_location.png`
     5. `05_return_destination.png`
     6. `06_legacy_booking_no_fulfillment.png`
     7. `07_completed_booking_preserved_fulfillment.png`
   - Stored under `docs/evidence/phase29-16-location-fulfillment/`.

---

### 2. Files Requiring Modification or Verification

1. `car_rental_backend/src/bookings/bookings.service.ts`:
   - Extend `overlappingBooking` query to include `BookingStatus.HANDOVER_READY` and `BookingStatus.RETURN_PENDING` to ensure active staging/return lifecycle states prevent double-booking.
2. `car_rental_backend/src/locations/phase29-16-location-fulfillment-e2e.spec.ts`:
   - Extend backend Jest test suite to cover full cross-layer snapshot persistence, full lifecycle progression for all scenarios, and concurrency lock coverage for `HANDOVER_READY` and `RETURN_PENDING`.
3. `apps/vendor_app/test/phase29_16_location_fulfillment_e2e_test.dart`:
   - Extend test suite with:
     - Multi-stage lifecycle persistence across all fulfillment modes comparing all 13 fields at every stage.
     - JSON serialization & deserialization roundtrip tests for Flutter `BookingModel`.
     - Error recovery / transaction safety tests ensuring invalid transitions/OTPs leave state and availability intact.
4. `apps/vendor_app/test/phase29_16_evidence_capture_test.dart`:
   - Align screenshot names and test cases to the 7 required visual artifacts from Step 13.

---

### 3. Verification & Regression Plan

1. **Targeted Tests**:
   - Backend: `npm test -- src/locations/phase29-16-location-fulfillment-e2e.spec.ts src/bookings/handover-inspection.spec.ts`
   - Flutter: `flutter test test/phase29_16_location_fulfillment_e2e_test.dart`
2. **Visual Evidence**:
   - Run `flutter test test/phase29_16_evidence_capture_test.dart` to generate all 7 required PNGs in `docs/evidence/phase29-16-location-fulfillment/`.
3. **Full Regression**:
   - `flutter analyze apps/vendor_app` (0 issues required)
   - `flutter test` across `apps/vendor_app` (190+ tests passing)
   - Backend Jest suite (`npm test`)
4. **Android APK**:
   - `flutter build apk --debug`
5. **Git Checkpoint**:
   - Commit: `feat(vendor): harden location fulfillment e2e integrity (Phase 29.16)`
   - Push to `origin/main` and verify.

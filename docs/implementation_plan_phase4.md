# DriveGo Phase 4 Implementation Plan: Trip Extension + Delivery/Pickup + Additional Driver

This document specifies the technical execution plan for implementing:
1. **Feature 10: Trip Extension**
2. **Feature 26: Delivery / Pickup (Home Delivery & Airport Pickup Add-on for `SELF_DRIVE` / `OUTSTATION`)**
3. **Feature 29: Additional Driver (Normalized Model, KYC Verification, and Add-on Fee)**

---

## User Review Required

> [!IMPORTANT]
> **Trip Type Lock:** `SELF_DRIVE` and `OUTSTATION` are ACTIVE. `LOCAL` and `AIRPORT_TRANSFER` REMAIN COMING SOON / DISABLED.
> Feature 26 (Delivery/Pickup) is strictly an Add-on operational service for `SELF_DRIVE` and `OUTSTATION` rentals.

> [!IMPORTANT]
> **Benchmark Booking Safety:**
> Booking ID: `cmsu5sk3m000qgw1zaf9ftksz`
> Status: `CONFIRMED`, Payment: `PAID`, Refund: `NONE`.
> Must remain 100% untouched.

---

## Proposed Phases & Changes

### Phase 4A: Database Schemas & Migrations

#### [MODIFY] [schema.prisma](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/prisma/schema.prisma)
- Add `TripExtension` model:
  - `id`, `bookingId`, `currentEndDate`, `requestedEndDate`, `extraDays`, `extraHours`, `baseFare`, `platformFee`, `gstAmount`, `totalFare`, `razorpayOrderId`, `razorpayPaymentId`, `status` (`PENDING_PAYMENT`, `CONFIRMED`, `CANCELLED`, `EXPIRED`), `invoiceId`, `createdAt`, `updatedAt`.
  - Relations: `booking Booking`, `invoice Invoice?`.
- Add `DeliveryType` enum and delivery fields to `Booking`:
  - `deliveryType` (`NONE`, `DOORSTEP_DELIVERY`, `DOORSTEP_PICKUP`, `ROUND_TRIP_DELIVERY`).
  - `deliveryAddress`, `deliveryLatitude`, `deliveryLongitude`, `deliveryFee`.
  - `pickupAddress`, `pickupLatitude`, `pickupLongitude`, `pickupFee`.
- Add `AdditionalDriver` model:
  - `id`, `bookingId`, `fullName`, `phone`, `email`, `licenceNumber`, `licenceFrontUrl`, `licenceBackUrl`, `expiryDate`, `kycStatus` (`PENDING`, `VERIFIED`, `REJECTED`), `rejectionReason`, `verifiedAt`, `feeAmount`, `createdAt`, `updatedAt`.
- Create formal Prisma migration `add_trip_extensions_delivery_additional_drivers`.

---

### Phase 4B: Backend Core Engines & APIs

#### [NEW] [trip-extensions.service.ts](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/bookings/trip-extensions.service.ts)
- `getQuote(bookingId, newEndDate)`:
  - Validates `Booking.status === ONGOING`.
  - Performs pessimistic row-level lock on `Car` (`FOR UPDATE`).
  - Checks conflicting future bookings and car `blockedDates`.
  - Computes additional fare, platform fee, GST (18%), and net to vendor.
- `createExtension(bookingId, customerId, newEndDate)`:
  - Generates `TripExtension` in `PENDING_PAYMENT` state.
  - Creates Razorpay order for `extensionTotalFare`.
- `verifyExtensionPayment(bookingId, extId, paymentDetails)`:
  - Validates HMAC SHA256 signature.
  - Updates `TripExtension.status = CONFIRMED`.
  - Atomically updates `Booking.endDate = requestedEndDate`.
  - Generates extension `Invoice`.
  - Emits audit log and notifications.

#### [NEW] [additional-drivers.service.ts](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/kyc/additional-drivers.service.ts)
- `addAdditionalDriver(bookingId, dto)`:
  - Validates max 2 drivers limit.
  - Validates licence expiration and age.
  - Creates `AdditionalDriver` record with `kycStatus: PENDING` (or `VERIFIED` if previously verified).
- `verifyAdditionalDriver(driverId, adminId, isApproved, rejectionReason)`:
  - Admin approval/rejection endpoint with audit logging.

#### [MODIFY] [bookings.service.ts](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/src/bookings/bookings.service.ts)
- Ingest `deliveryType`, `deliveryAddress`, `deliveryFee`, `pickupAddress`, `pickupFee`, and `additionalDrivers` during booking creation.
- Include delivery and driver fees in `Booking.baseFare`, `totalFare`, and `netToVendor`.

---

### Phase 4C: Customer App UX

#### [MODIFY] [addons_step.dart](file:///d:/Flutter/car_rental_monorepo/apps/customer_app/lib/features/booking/presentation/widgets/addons_step.dart)
- Add **Doorstep Delivery & Pickup** configuration:
  - Delivery address input with geocoding/pin picker and calculated fee.
  - Doorstep return collection address.
- Add **Additional Driver** section:
  - Add driver card with Name, Phone, Driving Licence Number, and Licence Photo upload widgets.

#### [MODIFY] [booking_detail_page.dart](file:///d:/Flutter/car_rental_monorepo/apps/customer_app/lib/features/my_bookings/presentation/pages/booking_detail_page.dart)
- Show **"Extend Trip"** card when `booking.status == 'ongoing'`.
- Interactive extension modal with new date/time picker, live price quote, and Razorpay checkout.
- Display Delivery address badges and Additional Driver verification cards.

---

### Phase 4D: Vendor & Admin Portals

#### [MODIFY] [vendor_booking_detail_page.dart](file:///d:/Flutter/car_rental_monorepo/apps/vendor_app/lib/features/bookings/presentation/pages/vendor_booking_detail_page.dart)
- Display Doorstep Delivery address and navigation link.
- Display updated return schedule when a trip extension is confirmed.
- Display authorized Additional Drivers list with verified driving licence cards.

#### [MODIFY] [admin_booking_management_page.dart](file:///d:/Flutter/car_rental_monorepo/apps/admin_panel/lib/features/bookings/presentation/pages/admin_booking_management_page.dart)
- View trip extensions timeline, delivery details, and additional driver verification status.

---

### Phase 4E: Full Integration, Reconciliation & Tests

- Unit tests for `TripExtensionsService` and `AdditionalDriversService`.
- Concurrency test: Two concurrent extension requests for the same vehicle.
- Collision test: Future booking collision blocking extension.
- Flutter analyze and Flutter widget test suite validation.
- Database safety check with `node scratch/check_db_safety.js`.

---

## Verification Plan

### Automated Tests
- `npx prisma validate`
- `npm run build`
- `npm test`
- `flutter analyze`
- `flutter test`

### Database Benchmark Check
- `node scratch/check_db_safety.js` (Confirm benchmark booking `cmsu5sk3m000qgw1zaf9ftksz` remains `CONFIRMED` / `PAID` / `NONE`).

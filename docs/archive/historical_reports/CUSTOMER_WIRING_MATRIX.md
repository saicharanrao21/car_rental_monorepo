# DriveGo — Customer App System Wiring & Verification Matrix

## 1. Overview & Verification Status
This matrix details the full-stack wiring of the DriveGo Customer Mobile Application (`apps/customer_app`), verifying every screen, user journey stage, Riverpod provider, repository call, backend endpoint, and Prisma database entity.

---

## 2. Customer App End-to-End Wiring Matrix

| Journey Stage | Screen / Route | Riverpod State Provider | Repository & API Call | Backend Controller & Endpoint | Prisma Entity | Audit & Verification Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Auth & Profile** | `/auth/phone` | `phoneAuthProvider` | `ApiAuthRepository` -> `POST /auth/otp/send` | `AuthController.sendOtp` (`POST /auth/otp/send`) | `OtpRequest` | **CERTIFIED** |
| **Auth & Profile** | `/auth/otp` | `otpVerificationProvider` | `ApiAuthRepository` -> `POST /auth/otp/verify` | `AuthController.verifyOtp` (`POST /auth/otp/verify`) | `User`, `OtpRequest` | **CERTIFIED** |
| **Discovery** | `/city-selection` | `supportedCitiesProvider` | `ApiCityRepository` -> `GET /cities/supported` | `ConfigEngineController` / `CitiesController` | `City`, `ServiceArea` | **CERTIFIED** |
| **Discovery** | `/cars` | `carSearchProvider` | `ApiCarsRepository` -> `GET /cars` | `CarsController.findAll` (`GET /cars`) | `Car`, `Vendor`, `PickupHub` | **CERTIFIED** |
| **Discovery** | `/cars/:id` | `carDetailProvider(id)` | `ApiCarsRepository` -> `GET /cars/:id` | `CarsController.findOne` (`GET /cars/:id`) | `Car`, `MileagePackage`, `Document` | **CERTIFIED** |
| **Booking Journey** | Fulfillment Mode | `bookingDraftProvider` | `ApiBookingRepository` -> `POST /pricing/quote` | `BookingsController.getQuote` (`POST /pricing/quote`) | `ServiceArea`, `Car` | **CERTIFIED** |
| **Booking Journey** | Doorstep Quote | `doorstepDeliveryProvider` | `ApiBookingRepository` -> `POST /delivery/quote` | `DeliveryController.getQuote` (`POST /delivery/quote`) | `ServiceArea`, `GeoPolygon` | **CERTIFIED** |
| **Booking Journey** | Available Coupons | `availableCouponsProvider` | `ApiBookingRepository` -> `GET /coupons/available` | `CouponsController.getAvailable` (`GET /coupons/available`) | `Coupon` | **CERTIFIED** |
| **Booking Journey** | Coupon Validation | `couponValidationNotifier` | `ApiBookingRepository` -> `POST /coupons/validate` | `CouponsController.validate` (`POST /coupons/validate`) | `Coupon`, `CouponRedemption` | **CERTIFIED** |
| **Booking Journey** | Create Booking | `bookingCreationNotifier` | `ApiBookingRepository` -> `POST /bookings` | `BookingsController.create` (`POST /bookings`) | `Booking`, `Payment`, `LedgerTransaction` | **CERTIFIED (Server-Authoritative Pricing)** |
| **Payments** | Payment Sheet | `paymentProcessingNotifier` | `ApiPaymentsRepository` -> `POST /payments/create-order` | `PaymentsController.createOrder` (`POST /payments/create-order`) | `Payment`, `Booking` | **CERTIFIED** |
| **Payments** | Payment Verify | `paymentVerificationNotifier` | `ApiPaymentsRepository` -> `POST /payments/verify` | `PaymentsController.verify` (`POST /payments/verify`) | `Payment`, `LedgerTransaction` | **CERTIFIED** |
| **Active Trip** | `/bookings/:id` | `bookingDetailProvider(id)` | `ApiBookingRepository` -> `GET /bookings/:id` | `BookingsController.findOne` (`GET /bookings/:id`) | `Booking`, `Car`, `Vendor` | **CERTIFIED** |
| **Active Trip** | Handover Sign | `handoverInspectionNotifier` | `ApiBookingRepository` -> `POST /bookings/:id/handover` | `BookingsController.submitHandover` (`POST /bookings/:id/handover`) | `HandoverInspection`, `Booking` | **CERTIFIED** |
| **Active Trip** | Extend Booking | `tripExtensionNotifier` | `ApiBookingRepository` -> `POST /bookings/:id/extend` | `BookingsController.extend` (`POST /bookings/:id/extend`) | `Booking`, `Payment` | **CERTIFIED** |
| **Trip End** | Return Inspection | `returnInspectionNotifier` | `ApiBookingRepository` -> `POST /bookings/:id/return` | `BookingsController.submitReturn` (`POST /bookings/:id/return`) | `ReturnInspection`, `DamageClaim` | **CERTIFIED** |
| **Feedback** | Submit Review | `reviewSubmissionNotifier` | `ApiReviewsRepository` -> `POST /reviews` | `ReviewsController.create` (`POST /reviews`) | `Review`, `Vendor` | **CERTIFIED** |

---

## 3. Financial & Coupon Wiring Audit

### 3.1 Strict Server-Side Pricing Guarantee
1. When the customer enters promo code `DRIVEGO500` or selects an available coupon from the modal:
   - `validateCoupon({ couponCode, estimatedFare, carId })` is dispatched to `POST /coupons/validate`.
   - The backend validates all business rules (start/end validity dates, minimum purchase amount, per-user redemption count, global usage cap, applicable cities).
   - If valid, the backend returns the discount amount, which is displayed in the UI price breakdown.
2. When creating the final booking (`POST /bookings`):
   - The client **only** submits the `couponCode` string.
   - The backend `BookingsService.create()` independently re-evaluates the coupon rules against the authoritative database state, calculates the net fare, generates double-entry ledger entries, and atomically records `CouponRedemption`.
   - No client-manipulated discount amounts can ever be injected into the ledger.

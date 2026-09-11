# DriveGo Phase 29.6 — Checkout & Financial Flow Architecture Audit

**Document Version**: 1.0.0  
**Phase**: Phase 29.6 (Customer Booking Checkout, Price Review, Protection/Add-ons & Payment Experience)  
**Author**: Principal Software Architect, Fintech/Payments Reviewer & CTO  
**Repository**: `d:\Flutter\car_rental_monorepo`  
**Verified Baseline SHA**: `3a07318629aec165edc1b23bf2b106f2dd413c59`

---

## 1. Current Booking Flow

### Architecture Overview
1. **Entry Point**: Customer clicks "Book Now" from `CarDetailPage` (`/cars/:id`), transferring vehicle state, date range, and selected mileage package to `BookingFlowPage` (`/booking/:carId`).
2. **Draft State Management**: `BookingDraft` (`booking_flow_providers.dart`) holds transient booking intent parameters:
   - `carId`, `vendorId`, `tripType` (`SELF_DRIVE`, `OUTSTATION`, `LOCAL`, `AIRPORT_TRANSFER`)
   - `pickupLocation`, `dropLocation`, `startDate`, `endDate`, `estimatedDistanceKm`
   - `selectedMileagePackageId` & `selectedMileagePackage`
   - `selectedProtectionPackageId`, `protectionFee`
   - `driverIncluded`, `childSeat`, `extraLuggage`
   - `hasDoorstepDelivery`, `deliveryAddress`, `deliveryFee`
   - `hasDoorstepPickup`, `returnPickupAddress`, `returnPickupFee`
   - `hasAdditionalDriver`, `additionalDriverName`, `additionalDriverPhone`, `additionalDriverLicence`, `additionalDriverFee`
   - `contactName`, `contactPhone`
   - `appliedCouponCode`, `couponDiscountAmount`, `appliedCoupon`
3. **Multi-Step Hierarchy**:
   - **Step 0 — Trip Details**: Location, pickup/drop times, vehicle recap, mileage package selector (`BookingTripScheduleCard`, `BookingMileagePackageSelector`).
   - **Step 1 — Plan & Add-ons**: Protection package radio selection (`BookingProtectionSection`) and convenience add-ons (`BookingAddonsSection`).
   - **Step 2 — Contact & Driver Info**: Driver full name, phone number, KYC verification status indicator (`ContactConfirmStep`, `BookingCustomerForm`).
   - **Step 3 — Review & Fare**: Authoritative fare calculation summary, coupon validation field (`POST /coupons/validate`), referee first-booking discount badge, and security deposit breakdown (`FareBreakdownStep`).
   - **Step 4 — Payment**: Payment method selection (UPI, Cards, Net Banking, Wallet toggle), payment order creation (`POST /payments/create-order`), Razorpay SDK launch / mock payment flow, and server-side cryptographic payment verification (`POST /payments/verify`).
4. **Authoritative Backend Creation (`POST /bookings`)**:
   - Acquires Redis distributed lock on `carId`.
   - Validates car existence, vendor verification status (`VERIFIED`), car availability (`isAvailable: true`), blocked date overlap, and trip type support.
   - Calculates authoritative duration, base rental fare (respecting weekly/monthly discount tiers), commission, platform fee, statutory GST, delivery fees, protection fee, coupon discount or referee referral discount, and dynamic security deposit.
   - Executes synchronous fraud risk assessment (`FraudService.evaluateUserRisk`).
   - Opens PostgreSQL transaction with pessimistic row-level lock (`SELECT id FROM "Car" WHERE id = ... FOR UPDATE`) to eliminate double-booking race conditions.
   - Creates `Booking` record with `status: PENDING` and linked `SecurityDeposit` record with `status: REQUIRED`.

---

## 2. Current Checkout Flow

- **Page Structure**: Single `BookingFlowPage` managing progressive sub-steps via `IndexedStack` and step indicator (`BookingProgressIndicator`).
- **Sticky Summary CTA Bar**: `BookingStickyBottomBar` positioned in `SafeArea` at the bottom of the screen displaying real-time estimated total, breakdown bottom sheet trigger (`BookingPriceBreakdownCard`), and contextual primary action button.
- **Client Fare Estimation Engine**: Client executes `FareCalculatorService.calculateFare` mirroring backend formula to provide fluid UI updates during parameter changes. The final authoritative payable total is strictly governed by the backend upon booking and order creation.

---

## 3. Current Payment Flow

1. **Order Creation (`POST /payments/create-order`)**:
   - Requires valid `bookingId` owned by authenticated customer with `status: PENDING`.
   - Re-checks existing `Payment` row: if already `PAID` or `REFUNDED`, rejects with conflict; if `CREATED` or `FAILED`, cleans up row to permit retry.
   - Computes total payable = `tripFare + securityDeposit`.
   - Evaluates wallet contribution if `useWallet: true`: uses `promoBalance` first, then `realBalance`.
   - If `gatewayAmount <= 0`, creates full wallet order (`order_wallet_full_<bookingId>`) with 0 paise amount.
   - If `gatewayAmount > 0`, creates Razorpay order (or mock order in non-production) for `amountInPaise`.
   - Inserts `Payment` record with `status: CREATED`.
2. **Gateway Initiation (`PaymentFlowService.launchRazorpayCheckout`)**:
   - Launches Razorpay mobile SDK on Android/iOS with `keyId`, `order_id`, `amount`, `prefill` (name, phone, email).
3. **Payment Verification (`POST /payments/verify`)**:
   - Validates ownership, booking existence, order ID binding.
   - Checks idempotency: if already `PAID`, immediately returns confirmation.
   - Cryptographically verifies HMAC-SHA256 signature using `RAZORPAY_KEY_SECRET` (or `mock_signature` in non-prod).
   - In production, calls Razorpay REST API to verify amount (in paise), INR currency, and `captured` status.
   - In atomic `$transaction`:
     - Settle wallet debit if `walletRequired > 0` (`LedgerEntryType.CHECKOUT_DEBIT`).
     - Updates `Payment` status to `PAID`.
     - Updates `SecurityDeposit` status to `HELD` (`heldAt: new Date()`).
     - Records coupon usage in `CouponUsage` table.
     - Emits `PAYMENT_SUCCESS` event, enqueues invoice generation and customer/vendor notifications.

---

## 4. Current Wallet Flow

- **Backend Ledger Architecture**: Double-entry ledger (`WalletLedgerEntry`) tracking `direction` (`CREDIT`/`DEBIT`), `type` (`CUSTOMER_DEPOSIT`, `CHECKOUT_DEBIT`, `TRIP_REFUND`, `PROMOTIONAL_CREDIT`, `REFERRAL_BONUS`, `ADMIN_ADJUSTMENT`), and `bucket` (`REAL_MONEY`, `PROMOTIONAL`).
- **Dynamic Usability Endpoint (`GET /wallet/usable?bookingAmount=X`)**:
   - Re-checks and cleans expired promotional credits.
   - Evaluates `SystemConfig` rules: `minBookingAmountForWalletUse`, `maxWalletPaymentPercentage`, `maxPromoCreditPerBooking`, `maxDailyWalletUsage`.
   - Computes usable amount, promo breakdown, real money breakdown, and returns authoritative approval/rejection reason.
- **Atomic Checkout Debit**: `WalletsService.debitWallet` executes within the payment verification database transaction, debiting promotional balance before real balance.

---

## 5. Current Coupon Flow

- **Validation Endpoint (`POST /coupons/validate`)**:
   - Checks active status, date validity, global usage limits, per-customer redemption count, and first-booking-only flag.
   - Validates context constraints: `city`, `tripType`, `carCategory`, and `minBookingAmount`.
   - Computes authoritative discount (`PERCENTAGE` with optional `maxDiscountAmount` cap, or `FIXED`).
   - Returns `{ valid: true, couponId, code, discountAmount, finalPayableAmount }`.
- **Available Coupons Endpoint (`GET /coupons/available?city=X`)**: Returns list of active public coupons matching customer eligibility.
- **Redemption Enforcement**: Bound to booking in `POST /bookings` and finalized upon payment in `POST /payments/verify`.

---

## 6. Current Referral Flow

- **Referee First-Booking Discount (`GET /referrals/eligibility`)**:
   - Checks if customer was referred and has 0 completed/confirmed bookings.
   - Returns `{ eligible: true, discountAmount: 300, minBookingAmount: 1500, referrerName: '...' }`.
   - Automatically applied in backend `createBooking` if no coupon code was entered.
- **Referrer Reward**: Credited as promotional wallet balance upon completion of referee's first trip.

---

## 7. Current Deposit Flow

- **Deposit Rule Resolution**: `DepositRulesService.getDepositAmount(carType, city)` dynamically resolves security deposit requirement (e.g. ₹0 for budget/compact hatchbacks, ₹2,000–₹5,000 for sedans/SUVs, ₹10,000+ for luxury).
- **Hold & Release Lifecycle**:
   - `REQUIRED`: Attached to draft and created booking.
   - `HELD`: Upon payment confirmation, marked held with timestamp.
   - `REFUNDED`: After return vehicle inspection with 0 damage claims, refunded to source within policy window.
   - `FORFEITED` / `PARTIALLY_REFUNDED`: In case of damage deductions or traffic challans.

---

## 8. Existing Idempotency Mechanisms

1. **Redis Car Lock**: Distributed lock during booking creation (`BookingLockService.acquireLock(carId)`).
2. **Database Row Lock**: `SELECT id FROM "Car" WHERE id = ... FOR UPDATE` inside Prisma transaction.
3. **Payment Record Binding**: One unique `Payment` record per `bookingId`. Duplicate order creation replaces non-paid orders; already-paid orders reject duplicate payments.
4. **Payment Verification Idempotency**: If payment is already `PAID`, `verifyPayment` returns success immediately without re-debiting wallet or duplicate ledger insertions.
5. **Wallet Debit Nonce**: `idempotencyKey: "wallet_checkout_debit_<bookingId>"` on `WalletLedgerEntry`.

---

## 9. Existing Payment Gateway Integration

- **Primary Gateway**: Razorpay (`razorpay_flutter` client SDK + `@razorpay/razorpay` backend SDK).
- **Mock Fallback**: `RAZORPAY_USE_MOCK=true` for non-production environments with strict runtime prevention in production (`NODE_ENV === 'production'` throws critical security error).
- **Webhook Endpoint**: `POST /payments/webhook` with `x-razorpay-signature` verification handling async payment authorization/capture.

---

## 10. Existing Booking Transaction Boundaries

- **Booking Creation**:
   - Phase 1 (Outside DB tx): Redis lock, Car & Vendor read validation, Fare & Commission calculation, Coupon/Referral validation, Protection package resolution, Fraud risk score evaluation.
   - Phase 2 (Inside DB tx, 15s timeout): Pessimistic row-lock on Car, Overlapping booking query (`PENDING`, `CONFIRMED`, `ONGOING`), `Booking` + `SecurityDeposit` creation.
   - Phase 3 (Post DB tx): Redis cache invalidation (`cache:search:cars:*`, `cache:car:<id>`), Vendor notification dispatch.
- **Payment Verification**:
   - Single atomic DB transaction executing Payment status update, SecurityDeposit status update, Wallet balance deduction + Ledger creation, and CouponUsage insertion.

---

## 11. Existing Failure / Retry Handling

- **Payment Cancellation / Error**: Razorpay modal dismissal or card decline records error in `PaymentStepState`; booking remains in `PENDING` status allowing user to retry payment without re-filling trip details.
- **Payment Order Retry**: `createOrder` cleanly deletes existing `CREATED`/`FAILED` payment orders before generating a fresh order ID.
- **Network Glitch During Verification**: Client performs 3 retries polling `GET /bookings/:id` to check if webhook or async worker already confirmed the transaction.

---

## 12. Existing Refund Handling

- **Cancellation Refund Engine**: `CancellationPolicyService.calculateRefund` calculates refund amount and penalty based on hours before trip start:
   - `> 24h`: 100% refund of rental fare + 100% deposit.
   - `6h – 24h`: 50% refund of rental fare + 100% deposit.
   - `< 6h`: 0% refund of rental fare + 100% deposit.
- **Refund Settlement**: `PaymentsService.processRefund` initiates Razorpay refund API call and credits wallet if wallet was used.

---

## 13. Existing KYC Requirements

- **Backend Endpoints**: `POST /kyc/submit` (driving licence number, expiry, front/back image URLs), `GET /kyc/status`.
- **Status Lifecycle**: `NOT_SUBMITTED`, `PENDING` (under admin review), `APPROVED` (eligible for pickup), `REJECTED` (requires re-upload).
- **Checkout Policy**: Self-drive rentals require customer to present original DL and Government ID at vehicle handover. KYC status is surfaced in the checkout flow.

---

## 14. Existing API Gaps

1. **Add-on Catalog Endpoint**: Backend currently supports add-on fields in `CreateBookingDto` (`driverIncluded`, `childSeat`, `extraLuggage`, `deliveryType`, `deliveryAddress`, `deliveryFee`, `pickupAddress`, `pickupFee`), but does not have a dedicated generic dynamic `GET /addons` catalog. Pricing for standard add-ons is governed by vehicle type and delivery location.
2. **Coupons Stacking Policy**: Backend strictly enforces either a coupon code OR referee referral discount (referral applied only when `couponCode` is absent). This is mathematically sound and prevents multi-discount exploits.

---

## 15. Existing UI Gaps & Modernization Opportunities

1. **DDS Token Compliance**: Align all checkout steps with Phase 29 `DDSColors`, `DDSTypography`, `DDSSpacing`, `DDSRadius`, `DDSElevation`, and `DriveGoButton`.
2. **Visual Hierarchy in Review Step**: Upgrade `FareBreakdownStep` into an intuitive review card separating Trip Details, Driver Info, Add-ons, transparent price line items, and the 100% Refundable Security Deposit banner.
3. **Wallet Balance Usability UX**: Integrate real-time `GET /wallet/usable` call with clear visual separation between Promotional Balance and Real Money.
4. **Enhanced Payment Processing & Error States**: Replace raw snackbar alerts with full animated loading states, explicit failure recovery views with retry triggers, and instant navigation to the modernized Booking Confirmation page.
5. **Modernized Confirmation Page**: Upgrade `BookingConfirmationPage` with order summary, host pickup instructions, security deposit refund timeline badge, downloadable tax invoice action, and one-tap customer support entry.

---

## 16. Security Risks & Mitigations

| Risk | Threat Vector | Mitigation Strategy |
| :--- | :--- | :--- |
| **Price Tampering** | Client manipulates discount or total in HTTP payload | Backend recalculates every fare component authoritatively from database; client-supplied prices are ignored. |
| **Double Booking** | Concurrent users book same vehicle simultaneously | Redis car lock + DB pessimistic row-lock (`SELECT FOR UPDATE`) inside transaction. |
| **Payment Signature Spoofing** | Attacker calls `/payments/verify` with fake signature | Backend validates HMAC-SHA256 signature using server-secret and verifies captured amount with Razorpay REST API in production. |
| **Wallet Overdraft / Replay** | Replay of checkout debit requests | Double-entry ledger with `idempotencyKey: "wallet_checkout_debit_<bookingId>"` and atomic transactional balance checks. |
| **IDOR in Booking / Payment** | User attempts to pay for or view another user's booking | Strict `booking.customerId === req.user.userId` checks across all customer endpoints. |

---

## 17. Financial Risks & Mitigations

| Risk | Impact | Mitigation Strategy |
| :--- | :--- | :--- |
| **Deposit Commingling** | Customer confuses refundable deposit with trip expenses | UI and backend strictly isolate `totalFare` from `securityDeposit.amount`; deposit is explicitly marked 100% refundable. |
| **Uncaptured Payment Confirmation** | Booking marked confirmed while payment is authorized but uncaptured | Backend verification requires `status === 'captured'` before transitioning payment to `PAID`. |
| **Orphaned Orders** | User creates multiple orders without paying | Previous `CREATED`/`FAILED` orders for the same booking are purged on retry; booking remains `PENDING` until verified. |

---

## 18. Recommended Implementation Boundaries

1. **Keep Backend Authoritative**: All prices, taxes (statutory GST), discounts, wallet usability, and deposits are computed server-side.
2. **Preserve Database Models & Schemas**: Work strictly with existing Prisma models (`Booking`, `Payment`, `SecurityDeposit`, `Wallet`, `WalletLedgerEntry`, `Coupon`, `ProtectionPackage`, `MileagePackage`).
3. **Refactor & Modernize UI Layer**:
   - `BookingFlowPage`: Streamlined step transitions with DDS design system tokens.
   - `TripDetailsStep`: Vehicle recap, trip schedule, mileage package selection.
   - `AddonsStep`: Protection package selection and convenience add-ons with clear pricing basis.
   - `ContactConfirmStep`: Driver contact form and KYC status badge.
   - `FareBreakdownStep`: Coupon entry, wallet balance breakdown, and transparent price review.
   - `PaymentStep`: Supported payment methods, real-time order creation, Razorpay/Mock handling, payment processing overlay, and error recovery.
   - `BookingConfirmationPage`: Modernized confirmation screen with booking ID, vehicle identity, schedule, payment receipt summary, host contact, invoice download, and support entry.

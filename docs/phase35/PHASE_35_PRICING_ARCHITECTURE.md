# Phase 35: Canonical Pricing & Quote Architecture

## 1. Executive Summary
Phase 35 establishes the **Server-Authoritative Dynamic Pricing, Quote, Fare Calculation & Price Integrity Engine** for DriveGo. The architecture eliminates client-side financial calculations, guarantees that every quote is deterministically calculated on the NestJS backend, and ensures that accepted quotes are preserved as immutable financial snapshots.

---

## 2. Canonical Pricing Domain Model

```
[Client Request: Car, Dates, TripType, Extras, Coupon]
                         │
                         ▼
             [PricingService.generateQuote]
                         │
       ┌─────────────────┼─────────────────┐
       ▼                 ▼                 ▼
[Vehicle Rate]    [Location Fees]    [Discounts & Coupons]
- Daily/Hourly    - Delivery fee     - Multi-day weekly/monthly
- Mileage package - One-way fee      - Validated coupon
                         │
                         ▼
        [Commission & Tax Engine]
        - Platform Fee = baseFare * commission%
        - GST = platformFee * 18%
                         │
                         ▼
             [Security Deposit Engine]
             - DepositRulesService (Category/City)
                         │
                         ▼
     [Canonical Quote & Structured Line Items]
     - BASE_RENTAL
     - DURATION_DISCOUNT / COUPON_DISCOUNT
     - PLATFORM_FEE / GST
     - FULFILLMENT_FEES (Delivery / Hub / One-Way)
     - PROTECTION_FEE
     - SECURITY_DEPOSIT (Refundable)
                         │
                         ▼
  [BookingQuote (15m TTL) + Immutable DB Snapshot]
```

---

## 3. Mathematical Formulae & Calculation Invariants

### 3.1 Rental Duration Calculation
Given start timestamp $S$ and end timestamp $E$:
$$\Delta t = E - S \text{ (in milliseconds)}$$
- **Standard Daily Rental** (`SELF_DRIVE`, `OUTSTATION`):
  $$D_{\text{days}} = \max\left(1, \left\lceil \frac{\Delta t}{86{,}400{,}000} \right\rceil\right)$$
- **Hourly Rental** (`LOCAL`, `AIRPORT_TRANSFER`):
  $$H_{\text{hours}} = \left\lceil \frac{\Delta t}{3{,}600{,}000} \right\rceil$$

### 3.2 Base Rental Rate & Duration Discounts
1. **Package Tier**: If a valid `mileagePackageId` is selected:
   $$R_{\text{initial}} = \text{basePricePerDay} \times D_{\text{days}}$$
2. **Hourly Rate**: If trip type is `LOCAL` or `AIRPORT_TRANSFER`:
   $$R_{\text{initial}} = \text{pricePerHour} \times H_{\text{hours}}$$
3. **Daily Rate**: Default:
   $$R_{\text{initial}} = \text{pricePerDay} \times D_{\text{days}}$$

**Duration Discount**:
$$\text{discountPct} = \begin{cases} 
\text{monthlyDiscountPercent}, & \text{if } D_{\text{days}} \ge 30 \text{ and } \text{monthlyDiscountPercent} > 0 \\
\text{weeklyDiscountPercent}, & \text{if } D_{\text{days}} \ge 7 \text{ and } \text{weeklyDiscountPercent} > 0 \\
0, & \text{otherwise}
\end{cases}$$

$$\text{durationDiscountAmount} = R_{\text{initial}} \times \left(\frac{\text{discountPct}}{100}\right)$$
$$R_{\text{base}} = R_{\text{initial}} - \text{durationDiscountAmount}$$

### 3.3 Platform Commission & Taxes
- Specificity-matched commission percentage $C_{\text{pct}}$ from `CommissionResolverService`:
  $$\text{platformFee} = R_{\text{base}} \times \left(\frac{C_{\text{pct}}}{100}\right)$$
- Goods & Services Tax (GST applies at 18% on platform services):
  $$\text{gstAmount} = \text{platformFee} \times 0.18$$

### 3.4 Location & Fulfillment Charges
Authoritatively quoted from `LocationsService.calculateDeliveryQuote`:
$$\text{fulfillmentTotal} = \text{deliveryFee} + \text{pickupFee} + \text{returnFee} + \text{oneWaySurcharge}$$

### 3.5 Optional Protection Packages & Add-ons
$$\text{protectionFee} = \text{protectionDailyRate} \times D_{\text{days}}$$

### 3.6 Coupon & Referral Discounts
$$\text{couponDiscount} = \text{CouponsService.validateCoupon}(...)$$
$$\text{totalDiscount} = \text{durationDiscountAmount} + \text{couponDiscount}$$

### 3.7 Dynamic Security Deposit
Dynamic deposit required at checkout, refundable upon return:
$$\text{depositAmount} = \text{DepositRulesService.getDepositAmount}(\text{category}, \text{city})$$

### 3.8 Customer Payable & Vendor Settlement Totals
$$\text{tripFare} = R_{\text{base}} + \text{platformFee} + \text{gstAmount} + \text{fulfillmentTotal} + \text{protectionFee} - \text{couponDiscount}$$
$$\text{totalCustomerPayable} = \text{tripFare} + \text{depositAmount}$$
$$\text{netToVendor} = R_{\text{base}} + \text{fulfillmentTotal}$$

---

## 4. Single Canonical Rounding Standard
To avoid floating-point drift and sub-paise ambiguity:
1. All domain calculations are executed using `Prisma.Decimal` (arbitrary-precision fixed point).
2. Every itemized line item is rounded to **2 decimal places** (`.toDecimalPlaces(2)`).
3. Payment gateway orders are derived strictly from the rounded total:
   $$\text{amountInPaise} = \text{Math.round}(\text{totalCustomerPayable} \times 100)$$

---

## 5. Quote Lifecycle & State Machine
Every quote has a discrete lifecycle:
- **`ACTIVE`**: Issued to client, valid for 15 minutes (`expiresAt = createdAt + 15m`).
- **`ACCEPTED`**: Converted into a confirmed booking. Transitions atomically inside database transaction.
- **`EXPIRED`**: Validity window passed without booking creation. Cannot be accepted for booking or payment.
- **`SUPERSEDED`**: A newer quote was requested for the same customer and car draft.

```
 [Generate Quote] ──> ACTIVE ──(15 mins pass)──> EXPIRED
                         │                          │
                    (User confirms)                 └──> [Refresh Quote] ──> ACTIVE
                         │
                         ▼
                     ACCEPTED (Immutable Snapshot Locked)
```

---

## 6. Financial Immutability & Reproducibility
When a customer creates a booking:
1. The quote is verified: must be `ACTIVE`, not expired, matching `carId`, `startDate`, `endDate`, and `tripType`.
2. The quote status transitions to `ACCEPTED`, and `acceptedAt` is recorded.
3. The booking stores `quoteId` and copies the full `priceSnapshot` JSON directly into the `Booking` record.
4. If a vendor later changes `pricePerDay` or taxes change in the future, the historical booking's financial ledger remains 100% reproducible and tamper-proof.

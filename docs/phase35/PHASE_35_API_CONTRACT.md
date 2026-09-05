# DriveGo — Phase 35: Canonical Pricing & Fare Integrity API Contract

## Document Overview
- **Author**: Senior Principal Engineer / CTO
- **System**: DriveGo Multi-Tenant Car Rental Platform
- **Phase**: 35 — Dynamic Pricing + Quote + Fare Calculation + Price Integrity Engine
- **Status**: Production Specification (Locked & Authoritative)

---

## 1. Core Endpoints

### 1.1 Generate Canonical Quote
Creates a server-authoritative quote with line items, applicable taxes, platform fees, delivery surcharges, protection plans, and security deposit.

- **HTTP Method**: `POST`
- **Path**: `/pricing/quote`
- **Auth**: Authenticated Customer / Vendor / Admin (`JwtAuthGuard`)

#### Request Body (`CreateQuoteDto`)
```json
{
  "carId": "car_mumbai_suv_01",
  "startDate": "2026-09-10T10:00:00.000Z",
  "endDate": "2026-09-13T10:00:00.000Z",
  "tripType": "SELF_DRIVE",
  "mileagePackageId": "pkg_unlimited_01",
  "protectionPlanId": "zero_dep_tier",
  "pickupLocationId": "hub_yard_andheri",
  "returnLocationId": "hub_csmia_t2",
  "deliveryAddress": "Terminal 2 Departure Gate 4, Mumbai",
  "customerLatitude": 19.0968,
  "customerLongitude": 72.8745,
  "couponCode": "MONSOON20",
  "idempotencyKey": "idem_quote_cust01_1788629000"
}
```

#### Field Specifications
| Field | Type | Required | Description |
|---|---|---|---|
| `carId` | `string` | **Yes** | Target vehicle UUID |
| `startDate` | `ISO8601 String` | **Yes** | Trip start timestamp (must be in future) |
| `endDate` | `ISO8601 String` | **Yes** | Trip end timestamp (`endDate > startDate`) |
| `tripType` | `TripType enum` | No | `LOCAL`, `OUTSTATION`, `AIRPORT_TRANSFER`, `SELF_DRIVE` (default `SELF_DRIVE`) |
| `mileagePackageId` | `string` | No | Configured mileage package tier ID |
| `protectionPlanId` | `string` | No | Selected protection plan (`standard_tier`, `zero_dep_tier`) |
| `pickupLocationId` | `string` | No | Pickup hub UUID |
| `returnLocationId` | `string` | No | Return hub UUID (triggers one-way surcharge if different) |
| `deliveryAddress` | `string` | No | Doorstep delivery destination |
| `customerLatitude` | `number` | No | Delivery location latitude (for geofenced dispatch) |
| `customerLongitude`| `number` | No | Delivery location longitude |
| `couponCode` | `string` | No | Promo code to apply server-side |
| `idempotencyKey` | `string` | No | Client idempotency key (15-minute caching) |

#### Response (`201 Created` / `200 OK`)
```json
{
  "success": true,
  "statusCode": 201,
  "message": "Authoritative quote generated successfully",
  "data": {
    "quoteId": "quote_cm7x89ab10001",
    "tenantId": "tenant_mumbai_hub",
    "carId": "car_mumbai_suv_01",
    "vehicleName": "Hyundai Creta SX(O)",
    "registrationNumber": "MH02AB1234",
    "tripType": "SELF_DRIVE",
    "startDate": "2026-09-10T10:00:00.000Z",
    "endDate": "2026-09-13T10:00:00.000Z",
    "durationDays": 3,
    "durationHours": 72,
    "currency": "INR",
    "pricingVersion": "v1.0",
    "subtotal": 6000.00,
    "discountTotal": 600.00,
    "feesTotal": 150.00,
    "taxTotal": 1035.00,
    "depositTotal": 3000.00,
    "tripFare": 6585.00,
    "totalPayable": 9585.00,
    "netToVendor": 5400.00,
    "status": "ACTIVE",
    "createdAt": "2026-09-05T16:30:00.000Z",
    "expiresAt": "2026-09-05T16:45:00.000Z",
    "lineItems": [
      {
        "type": "BASE_RENTAL",
        "name": "Base Vehicle Rental (3 days)",
        "description": "₹2000.00/day × 3 days",
        "rate": 2000.00,
        "quantity": 3.0,
        "amount": 6000.00,
        "isRefundable": false,
        "displayOrder": 1
      },
      {
        "type": "COUPON_DISCOUNT",
        "name": "Coupon Discount (MONSOON20)",
        "description": "10% off base rental",
        "rate": 600.00,
        "quantity": 1.0,
        "amount": -600.00,
        "isRefundable": false,
        "displayOrder": 2
      },
      {
        "type": "PLATFORM_FEE",
        "name": "Platform Convenience Fee",
        "description": "Standard booking processing fee",
        "rate": 150.00,
        "quantity": 1.0,
        "amount": 150.00,
        "isRefundable": false,
        "displayOrder": 3
      },
      {
        "type": "TAX_GST",
        "name": "Statutory GST (18%)",
        "description": "Statutory GST on rental services and platform fee",
        "rate": 1035.00,
        "quantity": 1.0,
        "amount": 1035.00,
        "isRefundable": false,
        "displayOrder": 4
      },
      {
        "type": "SECURITY_DEPOSIT",
        "name": "Refundable Security Deposit",
        "description": "Held in escrow; refundable upon post-trip inspection",
        "rate": 3000.00,
        "quantity": 1.0,
        "amount": 3000.00,
        "isRefundable": true,
        "displayOrder": 5
      }
    ],
    "metadata": {
      "baseDailyRate": 2000.00,
      "weeklyDiscountPercent": 10,
      "protectionDeductible": 0,
      "distanceIncluded": "Unlimited"
    }
  }
}
```

---

### 1.2 Inspect Quote by ID
Retrieves an existing quote with automatic status refresh (transitions to `EXPIRED` if current time exceeds `expiresAt`).

- **HTTP Method**: `GET`
- **Path**: `/pricing/quote/:id`
- **Auth**: Authenticated Customer / Vendor / Admin (`JwtAuthGuard`)
- **Access Control**:
  - Customers can only access quotes created for their session.
  - Vendors can only access quotes for cars within their tenant fleet.
  - Admins can inspect any quote platform-wide.

---

### 1.3 Refresh Expired Quote
Recalculates a fresh quote based on current vehicle rates, mileage packages, and updated pricing rules.

- **HTTP Method**: `POST`
- **Path**: `/pricing/quote/:id/refresh`
- **Auth**: Authenticated Customer (`JwtAuthGuard`)
- **Behavior**:
  - Marks original quote as `EXPIRED` if not already expired.
  - Generates a fresh `ACTIVE` quote with a new 15-minute TTL.

---

## 2. Integrated Booking Lifecycle Contract (`/bookings`)

### 2.1 Booking Creation with Quote (`POST /bookings`)
Clients supply `quoteId` obtained from the pricing engine.

#### Request Fragment
```json
{
  "carId": "car_mumbai_suv_01",
  "quoteId": "quote_cm7x89ab10001",
  "tripType": "SELF_DRIVE",
  "startDate": "2026-09-10T10:00:00.000Z",
  "endDate": "2026-09-13T10:00:00.000Z",
  "pickupHubId": "hub_yard_andheri",
  "returnHubId": "hub_csmia_t2"
}
```

#### Server-Side Invariants:
1. **Verification**: Backend verifies quote exists, belongs to tenant, matches vehicle and dates.
2. **TTL Validation**: Rejects quote with `409 Conflict` if `now > expiresAt`.
3. **Atomic Transition**: Atomically marks quote `status = ACCEPTED` inside the database transaction.
4. **Authoritative Amount Binding**:
   - `booking.totalFare` := `quote.totalPayable`
   - `booking.platformFee` := `quote.feesTotal`
   - `booking.gstAmount` := `quote.taxTotal`
   - `booking.netToVendor` := `quote.netToVendor`
   - `booking.priceSnapshot` := Full frozen JSON representation of the quote and line items.
   - Client-sent totals are strictly ignored.

---

## 3. Integrated Payment Integrity Contract (`/payments/orders`)

### 3.1 Payment Order Creation (`POST /payments/orders`)
```json
{
  "bookingId": "bk_cm7x89xy0002",
  "currency": "INR",
  "idempotencyKey": "idem_pay_ord_001"
}
```

#### Server-Side Invariants:
1. Backend fetches booking along with its accepted `quote` and `priceSnapshot`.
2. **Mismatch Defense**:
   ```typescript
   if (quote && Math.abs(booking.totalFare - quote.totalPayable) > 0.01) {
     throw new ConflictException("Financial integrity breach: booking total does not match authoritative quote");
   }
   ```
3. **Gateway Order Amount**:
   - Always derived from `booking.totalFare` (in integer paise: `Math.round(totalFare * 100)`).
   - Razorpay order amount matches the accepted quote total exactly.

---

## 4. Error Semantics & Status Codes

| HTTP Status | Error Code | Reason / Trigger |
|---|---|---|
| `400 Bad Request` | `VALIDATION_FAILED` | Invalid ISO dates, start date in past, or `endDate <= startDate` |
| `404 Not Found` | `CAR_NOT_FOUND` / `QUOTE_NOT_FOUND` | Vehicle ID or Quote ID does not exist |
| `409 Conflict` | `QUOTE_EXPIRED` | Attempting to accept or book using a quote whose TTL has passed |
| `409 Conflict` | `PRICE_MISMATCH` | Detected discrepancy between booking amount and accepted quote snapshot |
| `409 Conflict` | `QUOTE_ALREADY_ACCEPTED` | Replay attempt to accept an already consumed quote |
| `403 Forbidden` | `CROSS_TENANT_ACCESS` | Vendor attempting to inspect quote belonging to another tenant |

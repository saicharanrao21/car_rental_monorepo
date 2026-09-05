# DRIVEGO — PHASE 31 OPERATIONAL EVENT CATALOG
## TAXONOMY OF SUPPORTED OPERATIONAL NOTIFICATIONS

This catalog defines the 16 canonical operational events supported by the Phase 31 notification platform across Booking, Fulfillment, Payment, Escrow, and Dispute lifecycles.

---

### 1. BOOKING LIFECYCLE EVENTS

| Event Code | Priority | Target Audience | Channels Enabled | Variables Interpolated | Description |
|---|---|---|---|---|---|
| `BOOKING_CREATED` | NORMAL | Customer, Vendor | In-App, Push, Email | `customerName`, `bookingId`, `vehicleName`, `pickupTime`, `totalAmount` | Sent upon initial booking reservation. |
| `BOOKING_CONFIRMED` | NORMAL | Customer, Vendor | In-App, Push, SMS, WhatsApp, Email | `customerName`, `bookingId`, `vehicleName`, `registrationNumber`, `pickupAddress`, `pickupTime` | Sent after payment capture & vendor confirmation. |
| `BOOKING_CANCELLED` | HIGH | Customer, Vendor | In-App, Push, SMS, Email | `customerName`, `bookingId`, `vehicleName`, `refundAmount` | Triggered when a booking is cancelled by user or vendor. |
| `HANDOVER_READY` | HIGH | Customer, Vendor | In-App, Push, SMS, WhatsApp | `customerName`, `bookingId`, `vehicleName`, `pickupAddress`, `pickupOtp` | Notifies customer that vehicle is prepped & prompts OTP presentation. |
| `RENTAL_STARTED` | NORMAL | Customer, Vendor | In-App, Push, Email | `customerName`, `bookingId`, `vehicleName`, `returnTime` | Triggered when handover inspection is approved. |
| `RETURN_PENDING` | HIGH | Customer, Vendor | In-App, Push, SMS, WhatsApp | `customerName`, `bookingId`, `vehicleName`, `returnAddress`, `returnTime` | Reminder dispatched 2 hours prior to scheduled return. |
| `BOOKING_COMPLETED` | NORMAL | Customer, Vendor | In-App, Push, Email | `customerName`, `bookingId`, `vehicleName` | Sent after return inspection approval and odometer verification. |

---

### 2. FULFILLMENT LIFECYCLE EVENTS

| Event Code | Priority | Target Audience | Channels Enabled | Variables Interpolated | Description |
|---|---|---|---|---|---|
| `DOORSTEP_DISPATCH_STARTED`| NORMAL | Customer | In-App, Push, SMS | `customerName`, `bookingId`, `vehicleName`, `deliveryAddress` | Chauffeur / runner dispatched with vehicle to customer location. |
| `VEHICLE_DELIVERED` | NORMAL | Customer, Vendor | In-App, Push | `customerName`, `bookingId`, `vehicleName` | Vehicle delivered to customer doorstep. |
| `BRANCH_RELOCATION_RETURN` | NORMAL | Vendor | In-App, Push | `bookingId`, `vehicleName`, `returnAddress` | Return location adjusted to alternate approved branch hub. |

---

### 3. PAYMENT & REFUND LIFECYCLE EVENTS

| Event Code | Priority | Target Audience | Channels Enabled | Variables Interpolated | Description |
|---|---|---|---|---|---|
| `PAYMENT_CAPTURED` | NORMAL | Customer | In-App, Push, SMS, Email | `customerName`, `bookingId`, `paymentAmount` | Razorpay webhook verification success. |
| `PAYMENT_FAILED` | HIGH | Customer | In-App, Push, SMS | `customerName`, `bookingId`, `paymentAmount` | Gateway debit failure, card rejection, or signature mismatch. |
| `REFUND_PROCESSED` | NORMAL | Customer | In-App, Push, SMS, Email | `customerName`, `bookingId`, `refundAmount` | Idempotent gateway refund executed to customer source account. |
| `REFUND_FAILED` | HIGH | Customer, Admin | In-App, Push, Email | `customerName`, `bookingId`, `refundAmount` | Gateway error or bank account invalidity during refund attempt. |

---

### 4. ESCROW, PAYOUT & DISPUTE LIFECYCLE EVENTS

| Event Code | Priority | Target Audience | Channels Enabled | Variables Interpolated | Description |
|---|---|---|---|---|---|
| `SETTLEMENT_ELIGIBLE` | NORMAL | Vendor | In-App, Push, Email | `vendorName`, `bookingId`, `payoutAmount` | Escrow quarantine lifted; funds moved to vendor settled balance. |
| `ESCROW_HOLD_DISPUTED` | HIGH | Customer, Vendor | In-App, Push, Email | `bookingId`, `disputeReason` | Damage claim opened; security deposit and payout quarantined pending review. |

---

### 5. TEMPLATE INTERPOLATION STANDARDS
All templates are declared declaratively in `src/notifications/templates/notification-templates.ts`. 
- **Variable Syntax**: `{{variableName}}`
- **Sanitization**: All variables are stringified and HTML-escaped before rendering into Email templates.
- **Privacy Enforcement**: Customer phone numbers, passwords, OTP secrets, card PANs, and internal database foreign keys are strictly excluded from broadcast bodies.

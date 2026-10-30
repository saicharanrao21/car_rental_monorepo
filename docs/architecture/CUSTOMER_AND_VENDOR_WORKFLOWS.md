# DRIVEGO — CUSTOMER & VENDOR WORKFLOWS SPECIFICATION
## 23-Stage Customer Journey, Fleet Partner Operations & Vehicle Inspection Protocols

> **Document Reference**: `docs/architecture/CUSTOMER_AND_VENDOR_WORKFLOWS.md`  
> **Classification**: Core Marketplace Journey Standard  
> **Status**: APPROVED — PRODUCTION BLUEPRINT  
> **Author**: DriveGo Product Experience & Operations Architecture Group  

---

## 1. THE 23-STAGE END-TO-END CUSTOMER JOURNEY

The customer booking lifecycle encompasses 23 distinct operational checkpoints:

```
[1. Registration] ──> [2. Contact OTP] ──> [3. Profile & KYC] ──> [4. Search Vehicles]
                                                                          │
                                                                          ▼
[8. Deposit Disclosure] <── [7. Price Breakdown] <── [6. Availability] <── [5. Vehicle Detail]
         │
         ▼
[9. Booking Request] ──> [10. Payment Capture] ──> [11. Booking Confirmed] ──> [12. Pickup Scheduling]
                                                                                       │
                                                                                       ▼
[16. Active Trip] <── [15. Handover OTP Verified] <── [14. Collateral Verified] <── [13. Pre-Trip Inspection]
         │
         ▼
[17. Return Scheduling] ──> [18. Post-Trip Inspection] ──> [19. Return OTP Verified] ──> [20. Collateral Released]
                                                                                                │
                                                                                                ▼
                                                  [23. Reviews & Support] <── [22. Final Invoice] <── [21. Deposit Refunded]
```

---

## 2. PRE-TRIP & POST-TRIP VEHICLE INSPECTION SOP

Vehicle condition disputes are eliminated through mandatory standardized photographic inspections:

1. **Mandatory 8-Angle Photographic Evidence**:
   - Angle 1: Front Full View
   - Angle 2: Front Left Quarter (Bumper + Wheel + Headlight)
   - Angle 3: Left Side Profile (Doors + Windows)
   - Angle 4: Rear Left Quarter
   - Angle 5: Rear Full View (Trunk + Rear Bumper)
   - Angle 6: Rear Right Quarter
   - Angle 7: Right Side Profile
   - Angle 8: Front Right Quarter
2. **Dashboard & Fuel/Odometer Verification**:
   - Close-up photo of the illuminated dashboard showing odometer reading and fuel gauge level.
   - Attendant manually enters starting odometer in kilometers and starting fuel in percentage.
3. **Monotonic Odometer Rule**:
   - Backend invariant: Return odometer must strictly be $\ge$ Handover odometer ($\text{Odometer}_{\text{return}} \ge \text{Odometer}_{\text{handover}}$). Any attempt to record a return odometer lower than handover odometer is rejected immediately with code `INVALID_ODOMETER_REGRESSION`.

---

## 3. CRYPTOGRAPHIC HANDOVER OTP PROTOCOL

Vehicle release and return are secured by cryptographically generated One-Time Passwords:

1. **Generation & Dispatch**:
   - Handover OTP is generated server-side using cryptographically secure pseudorandom numbers (`crypto.randomInt(100000, 999999)`).
   - Salted and hashed using `bcrypt` (10 rounds) before database storage. The raw OTP is never stored in plaintext in the database.
   - Dispatched to the customer's phone via WhatsApp and SMS.
2. **Security Interlocks**:
   - **Time-to-Live (TTL)**: 15 minutes.
   - **Attempt Limit**: Maximum 5 invalid attempts before the OTP is permanently locked.
   - **Atomic Invalidation**: Upon successful comparison, the OTP record is atomically marked `verified = true` to prevent replay attacks.
3. **Handover Trigger**:
   - When the vendor enters the verified OTP into the Vendor App, the booking status atomically transitions from `CONFIRMED` or `HANDOVER_READY` to `ONGOING`.

---

## 4. ACTIVE TRIP TELEMATICS, GEOFENCING & IMMOBILIZER

1. **AIS-140 GPS Streaming**: Location, speed, battery level, and engine status ingested in real-time.
2. **Speed Alerts**: Automatic warning notifications dispatched to customer if speed exceeds 80 km/h on state roads or 100 km/h on national expressways.
3. **Geofencing & Boundary Crossings**: Real-time alerts when vehicle exits permitted state boundaries without required interstate permits.
4. **Emergency Engine Immobilizer**:
   - Controlled exclusively by Admin Operations Dispatchers in confirmed vehicle theft or criminal emergency situations.
   - Safety interlock: Immobilizer can only trigger when vehicle speed drops below 5 km/h.

---

## 5. RETURN INSPECTION, DAMAGE CLAIMS & DISPUTE TRIBUNAL

1. **Return Inspection**: Vendor repeats the 8-angle photo inspection and dashboard odometer/fuel logging.
2. **Damage Claim Submission**:
   - If new damage is detected, vendor logs a `DamageClaim` within 2 hours of return, attaching photos of the damage.
   - Claimed amount entered with repair estimate.
3. **Escrow Hold & Customer Dispute**:
   - Customer is immediately notified and given 24 hours to contest the claim with their own photos or rebuttal notes.
4. **Tribunal Adjudication**:
   - Operations Reviewer reviews pre-trip vs post-trip photos.
   - If approved: Approved amount is deducted from the customer's security deposit, and any remaining balance is refunded.
   - If rejected: The full security deposit is released to the customer.

---
*Ratified by DriveGo Product Experience & Operations Architecture Group.*


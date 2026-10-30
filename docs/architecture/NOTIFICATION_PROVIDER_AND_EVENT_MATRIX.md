# DRIVEGO — NOTIFICATION PROVIDER & EVENT ROUTING MATRIX
## Omnichannel Notification Architecture, Provider Failover & 25-Lifecycle Routing Standards

> **Document Reference**: `docs/architecture/NOTIFICATION_PROVIDER_AND_EVENT_MATRIX.md`  
> **Classification**: Authoritative Communications Standard  
> **Status**: APPROVED — PRODUCTION BLUEPRINT  
> **Author**: DriveGo Infrastructure & Communications Architecture Group  

---

## 1. OMNICHANNEL ENGINE ARCHITECTURE & PROVIDERS

DriveGo consolidates all customer, vendor, and administrative messaging into a centralized `NotificationOrchestratorService` backed by Redis message queues, template rendering, and automated failover circuits:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   COMMUNICATIONS ENGINE SELECTION                      │
├─────────────┬──────────────────────────┬───────────────────────────────┤
│ CHANNEL     │ PRIMARY PROVIDER         │ ENTERPRISE FAILOVER PROVIDER  │
├─────────────┼──────────────────────────┼───────────────────────────────┤
│ WhatsApp    │ Meta WhatsApp Cloud API  │ Gupshup Enterprise WhatsApp   │
├─────────────┼──────────────────────────┼───────────────────────────────┤
│ SMS         │ MSG91 (DLT Approved)     │ Twilio International          │
├─────────────┼──────────────────────────┼───────────────────────────────┤
│ Email       │ SendGrid Transactional   │ Resend / AWS SES              │
├─────────────┼──────────────────────────┼───────────────────────────────┤
│ Mobile Push │ Firebase Cloud Messaging │ Apple Push Notification (APN) │
└─────────────┴──────────────────────────┴───────────────────────────────┘
```

### Channel Specifics & Regulatory Mandates
1. **WhatsApp (Meta Cloud API + Gupshup Fallback)**:
   - Primary channel for transactional booking confirmations, Handover OTP delivery, digital vehicle custody receipts, and trip extension requests.
   - Native interactive buttons ("View Booking", "Share Live Location", "Contact Hub").
2. **SMS (MSG91 DLT Registered + Twilio Fallback)**:
   - Fully compliant with TRAI Distributed Ledger Technology (DLT) regulations under the Telecom Commercial Communications Customer Preference Regulations (TCCCPR, 2018).
   - Every transactional SMS carries a registered Entity ID, Header ID, and Template ID.
   - Automatic fallback triggered if WhatsApp delivery status is unacknowledged within 180 seconds.
3. **Email (SendGrid + Resend Fallback)**:
   - Formal channel for GST Tax Invoices, signed Master Rental Agreements (with digital cryptographic SHA-256 hash), dispute resolution verdicts, and monthly statements.
4. **Push Notifications (Firebase Cloud Messaging - FCM)**:
   - Real-time mobile alerts for driver assignment, geofence border warnings, speed alerts, and return countdown timers.

---

## 2. THE 25-EVENT LIFECYCLE ROUTING MATRIX

| # | Event Name | Target Recipient | Primary Channel | Failover Channel | DLT / Template ID | Key Payload Variables |
|---|---|---|---|---|---|---|
| **01** | Account Registration OTP | Customer / Vendor | WhatsApp | SMS | `DLT_110716001` | `otpCode`, `expiresInMin` |
| **02** | KYC Submitted for Review | Customer / Vendor | Push + Email | SMS | `wa_kyc_submitted` | `userName`, `referenceId` |
| **03** | KYC Approved & Activated | Customer / Vendor | WhatsApp + Push | Email | `DLT_110716003` | `userName`, `dashboardUrl` |
| **04** | KYC Rejected with Reason | Customer / Vendor | WhatsApp + Email | SMS | `wa_kyc_rejected` | `userName`, `rejectionReason` |
| **05** | Booking Requested | Vendor Manager | Push + WhatsApp | SMS | `wa_vendor_booking_req`| `bookingId`, `carModel`, `dates` |
| **06** | Booking Confirmed | Customer | WhatsApp + Email | SMS | `DLT_110716006` | `bookingId`, `carModel`, `pickupTime` |
| **07** | Booking Payment Receipt | Customer | Email + WhatsApp | — | `wa_payment_receipt` | `bookingId`, `amount`, `invoiceUrl` |
| **08** | Pickup Reminder (T-2h) | Customer | WhatsApp + Push | SMS | `wa_pickup_reminder` | `customerName`, `hubAddress` |
| **09** | Vehicle Ready for Handover | Customer | Push + WhatsApp | — | `wa_vehicle_ready` | `carModel`, `plateNumber`, `hubBay` |
| **10** | Pickup Handover OTP | Customer | WhatsApp + SMS | Push | `DLT_110716010` | `otpCode`, `carModel`, `plateNumber` |
| **11** | Customer Collateral Secured| Customer | WhatsApp + Email | Push | `wa_collateral_custody` | `collateralType`, `identifier`, `yardSlot` |
| **12** | Trip Started / Vehicle Released| Customer & Vendor | Push + WhatsApp | Email | `wa_trip_started` | `bookingId`, `odometer`, `fuelPercent`|
| **13** | Speed Limit Warning | Customer | Push + WhatsApp | Voice Call | `wa_speed_alert` | `currentSpeed`, `limitSpeed`, `location` |
| **14** | Geofence Boundary Breach | Customer & Operations | Push + Voice Call | WhatsApp | `wa_geofence_breach` | `bookingId`, `zoneName` |
| **15** | Return Reminder (T-1h) | Customer | WhatsApp + Push | SMS | `wa_return_reminder` | `returnTime`, `hubAddress` |
| **16** | Return Handover OTP | Customer | WhatsApp + SMS | Push | `DLT_110716016` | `otpCode`, `bookingId` |
| **17** | Collateral Returned | Customer | WhatsApp + Email | Push | `wa_collateral_released`| `collateralType`, `identifier`, `hubName` |
| **18** | Deposit Refund Initiated | Customer | WhatsApp + SMS | Email | `DLT_110716018` | `refundAmount`, `bookingId` |
| **19** | Damage Claim Logged | Customer | Email + WhatsApp | Push | `wa_damage_claim` | `bookingId`, `claimedAmount` |
| **20** | Damage Tribunal Verdict | Customer & Vendor | Email + WhatsApp | — | `wa_dispute_verdict` | `bookingId`, `finalAmount` |
| **21** | Final Tax Invoice Dispatched| Customer | Email | WhatsApp | `wa_tax_invoice` | `invoiceNumber`, `pdfDownloadUrl` |
| **22** | Vendor Weekly Earnings | Vendor | Email + WhatsApp | — | `wa_vendor_weekly_payout`| `weekPeriod`, `netPaid` |
| **23** | Vendor Reserve Released | Vendor | WhatsApp + Email | — | `wa_reserve_released` | `reservedAmount`, `bookingId` |
| **24** | Account Deletion Requested | Customer | Email + SMS | Push | `DLT_110716024` | `gracePeriodDays`, `reactivateUrl` |
| **25** | Emergency Immobilized Alert | Customer & Operations | Push + Voice Call | SMS | `wa_immobilizer_alert` | `bookingId`, `emergencyContact` |

---
*Ratified by DriveGo Infrastructure & Communications Architecture Group.*


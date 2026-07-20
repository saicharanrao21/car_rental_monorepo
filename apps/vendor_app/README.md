# Vendor Registry & Dashboard (`vendor_app`)

The operational control app for vehicle fleet owners. Vendors can register their business, list vehicles, accept or manage booking schedules, and track detailed earnings metrics.

## Key Features

1. **Vendor KYC Registration**: Form for business info, bank details, and PAN/GST document mock uploaders.
2. **Dashboard Overview**: Quick KPIs, upcoming bookings feed, and quick actions.
3. **Fleet Manager**: Add and edit cars in the vendor's fleet, set features/pricing, and toggle active/maintenance status.
4. **Booking Manager**: Lifecycle operations for vehicle handoffs (Accept, Reject, Start Trip, End Trip).
5. **Earnings Panel**: Visual bar chart of daily earnings, payout tables, and commission transparency calculations.

## How to Run

```bash
cd apps/vendor_app
flutter run
```

## Backend Integration Points

* **Document Storage**: Upload KYC PDF/Image documents to AWS S3 or Google Cloud Storage.
* **KYC Verification**: Connect PAN and GST fields to standard government API verification gateways.
* **Database Mutations**: Sync vehicle additions and status changes with a central relational database.
* **Push Notifications**: Receive real-time ride request alerts from customers.

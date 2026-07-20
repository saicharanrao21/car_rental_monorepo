# Administrative Control Panel (`admin_panel`)

A web-focused, desktop-first management dashboard for platform administrators. Admins have complete control over system setups, vendor approvals, customer logs, commission structures, campaigns, and global settings.

## Key Features

1. **Analytical Dashboard**: Visual metrics on global bookings, active earnings, and vendor performance rankings.
2. **Vendor Approval Pipeline**: Inspect business documents, toggle verification statuses, and view vendor fleets.
3. **Fleet & Booking Ledger**: Centralized view of all vehicles and bookings with advanced filtering (city, category, status).
4. **Commission Rules Engine**: Manage fee brackets and simulate earnings calculations dynamically.
5. **Campaigns & Banners**: Drag-and-drop banner reordering, active status toggles, and new banner forms.
6. **Push Composer**: Broadcast notifications to segmented target groups with a live mock device preview.
7. **System Settings**: Configure platform properties, GST details, support channels, and toggle Dark Mode.

## How to Run

```bash
cd apps/admin_panel
flutter run -d chrome
```

## Backend Integration Points

* **Admin Authorization**: Hook up Firebase Auth or standard admin credentials verification.
* **Server-side Data Tables**: Move search and filter logic to DB index queries (instead of in-memory searches) for performance.
* **FCM Broadcast**: Hook notification submit action up to Firebase Admin SDK to push global alerts.
* **CSV Export**: Generate and download real CSV files using server-side reporting services.

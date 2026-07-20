# DriveGo Car Rental Aggregator — Flutter Monorepo

This monorepo houses a comprehensive, multi-platform car rental aggregator platform tailored for the Indian market. The architecture is modular, clean, and entirely driven by Riverpod state management and GoRouter.

## Monorepo Architecture

```
e:/Flutter/car_rental_monorepo
├── apps/
│   ├── customer_app/      # Customer-facing app (Android, iOS, Web)
│   ├── vendor_app/        # Vendor-facing registry & dashboard app (Android, iOS)
│   └── admin_panel/       # Web-only administrative control center (Desktop & Tablet)
└── packages/
    ├── core/              # Shared constants, strings, theme, calculations, formatting
    ├── models/            # Domain entities, Freezed models, & JSON serialization
    ├── mock_data/         # In-memory database of mock cars, bookings, vendors, banners
    └── ui_kit/            # Reusable UI library (AppButton, AppCard, AppLoader, Responsive helpers)
```

## Getting Started

### 1. Prerequisites
Ensure you have the Flutter SDK installed and configured.

### 2. Bootstrap the Workspace
We use Melos to manage dependencies across the monorepo.
```bash
# Activate Melos globally
dart pub global activate melos 2.9.0

# Bootstrap packages and run pub get everywhere
melos bootstrap
```

### 3. Build Runner (Generation)
To regenerate serialized files or data models:
```bash
melos run build_runner
```

### 4. Running the Applications
Run each application locally from its directory or via melos:
- **Customer App**: `cd apps/customer_app && flutter run`
- **Vendor App**: `cd apps/vendor_app && flutter run`
- **Admin Panel**: `cd apps/admin_panel && flutter run -d chrome`

---

## Mocked vs. Production Backend Wiring

For developer handoff and presentation, the entire platform is functional using a mock database in `packages/mock_data`. Below is a guide for what is currently mocked and what needs wiring to a real backend.

### 1. Authentication & Session Management
* **Mocked**: `MockAuthRepository` and session controllers simulate success/failure for email/OTP logins without external verification.
* **Production**: Wire up Firebase Auth, Supabase Auth, or a custom OAuth/JWT server.

### 2. Vehicle Registry & Bookings
* **Mocked**: Cars list and bookings are stored in-memory in the `MockData` static registry.
* **Production**: Connect repositories to REST/GraphQL APIs backed by PostgreSQL or Firestore to store cars, filter locations, and manage trip logs.

### 3. Payments, Revenue, & Commissions
* **Mocked**: Refund calculations, platform commissions, and fare estimates are computed on the client side using core services.
* **Production**: Integrate Stripe or Razorpay SDKs for payment processing and Webhooks to capture transactions.

### 4. Banners & Notifications
* **Mocked**: Creating, reordering, and deleting banners, and sending push notifications, only logs to the console via `debugPrint` and updates the UI state.
* **Production**: Wire up Firebase Cloud Messaging (FCM) or OneSignal for push alerts, and AWS S3/Firebase Storage for media assets.

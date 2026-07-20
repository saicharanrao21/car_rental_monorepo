# Customer Application (`customer_app`)

The client-facing portal for booking rental cars. Customers can filter by location, date ranges, and categories, select extra services, apply promo codes, and schedule rides.

## Key Features

1. **OTP Login Simulator**: Multi-step phone verification layout.
2. **Interactive Search**: Filters by Indian cities, booking categories, and dates.
3. **Vehicle Fleet Browser**: View car details, specs, vendor profiles, and trip models (Self-Drive, Outstation).
4. **Checkout Engine**: Fare calculator incorporating insurance, driver additions, and coupon discounts.
5. **Trips Ledger**: Active & past bookings, cancellation options, and mock refund estimators.

## How to Run

```bash
cd apps/customer_app
flutter run
```

## Backend Integration Points

* **Auth**: Connect `SessionNotifier` to Firebase Auth or an OAuth provider.
* **Search & Listings**: Fetch vehicles dynamically from a PostgreSQL database with location coordinates.
* **Payment Processing**: Integrate a payment gateway like Razorpay or Stripe on the checkout screen.
* **FCM Push Notifications**: Configure Firebase Cloud Messaging to receive booking alerts.

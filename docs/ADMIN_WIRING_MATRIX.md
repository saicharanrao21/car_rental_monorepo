# DriveGo — Admin Panel System Wiring & Verification Matrix

## 1. Overview & Verification Status
This matrix details the full-stack wiring of the DriveGo Admin Panel (`apps/admin_panel`), verifying every navigation item, presentation page, Riverpod provider, API repository, backend controller endpoint, and Prisma database entity.

---

## 2. Admin Panel End-to-End Wiring Matrix

| Section / Group | Screen / Route | Riverpod State Provider | Repository & API Call | Backend Controller & HTTP Method | Prisma Model / Entity | Audit & Verification Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Core Operations** | `/dashboard` | `adminDashboardStatsProvider` | `ApiAdminDashboardRepo` -> `GET /admin/dashboard/stats` | `AdminController.getStats` (`GET /admin/dashboard/stats`) | `Booking`, `Vendor`, `Car`, `LedgerAccount` | **CERTIFIED** |
| **Core Operations** | `/bookings` | `adminBookingsProvider` | `ApiAdminBookingsRepo` -> `GET /admin/bookings` | `AdminBookingsController.findAll` (`GET /admin/bookings`) | `Booking`, `User`, `Car` | **CERTIFIED** |
| **Core Operations** | `/bookings/:id` | `adminBookingDetailProvider` | `ApiAdminBookingsRepo` -> `GET /admin/bookings/:id` | `AdminBookingsController.findOne` (`GET /admin/bookings/:id`) | `Booking`, `Payment`, `LedgerTransaction` | **CERTIFIED** |
| **Fleet & Partners** | `/vendors` | `adminVendorsProvider` | `ApiAdminVendorRepo` -> `GET /admin/vendors` & `GET /vendors` | `AdminVendorsController.findAll` (`GET /admin/vendors`) & `VendorsController.findAll` | `Vendor`, `User`, `Car` | **CERTIFIED (Fixed Contract: added search & status alias)** |
| **Fleet & Partners** | `/vendors/:id` | `adminVendorDetailProvider` | `ApiAdminVendorRepo` -> `GET /vendors/:id` | `VendorsController.findOne` (`GET /vendors/:id`) | `Vendor`, `Car`, `Document` | **CERTIFIED** |
| **Fleet & Partners** | Status Toggle | `adminVendorStatusNotifier` | `ApiAdminVendorRepo` -> `PATCH /admin/vendors/:id/status` | `AdminVendorsController.updateStatus` (`PATCH /admin/vendors/:id/status`) | `Vendor.verificationStatus` | **CERTIFIED (Route wired in controller & repo)** |
| **Fleet & Partners** | `/cars` | `adminCarsProvider` | `ApiAdminCarsRepo` -> `GET /admin/cars` | `AdminCarsController.findAll` (`GET /admin/cars`) | `Car`, `Vendor`, `PickupHub` | **CERTIFIED** |
| **Fleet & Partners** | `/hubs` | `adminHubsProvider` | `ApiAdminHubsRepo` -> `GET /admin/hubs` | `AdminHubsController.findAll` (`GET /admin/hubs`) | `PickupHub`, `City` | **CERTIFIED** |
| **Growth & Marketing** | `/coupons` | `adminCouponsProvider` | `ApiAdminCouponsRepo` -> `GET /admin/coupons` | `AdminCouponsController.findAll` (`GET /admin/coupons`) | `Coupon`, `CouponRedemption` | **CERTIFIED (Fixed: Added route in router, sidebar nav, E2E test)** |
| **Growth & Marketing** | Create Coupon | `adminCouponsNotifier` | `ApiAdminCouponsRepo` -> `POST /admin/coupons` | `AdminCouponsController.create` (`POST /admin/coupons`) | `Coupon` | **CERTIFIED (Verified via E2E widget test)** |
| **Growth & Marketing** | Toggle Coupon | `adminCouponsNotifier` | `ApiAdminCouponsRepo` -> `PATCH /admin/coupons/:id/status` | `AdminCouponsController.updateStatus` (`PATCH /admin/coupons/:id/status`) | `Coupon.isActive` | **CERTIFIED** |
| **Finance & Ledger** | `/revenue` | `adminRevenueStatsProvider` | `ApiAdminRevenueRepo` -> `GET /admin/revenue` | `AdminRevenueController.getRevenue` (`GET /admin/revenue`) | `LedgerTransaction`, `LedgerBalance` | **CERTIFIED** |
| **Finance & Ledger** | `/payouts` | `adminPayoutsProvider` | `ApiAdminPayoutsRepo` -> `GET /admin/payouts` | `AdminPayoutsController.findAll` (`GET /admin/payouts`) | `VendorPayout`, `LedgerTransaction` | **CERTIFIED** |
| **Compliance & Areas** | `/service-areas` | `adminServiceAreasProvider` | `ApiAdminServiceAreasRepo` -> `GET /admin/service-areas` | `AdminServiceAreasController.findAll` (`GET /admin/service-areas`) | `ServiceArea`, `GeoPolygon` | **CERTIFIED** |
| **Compliance & Areas** | `/onboarding/reqs` | `adminRequirementsProvider` | `ApiAdminRequirementsRepo` -> `GET /admin/vendors/onboarding/definitions` | `AdminVendorOnboardingController.getDefinitions` (`GET /admin/vendors/onboarding/definitions`) | `OnboardingRequirementDefinition` | **CERTIFIED** |
| **System & Security** | `/audit-logs` | `adminAuditLogsProvider` | `ApiAdminAuditRepo` -> `GET /admin/audit-logs` | `AuditLogsController.findAll` (`GET /admin/audit-logs`) | `AuditLog`, `User` | **CERTIFIED** |
| **System & Security** | `/config` | `adminConfigEngineProvider` | `ApiAdminConfigRepo` -> `GET /admin/config-engine` | `ConfigEngineController.getConfig` (`GET /admin/config-engine`) | `SystemConfigParameter` | **CERTIFIED** |

---

## 3. Audited Gaps & Closed Items

### 3.1 Orphaned Coupons Page Fully Integrated
- **Prior Problem**: `AdminCouponsPage` existed in the codebase (`lib/features/coupons/presentation/pages/admin_coupons_page.dart`) with full CRUD state management, but was omitted from `app_router.dart` and the Admin sidebar navigation tree (`admin_shell.dart`).
- **Resolution**:
  - Registered `GoRoute(path: '/coupons', builder: (context, state) => const AdminCouponsPage())` in `app_router.dart`.
  - Added `AdminNavItem(label: 'Coupons & Promo Codes', icon: Icons.local_offer_outlined, route: '/coupons')` under the `Growth & Marketing` navigation category in `admin_shell.dart`.
  - Resolved UI rendering constraints (header `Expanded` wrapper, dropdown `isExpanded: true`, `Material` wrapper for `SwitchListTile`).
  - Added E2E verification test `apps/admin_panel/test/admin_coupons_e2e_test.dart` passing 2/2 tests cleanly.

### 3.2 Vendor Query & Status Contract Alignment
- **Prior Problem**: Admin vendor queries passed `search` and `status` query parameters, while backend `VendorsQueryDto` strictly expected `verificationStatus` and lacked full-text search across phone, email, city, and business name. Additionally, `@Patch(':id/status')` was mounted only under `/vendors/:id/status` rather than canonically under `/admin/vendors/:id/status`.
- **Resolution**:
  - Added `search?: string` and alias `status?: VerificationStatus` to `VendorsQueryDto`.
  - Updated `vendors.service.ts` `findAll()` to perform case-insensitive multi-field filtering across `businessName`, `ownerName`, `city`, `user.phone`, and `user.email`.
  - Added `@Patch(':id/status')` directly to `AdminVendorsController` with `Role.ADMIN` security enforcement.

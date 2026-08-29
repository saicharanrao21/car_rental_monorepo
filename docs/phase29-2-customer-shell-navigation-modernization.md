# DriveGo — Phase 29.2: Customer App Shell, Navigation & Brand Header Modernization

## 1. Executive Summary
Phase 29.2 initiates the first screen-level modernization for DriveGo by establishing a unified, accessible, and high-converting Customer Application Shell. Powered directly by the foundational design tokens of the DriveGo Design System (DDS) established in Phase 29.1, this phase modernizes the root navigation container (`AppShell`), the authoritative location & brand header (`HomeHeaderWidget`), and the primary navigation endpoints without modifying underlying business logic, state schemas, or deep-nested feature screens.

---

## 2. Shell Architecture

### 2.1 Before vs After Comparison
- **Previous Legacy State**:
  - Legacy `BottomNavigationBar` with hardcoded fixed colors and generic elevation shadows.
  - No adaptive tablet/desktop layout support (stretched full width on larger screens).
  - Legacy `AppBar` with inconsistent text styling and basic static icons.
  - Manual notifications without dynamic unread count calculation.
- **Modernized DDS State**:
  - Material 3 `NavigationBar` with `DDSColors.surfaceCard`, 1px `borderLight` top border, and subtle 4% elevation shadow (`Color(0x0A000000)`).
  - Material 3 electric blue pill indicator (`DDSColors.primaryBlue.withValues(alpha: 0.12)`) on active tab destinations.
  - Fully adaptive navigation: automatically switches to a high-contrast side `NavigationRail` on tablet/desktop viewports (`DDSBreakpoints.isTablet` / `isDesktop`).
  - Authoritative `HomeHeaderWidget` featuring `DDSColors.primaryNavy`, contextual time-of-day greeting, bold location title with Amber pin indicator, and dynamic notifications badge.

---

## 3. Component Specifications

### 3.1 Adaptive App Shell (`apps/customer_app/lib/core/widgets/app_shell.dart`)
- **Destinations**:
  1. **Home**: `Icons.home_outlined` / `Icons.home_rounded`, label: `'Home'`
  2. **Search**: `Icons.explore_outlined` / `Icons.explore_rounded`, label: `'Search'`
  3. **Bookings**: `Icons.directions_car_outlined` / `Icons.directions_car_rounded`, label: `'Bookings'`
  4. **Profile**: `Icons.person_outline_rounded` / `Icons.person_rounded`, label: `'Profile'`
- **Ergonomics & Safe Area**:
  - `SafeArea(top: false)` wrapper ensures the navigation bar sits cleanly above hardware gesture navigation bars on Android and iOS home indicator bars.
  - Minimum touch target heights meet WCAG standards (>= 48px, container height: 64px).

### 3.2 Authoritative Brand & Location Header (`apps/customer_app/lib/features/home/presentation/widgets/home_header_widget.dart`)
- **Brand Theme**: `DDSColors.primaryNavy` background with crisp white typography and amber accents.
- **Contextual Greeting**: Automatic resolution of time-of-day greeting (`"Good morning"`, `"Good afternoon"`, `"Good evening"`).
- **Location Selector**:
  - Prominent city chip with `Icons.location_on_rounded` in `DDSColors.accentAmber`.
  - Tapping opens the modal bottom sheet for city search and manual switching.
  - Real-time loading indicator (`CircularProgressIndicator` in amber) while GPS geocoding/nearest city resolution is in flight.
- **Top Actions**:
  - Saved Cars / Wishlist (`Icons.favorite_border_rounded` with tooltip `'Saved Cars'`).
  - Notifications (`Icons.notifications_none_rounded` with tooltip `'Notifications'`).
  - Dynamic unread count badge (`unreadNotificationsCountProvider`) rendering red indicator dot or count pill when unread messages exist.

---

## 4. Location UX & Multi-City Architecture
The location header binds seamlessly to `userLocationProvider` and `selectedCityProvider`:
1. **Device Location / GPS**: Displays current detected city with auto-prompt to switch when moving between regions.
2. **Manual Selection**: Tap opens `_SearchableCitySelector` modal supporting all 5 seeded metropolitan regions (Mumbai, Delhi, Bangalore, Chennai, Hyderabad).
3. **Immutability & Safety**: City change propagates cleanly to search and homepage filters without breaking state.

---

## 5. Visual Verification Evidence (AVD Emulator)

All flows have been launched and visually verified on Android Emulator (`sdk gphone64 x86 64`):

| Step | Screen | Artifact Path | Description |
|---|---|---|---|
| 01 | Splash Screen | `docs/evidence/phase29-2-customer-shell/01_customer_splash.png` | DriveGo brand car icon with typography on electric blue canvas |
| 02 | Phone Login | `docs/evidence/phase29-2-customer-shell/02_customer_phone_login.png` | Standardized phone input with `+91` prefix and DDS primary CTA button |
| 03 | OTP Verification | `docs/evidence/phase29-2-customer-shell/03_customer_otp_verify.png` | 6-digit OTP verification field with real-time countdown |
| 04 | Customer Home Shell | `docs/evidence/phase29-2-customer-shell/04_customer_home_shell.png` | Brand Header in Navy, Amber location pin, and modernized DDS Bottom Navigation |
| 05 | Location Selector Modal | `docs/evidence/phase29-2-customer-shell/05_customer_location_sheet.png` | Modal bottom sheet with search input and supported cities list |
| 05b | Switched City (Delhi) | `docs/evidence/phase29-2-customer-shell/05b_customer_city_switched.png` | Real-time header and search tile update to selected city (Delhi) |
| 06 | Notifications Screen | `docs/evidence/phase29-2-customer-shell/06_customer_notifications.png` | Clean notifications page with 'Mark all read' action and empty state |
| 06b | Saved Cars (Wishlist) | `docs/evidence/phase29-2-customer-shell/06b_customer_saved_cars.png` | Wishlist empty state with heart illustration |
| 07 | Search / Explore Tab | `docs/evidence/phase29-2-customer-shell/07_customer_search_tab.png` | Active pill indicator on Search tab, showing trip type selection |
| 08 | Bookings Tab | `docs/evidence/phase29-2-customer-shell/08_customer_bookings_tab.png` | Active pill indicator on Bookings tab with categorized trip filters |
| 09 | Profile Tab | `docs/evidence/phase29-2-customer-shell/09_customer_profile_tab.png` | Active pill indicator on Profile tab with user initials and account options |

---

## 6. Testing & Quality Assurance
- **Automated Test Suites**:
  - `apps/customer_app`: **91 / 91 passed** (88 baseline + 3 new shell unit/widget tests)
  - `packages/core`: **8 / 8 passed**
  - `packages/ui_kit`: **13 / 13 passed**
  - `apps/vendor_app`: **17 / 17 passed**
  - `apps/admin_panel`: **11 / 11 passed**
  - **Total Monorepo Flutter Tests**: **140 / 140 passed** (100% green).
- **Static Analysis (`flutter analyze`)**:
  - 0 errors, 0 warnings across all 5 directories.

---

## 7. Deferred Work & Scope Boundaries
- Feature-screen internals (e.g., specific vehicle card designs, booking summary breakdown, checkout stepper, and KYC upload modals) are preserved intact and will be systematically modernized in subsequent dedicated phases (Phases 29.3 – 29.8).

# DRIVEGO DESIGN SYSTEM (DDS) — FOUNDATION SPECIFICATION
**Phase 29.1 Engineering & Architecture Documentation**

**Document Version**: 1.0.0
**Phase**: 29.1 — DDS Shared Design Tokens & UI Kit Component Overhaul
**Status**: Implemented, Tested & Verified
**Protected Git Baseline**: `db48a0f2866af205c8115e65cdc1f3bb9205257c`

---

## 1. Design System Architecture

The **DriveGo Design System (DDS)** establishes a unified, type-safe, multi-tenant visual and structural language across all applications in the DriveGo monorepo:

```
d:\Flutter\car_rental_monorepo\
├── packages/
│   ├── core/                        # DDS Token Engine & Material 3 Themes
│   │   ├── lib/src/
│   │   │   ├── dds_colors.dart      # Semantic color palette
│   │   │   ├── dds_typography.dart  # 8-step typographic scale
│   │   │   ├── dds_spacing.dart     # 8-step spacing scale & standard insets
│   │   │   ├── dds_radius.dart      # Standardized corner radii
│   │   │   ├── dds_elevation.dart   # Standardized elevation & box-shadows
│   │   │   ├── dds_motion.dart      # Transition durations & animation curves
│   │   │   ├── dds_breakpoints.dart # Responsive screen width thresholds
│   │   │   ├── app_theme.dart       # Material 3 light & dark theme generators
│   │   │   ├── app_colors.dart      # Legacy backwards-compatibility alias
│   │   │   └── app_spacing.dart     # Legacy backwards-compatibility alias
│   └── ui_kit/                      # DDS Standard Reusable Components
│       ├── lib/src/
│       │   ├── drivego_button.dart        # Universal primary/secondary/destructive button
│       │   ├── drivego_text_field.dart    # Accessible form input
│       │   ├── drivego_card.dart          # Standardized surface card
│       │   ├── drivego_status_badge.dart  # Unified status badge (booking/KYC/marketplace)
│       │   ├── drivego_price_tag.dart     # Formatted ₹ currency & strikethrough tag
│       │   ├── drivego_loading_state.dart # Shimmer skeleton & circular loaders
│       │   ├── drivego_empty_state.dart   # Zero-data screen placeholder with CTAs
│       │   ├── drivego_error_state.dart   # Resilient error boundary with retry CTA
│       │   ├── drivego_bottom_sheet.dart  # Standard modal sheet with grab handle
│       │   ├── drivego_dialog.dart        # Confirmation & destructive dialogs
│       │   ├── drivego_section_header.dart# Category & list header with action
│       │   ├── drivego_chip.dart          # Filter & choice chip
│       │   └── drivego_app_bar.dart       # Modernized brand app bar
└── apps/
    ├── customer_app/   # Consumes DDS tokens & ui_kit components
    ├── vendor_app/     # Consumes DDS tokens & ui_kit components
    └── admin_panel/    # Consumes DDS tokens & ui_kit components
```

---

## 2. Token Definitions

### Colors (`DDSColors`)

| Token Name | Hex Value | Semantic Purpose |
|---|---|---|
| `primaryNavy` | `#0F172A` | Primary headers, high-contrast text, admin navigation |
| `primaryBlue` | `#1E40AF` | Brand primary color, primary buttons, active tabs |
| `accentAmber` | `#F59E0B` | Ratings, pricing highlights, featured badges |
| `electricCobalt` | `#2563EB` | Interactive focus rings, active toggles |
| `bgCanvas` | `#F8FAFC` | Main light scaffold background (Slate 50) |
| `surfaceCard` | `#FFFFFF` | Clean white surface for cards and sheets |
| `surfaceSubtle` | `#F1F5F9` | Input background fill, subtle chip containers |
| `borderLight` | `#E2E8F0` | Default card borders, dividers, outlines |
| `borderMedium` | `#CBD5E1` | Input enabled borders, active chip outlines |
| `bgDark` | `#0B0F19` | Midnight dark canvas |
| `surfaceDark` | `#151C2C` | Dark theme surface cards |
| `textPrimary` | `#0F172A` | 90% contrast primary text |
| `textSecondary` | `#475569` | 65% contrast secondary text |
| `textMuted` | `#94A3B8` | 45% contrast placeholder and hint text |
| `successGreen` | `#10B981` | Emerald 500 (Confirmed, Active, Verified) |
| `successGreenBg` | `#ECFDF5` | Emerald 50 badge background |
| `warningOrange` | `#F97316` | Orange 500 (Pending, Under Review) |
| `warningOrangeBg` | `#FFF7ED` | Orange 50 badge background |
| `errorRed` | `#EF4444` | Red 500 (Cancelled, Rejected, Failed) |
| `errorRedBg` | `#FEF2F2` | Red 50 badge background |
| `infoBlue` | `#3B82F6` | Blue 500 (Ongoing, In Transit) |
| `infoBlueBg` | `#EFF6FF` | Blue 50 badge background |
| `sponsoredGold` | `#D97706` | Amber 600 sponsored vehicle tag |
| `sponsoredBg` | `#FEF3C7` | Amber 100 sponsored badge background |

---

### Typography Scale (`DDSTypography`)

Driven by `GoogleFonts.plusJakartaSans`:

| Step Name | Size | Weight | Line Height | Letter Spacing | Usage |
|---|---|---|---|---|---|
| `displayLarge` | 32px | 700 (Bold) | 40px | -0.5px | Hero headings |
| `headlineMedium` | 24px | 600 (SemiBold) | 32px | -0.25px | Major section titles |
| `titleLarge` | 18px | 600 (SemiBold) | 24px | 0.0px | Modal headers, card titles |
| `titleMedium` | 16px | 500 (Medium) | 22px | 0.0px | Sub-headers, tab labels |
| `bodyLarge` | 15px | 400 (Regular) | 22px | 0.0px | Primary body text |
| `bodyMedium` | 14px | 400 (Regular) | 20px | 0.0px | Input text, secondary captions |
| `labelLarge` | 14px | 600 (SemiBold) | 18px | +0.2px | Standard button text |
| `labelSmall` | 11px | 600 (SemiBold) | 14px | +0.4px | Badges, small status chips |
| `priceDisplay` | 20px | 800 (ExtraBold)| 24px | -0.5px | Numeric tariff values (₹) |

---

### Spacing & Insets (`DDSSpacing`)

| Token | Value | Purpose |
|---|---|---|
| `xxs` | 4.0px | Micro gap (e.g. icon-to-text) |
| `xs` | 8.0px | Element gap (e.g. input-to-label) |
| `sm` | 12.0px | Compact padding |
| `md` | 16.0px | Standard card padding / item gap |
| `lg` | 24.0px | Section gap / modal padding |
| `xl` | 32.0px | Page block separation |
| `xxl` | 48.0px | Hero section vertical spacing |
| `screenPadding` | `H: 16px, V: 12px` | Standard screen margin |
| `cardPadding` | `16px all` | Standard card internal padding |
| `modalPadding` | `24px all` | Dialog & modal sheet padding |

---

### Radius Scale (`DDSRadius`)

| Token | Value | Applied To |
|---|---|---|
| `small` | 6.0px | Badges, small tags, micro indicators |
| `medium` | 12.0px | Standard cards, text fields, buttons |
| `large` | 18.0px | Bottom sheets, dialogs, hero banners |
| `pill` | 999.0px | Round action pills, avatars, chips |

---

### Elevation & Shadows (`DDSElevation`)

| Token | Elevation | Blur / Offset | Usage |
|---|---|---|---|
| `none` | 0dp | None | Flat inline elements |
| `subtle` | 1dp | `Blur: 4, Y: 1, Opacity: 4%` | Active chips, list items |
| `card` | 2dp | `Blur: 8, Y: 2, Opacity: 6%` | Standard cards |
| `floating` | 4dp | `Blur: 16, Y: 4, Opacity: 10%`| Sticky bottom checkout bars |
| `modal` | 8dp | `Blur: 24, Y: 8, Opacity: 16%`| Bottom sheets & dialogs |

---

### Motion Tokens (`DDSMotion`)

| Token | Duration | Curve | Purpose |
|---|---|---|---|
| `fast` | 150ms | `Curves.easeInOutCubic` | Button press, chip toggle |
| `standard` | 250ms | `Curves.easeInOutCubic` | Screen cross-fade, drawer slide |
| `emphasis` | 350ms | `Curves.easeOutCubic` | Hero banner transitions |
| `sheet` | 300ms | `Curves.easeOutCubic` | Bottom sheet enter / exit |

---

### Breakpoints (`DDSBreakpoints`)

| Identifier | Min Width | Target Devices |
|---|---|---|
| `compactMobile` | < 360px | Small compact Androids |
| `standardMobile`| < 600px | Standard Android/iOS smartphones |
| `tablet` | 600px – 1199px | iPads, Android tablets, foldables |
| `desktop` | >= 1200px | Standard desktop browser / laptops |
| `wideDesktop` | >= 1440px | Large monitors & ultrawide panels |

---

## 3. Standard UI Components

1. **`DriveGoButton`**:
   - Variants: `primary`, `secondary` (outlined), `tertiary` (text), `destructive`.
   - Sizes: `compact` (40px), `standard` (48px), `large` (54px).
   - Features: Built-in `isLoading` spinner without layout shift, `icon` support, full-width or auto-width sizing.
2. **`DriveGoTextField`**:
   - Supports floating/fixed labels, helper text, error text, prefix/suffix widgets, password toggle.
   - Built-in border state transitions (enabled, focused, error, disabled).
3. **`DriveGoCard`**:
   - Standardized surface card with subtle 1px border and 2dp elevation.
   - Clickable with ink ripple (`onTap`).
4. **`DriveGoStatusBadge`**:
   - Auto-resolves status text into semantic color pairs (e.g. `CONFIRMED` $\rightarrow$ Emerald, `PENDING` $\rightarrow$ Orange, `CANCELLED` $\rightarrow$ Red, `SPONSORED` $\rightarrow$ Gold).
5. **`DriveGoPriceTag`**:
   - Displays Indian Rupees (`₹`) via `IndianCurrencyFormatter`.
   - Supports strikethrough original tariff (e.g. ~~₹3,000~~ **₹2,500** /day).
6. **`DriveGoLoadingState`**:
   - Variants: `fullPage`, `card`, `list`, `inline`.
   - Includes `DriveGoShimmerCard` skeleton loader to eliminate blank screens.
7. **`DriveGoEmptyState`**:
   - Clean illustration placeholder with title, description, and primary/secondary CTA buttons.
8. **`DriveGoErrorState`**:
   - Human-readable error message with single-tap `Retry` button and optional secondary action.
9. **`DriveGoBottomSheet`**:
   - Floating modal bottom sheet with top grab handle, header title, close icon, and safe-area insets.
10. **`DriveGoDialog`**:
    - Standard confirmation, warning, and destructive dialog builders.
11. **`DriveGoSectionHeader`**:
    - Category & list title with integrated "See all" or custom action button.
12. **`DriveGoChip`**:
    - Interactive choice & filter chip with animated selection state and optional checkmark.
13. **`DriveGoAppBar`**:
    - Unified header with title, subtitle, back navigation, and action buttons.

---

## 4. Backwards Compatibility & Migration Strategy

- **Zero Breaking Changes**: Legacy classes (`AppButton`, `AppTextField`, `AppCard`, `StatusBadge`, `PriceTag`, `AppLoader`, `EmptyStateWidget`, `ErrorStateWidget`, `AppBottomSheet`, `SectionHeader`) remain in `packages/ui_kit` and forward directly to their DDS counterparts.
- **Zero API/Backend Changes**: All models, services, and business logic remain untouched.
- **Phase-by-Phase Adoption**: Feature pages in `customer_app`, `vendor_app`, and `admin_panel` will be progressively migrated to direct DDS components during Phases 29.2 through 29.12.

---

## 5. Verification & Testing

- **Core Tokens Test Suite**: `packages/core/test/dds_tokens_test.dart` (8 tests passed).
- **Component Test Suite**: `packages/ui_kit/test/dds_components_test.dart` (13 tests passed).
- **Customer App Tests**: 88/88 passed.
- **Vendor App Tests**: 17/17 passed.
- **Admin Panel Tests**: 11/11 passed.
- **Total Flutter Automated Tests**: **137 / 137 passed (100% green)**.
- **Analyzer Check**: `flutter analyze` clean across all 5 packages/apps with **0 errors and 0 warnings**.

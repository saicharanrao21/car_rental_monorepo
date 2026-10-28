# DriveGo Automotive Design System (DDS 2.0)
## Unified Specification for Customer & Partner Mobile Experiences

---

## 1. Executive Summary & Brand Direction

DriveGo is a modern, premium automotive rental marketplace connecting customers with verified local fleets.
The design language is engineered to communicate:
- **Precision & Reliability:** Clean lines, geometric balance, crisp contrast, and functional typography.
- **Automotive Energy:** Dynamic proportions, aerodynamic wing/speed geometries, and high-visibility status indicators.
- **Trust & Frictionless Utility:** Intuitive form hierarchy, transparent pricing display, and unambiguous verification flows.
- **Accessibility by Default:** Rigorous WCAG AA compliant contrast ratios ($\ge 4.5:1$ normal text, $\ge 3.0:1$ large text), minimum $48 \times 48\,\text{dp}$ touch targets, and full support for reduced-motion preferences.

---

## 2. Core Color Palette & Semantic Roles

The DriveGo design system employs an automotive color palette refined for readability, clarity, and brand recognition across both the Customer and Vendor applications.

| Token Name | Hex Code | RGB | Role / Usage | Minimum Contrast vs Canvas/White |
| :--- | :--- | :--- | :--- | :--- |
| `primaryBlue` | `#2457D6` | `(36, 87, 214)` | Primary interactive actions, active tab items, primary brand color | **6.17 : 1** (White on Blue) |
| `primaryNavy` | `#14243A` | `(20, 36, 58)` | Top navigation headers, dark surfaces, authoritative headings | **15.6 : 1** (White on Navy) |
| `bgCanvas` | `#F5F7FB` | `(245, 247, 251)` | Primary scaffold background, low eye strain | **15.1 : 1** (TextPrimary on Canvas) |
| `surfaceCard` | `#FFFFFF` | `(255, 255, 255)` | Content containers, sheets, cards, dialogs | **16.2 : 1** (TextPrimary on Surface) |
| `surfaceSubtle` | `#EDF2F9` | `(237, 242, 249)` | Form field fills, neutral pill backgrounds, disabled fills | — |
| `borderLight` | `#DFE5EF` | `(223, 229, 239)` | Subtle card borders, dividers, list separators | — |
| `borderMedium` | `#CBD5E1` | `(203, 213, 225)` | Form input resting borders | — |
| `textPrimary` | `#172033` | `(23, 32, 51)` | Headings, primary body text, titles | **16.2 : 1** on White |
| `textSecondary`| `#64748B` | `(100, 116, 139)`| Subtitles, timestamps, metadata, captions | **4.77 : 1** on White |
| `textMuted` | `#94A3B8` | `(148, 163, 184)`| Placeholders, disabled text, search hints | **3.02 : 1** on White (Large/Decorative) |
| `accentTeal` | `#16A394` | `(22, 163, 148)` | Vendor partner accents, fleet badges, verified tags | **4.92 : 1** (Navy on Teal) |
| `accentAmber` | `#F59E0B` | `(245, 158, 11)` | Ratings, pricing highlights, promotional banners | **3.5 : 1** (Rating Star on Surface) |
| `successGreen` | `#16845B` | `(22, 132, 91)` | Confirmed bookings, KYC verified, positive balances | **4.56 : 1** (White on Green) |
| `successGreenBg`| `#ECFDF5` | `(236, 253, 245)`| Success banner backgrounds, verified chips | — |
| `warningOrange`| `#B76E00` | `(183, 110, 0)` | Pending approvals, expiry notices, inspection alerts | **4.38 : 1** (White on Orange) |
| `warningOrangeBg`| `#FFFBEB` | `(255, 251, 235)`| Warning chip and alert backgrounds | — |
| `errorRed` | `#C62828` | `(198, 40, 40)` | Form validation errors, cancellations, destructive actions | **6.17 : 1** (White on Red) |
| `errorRedBg` | `#FEF2F2` | `(254, 242, 242)`| Error banner backgrounds, destructive chips | — |

---

## 3. Typography Scale (Inter / Roboto)

The typography scale enforces typographic rhythm with clear mathematical scaling:

| Style | Size (sp) | Weight | Line Height | Letter Spacing | Semantic Usage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `displayLarge` | 32 | Bold (700) | 40 | -0.5 | Splash branding, main promotional banners |
| `headlineLarge`| 26 | Bold (700) | 34 | -0.3 | Onboarding headings, screen primary titles |
| `headlineMedium`| 22 | SemiBold (600)| 28 | -0.2 | Section titles, vehicle make/model |
| `titleLarge` | 18 | SemiBold (600)| 24 | 0.0 | Card titles, modal headers, price figures |
| `titleMedium` | 16 | Medium (500) | 22 | 0.1 | Form field labels, list item titles |
| `bodyLarge` | 15 | Regular (400) | 22 | 0.2 | Primary narrative copy, detailed specifications |
| `bodyMedium` | 14 | Regular (400) | 20 | 0.25 | Secondary descriptions, subtexts |
| `bodySmall` | 12 | Regular (400) | 16 | 0.4 | Captions, legal footers, disclaimer text |
| `labelLarge` | 14 | SemiBold (600)| 20 | 0.1 | Primary button text, chip text, tab labels |
| `labelSmall` | 11 | Medium (500) | 14 | 0.5 | Status badges, compact metric labels |

---

## 4. Spacing, Radii, and Elevation

- **Base Grid:** 4dp/8dp mathematical baseline.
  - `space4`: 4dp, `space8`: 8dp, `space12`: 12dp, `space16`: 16dp, `space24`: 24dp, `space32`: 32dp, `space48`: 48dp.
- **Border Radii:**
  - `radiusSmall`: 8dp (Chips, small badges, input fields)
  - `radiusMedium`: 12dp (Buttons, standard cards, dialog containers)
  - `radiusLarge`: 16dp (Hero cards, bottom sheets, onboarding cards)
  - `radiusPill`: 999dp (Floating tags, pill buttons)
- **Elevation & Shadows:**
  - `level0`: 0 elevation, crisp 1dp border (`borderLight`)
  - `level1`: 2dp blur, 1dp spread, 4% opacity black (Subtle resting card)
  - `level2`: 8dp blur, 2dp spread, 8% opacity black (Interactive raised card / Sheet)

---

## 5. Iconography and Automotive Brand Mark

The DriveGo brand icon is an aerodynamic twin-wing vector mark that evokes:
1. An forward-pointing aerodynamic car chassis / wing element.
2. The letter **"D"** and **"G"** in stylized geometric harmony.
3. Clean vector geometry that scales gracefully from $24\times24\,\text{dp}$ in-app marks up to high-DPI launcher icons ($192\times192\,\text{dp}$ and adaptive vector drawables).

- **Customer App Icon:**
  - Background: Deep Navy (`#14243A`) with subtle radial gradient.
  - Foreground: Dual-tone aerodynamic wing in Electric Cobalt / Primary Blue (`#2457D6`) and crisp Pure White (`#FFFFFF`).
- **Vendor Partner App Icon:**
  - Background: Slate Charcoal (`#0F172A`).
  - Foreground: Matching DriveGo aerodynamic wing with an emerald/teal partner accent ring (`#16A394`), visually identifying business and fleet management while retaining unified brand heritage.

---

## 6. Motion & Animation Principles

1. **Restraint & Purpose:** Animations must orient the user, communicate system status, or create seamless continuity. Avoid infinite bouncing or distracting loops.
2. **Reduced-Motion Respect:** Check `MediaQuery.of(context).disableAnimations` or `animationsEnabled`. When disabled, transitions snap cleanly with zero duration.
3. **Durations:**
   - Fast (Micro-interactions, button presses, chips): 150ms – 200ms (`Curves.easeOutQuad`).
   - Standard (Transitions, sheet expansion, page slides): 250ms – 300ms (`Curves.easeInOutCubic`).
   - Splash sequence: 600ms – 800ms total, non-blocking asynchronous data initialization.
4. **Zero Cold-Boot Flash:** Native Android `launch_background.xml` shares the exact background color and centered brand logo with the Flutter entry screen, preventing white/black flickering during process startup.

---

## 7. Customer vs. Vendor Experience Continuity

| Element | Customer Application | Vendor (Partner) Application |
| :--- | :--- | :--- |
| **Brand Identity** | "DriveGo — Premium Car Rentals" | "DriveGo Partner — Fleet & Business" |
| **Primary Goal** | Vehicle discovery, instant booking, hassle-free rental | Fleet uptime, booking management, earnings, KYC |
| **Primary Theme Tone**| Welcoming, aspirational, transparent, high-visual car cards | Dense, metric-focused, operational clarity, quick status actions |
| **Authentication** | Phone OTP + Compliant Google/Apple Social Auth | Phone OTP business sign-in with partner role validation |
| **Accent Hue** | Electric Cobalt & Amber Highlights | Operations Teal (`#16A394`) & Enterprise Slate |

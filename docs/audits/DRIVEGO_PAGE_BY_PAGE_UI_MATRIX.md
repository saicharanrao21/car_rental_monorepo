# DRIVEGO — PAGE-BY-PAGE UI PRIORITY & COMPLIANCE MATRIX
**Baseline Version:** Git SHA `3b8fdc338b94396255a839be307bfa0074b367df` (origin/main)  
**Author:** Principal UI/UX Architect & QA Lead  
**Scope:** Complete Page-by-Page Audit for Customer App, Vendor App, and Admin Control Tower

---

## 1. Classification Definitions
- **P0 (Critical / Misleading / Broken / Fake):** Broken navigation, fake/mock data presented as real, silent API failures, hardcoded metrics, security/PII leak risks, or blocking user flows.
- **P1 (Major UX / Architectural Debt):** Incomplete state management, lack of error recovery, endpoint contract mismatch, string-based data degradation, or missing required controls.
- **P2 (Modernization Needed):** Functional and stable, but visually outdated (MVP aesthetic), non-DDS token usage, inconsistent elevation/typography, or partial responsive handling.
- **P3 (Polish Only):** High quality, DDS-compliant, fully integrated; only minor micro-animation, spacing, or visual polish needed.

---

## 2. Customer App Audit Matrix (23 Routes)

| Route Path | Page / Screen Name | Data Source (Real/Mock/Hybrid) | DDS Compliance | Loading / Empty / Error States | Priority | Detailed Findings & Recommended Remediation |
|---|---|---|---|---|---|---|
| `/splash` | `SplashPage` | REAL (Session check) | FULL (DDS) | Handled smoothly | **P3** | Clean branding and session initialization. No issues found. |
| `/onboarding` | `OnboardingPage` | REAL (Local State) | FULL (DDS) | Handled | **P3** | Modern illustration carousel with persistent completion flag in secure storage. |
| `/auth/phone` | `PhoneEntryPage` | REAL (API Auth) | FULL (DDS) | Full validation + spinner | **P2** | Real OTP generation trigger. Polish country code selector and keypad interactions. |
| `/auth/otp` | `OtpVerificationPage` | REAL (API Auth) | FULL (DDS) | Full validation + timer | **P1** | Real OTP verification. 100% redacted in logs/UI. Ensure auto-submit on 6-digit autofill. |
| `/auth/register` | `RegisterPage` | REAL (API Auth) | FULL (DDS) | Form validation | **P2** | Creates new customer user profile in PostgreSQL backend. |
| `/home` | `HomePage` | REAL (ApiHomeRepo) | FULL (Modern DDS) | Skeleton loader + Empty fallback | **P2** | Modernized in Phase 29.1. Integrates geolocation, banners, top vendors, and date selector. Minor polish on city change dialog. |
| `/search` | `SearchResultsPage` | REAL (ApiSearchRepo) | FULL (Modern DDS) | Filter sheets + Empty state | **P1** | Date-first search works with real cars. However, **Pickup/Drop location is passed as an unstructured string** rather than a `VendorLocation` ID. |
| `/car/:id` | `CarDetailPage` | REAL (ApiCarDetailRepo) | FULL (Modern DDS) | Full shimmer + Error retry | **P2** | Real specifications, pricing calculator, mileage packages, and vendor reputation card. |
| `/booking/:carId` | `BookingFlowPage` (5-step) | REAL / HYBRID | FULL (Modern DDS) | Step indicator + sticky bottom bar | **P1** | **Architectural Gap:** Trip details card uses string-based `LocationSelectionSheet`. Does not invoke `/locations/quote` to compute live doorstep delivery or inter-branch relocation surcharges. |
| `/booking/confirmation/:id` | `BookingConfirmationPage` | REAL (ApiBookingRepo) | FULL (Modern DDS) | Success animation + card | **P2** | Displays confirmed booking reference, instructions, and OTP handover readiness. |
| `/bookings` | `MyBookingsPage` | REAL (ApiMyBookingsRepo) | FULL (Modern DDS) | Tabbed (Active/Past) + Empty states | **P2** | Real customer booking history fetched from NestJS backend. |
| `/bookings/:id` | `BookingDetailPage` | REAL (ApiMyBookingsRepo) | FULL (Modern DDS) | Dynamic status tracking | **P1** | Includes OTP security card (masked), cancellation, and support links. Handover cards need enrichment with dynamic vendor location GPS directions. |
| `/profile` | `ProfilePage` | REAL (ApiProfileRepo) | FULL (Modern DDS) | User stats + action rows | **P2** | Modern card layout with profile editing, avatar, and sub-page navigation. |
| `/kyc` | `KycUploadPage` | REAL (ApiKycRepo) | FULL (Modern DDS) | Document capture + status | **P1** | Driving licence / Aadhaar document upload. Real multipart file upload to backend. |
| `/wallet` | `WalletPage` | HYBRID | FULL (Modern DDS) | Transaction ledger + top-up | **P0** | **Mock Payment Fallback:** Lines 215-220 contain simulated Razorpay payment signature generation (`pay_mock_...`) when live gateway is disabled. Needs strict gateway production mode. |
| `/loyalty` | `LoyaltyPage` | REAL (ApiLoyaltyRepo) | FULL (Modern DDS) | Tier progress + perks card | **P2** | Real points balance, tier status (Bronze/Silver/Gold/Platinum), and redemption to wallet. |
| `/referral` | `ReferralPage` | REAL (ApiReferralRepo) | FULL (Modern DDS) | Copy code + rewards tracker | **P2** | Real referral attribution tracking and earnings ledger. |
| `/wishlist` | `WishlistPage` | REAL (ApiWishlistRepo) | FULL (Modern DDS) | Grid view + remove action | **P2** | Real car wishlist persistence in backend. |
| `/notifications` | `NotificationsPage` | REAL (ApiNotifRepo) | FULL (Modern DDS) | Category filters + mark read | **P2** | Real notification inbox with category filters (Booking, Payment, Trip, System). |
| `/support` | `SupportCenterPage` | REAL (ApiSupportRepo) | FULL (Modern DDS) | Ticket history + FAQ | **P2** | Real support ticket creation and status tracking. |
| `/support/create` | `CreateTicketPage` | REAL (ApiSupportRepo) | FULL (Modern DDS) | Category & priority picker | **P2** | Real ticket submission form with attachment capability. |
| `/support/tickets/:id` | `TicketDetailPage` | REAL (ApiSupportRepo) | FULL (Modern DDS) | Real-time chat bubbles | **P2** | Real two-way message exchange with support agents. |
| `/location/select` | `LocationSelectionSheet` | MOCK / HYBRID | PARTIAL (MVP) | Search list + GPS detect | **P0** | **Hardcoded City Hubs:** Contains static string array `_cityPopularHubs` (lines 62-111) instead of querying `/locations/public/catalog` or active vendor locations from backend. |

---

## 3. Vendor App Audit Matrix (19 Routes)

| Route Path | Page / Screen Name | Data Source (Real/Mock/Hybrid) | DDS Compliance | Loading / Empty / Error States | Priority | Detailed Findings & Recommended Remediation |
|---|---|---|---|---|---|---|
| `/splash` | `VendorSplashPage` | REAL (Session check) | FULL (DDS) | Handled | **P3** | Smooth vendor authentication check and routing. |
| `/auth/phone` | `VendorPhoneEntryPage` | REAL (API Auth) | FULL (DDS) | Form validation | **P2** | Real phone number submission for vendor role. |
| `/auth/otp` | `VendorOtpVerificationPage` | REAL (API Auth) | FULL (DDS) | 100% Redacted | **P1** | Real vendor OTP verification. Ensure error toasts display specific server error messages. |
| `/register` | `VendorRegistrationPage` | REAL (API Auth) | FULL (DDS) | Multi-step form | **P2** | Business name, GST, PAN, and bank details registration. |
| `/pending-approval` | `PendingApprovalPage` | REAL (Status Check) | FULL (DDS) | Pending animation | **P2** | Displays verification status. Replace `(TODO)` support snackbar with real support routing. |
| `/dashboard` | `VendorDashboardPage` | REAL (ApiDashboardRepo) | FULL (Modern DDS) | Metric cards + Triage queue | **P1** | Actionable triage queue, revenue charts, and operational quick actions. Summary endpoint has hardcoded fallback counts if zero bookings exist. |
| `/bookings` | `VendorBookingsPage` | REAL (ApiBookingsRepo) | FULL (Modern DDS) | Filter chips + Card list | **P2** | Real vendor bookings list categorized by status (Pending, Confirmed, Ongoing, Completed). |
| `/bookings/:id` | `VendorBookingDetailPage` | REAL (ApiBookingsRepo) | FULL (Modern DDS) | Handover inspection CTA | **P1** | Rich pickup/drop-off navigation cards added in Phase 29.11. Displays customer handover OTP entry button. |
| `/bookings/:id/handover` | `HandoverInspectionPage` | REAL (ApiInspectionRepo) | FULL (Modern DDS) | 4-photo capture + Odometer | **P1** | Monotonic odometer validation, fuel gauge slider, 4-photo inspection, and customer pickup OTP verification. |
| `/bookings/:id/return` | `ReturnInspectionPage` | REAL (ApiInspectionRepo) | FULL (Modern DDS) | Damage check + Settlement | **P1** | Post-trip inspection, damage claim creation, fuel shortfall calculation, and return OTP verification. |
| `/fleet` | `VendorFleetPage` | REAL (ApiFleetRepo) | FULL (Modern DDS) | Search + Status drawer | **P2** | Real vehicle fleet cards, availability toggle with safety confirmation dialog. |
| `/fleet/add` | `FastAddVehicleWizardPage` | REAL (ApiFleetRepo) | FULL (Modern DDS) | 6-Step guided wizard | **P2** | Fast add vehicle with make, model, year, category, mileage packages, and photo uploads. |
| `/fleet/bulk-upload` | `CsvBulkUploadPage` | REAL (ApiFleetRepo) | FULL (Modern DDS) | CSV parser + Data grid | **P2** | Client-side CSV validation and batch API upload. |
| `/fleet/:id` | `VehicleDetailPage` | REAL (ApiFleetRepo) | FULL (Modern DDS) | Specs + Pricing tiers | **P2** | Vehicle specifications, dynamic pricing adjustment, and hub assignment selector. |
| `/locations` | `VendorLocationSettingsPage` | HYBRID | FULL (Modern DDS) | Mode selector + Hub cards | **P0** | **Silent Failures & Fallbacks:** Initial state loads static mock locations (`loc_hyd_main_yard` etc.). Calls `/locations/vendors/me/delivery-policy` (404 mismatch) and silently swallows errors in `catch (_)`. |
| `/locations/add` | `AddLocationWizardPage` | HYBRID | FULL (Modern DDS) | 8-Step guided wizard | **P1** | Rich 8-step wizard. Saves location via API, but backend packs all capabilities into JSON string `operatingHours`. |
| `/locations/:id` | `LocationDetailPage` | HYBRID | FULL (Modern DDS) | Branch dashboard + Cars | **P1** | Displays branch stats, hours, fees, and assigned fleet. Update uses `PATCH` instead of backend `PUT`. |
| `/earnings` | `VendorEarningsPage` | REAL (ApiEarningsRepo) | FULL (Modern DDS) | Payout cards + Breakdown | **P2** | Real earnings breakdown, pending payout requests, and bank account management. |
| `/profile` | `VendorProfilePage` | REAL (ApiProfileRepo) | FULL (Modern DDS) | KYC docs + Settings | **P2** | Business information, trade licence, RC uploads, operating settings, and logout. |

---

## 4. Admin Panel Audit Matrix (22 Routes)

| Route Path | Feature Page Name | Operational Domain | UX Structure (Control Tower vs MVP) | Filter / Search / Pagination | Priority | Detailed Findings & Recommended Remediation |
|---|---|---|---|---|---|---|
| `/dashboard` | `AdminDashboardPage` | EXECUTIVE | MVP Layout | Date filter, metric cards | **P1** | Executive KPI cards (GMV, active trips, fleet utilization). Needs modernization into unified Control Tower executive summary. |
| `/vendors` | `VendorManagementPage` | OPERATIONS & FLEET | Basic Data Table | Search + Status filter | **P1** | Vendor KYC verification, tier management, and branch overview. Needs slide-over detail drawer instead of full-page navigation. |
| `/customers` | `CustomerManagementPage` | CUSTOMER CARE | Basic Data Table | Search + Ban toggle | **P1** | Line 186 has hardcoded mock join date (`15 Jan 2026`). Real customer list from backend, but missing KYC document inspection modal. |
| `/bookings` | `AdminBookingManagementPage` | OPERATIONS & FLEET | Basic Data Table | Status filter + Search | **P1** | Real booking list. Lacks unified booking fulfillment snapshot inspection tab. |
| `/fleet` | `AdminFleetOverviewPage` | OPERATIONS & FLEET | Basic Data Table | Make/Model filter | **P2** | Lines 399-413 have placeholder photo galleries. Real fleet list with verification approval toggle. |
| `/support-tickets` | `AdminSupportTicketsPage` | CUSTOMER CARE | Two-pane Layout | Priority filter + Assignee | **P1** | Real-time support ticket triage and agent assignment. Modernization needed for chat bubble styling. |
| `/emergency-dispatch` | `AdminEmergencyDispatchPage` | CUSTOMER CARE | Map + Incident List | Live status chips | **P1** | Emergency SOS dispatch console. Real incidents, provider dispatching, and resolution workflow. |
| `/disputes` | `AdminDisputesPage` | CUSTOMER CARE | Data Table + Modal | Status filter | **P2** | Security deposit disputes and damage claim evidence inspection. |
| `/commission` | `CommissionSettingsPage` | FINANCE & SETTLEMENTS | Form Card | Tier commission inputs | **P2** | Configures platform commission percentages per tier (Basic vs Pro). Real backend persistence. |
| `/revenue` | `RevenueReportsPage` | FINANCE & SETTLEMENTS | Charts + Summary | Date range picker | **P2** | Platform net revenue, vendor payouts ledger, and GST reconciliation reports. |
| `/invoices` | `AdminInvoicesPage` | FINANCE & SETTLEMENTS | Data Table + PDF link | Invoice search | **P2** | Real invoice generation, tax breakdown, and credit note issuance. |
| `/banners` | `BannersPromotionsPage` | GROWTH & MARKETING | Card Grid + Modal | City & type filters | **P2** | Banner image uploads, action URL linking, and priority sorting. |
| `/coupons` | `AdminCouponsPage` | GROWTH & MARKETING | Data Table + Create form | Code search + Status | **P2** | Discount coupon creation, validity rules, and usage tracking. |
| `/referrals` | `AdminReferralCampaignsPage` | GROWTH & MARKETING | Metric Cards + Table | Reward rules | **P2** | Referral reward rule configuration and fraud blocker flags. |
| `/loyalty` | `AdminLoyaltyManagementPage` | GROWTH & MARKETING | Tier Editor | Points multiplier | **P2** | Configures points-to-rupee conversion rates and tier thresholds. |
| `/notifications` | `PushNotificationsPage` | GROWTH & MARKETING | Campaign Form + Mock preview | Target role picker | **P2** | Broadcasts push notifications to customers or vendors via FCM. |
| `/whatsapp` | `AdminWhatsAppPage` | GROWTH & MARKETING | Template Table | Template preview | **P2** | WhatsApp notification templates and message logs. |
| `/audit-log` | `AdminAuditLogPage` | SECURITY / GOVERNANCE | Data Table + JSON viewer | Entity & Actor search | **P1** | Structured audit trail of privileged admin actions. Needs dedicated filters for Location & Fulfillment mutations. |
| `/fraud` | `AdminFraudPage` | SECURITY / GOVERNANCE | Risk Table | Severity chips | **P1** | Flagged accounts, velocity violations, and banned device identifiers. |
| `/protection-packages` | `AdminProtectionPackagesPage` | SECURITY / GOVERNANCE | Package Cards | Deductible inputs | **P2** | Configures insurance protection tiers (Basic, Standard, Premium, Zero-Dep). |
| `/supported-cities` | `SupportedCitiesPage` | OPERATIONS & FLEET | Simple Table + Modal | City status toggle | **P2** | Adds new operational cities, coordinates, and operational status. |
| `/locations` | `OperationalMapPage` | OPERATIONS & FLEET | Map View | Layer toggles | **P0** | **Missing Location Control Tower:** Currently only displays a basic Google map of hubs. Lacks vendor location review queue, moderation drawer, and one-way matrix inspection. |

# DRIVEGO — PHASE 29.8 ARCHITECTURAL & API AUDIT
**VENDOR PARTNER APP: OPERATIONS DASHBOARD & ACTIONABLE TRIAGE CENTER**

---

## 1. Executive Context & Scope
The goal of Phase 29.8 is to transform the Vendor Partner App dashboard from a basic administrative screen into a real-time **Car Rental Operations Operating System (OS)** and **Actionable Triage Center**. The vendor dashboard must immediately answer: *"What do I need to do right now?"* while providing live operational snapshots for Bookings, Today's Schedule, Fleet Status, Earnings, and Support.

---

## 2. API & Data Flow Mapping

### Screen → Provider → Repository → Backend Endpoint → Database Model

| UI Component / Section | Riverpod Provider | Repository Method | Backend REST API | Database Models Involved |
| :--- | :--- | :--- | :--- | :--- |
| **Vendor Header & Health** | `vendorSessionProvider` | `VendorSessionNotifier` | `/vendors/me` | `Vendor`, `User` |
| **Operational Triage / Actions** | `vendorOperationsTriageProvider` | `DashboardRepository.getOperationsTriage` | `/vendors/me/bookings`, `/vendors/me/cars`, `/vendors/me/earnings/summary` | `Booking`, `Car`, `Payout`, `Document` |
| **Booking Snapshot Matrix** | `vendorBookingMatrixProvider` | `DashboardRepository.getBookingMatrix` | `/vendors/me/bookings` | `Booking` (statuses: PENDING, CONFIRMED, ONGOING, COMPLETED) |
| **Today's Operations Timeline**| `vendorTodayOperationsProvider` | `DashboardRepository.getTodayOperations` | `/vendors/me/bookings` | `Booking` (startDate / endDate matching today) |
| **Vehicle Fleet Snapshot** | `vendorFleetSummaryProvider` | `DashboardRepository.getFleetSummary` | `/vendors/me/cars` | `Car` (`isAvailable`, `blockedDates`, `type`) |
| **Earnings & Financial Overview**| `dashboardStatsProvider`, `earningsSummaryProvider` | `DashboardRepository.getStats`, `EarningsRepository.getSummary` | `/vendors/me/earnings/summary` | `Booking` (`netToVendor`, `platformFee`), `Payout` |
| **Document Compliance Alerts** | `vendorExpiringDocumentsProvider` | `DocumentsRepository.getDocuments` | `/vendors/me/documents` | `Document` (`status`, `expiresAt`) |
| **Support & Dispute Entry** | `vendorSupportSummaryProvider` | `SupportRepository.getMyTickets` | `/support/tickets/:id`, `/disputes/:id` | `SupportTicket`, `Dispute` |

---

## 3. Operations Priority & Triage Hierarchy

1. **URGENT**:
   - Incoming booking requests pending confirmation (`BookingStatus.PENDING`).
   - Customer disputes or damage claims requiring immediate vendor response.
2. **HIGH**:
   - Pickups approaching within the next 2 hours (`CONFIRMED` / `HANDOVER_READY`).
   - Returns approaching / overdue (`ONGOING` / `RETURN_PENDING`).
3. **TODAY**:
   - Scheduled vehicle handovers and returns for the current calendar date.
   - Expiring vehicle documents (RC, Insurance, Trade License within 7 days).
4. **UPCOMING**:
   - Confirmed future bookings scheduled for upcoming days.
5. **INFORMATIONAL / FINANCIAL**:
   - Unavailable / maintenance vehicles in fleet.
   - Pending settlement payout balance held in 2-day verification window.

When zero actionable items exist, the dashboard displays the **"You're All Caught Up"** operational stability banner with a checklist of active safeguards.

---

## 4. Design System (DDS) Alignment
The modernized dashboard implements standard DDS design tokens:
- **Colors**: `DDSColors.primaryNavy` (#0B192C), `DDSColors.primaryBlue` (#1E3E62 / #0066FF), `DDSColors.bgCanvas` (#F8FAFC), `DDSColors.surfaceCard` (#FFFFFF), `DDSColors.successGreen`, `DDSColors.warningOrange`, `DDSColors.errorRed`.
- **Typography**: `DDSTypography` (Plus Jakarta Sans scale: `headlineMedium`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMedium`, `labelLarge`, `labelSmall`, `priceDisplay`).
- **Spacing & Radius**: `DDSSpacing.sm` (8px), `DDSSpacing.md` (16px), `DDSSpacing.lg` (24px), `DDSRadius.mediumBorderRadius` (12px), `DDSRadius.largeBorderRadius` (16px).
- **Accessibility**: High contrast ratios compliant with WCAG AA standards and touch targets >= 48dp.

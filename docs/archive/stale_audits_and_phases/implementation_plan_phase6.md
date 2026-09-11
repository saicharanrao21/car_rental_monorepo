# DRIVEGO PHASE 6 IMPLEMENTATION PLAN
**Scope:** Customer Support (Feature 15) + Roadside / Emergency Assistance (Feature 16) + Insurance / Protection Presentation (Feature 17)
**Target:** Production-Ready End-to-End Implementation Across DB, Backend, Mobile Apps, Admin Panel, Tests & Documentation

---

## 1. Architectural Blueprint & Phased Execution

### Phase 6A: Database Schema & Formal Prisma Migration
1. **New Enums:**
   - `TicketCategory` (`BOOKING`, `PAYMENT`, `REFUND`, `SECURITY_DEPOSIT`, `VEHICLE`, `PICKUP_DELIVERY`, `KYC_LICENCE`, `TRIP_EXTENSION`, `DAMAGE_DISPUTE`, `EMERGENCY`, `OTHER`)
   - `TicketPriority` (`LOW`, `NORMAL`, `HIGH`, `URGENT`)
   - `TicketStatus` (`OPEN`, `ASSIGNED`, `IN_PROGRESS`, `WAITING_FOR_CUSTOMER`, `WAITING_FOR_VENDOR`, `RESOLVED`, `CLOSED`)
   - `IncidentType` (`ACCIDENT`, `BREAKDOWN`, `FLAT_TYRE`, `BATTERY`, `LOCKOUT`, `FUEL_EMERGENCY`, `ENGINE_ISSUE`, `TOWING_REQUIRED`, `MEDICAL_EMERGENCY`, `OTHER`)
   - `EmergencyStatus` (`REQUESTED`, `ACKNOWLEDGED`, `ASSIGNED`, `PROVIDER_EN_ROUTE`, `CUSTOMER_CONTACTED`, `ON_SITE`, `RESOLVED`, `CANCELLED`)
   - `ProtectionPlanCode` (`BASIC`, `STANDARD`, `PREMIUM`, `ZERO_DEP`)
2. **New Models:**
   - `SupportTicket` & `TicketMessage`
   - `EmergencyRequest`
   - `ProtectionPackage`
3. **Model Modifications:**
   - `Booking`: Add `protectionPackageId`, `protectionCode`, `protectionFee`, `protectionDeductible`.
   - `Invoice`: Add `protectionFee`.
4. **Formal SQL Migration:**
   - Create `20260816150000_add_support_emergency_protection/migration.sql` and apply to database.

---

### Phase 6B: Backend Services & REST Controllers
1. **`SupportTicketsModule` (`src/support/`):**
   - `SupportTicketsService`: `createTicket`, `getMyTickets`, `getTicketById`, `replyTicket`, `updateTicketStatus`, `assignTicket`, `closeTicket`, `reopenTicket`.
   - `SupportTicketsController`: Customer & Admin endpoints with RBAC (`CUSTOMER`, `SUPPORT_AGENT`, `ADMIN`), IDOR protection, and state machine transition guards.
2. **`EmergencyAssistanceModule` (`src/emergency/`):**
   - `EmergencyAssistanceService`: `createRequest`, `getActiveRequestForBooking`, `getAllRequests`, `getVendorRequests`, `updateRequestStatus`, `assignProvider`, `resolveRequest`.
   - Rate limiting, duplicate SOS prevention on active bookings, push notification dispatch to Admin & Vendor.
   - `EmergencyAssistanceController`: Customer, Vendor, and Admin REST endpoints.
3. **`ProtectionPackagesModule` (`src/protection/`):**
   - `ProtectionPackagesService`: `getActivePackages`, `createPackage`, `updatePackage`, `togglePackageActive`.
   - `ProtectionPackagesController`: Public listing and Admin management endpoints.
4. **`BookingsService.createBooking` & `InvoicesService` Updates:**
   - Ingest `protectionPackageId`, compute authoritative `protectionFee`, add to `totalFare`, generate invoice line item.

---

### Phase 6C: Shared Dart Models & Core UI Packages
1. Update `packages/models/` with:
   - `SupportTicketModel`, `TicketMessageModel`
   - `EmergencyRequestModel`
   - `ProtectionPackageModel`
   - Update `BookingModel` & `InvoiceModel` with protection fields.

---

### Phase 6D: Customer App UX
1. **Customer Support Hub (`apps/customer_app/lib/features/support/`):**
   - `SupportCenterPage`: Categorized FAQ accordion + "Create Ticket" floating action + "My Support Tickets" list.
   - `CreateTicketPage`: Category selector, booking link picker, subject & description inputs, attachment upload.
   - `TicketDetailPage`: Conversation timeline, sender role badges, customer reply composer, Close/Reopen actions.
2. **Emergency Assistance / SOS (`BookingDetailPage`):**
   - Prominent red **"Emergency Assistance (SOS)"** action on active/ongoing bookings.
   - Confirmation dialog with warning, incident type selection (`Flat Tyre`, `Breakdown`, `Accident`, etc.), optional notes.
   - Live Emergency Status Card on `BookingDetailPage` tracking ETA, assigned provider, and contact status.
3. **Protection Packages Selection (`AddonsStep`):**
   - Interactive protection tier comparison cards (`BASIC` Included, `STANDARD` +₹250/day, `PREMIUM Zero-Dep` +₹500/day).
   - Real-time deductible limits and coverage summaries.

---

### Phase 6E: Vendor App & Admin Panel UX
1. **Vendor App (`VendorBookingDetailPage`):**
   - Roadside Incident Notification banner for vendor vehicles during active rentals.
2. **Admin Panel (`AdminSupportPage`, `AdminEmergencyPage`, `AdminProtectionPackagesPage`):**
   - Tabbed Support Ticket inbox with filtering, priority sorting, agent assignment, and internal notes.
   - Emergency Dispatch queue with high-priority visual alerting, provider assignment, and status timeline.
   - Protection Package configuration interface for setting rates, deductibles, and city applicability.

---

### Phase 6F: Automated Tests & Verification
1. **Backend Unit Tests:**
   - `support-tickets.spec.ts` (creation, IDOR checks, state machine transitions, internal notes filtering).
   - `emergency-assistance.spec.ts` (SOS submission, duplicate prevention, vendor isolation, provider assignment).
   - `protection-packages.spec.ts` (pricing calculation, booking snapshot, invoice line item, city override).
2. **Regression & Safety Checks:**
   - `npx prisma validate` & `npm run build`
   - `npm test` (all suites passing)
   - `flutter analyze lib` & `flutter test`
   - `node scratch/check_db_safety.js` (Benchmark booking `cmsu5sk3m000qgw1zaf9ftksz` remains `CONFIRMED / PAID / NONE`).

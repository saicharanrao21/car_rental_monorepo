# DRIVEGO — PHASE 6 PRE-IMPLEMENTATION AUDIT REPORT
**Scope:** Feature 15 (Customer Support) + Feature 16 (Roadside / Emergency Assistance) + Feature 17 (Insurance / Protection Presentation)
**Audit Date:** August 16, 2026
**Checkpoint Commit:** `ed79f4b`
**Benchmark Safety Status:** `cmsu5sk3m000qgw1zaf9ftksz` (`CONFIRMED` / `PAID` / `NONE` — 100% Intact)

---

## 1. Feature 15: Customer Support Audit

### A. Current State
- **Database:** No dedicated `SupportTicket` or `TicketMessage` models in `prisma/schema.prisma`.
- **Backend:** `Role.SUPPORT_AGENT` enum value exists in `Role` enum, but no `SupportTicketsModule` or service exists.
- **Customer App:** Static FAQ list in `ProfilePage` (`_HelpSupportSection`); no interactive ticketing, categories, attachment uploads, or live conversation threads.
- **Admin Panel:** No ticket inbox or support agent queue.

### B. Gap Analysis
- **Missing:**
  1. `SupportTicket` and `TicketMessage` Prisma models with foreign keys to `User`, `Booking`, and `SupportTicket`.
  2. `TicketCategory` (`BOOKING`, `PAYMENT`, `REFUND`, `SECURITY_DEPOSIT`, `VEHICLE`, `PICKUP_DELIVERY`, `KYC_LICENCE`, `TRIP_EXTENSION`, `DAMAGE_DISPUTE`, `EMERGENCY`, `OTHER`).
  3. `TicketPriority` (`LOW`, `NORMAL`, `HIGH`, `URGENT`).
  4. `TicketStatus` state machine (`OPEN`, `ASSIGNED`, `IN_PROGRESS`, `WAITING_FOR_CUSTOMER`, `WAITING_FOR_VENDOR`, `RESOLVED`, `CLOSED`) with server-side transition guards.
  5. Internal staff notes flag (`isInternal: Boolean`) hidden from customers.
  6. Customer Support ticketing UI in `customer_app` (Ticket creation with booking link, ticket detail message thread, status updates).
  7. Admin support dashboard in `admin_panel` (Filterable queues, agent assignment, reply composer, internal notes).

### C. Classification: **MISSING BACKEND & INTERACTIVE UI (PARTIAL $\rightarrow$ FULL IMPLEMENTATION NEEDED)**

---

## 2. Feature 16: Roadside / Emergency Assistance Audit

### A. Current State
- **Database:** No dedicated `EmergencyRequest` model in `prisma/schema.prisma`.
- **Backend:** No emergency SOS dispatch engine or incident escalation service.
- **Customer App:** Emergency SOS phone link in `BookingDetailPage` / `PlatformSettings`.
- **Vendor App:** No roadside incident visibility on active vehicles.
- **Admin Panel:** No emergency dispatcher queue.

### B. Gap Analysis
- **Missing:**
  1. `EmergencyRequest` model with fields for `requestNumber`, `incidentType` (`ACCIDENT`, `BREAKDOWN`, `FLAT_TYRE`, `BATTERY`, `LOCKOUT`, `FUEL_EMERGENCY`, `ENGINE_ISSUE`, `TOWING_REQUIRED`, `MEDICAL_EMERGENCY`, `OTHER`), `urgency`, `status` (`REQUESTED`, `ACKNOWLEDGED`, `ASSIGNED`, `PROVIDER_EN_ROUTE`, `CUSTOMER_CONTACTED`, `ON_SITE`, `RESOLVED`, `CANCELLED`), vehicle metadata, coordinates, contact notes, and provider details.
  2. Controlled state machine with duplicate SOS prevention per booking.
  3. Customer App SOS modal with confirmation warning, incident picker, and live status tracker.
  4. Vendor App emergency incident card restricted strictly to `emergency.vendorId === user.vendor.id`.
  5. Admin Emergency Dispatcher queue with high-priority visual alerting and provider assignment.

### C. Classification: **MISSING BACKEND & INTERACTIVE UI (PARTIAL $\rightarrow$ FULL IMPLEMENTATION NEEDED)**

---

## 3. Feature 17: Insurance / Protection Presentation Audit

### A. Current State
- **Database:** `Booking` model has no protection package relation; `Car` has general specifications.
- **Backend:** Fare calculation in `BookingsService` computes base rental, platform fee, GST, and delivery add-ons, but lacks protection plan resolution.
- **Customer App:** Basic insurance disclosure text in `CarDetailPage`; no selectable protection tier cards (`BASIC`, `STANDARD`, `PREMIUM`, `ZERO_DEP`).

### B. Gap Analysis
- **Missing:**
  1. `ProtectionPackage` Prisma model (`name`, `code`, `dailyRate`, `coverageSummary`, `deductibleAmount`, `maxCoverageAmount`, `exclusions`, `termsUrl`, `city`, `isActive`, `displayOrder`).
  2. `Booking` foreign keys: `protectionPackageId`, `protectionCode`, `protectionFee`, `protectionDeductible`.
  3. `Invoice` line item: `protectionFee`.
  4. Authoritative server calculation in `BookingsService.createBooking` multiplying daily protection rate $\times$ rental days and adding to `totalFare`.
  5. Customer App interactive protection selection cards in `AddonsStep` / `BookingFlowPage`.
  6. Admin Panel protection package manager (`AdminProtectionPackagesPage`).

### C. Classification: **MISSING MODELS & PRICING ENGINE (PARTIAL $\rightarrow$ FULL IMPLEMENTATION NEEDED)**

---

## 4. Pre-Implementation Safety Invariants

1. **Benchmark Booking:** `cmsu5sk3m000qgw1zaf9ftksz` will remain completely untouched.
2. **Financial Isolation:** Protection fees must be separate line items; coupons must NOT reduce security deposits; invoices must remain point-in-time immutable.
3. **Multi-City Isolation:** Protection packages, support tickets, and emergency requests must respect city boundaries without hardcoded city names.
